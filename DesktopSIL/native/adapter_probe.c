/* Test executable only: exercise the same runtime parameter loader and
 * sample scheduler as the native engine, with fixed open-loop commands. */
#include "desktop_sil.c"
double bfDesktopImuTelemetry[12];
double bfDesktopTaskTiming[30];
void bfDesktopResetTiming(void) { memset(bfDesktopTaskTiming,0,sizeof(bfDesktopTaskTiming)); }
int bfDesktopStep(const double *req,double *resp) { (void)req; (void)resp; return 0; }
int main(int argc,char **argv) {
    if(argc!=3 || !readSettings(argv[1])) return 2;
    FILE *f=fopen(argv[2],"w"); if(!f) return 2;
    plantInitialize(linear!=0,linear_a,linear_b);
    uint64_t base=0,ctrl=0,gs=0,as=0;
    double t=0,delta[4]={3,-2,1,4};
    plantInputs(delta);
    for(;;) {
        int ch=fabs(t-ctrl/4000.0)<1e-10,gh=fabs(t-gs/gyro_hz)<1e-10,ah=fabs(t-as/accel_hz)<1e-10;
        plantOutputs(ch,gh,ah);
        if(fabs(t-base*DT)<1e-10) {
            fprintf(f,"%.17g",t);
            for(int i=0;i<12;i++) fprintf(f,",%.17g",plantOutputValues.true_state[i]);
            for(int i=0;i<3;i++) fprintf(f,",%.17g",plantOutputValues.gyro_measured[i]);
            for(int i=0;i<3;i++) fprintf(f,",%.17g",plantOutputValues.accel_measured[i]);
            for(int i=0;i<4;i++) fprintf(f,",%.17g",plantOutputValues.actuator_delta[i]);
            for(int i=0;i<3;i++) fprintf(f,",%.17g",plantOutputValues.gyro_ideal[i]);
            for(int i=0;i<3;i++) fprintf(f,",%.17g",plantOutputValues.accel_ideal[i]);
            fputc('\n',f); base++;
        }
        if(t+1e-10>=duration) break;
        if(ch) ctrl++;
        if(gh) gs++;
        if(ah) as++;
        double next=fmin(duration,fmin(base*DT,fmin(ctrl/4000.0,fmin(gs/gyro_hz,as/accel_hz))));
        plantAdvance(next,next-t); t=next;
    }
    plantTerminate(); fclose(f); return 0;
}
