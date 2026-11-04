/* Native closed loop: generated Simulink plant + pinned Betaflight SITL.
 * Plant/controller signals use SI; receiver and motor signals use PWM/pot.
 * This adapter does not implement a replacement controller or estimator.
 */
#define _POSIX_C_SOURCE 200809L
#include "plant_adapter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

extern int bfDesktopStep(const double *request, double *response);
extern double bfDesktopImuTelemetry[12];
extern double bfDesktopTaskTiming[30];
extern void bfDesktopResetTiming(void);
#define PI 3.14159265358979323846
#define P hover_plant_sil_P
#define DT (1.0/plant_hz)
static double duration=10, realtime=0, warmup=5, arm_settle=.3, spoolup=1;
static double log_hz=1000, mode=16, reference_time=0, seed=23341;
static double plant_hz=16000;
static double firmware_hz=4000, firmware_accel_hz=4000, synchronized_clock=0;
static double reference[12], rc_flight[16], rc_disarmed[16], rc_armed[16];
static double tau_wing=1.0/22, cdw=1, aomega=.48643917993359775;
static double linear=0, gyro_hz=3200, accel_hz=1600, rc_hz=100, pid_divider=1;
static double linear_a[144],linear_b[48],motor_order[4]={1,2,3,4};
static double commands[1024][4]; static int commandCount;
static double request[52], response[40];
static FILE *trace;
typedef struct { const char *name; double *value; int count; } Setting;
#define S(name,field,count) {name,field,count}
static Setting settings[]={
    S("duration",&duration,1), S("realtime",&realtime,1), S("warmup",&warmup,1),
    S("arm_settle",&arm_settle,1), S("spoolup",&spoolup,1), S("log_hz",&log_hz,1),
    S("plant_hz",&plant_hz,1),
    S("firmware_hz",&firmware_hz,1),S("firmware_accel_hz",&firmware_accel_hz,1),S("synchronized_clock",&synchronized_clock,1),
    S("mode",&mode,1), S("reference_time",&reference_time,1), S("seed",&seed,1),
    S("reference",reference,12), S("initial",P.X0,12),
    S("rc_flight",rc_flight,16),S("rc_disarmed",rc_disarmed,16),S("rc_armed",rc_armed,16),
    S("mass",&P.m,1),S("gravity",&P.g,1),S("arm_length",&P.S,1),S("rho",&P.rho,1),
    S("C11",&P.C11,1),S("C21",&P.C21,1),S("inertia",P.Constant2_Value,3),
    S("Ax",&P.Ax,1),S("Ay",&P.Ay,1),S("Az",&P.Az,1),S("Aomega",&aomega,1),
    S("CDx",&P.CDx,1),S("CDy",&P.CDy,1),S("CDz",&P.CDz,1),S("CDw",&cdw,1),
    S("tau_wing",&tau_wing,1),S("noise",&P.noise_true,1),
    S("linear",&linear,1),S("gyro_hz",&gyro_hz,1),S("accel_hz",&accel_hz,1),S("rc_hz",&rc_hz,1),S("pid_divider",&pid_divider,1),
    S("linear_A",linear_a,144),S("linear_B",linear_b,48),S("motor_order",motor_order,4),
    S("Xu",&P.Xu,1),S("Yv",&P.Yv,1),S("Zw",&P.Zw,1),
    S("gyro_range",&P.gyro.range,1),S("accel_range",&P.accel.range,1),
    S("gyro_density",&P.gyro.noise_density,1),S("gyro_bandwidth",&P.gyro.BW,1),
    S("gyro_bias",P.gyro.bias,3),S("gyro_vibration",&P.gyro.vibration,1),
    S("accel_density",&P.accel.noise_density,1),S("accel_bandwidth",&P.accel.BW,1),
    S("accel_bias",P.accel.bias,3),S("accel_vibration",&P.accel.vibration,1)
};

