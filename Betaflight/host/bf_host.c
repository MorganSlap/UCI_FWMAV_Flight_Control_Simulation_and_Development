/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Deterministic process boundary for the upstream Betaflight SITL target.
 * The original initialization, scheduler, receiver, filters, estimator,
 * controllers, arming logic and mixer execute inside this process.
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

#include "platform.h"
#include "bf_host.h"
#include "common/maths.h"
#include "drivers/accgyro/accgyro_virtual.h"
#include "drivers/barometer/barometer_virtual.h"
#include "drivers/compass/compass_virtual.h"
#include "sensors/gyro.h"
#include "flight/imu.h"
#include "flight/pid.h"
#include "flight/mixer.h"
#include "fc/rc.h"
#include "fc/runtime_config.h"
#include "rx/rx.h"
#include "pg/rx.h"
#include "io/gps_virtual.h"
#include "scheduler/scheduler.h"
#include "dyad.h"

#define BF_HOST_MAGIC 20261011.0
#define BF_HOST_VERSION 1.0
#define BF_HOST_REQUEST_WORDS 52
#define BF_HOST_RESPONSE_WORDS 40
#define BF_HOST_QUANTUM_US 10U
#define BF_HOST_MAX_TASKS_PER_TICK 512U
#define BF_HOST_PI 3.14159265358979323846
#define BF_HOST_RAD_TO_DEG (180.0 / BF_HOST_PI)
#define BF_HOST_DEG_TO_RAD (BF_HOST_PI / 180.0)
#define BF_HOST_G 9.80665
#define BF_HOST_RC_NEW 8U

enum { HOST_OK, HOST_BAD_PROTOCOL, HOST_BAD_TIME, HOST_BAD_VALUE,
    HOST_NOT_READY, HOST_STEP_TOO_LARGE, HOST_SCHEDULER_LIVELOCK };

static uint64_t hostTimeUs;
static uint64_t hostEpochUs;
static uint64_t taskCount;
static uint64_t tickCount;
static double lastRequestTime;
static double lastSequence = -1;
static float motorPwm[4] = {1000, 1000, 1000, 1000};
static uint16_t hostPort = 9005;
static int listenSocket = -1;
static int clientSocket = -1;
static bool haveSample;
static bool runStarted;
static double heldRequest[BF_HOST_REQUEST_WORDS];

static int16_t sensorCount(double value)
{
    /* Explicit bounds also work with upstream -Ofast (which folds isfinite). */
    if (value > 32767) value = 32767;
    if (value < -32767) value = -32767;
    return (int16_t)lrint(value);
}

/* IEEE-754 exponent test must not depend on -ffinite-math-only semantics. */
static bool finiteDouble(double value)
{
    uint64_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return (bits & UINT64_C(0x7ff0000000000000)) != UINT64_C(0x7ff0000000000000);
}

uint64_t bfHostMicros(void) { return hostTimeUs; }

void bfHostDelayUs(uint64_t duration)
{
    /* Device startup delays advance simulated time without sleeping. */
    hostTimeUs += duration;
}

void bfHostNoteTask(void) { taskCount++; }

void bfHostWriteMotor(uint8_t index, float pwm)
{
    if (index < 4) motorPwm[index] = pwm;
}

bool bfHostParseArgument(int argc, char **argv, int *index)
{
    if (strcmp(argv[*index], "--host-port") != 0) return false;
    if (*index + 1 >= argc) {
        fprintf(stderr, "[BFHOST] --host-port requires a TCP port\n");
        exit(2);
    }
    char *end = NULL;
    const long port = strtol(argv[++*index], &end, 10);
    if (!end || *end || port < 1024 || port > 65535) {
        fprintf(stderr, "[BFHOST] host port must be an integer from 1024 through 65535\n");
        exit(2);
    }
    hostPort = (uint16_t)port;
    return true;
}

void bfHostInit(void)
{
    hostTimeUs = 0;
    taskCount = 0;
    tickCount = 0;
    signal(SIGPIPE, SIG_IGN);
    /* serial_tcp opens its dyad streams during ordinary firmware init.
       There is no background TCP worker in host mode. */
    dyad_init();
    dyad_setUpdateTimeout(0.0);
    atexit(bfHostShutdown);
}

