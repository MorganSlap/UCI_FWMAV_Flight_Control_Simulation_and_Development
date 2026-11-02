/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_linear_sil.c
 *
 * Code generated for Simulink model 'hover_linear_sil'.
 *
 * Model version                  : 1.1
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Sun Nov  1 20:21:48 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: Intel->x86-64 (Windows64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "hover_linear_sil.h"
#include <string.h>
#include <emmintrin.h>
#include <math.h>
#include "rtwtypes.h"
#include "hover_linear_sil_private.h"
#include "rt_nonfinite.h"

/* Block signals (default storage) */
B_hover_linear_sil_T hover_linear_sil_B;

/* Continuous states */
X_hover_linear_sil_T hover_linear_sil_X;

/* Disabled State Vector */
XDis_hover_linear_sil_T hover_linear_sil_XDis;

/* Block states (default storage) */
DW_hover_linear_sil_T hover_linear_sil_DW;

/* External inputs (root inport signals with default storage) */
ExtU_hover_linear_sil_T hover_linear_sil_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_hover_linear_sil_T hover_linear_sil_Y;

/* Real-time model */
static RT_MODEL_hover_linear_sil_T hover_linear_sil_M_;
RT_MODEL_hover_linear_sil_T *const hover_linear_sil_M = &hover_linear_sil_M_;
static void rate_scheduler(void);

/*
 *         This function updates active task flag for each subrate.
 *         The function is called at model base rate, hence the
 *         generated code self-manages all its subrates.
 */
static void rate_scheduler(void)
{
  /* Compute which subrates run during the next base time step.  Subrates
   * are an integer multiple of the base rate counter.  Therefore, the subtask
   * counter is reset when it reaches its limit (zero means run).
   */
  (hover_linear_sil_M->Timing.TaskCounters.TID[2])++;
  if ((hover_linear_sil_M->Timing.TaskCounters.TID[2]) > 3) {/* Sample time: [0.00025s, 0.0s] */
    hover_linear_sil_M->Timing.TaskCounters.TID[2] = 0;
  }

  (hover_linear_sil_M->Timing.TaskCounters.TID[3])++;
  if ((hover_linear_sil_M->Timing.TaskCounters.TID[3]) > 4) {/* Sample time: [0.0003125s, 0.0s] */
    hover_linear_sil_M->Timing.TaskCounters.TID[3] = 0;
  }

  (hover_linear_sil_M->Timing.TaskCounters.TID[4])++;
  if ((hover_linear_sil_M->Timing.TaskCounters.TID[4]) > 9) {/* Sample time: [0.000625s, 0.0s] */
    hover_linear_sil_M->Timing.TaskCounters.TID[4] = 0;
  }
}

/*
 * This function updates continuous states using the ODE5 fixed-step
 * solver algorithm
 */
static void rt_ertODEUpdateContinuousStates(RTWSolverInfo *si )
{
  /* Solver Matrices */
  static const real_T rt_ODE5_A[6] = {
    1.0/5.0, 3.0/10.0, 4.0/5.0, 8.0/9.0, 1.0, 1.0
  };

  static const real_T rt_ODE5_B[6][6] = {
    { 1.0/5.0, 0.0, 0.0, 0.0, 0.0, 0.0 },

    { 3.0/40.0, 9.0/40.0, 0.0, 0.0, 0.0, 0.0 },

    { 44.0/45.0, -56.0/15.0, 32.0/9.0, 0.0, 0.0, 0.0 },

    { 19372.0/6561.0, -25360.0/2187.0, 64448.0/6561.0, -212.0/729.0, 0.0, 0.0 },

    { 9017.0/3168.0, -355.0/33.0, 46732.0/5247.0, 49.0/176.0, -5103.0/18656.0,
      0.0 },

    { 35.0/384.0, 0.0, 500.0/1113.0, 125.0/192.0, -2187.0/6784.0, 11.0/84.0 }
  };

  time_T t = rtsiGetT(si);
  time_T tnew = rtsiGetSolverStopTime(si);
  time_T h = rtsiGetStepSize(si);
  real_T *x = rtsiGetContStates(si);
  ODE5_IntgData *id = (ODE5_IntgData *)rtsiGetSolverData(si);
  real_T *y = id->y;
  real_T *f0 = id->f[0];
  real_T *f1 = id->f[1];
  real_T *f2 = id->f[2];
  real_T *f3 = id->f[3];
  real_T *f4 = id->f[4];
  real_T *f5 = id->f[5];
  real_T hB[6];
  int_T i;
  int_T nXc = 16;
  rtsiSetSimTimeStep(si,MINOR_TIME_STEP);

  /* Save the state values at time t in y, we'll use x as ynew. */
  (void) memcpy(y, x,
                (uint_T)nXc*sizeof(real_T));

  /* Assumes that rtsiSetT and ModelOutputs are up-to-date */
  /* f0 = f(t,y) */
  rtsiSetdX(si, f0);
  hover_linear_sil_derivatives();

  /* f(:,2) = feval(odefile, t + hA(1), y + f*hB(:,1), args(:)(*)); */
  hB[0] = h * rt_ODE5_B[0][0];
  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[0]);
  rtsiSetdX(si, f1);
  hover_linear_sil_output();
  hover_linear_sil_derivatives();

  /* f(:,3) = feval(odefile, t + hA(2), y + f*hB(:,2), args(:)(*)); */
  for (i = 0; i <= 1; i++) {
    hB[i] = h * rt_ODE5_B[1][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[1]);
  rtsiSetdX(si, f2);
  hover_linear_sil_output();
  hover_linear_sil_derivatives();

  /* f(:,4) = feval(odefile, t + hA(3), y + f*hB(:,3), args(:)(*)); */
  for (i = 0; i <= 2; i++) {
    hB[i] = h * rt_ODE5_B[2][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1] + f2[i]*hB[2]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[2]);
  rtsiSetdX(si, f3);
  hover_linear_sil_output();
  hover_linear_sil_derivatives();

  /* f(:,5) = feval(odefile, t + hA(4), y + f*hB(:,4), args(:)(*)); */
  for (i = 0; i <= 3; i++) {
    hB[i] = h * rt_ODE5_B[3][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1] + f2[i]*hB[2] +
                   f3[i]*hB[3]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[3]);
  rtsiSetdX(si, f4);
  hover_linear_sil_output();
  hover_linear_sil_derivatives();

  /* f(:,6) = feval(odefile, t + hA(5), y + f*hB(:,5), args(:)(*)); */
  for (i = 0; i <= 4; i++) {
    hB[i] = h * rt_ODE5_B[4][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1] + f2[i]*hB[2] +
                   f3[i]*hB[3] + f4[i]*hB[4]);
  }

  rtsiSetT(si, tnew);
  rtsiSetdX(si, f5);
  hover_linear_sil_output();
  hover_linear_sil_derivatives();

  /* tnew = t + hA(6);
     ynew = y + f*hB(:,6); */
  for (i = 0; i <= 5; i++) {
    hB[i] = h * rt_ODE5_B[5][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1] + f2[i]*hB[2] +
                   f3[i]*hB[3] + f4[i]*hB[4] + f5[i]*hB[5]);
  }

  rtsiSetSimTimeStep(si,MAJOR_TIME_STEP);
}