static double wallTime(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
    return (double)t.tv_sec+1e-9*t.tv_nsec;
}
static void nap(void) { struct timespec t={0,2000000}; nanosleep(&t,NULL); }
static int readSettings(const char *path) {
    FILE *f=fopen(path,"r"); if (!f) { perror(path); return 0; }
    char line[16384];
    while (fgets(line,sizeof(line),f)) {
        if (line[0]=='#' || line[0]=='\n') continue;
        char key[80]; int used=0;
        if(sscanf(line,"%79s%n",key,&used)!=1) continue;
        if(!strcmp(key,"command")) {
            if(commandCount>=1024 || sscanf(line+used,"%lf %lf %lf %lf",&commands[commandCount][0],&commands[commandCount][1],&commands[commandCount][2],&commands[commandCount][3])!=4) { fclose(f); return 0; }
            commandCount++; continue;
        }
        size_t i; for(i=0;i<sizeof(settings)/sizeof(settings[0]);i++) if(!strcmp(key,settings[i].name)) break;
        if(i==sizeof(settings)/sizeof(settings[0])) { fprintf(stderr,"Unknown setting: %s\n",key); fclose(f); return 0; }
        char *p=line+used;
        for(int j=0;j<settings[i].count;j++) {
            char *end; double v=strtod(p,&end);
            if(end==p || !isfinite(v)) { fprintf(stderr,"Invalid setting: %s\n",key); fclose(f); return 0; }
            settings[i].value[j]=v; p=end;
        }
    }
    fclose(f);
    if(duration<=0 || duration>3600 || P.m<=0 || P.C11<=0 || tau_wing<=0 ||
       log_hz<1 || log_hz>16000 || (plant_hz!=3200 && plant_hz!=4000 && plant_hz!=6400 && plant_hz!=8000 && plant_hz!=16000 && plant_hz!=32000 && plant_hz!=64000) || warmup<0 || arm_settle<0 || spoolup<0 ||
       (mode!=0 && mode!=16 && mode!=32) || seed<0 || seed>4294967295.0 ||
       gyro_hz<=0 || accel_hz<=0 || gyro_hz>64000 || accel_hz>64000 || rc_hz<=0 || rc_hz>2000 ||
       firmware_hz<1000 || firmware_hz>8000 || firmware_accel_hz<100 || firmware_accel_hz>4000 ||
       (synchronized_clock && (firmware_hz!=gyro_hz || firmware_accel_hz!=accel_hz)) ||
       pid_divider<1 || pid_divider>16 || floor(pid_divider)!=pid_divider ||
       P.gyro.BW<0 || P.accel.BW<0 || P.gyro.noise_density<0 || P.accel.noise_density<0 ||
       P.Constant2_Value[0]<=0 || P.Constant2_Value[1]<=0 || P.Constant2_Value[2]<=0) {
        fprintf(stderr,"Invalid physical parameters or timing\n"); return 0;
    }
    P.u0=(P.m*P.g/4-P.C21)/P.C11;
    P.Constant4_Value[0]=P.CDx; P.Constant4_Value[1]=P.CDy; P.Constant4_Value[2]=P.CDz;
    P.Constant5_Value[0]=P.Ax; P.Constant5_Value[1]=P.Ay; P.Constant5_Value[2]=P.Az;
    for(int i=3;i<6;i++) { P.Constant4_Value[i]=cdw; P.Constant5_Value[i]=aomega; }
    P.TransferFcn_A=P.TransferFcn1_A=P.TransferFcn2_A=P.TransferFcn3_A=-1/tau_wing;
    P.TransferFcn_C=P.TransferFcn1_C=P.TransferFcn2_C=P.TransferFcn3_C=1/tau_wing;
    P.WingThrustUncertainty_seed=P.GyroWhiteNoise_seed=P.AccelWhiteNoise_seed=seed;
    P.gyro.sample_rate=gyro_hz; P.accel.sample_rate=accel_hz;
    for(int i=0;i<3;i++) {
        /* Generated masks divide by their nominal Ts. Rescale their tunable
         * power for the runtime sample period, retaining density² BW / Ts. */
        P.sil_gyro_noise_power[i]=pow(P.gyro.noise_density*PI/180,2)*P.gyro.BW*gyro_hz/3200;
        P.sil_accel_noise_power[i]=pow(P.accel.noise_density*P.g,2)*P.accel.BW*accel_hz/1600;
    }
    P.GyroRange_UpperSat=P.gyro.range*PI/180; P.GyroRange_LowerSat=-P.GyroRange_UpperSat;
    P.AccelRange_UpperSat=P.accel.range*9.81; P.AccelRange_LowerSat=-P.AccelRange_UpperSat;
    return 1;
}

