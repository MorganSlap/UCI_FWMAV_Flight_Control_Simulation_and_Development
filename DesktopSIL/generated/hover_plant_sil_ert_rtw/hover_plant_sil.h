/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_plant_sil.h
 *
 * Code generated for Simulink model 'hover_plant_sil'.
 *
 * Model version                  : 1.1
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Sun Nov  1 20:21:21 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: Intel->x86-64 (Windows64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef hover_plant_sil_h_
#define hover_plant_sil_h_
#ifndef hover_plant_sil_COMMON_INCLUDES_
#define hover_plant_sil_COMMON_INCLUDES_
#include "rtwtypes.h"
#include "rtw_continuous.h"
#include "rtw_solver.h"
#include "rt_nonfinite.h"
#include "math.h"
#endif                                 /* hover_plant_sil_COMMON_INCLUDES_ */

#include "hover_plant_sil_types.h"
#include "rtGetInf.h"
#include "rtGetNaN.h"
#include <string.h>

/* Macros for accessing real-time model data structure */
#ifndef rtmGetContStateDisabled
#define rtmGetContStateDisabled(rtm)   ((rtm)->contStateDisabled)
#endif

#ifndef rtmSetContStateDisabled
#define rtmSetContStateDisabled(rtm, val) ((rtm)->contStateDisabled = (val))
#endif

#ifndef rtmGetContStates
#define rtmGetContStates(rtm)          ((rtm)->contStates)
#endif

#ifndef rtmSetContStates
#define rtmSetContStates(rtm, val)     ((rtm)->contStates = (val))
#endif

#ifndef rtmGetContTimeOutputInconsistentWithStateAtMajorStepFlag
#define rtmGetContTimeOutputInconsistentWithStateAtMajorStepFlag(rtm) ((rtm)->CTOutputIncnstWithState)
#endif

#ifndef rtmSetContTimeOutputInconsistentWithStateAtMajorStepFlag
#define rtmSetContTimeOutputInconsistentWithStateAtMajorStepFlag(rtm, val) ((rtm)->CTOutputIncnstWithState = (val))
#endif

#ifndef rtmGetDerivCacheNeedsReset
#define rtmGetDerivCacheNeedsReset(rtm) ((rtm)->derivCacheNeedsReset)
#endif

#ifndef rtmSetDerivCacheNeedsReset
#define rtmSetDerivCacheNeedsReset(rtm, val) ((rtm)->derivCacheNeedsReset = (val))
#endif

#ifndef rtmGetIntgData
#define rtmGetIntgData(rtm)            ((rtm)->intgData)
#endif

#ifndef rtmSetIntgData
#define rtmSetIntgData(rtm, val)       ((rtm)->intgData = (val))
#endif

#ifndef rtmGetOdeF
#define rtmGetOdeF(rtm)                ((rtm)->odeF)
#endif

#ifndef rtmSetOdeF
#define rtmSetOdeF(rtm, val)           ((rtm)->odeF = (val))
#endif

#ifndef rtmGetOdeY
#define rtmGetOdeY(rtm)                ((rtm)->odeY)
#endif

#ifndef rtmSetOdeY
#define rtmSetOdeY(rtm, val)           ((rtm)->odeY = (val))
#endif

#ifndef rtmGetPeriodicContStateIndices
#define rtmGetPeriodicContStateIndices(rtm) ((rtm)->periodicContStateIndices)
#endif

#ifndef rtmSetPeriodicContStateIndices
#define rtmSetPeriodicContStateIndices(rtm, val) ((rtm)->periodicContStateIndices = (val))
#endif

#ifndef rtmGetPeriodicContStateRanges
#define rtmGetPeriodicContStateRanges(rtm) ((rtm)->periodicContStateRanges)
#endif

#ifndef rtmSetPeriodicContStateRanges
#define rtmSetPeriodicContStateRanges(rtm, val) ((rtm)->periodicContStateRanges = (val))
#endif

#ifndef rtmGetZCCacheNeedsReset
#define rtmGetZCCacheNeedsReset(rtm)   ((rtm)->zCCacheNeedsReset)
#endif

#ifndef rtmSetZCCacheNeedsReset
#define rtmSetZCCacheNeedsReset(rtm, val) ((rtm)->zCCacheNeedsReset = (val))
#endif

#ifndef rtmGetdX
#define rtmGetdX(rtm)                  ((rtm)->derivs)
#endif

#ifndef rtmSetdX
#define rtmSetdX(rtm, val)             ((rtm)->derivs = (val))
#endif

#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

#ifndef rtmGetStopRequested
#define rtmGetStopRequested(rtm)       ((rtm)->Timing.stopRequestedFlag)
#endif

#ifndef rtmSetStopRequested
#define rtmSetStopRequested(rtm, val)  ((rtm)->Timing.stopRequestedFlag = (val))
#endif

#ifndef rtmGetStopRequestedPtr
#define rtmGetStopRequestedPtr(rtm)    (&((rtm)->Timing.stopRequestedFlag))
#endif

#ifndef rtmGetT
#define rtmGetT(rtm)                   (rtmGetTPtr((rtm))[0])
#endif

#ifndef rtmGetTPtr
#define rtmGetTPtr(rtm)                ((rtm)->Timing.t)
#endif

#ifndef rtmGetTStart
#define rtmGetTStart(rtm)              ((rtm)->Timing.tStart)
#endif

/* Block signals (default storage) */
typedef struct {
  real_T NoiseOption[4];               /* '<S2>/Noise Option' */
  real_T Sum1[3];                      /* '<S3>/Sum1' */
  real_T GyroSampleRate[3];            /* '<S3>/Gyro Sample Rate' */
  real_T Sum1_m[3];                    /* '<S1>/Sum1' */
  real_T AccelSampleRate[3];           /* '<S1>/Accel Sample Rate' */
  real_T dx[12];                       /* '<S10>/MATLAB Function1' */
} B_hover_plant_sil_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T NextOutput;                   /* '<S7>/White Noise' */
  real_T NextOutput_l;                 /* '<S8>/White Noise' */
  real_T NextOutput_lo;                /* '<S6>/White Noise' */
  uint32_T RandSeed;                   /* '<S7>/White Noise' */
  uint32_T RandSeed_e;                 /* '<S8>/White Noise' */
  uint32_T RandSeed_j;                 /* '<S6>/White Noise' */
} DW_hover_plant_sil_T;