real_T hover_linear_sil_rt_ur_uOkk5MrH(uint32_T *u)
{
  uint32_T hi;
  uint32_T lo;

  /* Uniform random number generator (random number between 0 and 1)

     #define IA      16807                      magic multiplier = 7^5
     #define IM      2147483647                 modulus = 2^31-1
     #define IQ      127773                     IM div IA
     #define IR      2836                       IM modulo IA
     #define S       4.656612875245797e-10      reciprocal of 2^31-1
     test = IA * (seed % IQ) - IR * (seed/IQ)
     seed = test < 0 ? (test + IM) : test
     return (seed*S)
   */
  lo = *u % 127773U * 16807U;
  hi = *u / 127773U * 2836U;
  if (lo < hi) {
    *u = 2147483647U - (hi - lo);
  } else {
    *u = lo - hi;
  }

  return (real_T)*u * 4.6566128752457969E-10;
}

real_T hover_linear_sil_rt_nr_Wisg0zun(uint32_T *u)
{
  real_T si;
  real_T sr;
  real_T y;

  /* Normal (Gaussian) random number generator */
  do {
    sr = 2.0 * hover_linear_sil_rt_ur_uOkk5MrH(u) - 1.0;
    si = 2.0 * hover_linear_sil_rt_ur_uOkk5MrH(u) - 1.0;
    si = sr * sr + si * si;
  } while (si > 1.0);

  y = sqrt(-2.0 * log(si) / si) * sr;
  return y;
}