/* Independent, repeatable fixture noise. Free-flight noise comes exclusively
 * from the generated Simulink blocks (including their original RNG/seeds).
 * The fixture uses Box-Muller, not MATLAB's mt19937ar normal transformation. */
static uint32_t fixture_rng;
static double uniform01(void) {
    fixture_rng=1664525U*fixture_rng+1013904223U;
    return ((double)fixture_rng+0.5)/4294967296.0;
}
static double normal01(void) { double u=uniform01(); return sqrt(-2*log(u))*cos(2*PI*uniform01()); }
static int exchange(void) {
    int status=bfDesktopStep(request,response);
    if(trace) { fwrite(request,sizeof(double),52,trace); fwrite(response,sizeof(double),40,trace); }
    request[3]++;
    if(status) fprintf(stderr,"Firmware step failed: status=%d t=%.9g\n",status,request[4]);
    return status==0;
}
static int startup(double *epoch) {
    int warm=(int)ceil(warmup*firmware_hz), arm=(int)ceil(arm_settle*firmware_hz), spool=(int)ceil(spoolup*firmware_hz);
    int last=warm+arm+spool, sensor=-1, frame=-1;
    double noise=0, phi=P.X0[6], theta=P.X0[7];
    double fixture[3]={P.g*sin(theta),-P.g*sin(phi)*cos(theta),-P.g*cos(phi)*cos(theta)};
    double sigma=P.gyro.noise_density*PI/180*sqrt(P.gyro.BW*gyro_hz)*P.noise_true;
    fixture_rng=(uint32_t)seed;
    memcpy(request+27,P.X0,12*sizeof(double));
    request[46]=phi; request[47]=theta;
    for(int tick=0;tick<=last;tick++) {
        double t=tick/firmware_hz; request[4]=t;
        int index=(int)floor(t*gyro_hz+1e-8);
        while(sensor<index) { sensor++; noise=sigma*normal01(); }
        for(int i=0;i<3;i++) {
            request[5+i]=P.noise_true*P.gyro.bias[i]*PI/180+noise;
            request[8+i]=fixture[i]+P.noise_true*P.accel.bias[i]*P.g;
        }
        int newframe=(int)floor((t+1e-10)*rc_hz);
        request[39]=(newframe!=frame || tick==warm+1 || tick==warm+arm+1) ? 8 : 0;
        frame=newframe;
        memcpy(request+11,tick<=warm ? rc_disarmed : (tick<=warm+arm ? rc_armed : rc_flight),16*sizeof(double));
        if(tick>warm+arm) request[39]+=mode;
        if(!exchange()) return 0;
        if(tick==warm && response[30]!=0) { fprintf(stderr,"Armed during calibration\n"); return 0; }
        if(tick==warm+arm || tick==last) {
            if(response[30]!=1 || response[35]!=4 || response[33]!=(unsigned)(1e6/firmware_hz) || response[34]!=(unsigned)(1e6*pid_divider/firmware_hz) ||
               (mode==16 && !((unsigned)response[32]&1U)) || (mode==32 && ((unsigned)response[32]&3U))) {
                fprintf(stderr,"Startup check failed: armed=%.0f disable=%.0f modes=%.0f gyro_us=%.0f pid_us=%.0f motors=%.0f\n",response[30],response[31],response[32],response[33],response[34],response[35]); return 0;
            }
        }
        if(tick%400==0 && access("stop",F_OK)==0) return 0;
    }
    *epoch=(last+1)/firmware_hz;
    return 1;
}