void bfHostShutdown(void)
{
    if (clientSocket >= 0) { close(clientSocket); clientSocket = -1; }
    if (listenSocket >= 0) { close(listenSocket); listenSocket = -1; }
}

static void feedIMU(const double *request)
{
    /* Port convention: aircraft body FRD. The Mahony path consumes these
       body rates with the same signs; Euler heading is negated on output.
       Specific force is -g on body Z at level rest. No truth quaternion is
       passed to imuSetAttitude*; the real estimator consumes these sensors. */
    virtualGyroSet(virtualGyroDev,
        sensorCount(request[5] * BF_HOST_RAD_TO_DEG / (double)virtualGyroDev->scale),
        sensorCount(request[6] * BF_HOST_RAD_TO_DEG / (double)virtualGyroDev->scale),
        sensorCount(request[7] * BF_HOST_RAD_TO_DEG / (double)virtualGyroDev->scale));
    virtualAccSet(virtualAccDev,
        sensorCount(-request[8] * 256.0 / BF_HOST_G),
        sensorCount(-request[9] * 256.0 / BF_HOST_G),
        sensorCount(-request[10] * 256.0 / BF_HOST_G));
}

static void feedAuxiliary(const double *request)
{
    const unsigned flags = (unsigned)request[39];
    if (flags & BF_HOST_RC_NEW) {
        uint16_t channels[16];
        for (unsigned i = 0; i < 16; i++) channels[i] = (uint16_t)lrint(request[11 + i]);
        if (flags & (16U | 32U)) {
            const double *reference = request + 40;
            const double signs[3] = {1, 1, 1};
            for (unsigned axis = 0; axis < 3; axis++) {
                float desiredRate;
                if ((flags & 16U) && axis < 2) {
                    desiredRate = bfHostAngleToRate(axis, reference[6+axis] * signs[axis] * BF_HOST_RAD_TO_DEG);
                } else {
                    desiredRate = reference[9+axis] * signs[axis] * BF_HOST_RAD_TO_DEG;
                }
                const uint8_t rawChannel = rxConfig()->rcmap[axis];
                if (rawChannel < 16) channels[rawChannel] = bfHostRateToPwm(axis, desiredRate);
            }
        }
        rxUpdateUdpChannels(channels, 16);
    }
    const double *x = request + 27; /* N E D u v w phi theta psi p q r */
#ifdef USE_VIRTUAL_BARO
    if (flags & 1U) {
        const double altitude = -x[2];
        double base = 1.0 - 2.25577e-5 * altitude;
        if (base < 0.01) base = 0.01;
        virtualBaroSet((int32_t)(101325.0 * pow(base, 5.25588)), 2500);
    }
#endif
#ifdef USE_VIRTUAL_MAG
    if (flags & 2U) {
        /* Ideal physical magnetometer: rotate fixed NED Earth field into
           body FRD, then onto BF sensor axes. This is a sensor model, never
           an estimator reset. Default nav flags leave it disabled. */
        const double cr = cos(x[6]), sr = sin(x[6]);
        const double cp = cos(x[7]), sp = sin(x[7]);
        const double cy = cos(x[8]), sy = sin(x[8]);
        const double north = 2048.0, east = 0.0, down = 3547.0;
        const double bx = cp*cy*north + cp*sy*east - sp*down;
        const double by = (sr*sp*cy-cr*sy)*north + (sr*sp*sy+cr*cy)*east + sr*cp*down;
        const double bz = (cr*sp*cy+sr*sy)*north + (cr*sp*sy-sr*cy)*east + cr*cp*down;
        virtualMagSet(sensorCount(bx), sensorCount(-by), sensorCount(-bz));
    }
#endif
#ifdef USE_VIRTUAL_GPS
    if (flags & 4U) {
        const double cr = cos(x[6]), sr = sin(x[6]);
        const double cp = cos(x[7]), sp = sin(x[7]);
        const double cy = cos(x[8]), sy = sin(x[8]);
        const double vn = cp*cy*x[3] + (sr*sp*cy-cr*sy)*x[4] + (cr*sp*cy+sr*sy)*x[5];
        const double ve = cp*sy*x[3] + (sr*sp*sy+cr*cy)*x[4] + (cr*sp*sy-sr*cy)*x[5];
        const double vd = -sp*x[3] + sr*cp*x[4] + cr*cp*x[5];
        const double lat0 = 33.6405, lon0 = -117.8443;
        const double latitude = lat0 + x[0] / 6378137.0 * BF_HOST_RAD_TO_DEG;
        const double longitude = lon0 + x[1] / (6378137.0*cos(lat0*BF_HOST_DEG_TO_RAD)) * BF_HOST_RAD_TO_DEG;
        double course = atan2(ve, vn) * BF_HOST_RAD_TO_DEG;
        if (course < 0) course += 360.0;
        setVirtualGPS(latitude, longitude, -x[2], sqrt(vn*vn+ve*ve),
            sqrt(vn*vn+ve*ve+vd*vd), course, vn, ve, vd);
    }
#endif
}

