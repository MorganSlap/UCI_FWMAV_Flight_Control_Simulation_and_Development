/* Open-loop generated-code equivalence probe. Input and output are SI. */
#include "hover_plant_sil.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    FILE *f=fopen(argv[2],"w"); if (!f) return 2;
    hover_plant_sil_P.noise_true=atoi(argv[1]);
    hover_plant_sil_P.X0[6]=0.03;
    hover_plant_sil_P.X0[7]=-0.02;
    hover_plant_sil_initialize();
    for (int n=0;n<=16000;n++) {
        double t=n/16000.0;
        /* Constant input exercises actuator transients and all tilt dynamics. */
        for (int i=0;i<4;i++) hover_plant_sil_U.motor_delta[i]=(i%2 ? -2 : 3);
        hover_plant_sil_output();
        fprintf(f,"%.17g",t);
        for(int i=0;i<12;i++) fprintf(f,",%.17g",hover_plant_sil_Y.true_state[i]);
        for(int i=0;i<3;i++) fprintf(f,",%.17g",hover_plant_sil_Y.gyro_measured[i]);
        for(int i=0;i<3;i++) fprintf(f,",%.17g",hover_plant_sil_Y.accel_measured[i]);
        for(int i=0;i<4;i++) fprintf(f,",%.17g",hover_plant_sil_Y.actuator_delta[i]);
        fputc('\n',f);
        if(n<16000) hover_plant_sil_update();
    }
    hover_plant_sil_terminate(); fclose(f); return 0;
}