static const char *stateNames[]={"x_m","y_m","z_m","u_mps","v_mps","w_mps","roll_rad","pitch_rad","yaw_rad","p_radps","q_radps","r_radps"};
static const char *diagNames[]={"motor1_pot","motor2_pot","motor3_pot","motor4_pot", "estimate_roll_rad","estimate_pitch_rad","estimate_yaw_rad", "filtered_p_radps","filtered_q_radps","filtered_r_radps", "setpoint_p_radps","setpoint_q_radps","setpoint_r_radps", "roll_P","roll_I","roll_D","roll_F","pitch_P","pitch_I","pitch_D","pitch_F","yaw_P","yaw_I","yaw_D","yaw_F", "armed","arming_disable","mode_flags","gyro_period_us","pid_period_us","motor_count","roll_PID_sum","pitch_PID_sum","yaw_PID_sum","firmware_ticks"};
static const char *taskNames[]={"gyro","filter","pid","accel","attitude","receiver"};
static void writeHeader(FILE *f) {
    fprintf(f,"time_s");
    for(int i=0;i<12;i++) fprintf(f,",%s",stateNames[i]);
    fprintf(f,",raw_gyro_x_radps,raw_gyro_y_radps,raw_gyro_z_radps,raw_accel_x_mps2,raw_accel_y_mps2,raw_accel_z_mps2");
    for(int i=0;i<4;i++) fprintf(f,",actuator%d_delta_pot",i+1);
    for(int i=0;i<35;i++) fprintf(f,",%s",diagNames[i]);
    for(int i=0;i<12;i++) fprintf(f,",reference_%s",stateNames[i]);
    fprintf(f,",ideal_gyro_x_radps,ideal_gyro_y_radps,ideal_gyro_z_radps,ideal_accel_x_mps2,ideal_accel_y_mps2,ideal_accel_z_mps2");
    fprintf(f,",filtered_input_p_radps,filtered_input_q_radps,filtered_input_r_radps,filtered_input_accel_x_mps2,filtered_input_accel_y_mps2,filtered_input_accel_z_mps2,mahony_accel_accepted,mahony_update_dt_s,mahony_update_count,mahony_propagation_p_radps,mahony_propagation_q_radps,mahony_propagation_r_radps");
    for(int i=0;i<6;i++) fprintf(f,",task_%s_count,task_%s_last_time_s,task_%s_dt_s",taskNames[i],taskNames[i],taskNames[i]);
    fputc('\n',f);
}
static void writeRow(FILE *f,double t) {
    double row[106]; int n=0; row[n++]=t;
    for(int i=0;i<12;i++) row[n++]=plantOutputValues.true_state[i];
    for(int i=0;i<3;i++) row[n++]=plantOutputValues.gyro_measured[i];
    for(int i=0;i<3;i++) row[n++]=plantOutputValues.accel_measured[i];
    for(int i=0;i<4;i++) row[n++]=plantOutputValues.actuator_delta[i];
    for(int i=5;i<40;i++) row[n++]=response[i];
    for(int i=0;i<12;i++) row[n++]=request[40+i];
    for(int i=0;i<3;i++) row[n++]=plantOutputValues.gyro_ideal[i];
    for(int i=0;i<3;i++) row[n++]=plantOutputValues.accel_ideal[i];
    for(int i=0;i<12;i++) row[n++]=bfDesktopImuTelemetry[i]*(i>=3 && i<=5 ? -9.80665/256.0 : 1.0);
    for(int i=0;i<6;i++) { row[n++]=bfDesktopTaskTiming[i]; row[n++]=bfDesktopTaskTiming[6+i]; row[n++]=bfDesktopTaskTiming[12+i]; }
    if(fwrite(row,sizeof(double),(size_t)n,f)!=(size_t)n) { perror("Signal log write"); exit(4); }
}