/* Continuous states (default storage) */
typedef struct {
  real_T Integrator_CSTATE[12];        /* '<S10>/Integrator' */
  real_T TransferFcn_CSTATE;           /* '<S2>/Transfer Fcn' */
  real_T TransferFcn1_CSTATE;          /* '<S2>/Transfer Fcn1' */
  real_T TransferFcn2_CSTATE;          /* '<S2>/Transfer Fcn2' */
  real_T TransferFcn3_CSTATE;          /* '<S2>/Transfer Fcn3' */
} X_hover_plant_sil_T;

/* State derivatives (default storage) */
typedef struct {
  real_T Integrator_CSTATE[12];        /* '<S10>/Integrator' */
  real_T TransferFcn_CSTATE;           /* '<S2>/Transfer Fcn' */
  real_T TransferFcn1_CSTATE;          /* '<S2>/Transfer Fcn1' */
  real_T TransferFcn2_CSTATE;          /* '<S2>/Transfer Fcn2' */
  real_T TransferFcn3_CSTATE;          /* '<S2>/Transfer Fcn3' */
} XDot_hover_plant_sil_T;

/* State disabled  */
typedef struct {
  boolean_T Integrator_CSTATE[12];     /* '<S10>/Integrator' */
  boolean_T TransferFcn_CSTATE;        /* '<S2>/Transfer Fcn' */
  boolean_T TransferFcn1_CSTATE;       /* '<S2>/Transfer Fcn1' */
  boolean_T TransferFcn2_CSTATE;       /* '<S2>/Transfer Fcn2' */
  boolean_T TransferFcn3_CSTATE;       /* '<S2>/Transfer Fcn3' */
} XDis_hover_plant_sil_T;

#ifndef ODE5_INTG
#define ODE5_INTG

/* ODE5 Integration Data */
typedef struct {
  real_T *y;                           /* output */
  real_T *f[6];                        /* derivatives */
} ODE5_IntgData;