static int runSchedulerAtCurrentTime(void)
{
    tickCount++;
    for (unsigned pass = 0; pass < BF_HOST_MAX_TASKS_PER_TICK; pass++) {
        const uint64_t before = taskCount;
        scheduler();
        if (taskCount == before) return HOST_OK;
    }
    fprintf(stderr, "[BFHOST] scheduler did not quiesce at %llu us\n", (unsigned long long)hostTimeUs);
    return HOST_SCHEDULER_LIVELOCK;
}

static int stepTo(const double *request)
{
    if (!virtualGyroDev || !virtualAccDev || !gyro.sampleLooptime) return HOST_NOT_READY;
    if (request[4] < lastRequestTime || request[4] < 0 || request[4] > 86400.0) return HOST_BAD_TIME;
    if (request[4] - lastRequestTime > 10.0) return HOST_STEP_TOO_LARGE;
    if (request[3] <= lastSequence || request[3] < 0 || request[3] > 9007199254740991.0 || floor(request[3]) != request[3]) return HOST_BAD_PROTOCOL;
    for (unsigned i = 11; i < 27; i++) {
        if (request[i] < 750 || request[i] > 2250) return HOST_BAD_VALUE;
    }
    if (request[39] < 0 || request[39] > 63 || floor(request[39]) != request[39]) return HOST_BAD_VALUE;
    if (((unsigned)request[39] & 48U) == 48U) return HOST_BAD_VALUE;
    const uint64_t target = hostEpochUs + (uint64_t)llround(request[4] * 1e6);
    if (target < hostTimeUs) return HOST_BAD_TIME;
    if (!haveSample) {
        memcpy(heldRequest, request, sizeof(heldRequest));
        haveSample = true;
    }
    /* Integrate firmware time with the previous sensor sample held until the
       next packet timestamp. At that timestamp, sample first, then dispatch.
       Tasks run with zero modeled CPU duration; priority/eligibility and every
       actual task body remain upstream code. */
    while (hostTimeUs < target) {
        uint64_t next = hostTimeUs + BF_HOST_QUANTUM_US;
        if (next >= target) break;
        hostTimeUs = next;
        feedIMU(heldRequest);
        const int status = runSchedulerAtCurrentTime();
        if (status != HOST_OK) return status;
    }
    hostTimeUs = target;
    feedIMU(request);
    feedAuxiliary(request);
    const int status = runSchedulerAtCurrentTime();
    memcpy(heldRequest, request, sizeof(heldRequest));
    lastRequestTime = request[4];
    lastSequence = request[3];
    return status;
}