/* Model output function */
void hover_linear_sil_output(void)
{
  __m128d tmp_1;
  real_T tmp_2[2];
  real_T force_idx_0;
  real_T force_idx_1;
  real_T force_idx_2;
  int_T iy;
  int_T ri;
  boolean_T tmp;
  boolean_T tmp_0;
  if (rtmIsMajorTimeStep(hover_linear_sil_M)) {
    /* set solver stop time */
    rtsiSetSolverStopTime(&hover_linear_sil_M->solverInfo,
                          ((hover_linear_sil_M->Timing.clockTick0+1)*
      hover_linear_sil_M->Timing.stepSize0));
  }                                    /* end MajorTimeStep */

  /* Update absolute time of base rate at minor time step */
  if (rtmIsMinorTimeStep(hover_linear_sil_M)) {
    hover_linear_sil_M->Timing.t[0] = rtsiGetT(&hover_linear_sil_M->solverInfo);
  }

  /* StateSpace: '<S10>/Full State Lin Sim' */
  memset(&hover_linear_sil_Y.true_state[0], 0, 12U * sizeof(real_T));
  for (iy = 0; iy < 12; iy++) {
    for (ri = 0; ri <= 10; ri += 2) {
      tmp_1 = _mm_loadu_pd(&hover_linear_sil_Y.true_state[ri]);
      _mm_storeu_pd(&hover_linear_sil_Y.true_state[ri], _mm_add_pd(_mm_mul_pd
        (_mm_loadu_pd(&hover_linear_sil_P.FullStateLinSim_C[iy * 12 + ri]),
         _mm_set1_pd(hover_linear_sil_X.FullStateLinSim_CSTATE[iy])), tmp_1));
    }
  }

  /* End of StateSpace: '<S10>/Full State Lin Sim' */
  tmp_0 = (rtmIsMajorTimeStep(hover_linear_sil_M) &&
           hover_linear_sil_M->Timing.TaskCounters.TID[2] == 0);
  if (tmp_0) {
    /* Gain: '<S7>/Output' */
    hover_linear_sil_B.NoiseOption[0] =
      hover_linear_sil_P.WingThrustUncertainty_Cov[0];
    hover_linear_sil_B.NoiseOption[0] = sqrt(hover_linear_sil_B.NoiseOption[0]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_linear_sil_B.NoiseOption[0] = hover_linear_sil_B.NoiseOption[0] /
      0.015811388300841896 * hover_linear_sil_DW.NextOutput *
      hover_linear_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_linear_sil_B.NoiseOption[1] =
      hover_linear_sil_P.WingThrustUncertainty_Cov[1];
    hover_linear_sil_B.NoiseOption[1] = sqrt(hover_linear_sil_B.NoiseOption[1]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_linear_sil_B.NoiseOption[1] = hover_linear_sil_B.NoiseOption[1] /
      0.015811388300841896 * hover_linear_sil_DW.NextOutput *
      hover_linear_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_linear_sil_B.NoiseOption[2] =
      hover_linear_sil_P.WingThrustUncertainty_Cov[2];
    hover_linear_sil_B.NoiseOption[2] = sqrt(hover_linear_sil_B.NoiseOption[2]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_linear_sil_B.NoiseOption[2] = hover_linear_sil_B.NoiseOption[2] /
      0.015811388300841896 * hover_linear_sil_DW.NextOutput *
      hover_linear_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_linear_sil_B.NoiseOption[3] =
      hover_linear_sil_P.WingThrustUncertainty_Cov[3];
    hover_linear_sil_B.NoiseOption[3] = sqrt(hover_linear_sil_B.NoiseOption[3]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_linear_sil_B.NoiseOption[3] = hover_linear_sil_B.NoiseOption[3] /
      0.015811388300841896 * hover_linear_sil_DW.NextOutput *
      hover_linear_sil_P.noise_true;
  }

  /* TransferFcn: '<S2>/Transfer Fcn1' incorporates:
   *  Sum: '<S2>/Sum'
   *  TransferFcn: '<S2>/Transfer Fcn'
   */
  tmp_1 = _mm_add_pd(_mm_mul_pd(_mm_set_pd(hover_linear_sil_P.TransferFcn1_C,
    hover_linear_sil_P.TransferFcn_C), _mm_set_pd
    (hover_linear_sil_X.TransferFcn1_CSTATE,
     hover_linear_sil_X.TransferFcn_CSTATE)), _mm_loadu_pd
                     (&hover_linear_sil_B.NoiseOption[0]));

  /* Sum: '<S2>/Sum' */
  _mm_storeu_pd(&hover_linear_sil_B.Sum[0], tmp_1);

  /* TransferFcn: '<S2>/Transfer Fcn3' incorporates:
   *  Sum: '<S2>/Sum'
   *  TransferFcn: '<S2>/Transfer Fcn2'
   */
  tmp_1 = _mm_add_pd(_mm_mul_pd(_mm_set_pd(hover_linear_sil_P.TransferFcn3_C,
    hover_linear_sil_P.TransferFcn2_C), _mm_set_pd
    (hover_linear_sil_X.TransferFcn3_CSTATE,
     hover_linear_sil_X.TransferFcn2_CSTATE)), _mm_loadu_pd
                     (&hover_linear_sil_B.NoiseOption[2]));

  /* Sum: '<S2>/Sum' */
  _mm_storeu_pd(&hover_linear_sil_B.Sum[2], tmp_1);

  /* Outport: '<Root>/actuator_delta' */
  hover_linear_sil_Y.actuator_delta[0] = hover_linear_sil_B.Sum[0];
  hover_linear_sil_Y.actuator_delta[1] = hover_linear_sil_B.Sum[1];
  hover_linear_sil_Y.actuator_delta[2] = hover_linear_sil_B.Sum[2];
  hover_linear_sil_Y.actuator_delta[3] = hover_linear_sil_B.Sum[3];

  /* MATLAB Function: '<Root>/MATLAB Function' */
  force_idx_2 = 0.5 * hover_linear_sil_P.rho;
  if (hover_linear_sil_P.imu_nonlinear) {
    tmp_1 = _mm_mul_pd(_mm_mul_pd(_mm_set_pd(-(hover_linear_sil_P.CDy *
      hover_linear_sil_P.Ay * force_idx_2), -(hover_linear_sil_P.CDx *
      hover_linear_sil_P.Ax * force_idx_2)), _mm_set_pd(fabs
      (hover_linear_sil_Y.true_state[4]), fabs(hover_linear_sil_Y.true_state[3]))),
                       _mm_loadu_pd(&hover_linear_sil_Y.true_state[3]));
    _mm_storeu_pd(&tmp_2[0], tmp_1);
    force_idx_0 = tmp_2[0];
    force_idx_1 = tmp_2[1];
    force_idx_2 = -(hover_linear_sil_P.CDz * hover_linear_sil_P.Az * force_idx_2)
      * fabs(hover_linear_sil_Y.true_state[5]) * hover_linear_sil_Y.true_state[5];
  } else {
    tmp_1 = _mm_mul_pd(_mm_set_pd(-hover_linear_sil_P.Yv, -hover_linear_sil_P.Xu),
                       _mm_loadu_pd(&hover_linear_sil_Y.true_state[3]));
    _mm_storeu_pd(&tmp_2[0], tmp_1);
    force_idx_0 = tmp_2[0];
    force_idx_1 = tmp_2[1];
    force_idx_2 = -hover_linear_sil_P.Zw * hover_linear_sil_Y.true_state[5];
  }

  hover_linear_sil_Y.accel_ideal[0] = force_idx_0 / hover_linear_sil_P.m;
  hover_linear_sil_Y.accel_ideal[1] = force_idx_1 / hover_linear_sil_P.m;
  hover_linear_sil_Y.accel_ideal[2] = (-hover_linear_sil_P.g -
    (((hover_linear_sil_B.Sum[0] + hover_linear_sil_B.Sum[1]) +
      hover_linear_sil_B.Sum[2]) + hover_linear_sil_B.Sum[3]) *
    hover_linear_sil_P.C11 / hover_linear_sil_P.m) + force_idx_2 /
    hover_linear_sil_P.m;
  tmp = (rtmIsMajorTimeStep(hover_linear_sil_M) &&
         hover_linear_sil_M->Timing.TaskCounters.TID[3] == 0);
  if (tmp) {
    /* Gain: '<S8>/Output' */
    hover_linear_sil_B.Sum1[0] = hover_linear_sil_P.sil_gyro_noise_power[0];
    hover_linear_sil_B.Sum1[0] = sqrt(hover_linear_sil_B.Sum1[0]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_linear_sil_B.Sum1[0] = hover_linear_sil_B.Sum1[0] /
      0.017677669529663688 * hover_linear_sil_DW.NextOutput_l *
      hover_linear_sil_P.noise_true + hover_linear_sil_P.gyro.bias[0] *
      0.017453292519943295 * hover_linear_sil_P.noise_true;

    /* Gain: '<S8>/Output' */
    hover_linear_sil_B.Sum1[1] = hover_linear_sil_P.sil_gyro_noise_power[1];
    hover_linear_sil_B.Sum1[1] = sqrt(hover_linear_sil_B.Sum1[1]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_linear_sil_B.Sum1[1] = hover_linear_sil_B.Sum1[1] /
      0.017677669529663688 * hover_linear_sil_DW.NextOutput_l *
      hover_linear_sil_P.noise_true + hover_linear_sil_P.gyro.bias[1] *
      0.017453292519943295 * hover_linear_sil_P.noise_true;

    /* Gain: '<S8>/Output' */
    hover_linear_sil_B.Sum1[2] = hover_linear_sil_P.sil_gyro_noise_power[2];
    hover_linear_sil_B.Sum1[2] = sqrt(hover_linear_sil_B.Sum1[2]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_linear_sil_B.Sum1[2] = hover_linear_sil_B.Sum1[2] /
      0.017677669529663688 * hover_linear_sil_DW.NextOutput_l *
      hover_linear_sil_P.noise_true + hover_linear_sil_P.gyro.bias[2] *
      0.017453292519943295 * hover_linear_sil_P.noise_true;
  }

  /* Gain: '<Root>/Noise Option' incorporates:
   *  Sin: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  force_idx_1 = (sin(hover_linear_sil_P.WingDisturbanceUnitAmplitude_Fr *
                     hover_linear_sil_M->Timing.t[0] +
                     hover_linear_sil_P.WingDisturbanceUnitAmplitude_Ph) *
                 hover_linear_sil_P.WingDisturbanceUnitAmplitude_Am +
                 hover_linear_sil_P.WingDisturbanceUnitAmplitude_Bi) *
    hover_linear_sil_P.noise_true;

  /* Gain: '<S3>/Gyro Noise Scaling' */
  force_idx_2 = hover_linear_sil_P.gyro.vibration * 0.017453292519943295 *
    force_idx_1;
  if (tmp) {
    /* Sum: '<S3>/Sum' incorporates:
     *  MATLAB Function: '<Root>/MATLAB Function'
     *  Sum: '<S3>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1[0] + hover_linear_sil_Y.true_state[9])
      + force_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (force_idx_0 > hover_linear_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[0] =
        hover_linear_sil_P.GyroRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[0] =
        hover_linear_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[0] = force_idx_0;
    }

    /* Sum: '<S3>/Sum' incorporates:
     *  MATLAB Function: '<Root>/MATLAB Function'
     *  Sum: '<S3>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1[1] + hover_linear_sil_Y.true_state[10])
      + force_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (force_idx_0 > hover_linear_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[1] =
        hover_linear_sil_P.GyroRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[1] =
        hover_linear_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[1] = force_idx_0;
    }

    /* Sum: '<S3>/Sum' incorporates:
     *  MATLAB Function: '<Root>/MATLAB Function'
     *  Sum: '<S3>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1[2] + hover_linear_sil_Y.true_state[11])
      + force_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (force_idx_0 > hover_linear_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[2] =
        hover_linear_sil_P.GyroRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[2] =
        hover_linear_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_linear_sil_B.GyroSampleRate[2] = force_idx_0;
    }
  }

  if (tmp_0) {
    /* Outport: '<Root>/gyro_measured' incorporates:
     *  ZeroOrderHold: '<Root>/Gyro sample'
     *  ZeroOrderHold: '<S3>/Gyro Sample Rate'
     */
    hover_linear_sil_Y.gyro_measured[0] = hover_linear_sil_B.GyroSampleRate[0];
    hover_linear_sil_Y.gyro_measured[1] = hover_linear_sil_B.GyroSampleRate[1];
    hover_linear_sil_Y.gyro_measured[2] = hover_linear_sil_B.GyroSampleRate[2];
  }

  /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
  tmp = (rtmIsMajorTimeStep(hover_linear_sil_M) &&
         hover_linear_sil_M->Timing.TaskCounters.TID[4] == 0);
  if (tmp) {
    /* Gain: '<S6>/Output' */
    hover_linear_sil_B.Sum1_m[0] = hover_linear_sil_P.sil_accel_noise_power[0];
    hover_linear_sil_B.Sum1_m[0] = sqrt(hover_linear_sil_B.Sum1_m[0]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_linear_sil_B.Sum1_m[0] = hover_linear_sil_B.Sum1_m[0] / 0.025 *
      hover_linear_sil_DW.NextOutput_lo * hover_linear_sil_P.noise_true +
      hover_linear_sil_P.accel.bias[0] * hover_linear_sil_P.g *
      hover_linear_sil_P.noise_true;

    /* Gain: '<S6>/Output' */
    hover_linear_sil_B.Sum1_m[1] = hover_linear_sil_P.sil_accel_noise_power[1];
    hover_linear_sil_B.Sum1_m[1] = sqrt(hover_linear_sil_B.Sum1_m[1]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_linear_sil_B.Sum1_m[1] = hover_linear_sil_B.Sum1_m[1] / 0.025 *
      hover_linear_sil_DW.NextOutput_lo * hover_linear_sil_P.noise_true +
      hover_linear_sil_P.accel.bias[1] * hover_linear_sil_P.g *
      hover_linear_sil_P.noise_true;

    /* Gain: '<S6>/Output' */
    hover_linear_sil_B.Sum1_m[2] = hover_linear_sil_P.sil_accel_noise_power[2];
    hover_linear_sil_B.Sum1_m[2] = sqrt(hover_linear_sil_B.Sum1_m[2]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_linear_sil_B.Sum1_m[2] = hover_linear_sil_B.Sum1_m[2] / 0.025 *
      hover_linear_sil_DW.NextOutput_lo * hover_linear_sil_P.noise_true +
      hover_linear_sil_P.accel.bias[2] * hover_linear_sil_P.g *
      hover_linear_sil_P.noise_true;
  }

  /* Gain: '<S1>/Accel Noise Scaling' */
  force_idx_1 *= hover_linear_sil_P.accel.vibration * hover_linear_sil_P.g;

  /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
  if (tmp) {
    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1_m[0] +
                   hover_linear_sil_Y.accel_ideal[0]) + force_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (force_idx_0 > hover_linear_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[0] =
        hover_linear_sil_P.AccelRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[0] =
        hover_linear_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[0] = force_idx_0;
    }

    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1_m[1] +
                   hover_linear_sil_Y.accel_ideal[1]) + force_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (force_idx_0 > hover_linear_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[1] =
        hover_linear_sil_P.AccelRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[1] =
        hover_linear_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[1] = force_idx_0;
    }

    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    force_idx_0 = (hover_linear_sil_B.Sum1_m[2] +
                   hover_linear_sil_Y.accel_ideal[2]) + force_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (force_idx_0 > hover_linear_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[2] =
        hover_linear_sil_P.AccelRange_UpperSat;
    } else if (force_idx_0 < hover_linear_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[2] =
        hover_linear_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_linear_sil_B.AccelSampleRate[2] = force_idx_0;
    }
  }

  if (tmp_0) {
    /* Outport: '<Root>/accel_measured' incorporates:
     *  ZeroOrderHold: '<Root>/Accelerometer sample'
     *  ZeroOrderHold: '<S1>/Accel Sample Rate'
     */
    hover_linear_sil_Y.accel_measured[0] = hover_linear_sil_B.AccelSampleRate[0];
    hover_linear_sil_Y.accel_measured[1] = hover_linear_sil_B.AccelSampleRate[1];
    hover_linear_sil_Y.accel_measured[2] = hover_linear_sil_B.AccelSampleRate[2];
  }

  /* Outport: '<Root>/gyro_ideal' incorporates:
   *  MATLAB Function: '<Root>/MATLAB Function'
   */
  hover_linear_sil_Y.gyro_ideal[0] = hover_linear_sil_Y.true_state[9];
  hover_linear_sil_Y.gyro_ideal[1] = hover_linear_sil_Y.true_state[10];
  hover_linear_sil_Y.gyro_ideal[2] = hover_linear_sil_Y.true_state[11];
}

/* Model update function */
void hover_linear_sil_update(void)
{
  if (rtmIsMajorTimeStep(hover_linear_sil_M) &&
      hover_linear_sil_M->Timing.TaskCounters.TID[2] == 0) {
    /* Update for RandomNumber: '<S7>/White Noise' */
    hover_linear_sil_DW.NextOutput = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed) * hover_linear_sil_P.WhiteNoise_StdDev +
      hover_linear_sil_P.WhiteNoise_Mean;
  }

  if (rtmIsMajorTimeStep(hover_linear_sil_M) &&
      hover_linear_sil_M->Timing.TaskCounters.TID[3] == 0) {
    /* Update for RandomNumber: '<S8>/White Noise' */
    hover_linear_sil_DW.NextOutput_l = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed_e) * hover_linear_sil_P.WhiteNoise_StdDev_i
      + hover_linear_sil_P.WhiteNoise_Mean_p;
  }

  if (rtmIsMajorTimeStep(hover_linear_sil_M) &&
      hover_linear_sil_M->Timing.TaskCounters.TID[4] == 0) {
    /* Update for RandomNumber: '<S6>/White Noise' */
    hover_linear_sil_DW.NextOutput_lo = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed_j) * hover_linear_sil_P.WhiteNoise_StdDev_c
      + hover_linear_sil_P.WhiteNoise_Mean_a;
  }

  if (rtmIsMajorTimeStep(hover_linear_sil_M)) {
    rt_ertODEUpdateContinuousStates(&hover_linear_sil_M->solverInfo);
  }

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The absolute time is the multiplication of "clockTick0"
   * and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
   * overflow during the application lifespan selected.
   */
  ++hover_linear_sil_M->Timing.clockTick0;
  hover_linear_sil_M->Timing.t[0] = rtsiGetSolverStopTime
    (&hover_linear_sil_M->solverInfo);

  {
    /* Update absolute timer for sample time: [6.25E-5s, 0.0s] */
    /* The "clockTick1" counts the number of times the code of this task has
     * been executed. The resolution of this integer timer is 6.25E-5, which is the step size
     * of the task. Size of "clockTick1" ensures timer will not overflow during the
     * application lifespan selected.
     */
    hover_linear_sil_M->Timing.clockTick1++;
  }

  rate_scheduler();
}

/* Derivatives for root system: '<Root>' */
void hover_linear_sil_derivatives(void)
{
  __m128d tmp;
  XDot_hover_linear_sil_T *_rtXdot;
  real_T Sum;
  real_T Sum_0;
  real_T Sum_1;
  real_T Sum_2;
  int_T is;
  int_T ri;
  _rtXdot = ((XDot_hover_linear_sil_T *) hover_linear_sil_M->derivs);

  /* Derivatives for StateSpace: '<S10>/Full State Lin Sim' */
  memset(&_rtXdot->FullStateLinSim_CSTATE[0], 0, 12U * sizeof(real_T));
  for (is = 0; is < 12; is++) {
    for (ri = 0; ri <= 10; ri += 2) {
      tmp = _mm_loadu_pd(&_rtXdot->FullStateLinSim_CSTATE[ri]);
      _mm_storeu_pd(&_rtXdot->FullStateLinSim_CSTATE[ri], _mm_add_pd(_mm_mul_pd
        (_mm_loadu_pd(&hover_linear_sil_P.A[is * 12 + ri]), _mm_set1_pd
         (hover_linear_sil_X.FullStateLinSim_CSTATE[is])), tmp));
    }
  }

  Sum = hover_linear_sil_B.Sum[0];
  Sum_0 = hover_linear_sil_B.Sum[1];
  Sum_1 = hover_linear_sil_B.Sum[2];
  Sum_2 = hover_linear_sil_B.Sum[3];
  for (ri = 0; ri <= 10; ri += 2) {
    tmp = _mm_loadu_pd(&_rtXdot->FullStateLinSim_CSTATE[ri]);
    _mm_storeu_pd(&_rtXdot->FullStateLinSim_CSTATE[ri], _mm_add_pd(_mm_add_pd
      (_mm_add_pd(_mm_add_pd(_mm_mul_pd(_mm_loadu_pd(&hover_linear_sil_P.B[ri]),
      _mm_set1_pd(Sum)), tmp), _mm_mul_pd(_mm_loadu_pd(&hover_linear_sil_P.B[ri
      + 12]), _mm_set1_pd(Sum_0))), _mm_mul_pd(_mm_loadu_pd
      (&hover_linear_sil_P.B[ri + 24]), _mm_set1_pd(Sum_1))), _mm_mul_pd
      (_mm_loadu_pd(&hover_linear_sil_P.B[ri + 36]), _mm_set1_pd(Sum_2))));
  }

  /* End of Derivatives for StateSpace: '<S10>/Full State Lin Sim' */

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn_CSTATE = hover_linear_sil_P.TransferFcn_A *
    hover_linear_sil_X.TransferFcn_CSTATE;
  _rtXdot->TransferFcn_CSTATE += hover_linear_sil_U.motor_delta[0];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn1' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn1_CSTATE = hover_linear_sil_P.TransferFcn1_A *
    hover_linear_sil_X.TransferFcn1_CSTATE;
  _rtXdot->TransferFcn1_CSTATE += hover_linear_sil_U.motor_delta[1];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn2' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn2_CSTATE = hover_linear_sil_P.TransferFcn2_A *
    hover_linear_sil_X.TransferFcn2_CSTATE;
  _rtXdot->TransferFcn2_CSTATE += hover_linear_sil_U.motor_delta[2];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn3' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn3_CSTATE = hover_linear_sil_P.TransferFcn3_A *
    hover_linear_sil_X.TransferFcn3_CSTATE;
  _rtXdot->TransferFcn3_CSTATE += hover_linear_sil_U.motor_delta[3];
}

/* Model initialize function */
void hover_linear_sil_initialize(void)
{
  /* Registration code */
  {
    /* Setup solver object */
    rtsiSetSimTimeStepPtr(&hover_linear_sil_M->solverInfo,
                          &hover_linear_sil_M->Timing.simTimeStep);
    rtsiSetTPtr(&hover_linear_sil_M->solverInfo, &rtmGetTPtr(hover_linear_sil_M));
    rtsiSetStepSizePtr(&hover_linear_sil_M->solverInfo,
                       &hover_linear_sil_M->Timing.stepSize0);
    rtsiSetdXPtr(&hover_linear_sil_M->solverInfo, &hover_linear_sil_M->derivs);
    rtsiSetContStatesPtr(&hover_linear_sil_M->solverInfo, (real_T **)
                         &hover_linear_sil_M->contStates);
    rtsiSetNumContStatesPtr(&hover_linear_sil_M->solverInfo,
      &hover_linear_sil_M->Sizes.numContStates);
    rtsiSetNumPeriodicContStatesPtr(&hover_linear_sil_M->solverInfo,
      &hover_linear_sil_M->Sizes.numPeriodicContStates);
    rtsiSetPeriodicContStateIndicesPtr(&hover_linear_sil_M->solverInfo,
      &hover_linear_sil_M->periodicContStateIndices);
    rtsiSetPeriodicContStateRangesPtr(&hover_linear_sil_M->solverInfo,
      &hover_linear_sil_M->periodicContStateRanges);
    rtsiSetContStateDisabledPtr(&hover_linear_sil_M->solverInfo, (boolean_T**)
      &hover_linear_sil_M->contStateDisabled);
    rtsiSetErrorStatusPtr(&hover_linear_sil_M->solverInfo, (&rtmGetErrorStatus
      (hover_linear_sil_M)));
    rtsiSetRTModelPtr(&hover_linear_sil_M->solverInfo, hover_linear_sil_M);
  }

  rtsiSetSimTimeStep(&hover_linear_sil_M->solverInfo, MAJOR_TIME_STEP);
  rtsiSetIsMinorTimeStepWithModeChange(&hover_linear_sil_M->solverInfo, false);
  rtsiSetIsContModeFrozen(&hover_linear_sil_M->solverInfo, false);
  hover_linear_sil_M->intgData.y = hover_linear_sil_M->odeY;
  hover_linear_sil_M->intgData.f[0] = hover_linear_sil_M->odeF[0];
  hover_linear_sil_M->intgData.f[1] = hover_linear_sil_M->odeF[1];
  hover_linear_sil_M->intgData.f[2] = hover_linear_sil_M->odeF[2];
  hover_linear_sil_M->intgData.f[3] = hover_linear_sil_M->odeF[3];
  hover_linear_sil_M->intgData.f[4] = hover_linear_sil_M->odeF[4];
  hover_linear_sil_M->intgData.f[5] = hover_linear_sil_M->odeF[5];
  hover_linear_sil_M->contStates = ((X_hover_linear_sil_T *) &hover_linear_sil_X);
  hover_linear_sil_M->contStateDisabled = ((XDis_hover_linear_sil_T *)
    &hover_linear_sil_XDis);
  hover_linear_sil_M->Timing.tStart = (0.0);
  rtsiSetSolverData(&hover_linear_sil_M->solverInfo, (void *)
                    &hover_linear_sil_M->intgData);
  rtsiSetSolverName(&hover_linear_sil_M->solverInfo,"ode5");
  rtmSetTPtr(hover_linear_sil_M, &hover_linear_sil_M->Timing.tArray[0]);
  hover_linear_sil_M->Timing.stepSize0 = 6.25E-5;

  {
    real_T tmp;
    uint32_T r;
    uint32_T t;
    uint32_T tseed;

    /* InitializeConditions for StateSpace: '<S10>/Full State Lin Sim' */
    memcpy(&hover_linear_sil_X.FullStateLinSim_CSTATE[0],
           &hover_linear_sil_P.X0[0], 12U * sizeof(real_T));

    /* InitializeConditions for RandomNumber: '<S7>/White Noise' */
    tmp = floor(hover_linear_sil_P.WingThrustUncertainty_seed);
    if (rtIsNaN(tmp) || rtIsInf(tmp)) {
      tmp = 0.0;
    } else {
      tmp = fmod(tmp, 4.294967296E+9);
    }

    if (tmp < 0.0) {
      tseed = (uint32_T)-(int32_T)(uint32_T)-tmp;
    } else {
      tseed = (uint32_T)tmp;
    }

    r = tseed >> 16U;
    t = tseed & 32768U;
    hover_linear_sil_DW.RandSeed = ((((tseed - (r << 16U)) + t) << 16U) + t) + r;
    if (hover_linear_sil_DW.RandSeed < 1U) {
      hover_linear_sil_DW.RandSeed = 1144108930U;
    } else if (hover_linear_sil_DW.RandSeed > 2147483646U) {
      hover_linear_sil_DW.RandSeed = 2147483646U;
    }

    hover_linear_sil_DW.NextOutput = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed) * hover_linear_sil_P.WhiteNoise_StdDev +
      hover_linear_sil_P.WhiteNoise_Mean;

    /* End of InitializeConditions for RandomNumber: '<S7>/White Noise' */

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn' */
    hover_linear_sil_X.TransferFcn_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn1' */
    hover_linear_sil_X.TransferFcn1_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn2' */
    hover_linear_sil_X.TransferFcn2_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn3' */
    hover_linear_sil_X.TransferFcn3_CSTATE = 0.0;

    /* InitializeConditions for RandomNumber: '<S8>/White Noise' */
    tmp = floor(hover_linear_sil_P.GyroWhiteNoise_seed);
    if (rtIsNaN(tmp) || rtIsInf(tmp)) {
      tmp = 0.0;
    } else {
      tmp = fmod(tmp, 4.294967296E+9);
    }

    if (tmp < 0.0) {
      tseed = (uint32_T)-(int32_T)(uint32_T)-tmp;
    } else {
      tseed = (uint32_T)tmp;
    }

    r = tseed >> 16U;
    t = tseed & 32768U;
    hover_linear_sil_DW.RandSeed_e = ((((tseed - (r << 16U)) + t) << 16U) + t) +
      r;
    if (hover_linear_sil_DW.RandSeed_e < 1U) {
      hover_linear_sil_DW.RandSeed_e = 1144108930U;
    } else if (hover_linear_sil_DW.RandSeed_e > 2147483646U) {
      hover_linear_sil_DW.RandSeed_e = 2147483646U;
    }

    hover_linear_sil_DW.NextOutput_l = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed_e) * hover_linear_sil_P.WhiteNoise_StdDev_i
      + hover_linear_sil_P.WhiteNoise_Mean_p;

    /* End of InitializeConditions for RandomNumber: '<S8>/White Noise' */

    /* InitializeConditions for RandomNumber: '<S6>/White Noise' */
    tmp = floor(hover_linear_sil_P.AccelWhiteNoise_seed);
    if (rtIsNaN(tmp) || rtIsInf(tmp)) {
      tmp = 0.0;
    } else {
      tmp = fmod(tmp, 4.294967296E+9);
    }

    if (tmp < 0.0) {
      tseed = (uint32_T)-(int32_T)(uint32_T)-tmp;
    } else {
      tseed = (uint32_T)tmp;
    }

    r = tseed >> 16U;
    t = tseed & 32768U;
    hover_linear_sil_DW.RandSeed_j = ((((tseed - (r << 16U)) + t) << 16U) + t) +
      r;
    if (hover_linear_sil_DW.RandSeed_j < 1U) {
      hover_linear_sil_DW.RandSeed_j = 1144108930U;
    } else if (hover_linear_sil_DW.RandSeed_j > 2147483646U) {
      hover_linear_sil_DW.RandSeed_j = 2147483646U;
    }

    hover_linear_sil_DW.NextOutput_lo = hover_linear_sil_rt_nr_Wisg0zun
      (&hover_linear_sil_DW.RandSeed_j) * hover_linear_sil_P.WhiteNoise_StdDev_c
      + hover_linear_sil_P.WhiteNoise_Mean_a;

    /* End of InitializeConditions for RandomNumber: '<S6>/White Noise' */
  }
}

/* Model terminate function */
void hover_linear_sil_terminate(void)
{
  /* (no terminate code required) */
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