#endif

/* External inputs (root inport signals with default storage) */
typedef struct {
  real_T motor_delta[4];               /* '<Root>/motor_delta' */
} ExtU_hover_plant_sil_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  real_T true_state[12];               /* '<Root>/true_state' */
  real_T gyro_measured[3];             /* '<Root>/gyro_measured' */
  real_T accel_measured[3];            /* '<Root>/accel_measured' */
  real_T actuator_delta[4];            /* '<Root>/actuator_delta' */
  real_T gyro_ideal[3];                /* '<Root>/gyro_ideal' */
  real_T accel_ideal[3];               /* '<Root>/accel_ideal' */
} ExtY_hover_plant_sil_T;

/* Parameters (default storage) */
struct P_hover_plant_sil_T_ {
  struct_IG7iew4hCkKOXTEkHXx6zC accel; /* Variable: accel
                                        * Referenced by:
                                        *   '<S1>/Accel Bias'
                                        *   '<S1>/Accel Noise Scaling'
                                        */
  struct_IG7iew4hCkKOXTEkHXx6zC gyro;  /* Variable: gyro
                                        * Referenced by:
                                        *   '<S3>/Gyro Bias'
                                        *   '<S3>/Gyro Noise Scaling'
                                        */
  real_T Ax;                           /* Variable: Ax
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T Ay;                           /* Variable: Ay
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T Az;                           /* Variable: Az
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T C11;                          /* Variable: C11
                                        * Referenced by:
                                        *   '<Root>/MATLAB Function'
                                        *   '<S10>/Constant6'
                                        */
  real_T C21;                          /* Variable: C21
                                        * Referenced by: '<S10>/Constant7'
                                        */
  real_T CDx;                          /* Variable: CDx
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T CDy;                          /* Variable: CDy
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T CDz;                          /* Variable: CDz
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T S;                            /* Variable: S
                                        * Referenced by: '<S10>/Constant3'
                                        */
  real_T X0[12];                       /* Variable: X0
                                        * Referenced by: '<S10>/Integrator'
                                        */
  real_T Xu;                           /* Variable: Xu
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T Yv;                           /* Variable: Yv
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T Zw;                           /* Variable: Zw
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T g;                            /* Variable: g
                                        * Referenced by:
                                        *   '<Root>/MATLAB Function'
                                        *   '<S1>/Accel Bias'
                                        *   '<S1>/Accel Noise Scaling'
                                        *   '<S10>/Constant9'
                                        */
  real_T m;                            /* Variable: m
                                        * Referenced by:
                                        *   '<Root>/MATLAB Function'
                                        *   '<S10>/Constant1'
                                        */
  real_T noise_true;                   /* Variable: noise_true
                                        * Referenced by:
                                        *   '<Root>/Noise Option'
                                        *   '<S1>/Noise Option'
                                        *   '<S1>/Noise Option1'
                                        *   '<S2>/Noise Option'
                                        *   '<S3>/Noise Option'
                                        *   '<S3>/Noise Option1'
                                        */
  real_T rho;                          /* Variable: rho
                                        * Referenced by:
                                        *   '<Root>/MATLAB Function'
                                        *   '<S10>/Constant8'
                                        */
  real_T sil_accel_noise_power[3];     /* Variable: sil_accel_noise_power
                                        * Referenced by: '<S6>/Output'
                                        */
  real_T sil_gyro_noise_power[3];      /* Variable: sil_gyro_noise_power
                                        * Referenced by: '<S8>/Output'
                                        */
  real_T u0;                           /* Variable: u0
                                        * Referenced by: '<S10>/Constant'
                                        */
  boolean_T imu_nonlinear;             /* Variable: imu_nonlinear
                                        * Referenced by: '<Root>/MATLAB Function'
                                        */
  real_T WingThrustUncertainty_Cov[4];
                                    /* Mask Parameter: WingThrustUncertainty_Cov
                                     * Referenced by: '<S7>/Output'
                                     */
  real_T WingThrustUncertainty_seed;
                                   /* Mask Parameter: WingThrustUncertainty_seed
                                    * Referenced by: '<S7>/White Noise'
                                    */
  real_T GyroWhiteNoise_seed;          /* Mask Parameter: GyroWhiteNoise_seed
                                        * Referenced by: '<S8>/White Noise'
                                        */
  real_T AccelWhiteNoise_seed;         /* Mask Parameter: AccelWhiteNoise_seed
                                        * Referenced by: '<S6>/White Noise'
                                        */
  real_T Constant2_Value[3];           /* Expression: [Ix, Iy, Iz]'
                                        * Referenced by: '<S10>/Constant2'
                                        */
  real_T Constant4_Value[6];           /* Expression: [CDx CDy CDz CDw CDw CDw]'
                                        * Referenced by: '<S10>/Constant4'
                                        */
  real_T Constant5_Value[6];     /* Expression: [Ax Ay Az Aomega Aomega Aomega]'
                                  * Referenced by: '<S10>/Constant5'
                                  */
  real_T TransferFcn_A;                /* Computed Parameter: TransferFcn_A
                                        * Referenced by: '<S2>/Transfer Fcn'
                                        */
  real_T TransferFcn_C;                /* Computed Parameter: TransferFcn_C
                                        * Referenced by: '<S2>/Transfer Fcn'
                                        */
  real_T TransferFcn1_A;               /* Computed Parameter: TransferFcn1_A
                                        * Referenced by: '<S2>/Transfer Fcn1'
                                        */
  real_T TransferFcn1_C;               /* Computed Parameter: TransferFcn1_C
                                        * Referenced by: '<S2>/Transfer Fcn1'
                                        */
  real_T TransferFcn2_A;               /* Computed Parameter: TransferFcn2_A
                                        * Referenced by: '<S2>/Transfer Fcn2'
                                        */
  real_T TransferFcn2_C;               /* Computed Parameter: TransferFcn2_C
                                        * Referenced by: '<S2>/Transfer Fcn2'
                                        */
  real_T TransferFcn3_A;               /* Computed Parameter: TransferFcn3_A
                                        * Referenced by: '<S2>/Transfer Fcn3'
                                        */
  real_T TransferFcn3_C;               /* Computed Parameter: TransferFcn3_C
                                        * Referenced by: '<S2>/Transfer Fcn3'
                                        */
  real_T WhiteNoise_Mean;              /* Expression: 0
                                        * Referenced by: '<S7>/White Noise'
                                        */
  real_T WhiteNoise_StdDev;            /* Computed Parameter: WhiteNoise_StdDev
                                        * Referenced by: '<S7>/White Noise'
                                        */
  real_T WhiteNoise_Mean_p;            /* Expression: 0
                                        * Referenced by: '<S8>/White Noise'
                                        */
  real_T WhiteNoise_StdDev_i;         /* Computed Parameter: WhiteNoise_StdDev_i
                                       * Referenced by: '<S8>/White Noise'
                                       */
  real_T WingDisturbanceUnitAmplitude_Am;/* Expression: 1
                                          * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
                                          */
  real_T WingDisturbanceUnitAmplitude_Bi;/* Expression: 0
                                          * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
                                          */
  real_T WingDisturbanceUnitAmplitude_Fr;/* Expression: 2*pi*24
                                          * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
                                          */
  real_T WingDisturbanceUnitAmplitude_Ph;/* Expression: 0
                                          * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
                                          */
  real_T GyroRange_UpperSat;           /* Expression: 1000*(pi/180)
                                        * Referenced by: '<S3>/Gyro Range'
                                        */
  real_T GyroRange_LowerSat;           /* Expression: -1000*(pi/180)
                                        * Referenced by: '<S3>/Gyro Range'
                                        */
  real_T WhiteNoise_Mean_a;            /* Expression: 0
                                        * Referenced by: '<S6>/White Noise'
                                        */
  real_T WhiteNoise_StdDev_c;         /* Computed Parameter: WhiteNoise_StdDev_c
                                       * Referenced by: '<S6>/White Noise'
                                       */
  real_T AccelRange_UpperSat;          /* Expression: 4*9.81
                                        * Referenced by: '<S1>/Accel Range'
                                        */
  real_T AccelRange_LowerSat;          /* Expression: -4*9.81
                                        * Referenced by: '<S1>/Accel Range'
                                        */
};