static void makeResponse(double *response, const double *request, int status)
{
    memset(response, 0, BF_HOST_RESPONSE_WORDS * sizeof(double));
    response[0] = BF_HOST_MAGIC;
    response[1] = BF_HOST_VERSION;
    response[2] = status;
    response[3] = request[3];
    response[4] = runStarted ? (double)(hostTimeUs-hostEpochUs)*1e-6 : 0;
    for (unsigned i = 0; i < 4; i++) response[5+i] = motorPwm[i];
    for (unsigned i = 0; i < 3; i++) {
        response[9+i] = attitude.raw[i] * BF_HOST_DEG_TO_RAD * 0.1;
        response[12+i] = (double)gyro.gyroADCf[i] * BF_HOST_DEG_TO_RAD;
        response[15+i] = (double)getSetpointRate(i) * BF_HOST_DEG_TO_RAD;
        response[18+4*i] = pidData[i].P;
        response[19+4*i] = pidData[i].I;
        response[20+4*i] = pidData[i].D;
        response[21+4*i] = pidData[i].F;
        response[36+i] = pidData[i].Sum;
    }
    response[11] = remainder(-response[11], 2.0 * BF_HOST_PI);
    response[30] = ARMING_FLAG(ARMED) ? 1 : 0;
    response[31] = getArmingDisableFlags();
    response[32] = flightModeFlags;
    response[33] = gyro.sampleLooptime;
    response[34] = targetPidLooptime;
    response[35] = getMotorCount();
    response[39] = (double)tickCount;
}

static bool receiveExact(int socketFd, void *buffer, size_t count)
{
    uint8_t *next = buffer;
    while (count) {
        const ssize_t size = recv(socketFd, next, count, 0);
        if (size == 0) return false;
        if (size < 0) { if (errno == EINTR) continue; return false; }
        next += size;
        count -= (size_t)size;
    }
    return true;
}

static bool sendExact(int socketFd, const void *buffer, size_t count)
{
    const uint8_t *next = buffer;
    while (count) {
        const ssize_t size = send(socketFd, next, count, 0);
        if (size <= 0) { if (size < 0 && errno == EINTR) continue; return false; }
        next += size;
        count -= (size_t)size;
    }
    return true;
}

void bfHostRun(void)
{
    const uint16_t endianTest = 1;
    if (*(const uint8_t *)&endianTest != 1 || sizeof(double) != 8) {
        fprintf(stderr, "[BFHOST] this protocol build requires little-endian IEEE754 doubles\n");
        exit(2);
    }
    hostEpochUs = hostTimeUs;
    runStarted = true;
    listenSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (listenSocket < 0) { perror("[BFHOST] socket"); exit(2); }
    const int enabled = 1;
    setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(hostPort);
    if (bind(listenSocket, (struct sockaddr *)&address, sizeof(address)) < 0 || listen(listenSocket, 1) < 0) {
        perror("[BFHOST] bind/listen"); exit(2);
    }
    printf("[BFHOST] READY version=1 request_words=52 response_words=40 port=%u gyro_us=%u pid_us=%u\n", hostPort, gyro.sampleLooptime, targetPidLooptime);
    fflush(stdout);
    clientSocket = accept(listenSocket, NULL, NULL);
    if (clientSocket < 0) { perror("[BFHOST] accept"); exit(2); }
    setsockopt(clientSocket, IPPROTO_TCP, TCP_NODELAY, &enabled, sizeof(enabled));
    double request[BF_HOST_REQUEST_WORDS], response[BF_HOST_RESPONSE_WORDS];
    while (receiveExact(clientSocket, request, sizeof(request))) {
        int status = HOST_OK;
        for (unsigned i = 0; i < BF_HOST_REQUEST_WORDS; i++) {
            if (!finiteDouble(request[i])) { status = HOST_BAD_VALUE; break; }
        }
        if (status == HOST_OK && (request[0] != BF_HOST_MAGIC || request[1] != BF_HOST_VERSION ||
                request[2] < 1 || request[2] > 3 || floor(request[2]) != request[2])) status = HOST_BAD_PROTOCOL;
        if (status == HOST_OK && request[2] == 1) status = stepTo(request);
        makeResponse(response, request, status);
        if (!sendExact(clientSocket, response, sizeof(response))) break;
        if (status == HOST_OK && request[2] == 3) break;
    }
    printf("[BFHOST] CLOSED ticks=%llu tasks=%llu\n", (unsigned long long)tickCount, (unsigned long long)taskCount);
    fflush(stdout);
    bfHostShutdown();
}