int desktopSilRun(void) {
    const char *path=getenv("BF_DESKTOP_CASE");
    if(!path || !readSettings(path)) return 2;
    request[0]=20261011; request[1]=1; request[2]=1;
    if(getenv("BF_DESKTOP_TRACE")) trace=fopen("firmware_trace.bin","wb");
    double epoch, totalStart=wallTime();
    printf("[DESKTOP] CALIBRATING\n"); fflush(stdout);
    if(!startup(&epoch)) {
        if(trace) fclose(trace);
        if(access("stop",F_OK)==0) {
            FILE *summary=fopen("engine_summary.json","w");
            if(summary) { fprintf(summary,"{\"completed\":false,\"stopped\":true,\"simulation_seconds\":0,\"flight_wall_seconds\":0,\"total_wall_seconds\":%.9g,\"speed_ratio\":0,\"phase\":\"startup\"}\n",wallTime()-totalStart); fclose(summary); }
            printf("[DESKTOP] STOPPED during startup\n"); fflush(stdout); return 0;
        }
        return 3;
    }
    plantInitialize(linear!=0,linear_a,linear_b);
    bfDesktopResetTiming();
    FILE *header=fopen("signals.header","w"); if(!header) return 4;
    writeHeader(header); fclose(header);
    FILE *data=fopen("signals.bin","wb"); if(!data) { perror("signals.bin"); return 4; }
    setvbuf(data,NULL,_IOFBF,1024*1024);
    double flightStart=wallTime(), pacingStart=flightStart, t=0;
    int stopped=0, failed=0;
    uint64_t integrationSteps=0;
    double minimumStep=DT, maximumStep=0;
    uint64_t baseTick=0,ctrlTick=0,gyroTick=0,accelTick=0,logTick=0,progressTick=0,rcTick=0;
    long receiverFrame=-1;
    printf("[DESKTOP] RUNNING\n"); fflush(stdout);
    for(;;) {
        int ctrlHit=fabs(t-ctrlTick/firmware_hz)<1e-10;
        int gyroHit=fabs(t-gyroTick/gyro_hz)<1e-10;
        int accelHit=fabs(t-accelTick/accel_hz)<1e-10;
        int rcHit=fabs(t-rcTick/rc_hz)<1e-10;
        if(ctrlHit && ctrlTick%40==0) {
            if(access("stop",F_OK)==0) { stopped=1; break; }
            double paused=wallTime();
            while(access("pause",F_OK)==0 && access("stop",F_OK)!=0) nap();
            pacingStart+=wallTime()-paused;
            if(realtime) while(wallTime()-pacingStart<t && access("stop",F_OK)!=0) nap();
        }
        plantOutputs(ctrlHit,gyroHit,accelHit);
        if(ctrlHit || (synchronized_clock && (gyroHit || accelHit || rcHit))) {
            request[4]=epoch+t;
            memcpy(request+5,plantOutputValues.gyro_measured,3*sizeof(double));
            memcpy(request+8,plantOutputValues.accel_measured,3*sizeof(double));
            memcpy(request+11,rc_flight,16*sizeof(double));
            memcpy(request+27,plantOutputValues.true_state,12*sizeof(double));
            long frame=(long)floor((t+1e-10)*rc_hz);
            request[39]=mode+(frame!=receiverFrame ? 8 : 0); receiverFrame=frame;
            for(int i=0;i<12;i++) request[40+i]=(t+1e-10>=reference_time) ? reference[i] : 0;
            for(int k=0;k<commandCount && commands[k][0]<=t+1e-10;k++) {
                int offset=mode==16?46:49;
                request[offset]=commands[k][1]; request[offset+1]=commands[k][2]; request[51]=commands[k][3];
            }
            if(!exchange() || response[30]!=1) { failed=1; break; }
            double delta[4]; for(int i=0;i<4;i++) delta[i]=response[4+(int)motor_order[i]]-P.u0;
            plantInputs(delta);
        }
        for(int i=0;i<12;i++) if(!isfinite(plantOutputValues.true_state[i])) failed=1;
        if(failed) { fprintf(stderr,"Nonfinite state or firmware disarmed at t=%.9g\n",t); break; }
        if(t+1e-10>=logTick/log_hz || t+1e-10>=duration) { writeRow(data,t); logTick++; }
        if(t+1e-10>=progressTick*.1) { progressTick++; fflush(data); printf("[DESKTOP] TIME %.4f\n",t); fflush(stdout); }
        if(t+1e-10>=duration) break;
        if(ctrlHit) ctrlTick++;
        if(gyroHit) gyroTick++;
        if(accelHit) accelTick++;
        if(rcHit) rcTick++;
        while(baseTick*DT<=t+1e-10) baseTick++;
        double next=fmin(duration,fmin(baseTick*DT,fmin(ctrlTick/firmware_hz,fmin(gyroTick/gyro_hz,fmin(accelTick/accel_hz,logTick/log_hz)))));
        if(synchronized_clock) next=fmin(next,rcTick/rc_hz);
        if(next<=t) { fprintf(stderr,"Scheduler failed to advance\n"); failed=1; break; }
        double step=next-t;
        if(step<minimumStep) minimumStep=step;
        if(step>maximumStep) maximumStep=step;
        plantAdvance(next,step); integrationSteps++; t=next;
    }
    fclose(data); if(trace) fclose(trace);
    plantTerminate();
    double elapsed=wallTime()-flightStart;
    FILE *summary=fopen("engine_summary.json","w");
    if(summary) {
        fprintf(summary,"{\"completed\":%s,\"stopped\":%s,\"simulation_seconds\":%.9g,\"flight_wall_seconds\":%.9g,\"total_wall_seconds\":%.9g,\"speed_ratio\":%.9g,\"plant_hz\":%.9g,\"solver\":\"ode5\",\"firmware_hz\":%.9g,\"firmware_accel_hz\":%.9g,\"pid_hz\":%.9g,\"gyro_hz\":%.9g,\"accel_hz\":%.9g,\"log_hz_actual\":%.9g,\"trim_pot\":%.12g,\"linear\":%s,\"task_timing\":{",(!failed&&!stopped)?"true":"false",stopped?"true":"false",t,elapsed,wallTime()-totalStart,t/fmax(elapsed,1e-9),plant_hz,firmware_hz,firmware_accel_hz,firmware_hz/pid_divider,gyro_hz,accel_hz,log_hz,P.u0,linear?"true":"false");
        for(int i=0;i<6;i++) {
            double count=bfDesktopTaskTiming[i], span=bfDesktopTaskTiming[6+i]-bfDesktopTaskTiming[18+i];
            fprintf(summary,"%s\"%s\":{\"count\":%.0f,\"measured_hz\":%.12g,\"last_period_s\":%.12g,\"max_period_s\":%.12g}",i?",":"",taskNames[i],count,span>0?(count-1)/span:0,bfDesktopTaskTiming[12+i],bfDesktopTaskTiming[24+i]);
        }
        fprintf(summary,"},\"integration\":{\"steps\":%llu,\"mean_steps_per_second\":%.12g,\"minimum_step_s\":%.12g,\"maximum_step_s\":%.12g}}\n",(unsigned long long)integrationSteps,t>0?integrationSteps/t:0,integrationSteps?minimumStep:0,maximumStep);
        fclose(summary);
    }
    printf("[DESKTOP] %s sim=%.3fs wall=%.3fs speed=%.2fx\n",failed?"FAILED":(stopped?"STOPPED":"COMPLETE"),t,elapsed,t/fmax(elapsed,1e-9)); fflush(stdout);
    return failed?5:0;
}