/* Real-time Model Data Structure */
struct tag_RTM_hover_plant_sil_T {
  const char_T *errorStatus;
  RTWSolverInfo solverInfo;
  X_hover_plant_sil_T *contStates;
  int_T *periodicContStateIndices;
  real_T *periodicContStateRanges;
  real_T *derivs;
  XDis_hover_plant_sil_T *contStateDisabled;
  boolean_T zCCacheNeedsReset;
  boolean_T derivCacheNeedsReset;
  boolean_T CTOutputIncnstWithState;
  real_T odeY[16];
  real_T odeF[6][16];
  ODE5_IntgData intgData;

  /*
   * Sizes:
   * The following substructure contains sizes information
   * for many of the model attributes such as inputs, outputs,
   * dwork, sample times, etc.
   */
  struct {
    int_T numContStates;
    int_T numPeriodicContStates;
    int_T numSampTimes;
  } Sizes;

  /*
   * Timing:
   * The following substructure contains information regarding
   * the timing information for the model.
   */
  struct {
    uint32_T clockTick0;
    time_T stepSize0;
    uint32_T clockTick1;
    struct {
      uint8_T TID[5];
    } TaskCounters;

    time_T tStart;
    SimTimeStep simTimeStep;
    boolean_T stopRequestedFlag;
    time_T *t;
    time_T tArray[5];
  } Timing;
};

