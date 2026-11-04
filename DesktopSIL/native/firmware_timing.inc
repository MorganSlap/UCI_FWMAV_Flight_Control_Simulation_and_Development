/* Appended to the desktop-only host build. Flight algorithms stay upstream. */
#include "fc/tasks.h"
unsigned bfDesktopGyroRateHz(void)
{
    const char *value = getenv("BF_DESKTOP_GYRO_HZ");
    return value ? (unsigned)strtoul(value, NULL, 10) : 4000U;
}
unsigned bfDesktopAccelRateHz(void)
{
    const char *value = getenv("BF_DESKTOP_ACCEL_HZ");
    return value ? (unsigned)strtoul(value, NULL, 10) : 4000U;
}
int bfDesktopSynchronizedClock(void)
{
    /* Immutable for this process; avoid an environment lookup on every clock read. */
    static int enabled = -1;
    if (enabled < 0) {
        const char *value = getenv("BF_DESKTOP_SYNC");
        enabled = value && value[0] == '1';
    }
    return enabled;
}
/* count, last time (s), last dt (s), first time (s), maximum dt (s) */
double bfDesktopTaskTiming[30];
void bfDesktopNoteTask(const void *task, uint32_t timeUs)
{
    const taskId_e ids[6] = { TASK_GYRO, TASK_FILTER, TASK_PID, TASK_ACCEL, TASK_ATTITUDE, TASK_RX };
    for (unsigned i=0; i<6; i++) {
        if (task != getTask(ids[i])) continue;
        const double now = (double)timeUs * 1e-6;
        if (bfDesktopTaskTiming[i] > 0) {
            const double dt = now - bfDesktopTaskTiming[6+i];
            bfDesktopTaskTiming[12+i] = dt;
            if (dt > bfDesktopTaskTiming[24+i]) bfDesktopTaskTiming[24+i] = dt;
        } else bfDesktopTaskTiming[18+i] = now;
        bfDesktopTaskTiming[i]++;
        bfDesktopTaskTiming[6+i] = now;
        break;
    }
}
void bfDesktopResetTiming(void) { memset(bfDesktopTaskTiming, 0, sizeof(bfDesktopTaskTiming)); }