/* Block parameters (default storage) */
extern P_hover_plant_sil_T hover_plant_sil_P;

/* Block signals (default storage) */
extern B_hover_plant_sil_T hover_plant_sil_B;

/* Continuous states (default storage) */
extern X_hover_plant_sil_T hover_plant_sil_X;

/* Disabled states (default storage) */
extern XDis_hover_plant_sil_T hover_plant_sil_XDis;

/* Block states (default storage) */
extern DW_hover_plant_sil_T hover_plant_sil_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_hover_plant_sil_T hover_plant_sil_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_hover_plant_sil_T hover_plant_sil_Y;

/* Model entry point functions */
extern void hover_plant_sil_initialize(void);
extern void hover_plant_sil_output(void);
extern void hover_plant_sil_update(void);
extern void hover_plant_sil_terminate(void);

/* Real-time Model object */
extern RT_MODEL_hover_plant_sil_T *const hover_plant_sil_M;

/*-
 * These blocks were eliminated from the model due to optimizations:
 *
 * Block '<S9>/Gain' : Unused code path elimination
 */

/*-
 * The generated code includes comments that allow you to trace directly
 * back to the appropriate location in the model.  The basic format
 * is <system>/block_name, where system is the system number (uniquely
 * assigned by Simulink) and block_name is the name of the block.
 *
 * Use the MATLAB hilite_system command to trace the generated code back
 * to the model.  For example,
 *
 * hilite_system('<S3>')    - opens system 3
 * hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
 *
 * Here is the system hierarchy for this model
 *
 * '<Root>' : 'hover_plant_sil'
 * '<S1>'   : 'hover_plant_sil/Accelerometer Model'
 * '<S2>'   : 'hover_plant_sil/Actuator Model'
 * '<S3>'   : 'hover_plant_sil/Gyro Model'
 * '<S4>'   : 'hover_plant_sil/Lin vs NonLin Dynamics'
 * '<S5>'   : 'hover_plant_sil/MATLAB Function'
 * '<S6>'   : 'hover_plant_sil/Accelerometer Model/Accel White Noise'
 * '<S7>'   : 'hover_plant_sil/Actuator Model/Wing Thrust Uncertainty'
 * '<S8>'   : 'hover_plant_sil/Gyro Model/Gyro White Noise'
 * '<S9>'   : 'hover_plant_sil/Gyro Model/Radians to Degrees'
 * '<S10>'  : 'hover_plant_sil/Lin vs NonLin Dynamics/Non Linear Simulation'
 * '<S11>'  : 'hover_plant_sil/Lin vs NonLin Dynamics/Non Linear Simulation/MATLAB Function1'
 */
#endif                                 /* hover_plant_sil_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
