/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_plant_sil.c
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

#include "hover_plant_sil.h"
#include <string.h>
#include <emmintrin.h>
#include <math.h>
#include "hover_plant_sil_private.h"
#include "rtwtypes.h"
#include "rt_nonfinite.h"

/* Block signals (default storage) */
B_hover_plant_sil_T hover_plant_sil_B;

/* Continuous states */
X_hover_plant_sil_T hover_plant_sil_X;

/* Disabled State Vector */
XDis_hover_plant_sil_T hover_plant_sil_XDis;

/* Block states (default storage) */
DW_hover_plant_sil_T hover_plant_sil_DW;

/* External inputs (root inport signals with default storage) */
ExtU_hover_plant_sil_T hover_plant_sil_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_hover_plant_sil_T hover_plant_sil_Y;

/* Real-time model */
static RT_MODEL_hover_plant_sil_T hover_plant_sil_M_;
RT_MODEL_hover_plant_sil_T *const hover_plant_sil_M = &hover_plant_sil_M_;
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
  (hover_plant_sil_M->Timing.TaskCounters.TID[2])++;
  if ((hover_plant_sil_M->Timing.TaskCounters.TID[2]) > 3) {/* Sample time: [0.00025s, 0.0s] */
    hover_plant_sil_M->Timing.TaskCounters.TID[2] = 0;
  }

  (hover_plant_sil_M->Timing.TaskCounters.TID[3])++;
  if ((hover_plant_sil_M->Timing.TaskCounters.TID[3]) > 4) {/* Sample time: [0.0003125s, 0.0s] */
    hover_plant_sil_M->Timing.TaskCounters.TID[3] = 0;
  }

  (hover_plant_sil_M->Timing.TaskCounters.TID[4])++;
  if ((hover_plant_sil_M->Timing.TaskCounters.TID[4]) > 9) {/* Sample time: [0.000625s, 0.0s] */
    hover_plant_sil_M->Timing.TaskCounters.TID[4] = 0;
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
  hover_plant_sil_derivatives();

  /* f(:,2) = feval(odefile, t + hA(1), y + f*hB(:,1), args(:)(*)); */
  hB[0] = h * rt_ODE5_B[0][0];
  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[0]);
  rtsiSetdX(si, f1);
  hover_plant_sil_output();
  hover_plant_sil_derivatives();

  /* f(:,3) = feval(odefile, t + hA(2), y + f*hB(:,2), args(:)(*)); */
  for (i = 0; i <= 1; i++) {
    hB[i] = h * rt_ODE5_B[1][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[1]);
  rtsiSetdX(si, f2);
  hover_plant_sil_output();
  hover_plant_sil_derivatives();

  /* f(:,4) = feval(odefile, t + hA(3), y + f*hB(:,3), args(:)(*)); */
  for (i = 0; i <= 2; i++) {
    hB[i] = h * rt_ODE5_B[2][i];
  }

  for (i = 0; i < nXc; i++) {
    x[i] = y[i] + (f0[i]*hB[0] + f1[i]*hB[1] + f2[i]*hB[2]);
  }

  rtsiSetT(si, t + h*rt_ODE5_A[2]);
  rtsiSetdX(si, f3);
  hover_plant_sil_output();
  hover_plant_sil_derivatives();

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
  hover_plant_sil_output();
  hover_plant_sil_derivatives();

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
  hover_plant_sil_output();
  hover_plant_sil_derivatives();

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

real_T hover_plant_sil_rt_powd_snf(real_T u0, real_T u1)
{
  real_T y;
  if (rtIsNaN(u0) || rtIsNaN(u1)) {
    y = (rtNaN);
  } else {
    real_T tmp;
    real_T tmp_0;
    tmp = fabs(u0);
    tmp_0 = fabs(u1);
    if (rtIsInf(u1)) {
      if (tmp == 1.0) {
        y = 1.0;
      } else if (tmp > 1.0) {
        if (u1 > 0.0) {
          y = (rtInf);
        } else {
          y = 0.0;
        }
      } else if (u1 > 0.0) {
        y = 0.0;
      } else {
        y = (rtInf);
      }
    } else if (tmp_0 == 0.0) {
      y = 1.0;
    } else if (tmp_0 == 1.0) {
      if (u1 > 0.0) {
        y = u0;
      } else {
        y = 1.0 / u0;
      }
    } else if (u1 == 2.0) {
      y = u0 * u0;
    } else if ((u1 == 0.5) && (u0 >= 0.0)) {
      y = sqrt(u0);
    } else if ((u0 < 0.0) && (u1 > floor(u1))) {
      y = (rtNaN);
    } else {
      y = pow(u0, u1);
    }
  }

  return y;
}

real_T hover_plant_sil_rt_ura_ukuL2Qrh(uint32_T *u)
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

real_T hover_plant_sil_rt_nra_NCYE4nEi(uint32_T *u)
{
  real_T si;
  real_T sr;
  real_T y;

  /* Normal (Gaussian) random number generator */
  do {
    sr = 2.0 * hover_plant_sil_rt_ura_ukuL2Qrh(u) - 1.0;
    si = 2.0 * hover_plant_sil_rt_ura_ukuL2Qrh(u) - 1.0;
    si = sr * sr + si * si;
  } while (si > 1.0);

  y = sqrt(-2.0 * log(si) / si) * sr;
  return y;
}

/* Model output function */
void hover_plant_sil_output(void)
{
  __m128d tmp_4;
  __m128d tmp_5;
  __m128d tmp_6;
  __m128d tmp_7;
  real_T dx_tmp_6[9];
  real_T tmp_2[9];
  real_T F[3];
  real_T dx_tmp_7[3];
  real_T force[3];
  real_T tmp_1[3];
  real_T x_tmp[3];
  real_T x_tmp_0[3];
  real_T tmp_3[2];
  real_T F_tmp;
  real_T T_idx_0;
  real_T T_idx_1;
  real_T T_idx_2;
  real_T T_idx_3;
  real_T b;
  real_T dx_tmp;
  real_T dx_tmp_0;
  real_T dx_tmp_1;
  real_T dx_tmp_2;
  real_T dx_tmp_3;
  real_T dx_tmp_4;
  real_T dx_tmp_5;
  real_T dx_tmp_tmp;
  real_T y;
  int32_T i;
  boolean_T tmp;
  boolean_T tmp_0;
  if (rtmIsMajorTimeStep(hover_plant_sil_M)) {
    /* set solver stop time */
    rtsiSetSolverStopTime(&hover_plant_sil_M->solverInfo,
                          ((hover_plant_sil_M->Timing.clockTick0+1)*
      hover_plant_sil_M->Timing.stepSize0));
  }                                    /* end MajorTimeStep */

  /* Update absolute time of base rate at minor time step */
  if (rtmIsMinorTimeStep(hover_plant_sil_M)) {
    hover_plant_sil_M->Timing.t[0] = rtsiGetT(&hover_plant_sil_M->solverInfo);
  }

  /* Outport: '<Root>/true_state' incorporates:
   *  Integrator: '<S10>/Integrator'
   */
  memcpy(&hover_plant_sil_Y.true_state[0], &hover_plant_sil_X.Integrator_CSTATE
         [0], 12U * sizeof(real_T));
  tmp_0 = (rtmIsMajorTimeStep(hover_plant_sil_M) &&
           hover_plant_sil_M->Timing.TaskCounters.TID[2] == 0);
  if (tmp_0) {
    /* Gain: '<S7>/Output' */
    hover_plant_sil_B.NoiseOption[0] =
      hover_plant_sil_P.WingThrustUncertainty_Cov[0];
    hover_plant_sil_B.NoiseOption[0] = sqrt(hover_plant_sil_B.NoiseOption[0]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_plant_sil_B.NoiseOption[0] = hover_plant_sil_B.NoiseOption[0] /
      0.015811388300841896 * hover_plant_sil_DW.NextOutput *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_plant_sil_B.NoiseOption[1] =
      hover_plant_sil_P.WingThrustUncertainty_Cov[1];
    hover_plant_sil_B.NoiseOption[1] = sqrt(hover_plant_sil_B.NoiseOption[1]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_plant_sil_B.NoiseOption[1] = hover_plant_sil_B.NoiseOption[1] /
      0.015811388300841896 * hover_plant_sil_DW.NextOutput *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_plant_sil_B.NoiseOption[2] =
      hover_plant_sil_P.WingThrustUncertainty_Cov[2];
    hover_plant_sil_B.NoiseOption[2] = sqrt(hover_plant_sil_B.NoiseOption[2]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_plant_sil_B.NoiseOption[2] = hover_plant_sil_B.NoiseOption[2] /
      0.015811388300841896 * hover_plant_sil_DW.NextOutput *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S7>/Output' */
    hover_plant_sil_B.NoiseOption[3] =
      hover_plant_sil_P.WingThrustUncertainty_Cov[3];
    hover_plant_sil_B.NoiseOption[3] = sqrt(hover_plant_sil_B.NoiseOption[3]);

    /* Gain: '<S2>/Noise Option' incorporates:
     *  Gain: '<S7>/Output'
     *  RandomNumber: '<S7>/White Noise'
     */
    hover_plant_sil_B.NoiseOption[3] = hover_plant_sil_B.NoiseOption[3] /
      0.015811388300841896 * hover_plant_sil_DW.NextOutput *
      hover_plant_sil_P.noise_true;
  }

  /* TransferFcn: '<S2>/Transfer Fcn1' incorporates:
   *  Sum: '<S2>/Sum'
   *  TransferFcn: '<S2>/Transfer Fcn'
   */
  tmp_4 = _mm_add_pd(_mm_mul_pd(_mm_set_pd(hover_plant_sil_P.TransferFcn1_C,
    hover_plant_sil_P.TransferFcn_C), _mm_set_pd
    (hover_plant_sil_X.TransferFcn1_CSTATE, hover_plant_sil_X.TransferFcn_CSTATE)),
                     _mm_loadu_pd(&hover_plant_sil_B.NoiseOption[0]));

  /* Sum: '<S2>/Sum' */
  _mm_storeu_pd(&hover_plant_sil_Y.actuator_delta[0], tmp_4);

  /* TransferFcn: '<S2>/Transfer Fcn3' incorporates:
   *  Sum: '<S2>/Sum'
   *  TransferFcn: '<S2>/Transfer Fcn2'
   */
  tmp_4 = _mm_add_pd(_mm_mul_pd(_mm_set_pd(hover_plant_sil_P.TransferFcn3_C,
    hover_plant_sil_P.TransferFcn2_C), _mm_set_pd
    (hover_plant_sil_X.TransferFcn3_CSTATE,
     hover_plant_sil_X.TransferFcn2_CSTATE)), _mm_loadu_pd
                     (&hover_plant_sil_B.NoiseOption[2]));

  /* Sum: '<S2>/Sum' */
  _mm_storeu_pd(&hover_plant_sil_Y.actuator_delta[2], tmp_4);

  /* Sum: '<S10>/Sum' incorporates:
   *  Constant: '<S10>/Constant'
   */
  tmp_4 = _mm_set1_pd(hover_plant_sil_P.u0);

  /* MATLAB Function: '<S10>/MATLAB Function1' incorporates:
   *  Constant: '<S10>/Constant6'
   *  Constant: '<S10>/Constant7'
   */
  tmp_6 = _mm_set1_pd(hover_plant_sil_P.C11);
  tmp_7 = _mm_set1_pd(hover_plant_sil_P.C21);

  /* SignalConversion generated from: '<S10>/Matrix Concatenate' */
  tmp_5 = _mm_add_pd(_mm_mul_pd(_mm_add_pd(_mm_loadu_pd
    (&hover_plant_sil_Y.actuator_delta[0]), tmp_4), tmp_6), tmp_7);
  _mm_storeu_pd(&tmp_3[0], tmp_5);

  /* MATLAB Function: '<S10>/MATLAB Function1' */
  T_idx_0 = tmp_3[0];
  T_idx_1 = tmp_3[1];

  /* SignalConversion generated from: '<S10>/Matrix Concatenate' */
  tmp_4 = _mm_add_pd(_mm_mul_pd(_mm_add_pd(_mm_loadu_pd
    (&hover_plant_sil_Y.actuator_delta[2]), tmp_4), tmp_6), tmp_7);
  _mm_storeu_pd(&tmp_3[0], tmp_4);

  /* MATLAB Function: '<S10>/MATLAB Function1' incorporates:
   *  Constant: '<S10>/Constant3'
   *  Constant: '<S10>/Constant4'
   *  Constant: '<S10>/Constant5'
   *  Constant: '<S10>/Constant8'
   *  Constant: '<S10>/Constant9'
   *  Integrator: '<S10>/Integrator'
   *  MATLAB Function: '<Root>/MATLAB Function'
   */
  T_idx_2 = tmp_3[0];
  T_idx_3 = tmp_3[1];
  y = -0.5 * hover_plant_sil_P.rho;
  force[0] = hover_plant_sil_X.Integrator_CSTATE[3];
  force[1] = hover_plant_sil_X.Integrator_CSTATE[4];
  force[2] = hover_plant_sil_X.Integrator_CSTATE[5];
  tmp_4 = _mm_set_pd(fabs(hover_plant_sil_X.Integrator_CSTATE[4]), fabs
                     (hover_plant_sil_X.Integrator_CSTATE[3]));
  tmp_6 = _mm_mul_pd(_mm_mul_pd(_mm_mul_pd(_mm_mul_pd(_mm_set1_pd(y),
    _mm_loadu_pd(&hover_plant_sil_P.Constant4_Value[0])), _mm_loadu_pd
    (&hover_plant_sil_P.Constant5_Value[0])), tmp_4), _mm_loadu_pd
                     (&hover_plant_sil_X.Integrator_CSTATE[3]));
  _mm_storeu_pd(&F[0], tmp_6);
  F_tmp = fabs(hover_plant_sil_X.Integrator_CSTATE[5]);
  F[2] = y * hover_plant_sil_P.Constant4_Value[2] *
    hover_plant_sil_P.Constant5_Value[2] * F_tmp *
    hover_plant_sil_X.Integrator_CSTATE[5];
  F[2] -= ((T_idx_0 + T_idx_1) + tmp_3[0]) + tmp_3[1];
  y = 0.5 * hover_plant_sil_P.rho;
  b = hover_plant_sil_rt_powd_snf(hover_plant_sil_P.S, 3.0);
  x_tmp[0] = hover_plant_sil_X.Integrator_CSTATE[9];
  x_tmp[1] = hover_plant_sil_X.Integrator_CSTATE[10];
  x_tmp[2] = hover_plant_sil_X.Integrator_CSTATE[11];
  dx_tmp = cos(hover_plant_sil_X.Integrator_CSTATE[7]);
  dx_tmp_0 = sin(hover_plant_sil_X.Integrator_CSTATE[7]);
  dx_tmp_1 = cos(hover_plant_sil_X.Integrator_CSTATE[8]);
  dx_tmp_2 = sin(hover_plant_sil_X.Integrator_CSTATE[8]);
  dx_tmp_3 = sin(hover_plant_sil_X.Integrator_CSTATE[6]);
  dx_tmp_4 = cos(hover_plant_sil_X.Integrator_CSTATE[6]);
  dx_tmp_5 = tan(hover_plant_sil_X.Integrator_CSTATE[7]);
  dx_tmp_6[0] = dx_tmp * dx_tmp_1;
  dx_tmp_6[1] = dx_tmp * dx_tmp_2;
  dx_tmp_6[2] = -dx_tmp_0;
  dx_tmp_tmp = dx_tmp_3 * dx_tmp_0;
  dx_tmp_6[3] = dx_tmp_tmp * dx_tmp_1 - dx_tmp_4 * dx_tmp_2;
  dx_tmp_6[4] = dx_tmp_tmp * dx_tmp_2 + dx_tmp_4 * dx_tmp_1;
  dx_tmp_6[5] = dx_tmp_3 * dx_tmp;
  dx_tmp_tmp = dx_tmp_4 * dx_tmp_0;
  dx_tmp_6[6] = dx_tmp_tmp * dx_tmp_1 + dx_tmp_3 * dx_tmp_2;
  dx_tmp_6[7] = dx_tmp_tmp * dx_tmp_2 - dx_tmp_3 * dx_tmp_1;
  dx_tmp_6[8] = dx_tmp_4 * dx_tmp;
  tmp_1[0] = -hover_plant_sil_P.g * dx_tmp_0;
  tmp_1[1] = hover_plant_sil_P.g * dx_tmp_3 * dx_tmp;
  tmp_1[2] = hover_plant_sil_P.g * dx_tmp_4 * dx_tmp;

  /* Integrator: '<S10>/Integrator' incorporates:
   *  MATLAB Function: '<S10>/MATLAB Function1'
   */
  tmp_6 = _mm_sub_pd(_mm_mul_pd(_mm_set_pd(hover_plant_sil_X.Integrator_CSTATE[3],
    hover_plant_sil_X.Integrator_CSTATE[5]), _mm_loadu_pd
    (&hover_plant_sil_X.Integrator_CSTATE[10])), _mm_mul_pd(_mm_loadu_pd
    (&hover_plant_sil_X.Integrator_CSTATE[4]), _mm_set_pd
    (hover_plant_sil_X.Integrator_CSTATE[9],
     hover_plant_sil_X.Integrator_CSTATE[11])));

  /* MATLAB Function: '<S10>/MATLAB Function1' incorporates:
   *  Constant: '<S10>/Constant1'
   *  Constant: '<S10>/Constant2'
   *  Constant: '<S10>/Constant3'
   *  Constant: '<S10>/Constant4'
   *  Constant: '<S10>/Constant5'
   *  Integrator: '<S10>/Integrator'
   */
  _mm_storeu_pd(&x_tmp_0[0], tmp_6);
  x_tmp_0[2] = hover_plant_sil_X.Integrator_CSTATE[4] *
    hover_plant_sil_X.Integrator_CSTATE[9] -
    hover_plant_sil_X.Integrator_CSTATE[3] *
    hover_plant_sil_X.Integrator_CSTATE[10];
  tmp_2[0] = 1.0;
  tmp_2[3] = dx_tmp_3 * dx_tmp_5;
  tmp_2[6] = dx_tmp_4 * dx_tmp_5;
  tmp_2[1] = 0.0;
  tmp_2[4] = dx_tmp_4;
  tmp_2[7] = -dx_tmp_3;
  tmp_2[2] = 0.0;
  tmp_2[5] = dx_tmp_3 / dx_tmp;
  tmp_2[8] = dx_tmp_4 / dx_tmp;
  dx_tmp = 0.0;
  dx_tmp_0 = 0.0;
  dx_tmp_1 = 0.0;
  for (i = 0; i < 3; i++) {
    tmp_6 = _mm_add_pd(_mm_mul_pd(_mm_loadu_pd(&dx_tmp_6[3 * i]), _mm_set1_pd
      (force[i])), _mm_set_pd(dx_tmp_0, dx_tmp));
    _mm_storeu_pd(&tmp_3[0], tmp_6);
    dx_tmp = tmp_3[0];
    dx_tmp_0 = tmp_3[1];
    dx_tmp_1 += dx_tmp_6[3 * i + 2] * force[i];
  }

  dx_tmp_7[2] = dx_tmp_1;
  dx_tmp_7[1] = dx_tmp_0;
  dx_tmp_7[0] = dx_tmp;
  dx_tmp = 0.0;
  dx_tmp_0 = 0.0;
  dx_tmp_1 = 0.0;
  for (i = 0; i < 3; i++) {
    tmp_6 = _mm_add_pd(_mm_mul_pd(_mm_loadu_pd(&tmp_2[3 * i]), _mm_set1_pd
      (x_tmp[i])), _mm_set_pd(dx_tmp_0, dx_tmp));
    _mm_storeu_pd(&tmp_3[0], tmp_6);
    dx_tmp = tmp_3[0];
    dx_tmp_0 = tmp_3[1];
    dx_tmp_1 += tmp_2[3 * i + 2] * x_tmp[i];
    hover_plant_sil_B.dx[i] = dx_tmp_7[i];
    hover_plant_sil_B.dx[i + 3] = (F[i] / hover_plant_sil_P.m + tmp_1[i]) -
      x_tmp_0[i];
  }

  hover_plant_sil_B.dx[6] = dx_tmp;
  hover_plant_sil_B.dx[7] = dx_tmp_0;
  hover_plant_sil_B.dx[8] = dx_tmp_1;
  tmp_6 = _mm_div_pd(_mm_sub_pd(_mm_sub_pd(_mm_mul_pd(_mm_sub_pd(_mm_set_pd
    (T_idx_0, T_idx_3), _mm_set_pd(T_idx_2, T_idx_1)), _mm_set1_pd
    (hover_plant_sil_P.S)), _mm_mul_pd(_mm_mul_pd(_mm_mul_pd(_mm_mul_pd
    (_mm_mul_pd(_mm_set1_pd(y), _mm_loadu_pd(&hover_plant_sil_P.Constant4_Value
    [3])), _mm_loadu_pd(&hover_plant_sil_P.Constant5_Value[3])), _mm_set1_pd(b)),
    _mm_set_pd(fabs(hover_plant_sil_X.Integrator_CSTATE[10]), fabs
               (hover_plant_sil_X.Integrator_CSTATE[9]))), _mm_loadu_pd
    (&hover_plant_sil_X.Integrator_CSTATE[9]))), _mm_mul_pd(_mm_mul_pd
    (_mm_sub_pd(_mm_set_pd(hover_plant_sil_P.Constant2_Value[0],
    hover_plant_sil_P.Constant2_Value[2]), _mm_loadu_pd
                (&hover_plant_sil_P.Constant2_Value[1])), _mm_set_pd
     (hover_plant_sil_X.Integrator_CSTATE[9],
      hover_plant_sil_X.Integrator_CSTATE[10])), _mm_set1_pd
    (hover_plant_sil_X.Integrator_CSTATE[11]))), _mm_loadu_pd
                     (&hover_plant_sil_P.Constant2_Value[0]));
  _mm_storeu_pd(&hover_plant_sil_B.dx[9], tmp_6);

  /* MATLAB Function: '<S10>/MATLAB Function1' incorporates:
   *  Constant: '<S10>/Constant2'
   *  Constant: '<S10>/Constant4'
   *  Constant: '<S10>/Constant5'
   *  Integrator: '<S10>/Integrator'
   */
  hover_plant_sil_B.dx[11] = ((0.0 - y * hover_plant_sil_P.Constant4_Value[5] *
    hover_plant_sil_P.Constant5_Value[5] * b * fabs
    (hover_plant_sil_X.Integrator_CSTATE[11]) *
    hover_plant_sil_X.Integrator_CSTATE[11]) -
    (hover_plant_sil_P.Constant2_Value[1] - hover_plant_sil_P.Constant2_Value[0])
    * hover_plant_sil_X.Integrator_CSTATE[9] *
    hover_plant_sil_X.Integrator_CSTATE[10]) /
    hover_plant_sil_P.Constant2_Value[2];

  /* MATLAB Function: '<Root>/MATLAB Function' incorporates:
   *  Integrator: '<S10>/Integrator'
   */
  if (hover_plant_sil_P.imu_nonlinear) {
    tmp_4 = _mm_mul_pd(_mm_mul_pd(_mm_set_pd(-(hover_plant_sil_P.CDy *
      hover_plant_sil_P.Ay * y), -(hover_plant_sil_P.CDx * hover_plant_sil_P.Ax *
      y)), tmp_4), _mm_loadu_pd(&hover_plant_sil_X.Integrator_CSTATE[3]));
    _mm_storeu_pd(&force[0], tmp_4);
    force[2] = -(hover_plant_sil_P.CDz * hover_plant_sil_P.Az * y) * F_tmp *
      hover_plant_sil_X.Integrator_CSTATE[5];
  } else {
    tmp_4 = _mm_mul_pd(_mm_set_pd(-hover_plant_sil_P.Yv, -hover_plant_sil_P.Xu),
                       _mm_loadu_pd(&hover_plant_sil_X.Integrator_CSTATE[3]));
    _mm_storeu_pd(&force[0], tmp_4);
    force[2] = -hover_plant_sil_P.Zw * hover_plant_sil_X.Integrator_CSTATE[5];
  }

  tmp_4 = _mm_div_pd(_mm_loadu_pd(&force[0]), _mm_set1_pd(hover_plant_sil_P.m));
  _mm_storeu_pd(&hover_plant_sil_Y.accel_ideal[0], tmp_4);
  hover_plant_sil_Y.accel_ideal[2] = (-hover_plant_sil_P.g -
    (((hover_plant_sil_Y.actuator_delta[0] + hover_plant_sil_Y.actuator_delta[1])
      + hover_plant_sil_Y.actuator_delta[2]) + hover_plant_sil_Y.actuator_delta
     [3]) * hover_plant_sil_P.C11 / hover_plant_sil_P.m) + force[2] /
    hover_plant_sil_P.m;
  tmp = (rtmIsMajorTimeStep(hover_plant_sil_M) &&
         hover_plant_sil_M->Timing.TaskCounters.TID[3] == 0);
  if (tmp) {
    /* Gain: '<S8>/Output' */
    hover_plant_sil_B.Sum1[0] = hover_plant_sil_P.sil_gyro_noise_power[0];
    hover_plant_sil_B.Sum1[0] = sqrt(hover_plant_sil_B.Sum1[0]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_plant_sil_B.Sum1[0] = hover_plant_sil_B.Sum1[0] / 0.017677669529663688
      * hover_plant_sil_DW.NextOutput_l * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.gyro.bias[0] * 0.017453292519943295 *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S8>/Output' */
    hover_plant_sil_B.Sum1[1] = hover_plant_sil_P.sil_gyro_noise_power[1];
    hover_plant_sil_B.Sum1[1] = sqrt(hover_plant_sil_B.Sum1[1]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_plant_sil_B.Sum1[1] = hover_plant_sil_B.Sum1[1] / 0.017677669529663688
      * hover_plant_sil_DW.NextOutput_l * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.gyro.bias[1] * 0.017453292519943295 *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S8>/Output' */
    hover_plant_sil_B.Sum1[2] = hover_plant_sil_P.sil_gyro_noise_power[2];
    hover_plant_sil_B.Sum1[2] = sqrt(hover_plant_sil_B.Sum1[2]);

    /* Sum: '<S3>/Sum1' incorporates:
     *  Constant: '<S3>/Gyro Bias'
     *  Gain: '<S3>/Noise Option'
     *  Gain: '<S3>/Noise Option1'
     *  Gain: '<S8>/Output'
     *  RandomNumber: '<S8>/White Noise'
     */
    hover_plant_sil_B.Sum1[2] = hover_plant_sil_B.Sum1[2] / 0.017677669529663688
      * hover_plant_sil_DW.NextOutput_l * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.gyro.bias[2] * 0.017453292519943295 *
      hover_plant_sil_P.noise_true;
  }

  /* Gain: '<Root>/Noise Option' incorporates:
   *  Sin: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  T_idx_1 = (sin(hover_plant_sil_P.WingDisturbanceUnitAmplitude_Fr *
                 hover_plant_sil_M->Timing.t[0] +
                 hover_plant_sil_P.WingDisturbanceUnitAmplitude_Ph) *
             hover_plant_sil_P.WingDisturbanceUnitAmplitude_Am +
             hover_plant_sil_P.WingDisturbanceUnitAmplitude_Bi) *
    hover_plant_sil_P.noise_true;

  /* Gain: '<S3>/Gyro Noise Scaling' */
  T_idx_2 = hover_plant_sil_P.gyro.vibration * 0.017453292519943295 * T_idx_1;
  if (tmp) {
    /* Sum: '<S3>/Sum' incorporates:
     *  Integrator: '<S10>/Integrator'
     *  Sum: '<S3>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1[0] + hover_plant_sil_X.Integrator_CSTATE[9])
      + T_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (T_idx_0 > hover_plant_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[0] = hover_plant_sil_P.GyroRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[0] = hover_plant_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[0] = T_idx_0;
    }

    /* Sum: '<S3>/Sum' incorporates:
     *  Integrator: '<S10>/Integrator'
     *  Sum: '<S3>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1[1] + hover_plant_sil_X.Integrator_CSTATE
               [10]) + T_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (T_idx_0 > hover_plant_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[1] = hover_plant_sil_P.GyroRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[1] = hover_plant_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[1] = T_idx_0;
    }

    /* Sum: '<S3>/Sum' incorporates:
     *  Integrator: '<S10>/Integrator'
     *  Sum: '<S3>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1[2] + hover_plant_sil_X.Integrator_CSTATE
               [11]) + T_idx_2;

    /* Saturate: '<S3>/Gyro Range' */
    if (T_idx_0 > hover_plant_sil_P.GyroRange_UpperSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[2] = hover_plant_sil_P.GyroRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.GyroRange_LowerSat) {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[2] = hover_plant_sil_P.GyroRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S3>/Gyro Sample Rate' */
      hover_plant_sil_B.GyroSampleRate[2] = T_idx_0;
    }
  }

  if (tmp_0) {
    /* Outport: '<Root>/gyro_measured' incorporates:
     *  ZeroOrderHold: '<Root>/Gyro sample'
     *  ZeroOrderHold: '<S3>/Gyro Sample Rate'
     */
    hover_plant_sil_Y.gyro_measured[0] = hover_plant_sil_B.GyroSampleRate[0];
    hover_plant_sil_Y.gyro_measured[1] = hover_plant_sil_B.GyroSampleRate[1];
    hover_plant_sil_Y.gyro_measured[2] = hover_plant_sil_B.GyroSampleRate[2];
  }

  /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
  tmp = (rtmIsMajorTimeStep(hover_plant_sil_M) &&
         hover_plant_sil_M->Timing.TaskCounters.TID[4] == 0);
  if (tmp) {
    /* Gain: '<S6>/Output' */
    hover_plant_sil_B.Sum1_m[0] = hover_plant_sil_P.sil_accel_noise_power[0];
    hover_plant_sil_B.Sum1_m[0] = sqrt(hover_plant_sil_B.Sum1_m[0]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_plant_sil_B.Sum1_m[0] = hover_plant_sil_B.Sum1_m[0] / 0.025 *
      hover_plant_sil_DW.NextOutput_lo * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.accel.bias[0] * hover_plant_sil_P.g *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S6>/Output' */
    hover_plant_sil_B.Sum1_m[1] = hover_plant_sil_P.sil_accel_noise_power[1];
    hover_plant_sil_B.Sum1_m[1] = sqrt(hover_plant_sil_B.Sum1_m[1]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_plant_sil_B.Sum1_m[1] = hover_plant_sil_B.Sum1_m[1] / 0.025 *
      hover_plant_sil_DW.NextOutput_lo * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.accel.bias[1] * hover_plant_sil_P.g *
      hover_plant_sil_P.noise_true;

    /* Gain: '<S6>/Output' */
    hover_plant_sil_B.Sum1_m[2] = hover_plant_sil_P.sil_accel_noise_power[2];
    hover_plant_sil_B.Sum1_m[2] = sqrt(hover_plant_sil_B.Sum1_m[2]);

    /* Sum: '<S1>/Sum1' incorporates:
     *  Constant: '<S1>/Accel Bias'
     *  Gain: '<S1>/Noise Option'
     *  Gain: '<S1>/Noise Option1'
     *  Gain: '<S6>/Output'
     *  RandomNumber: '<S6>/White Noise'
     */
    hover_plant_sil_B.Sum1_m[2] = hover_plant_sil_B.Sum1_m[2] / 0.025 *
      hover_plant_sil_DW.NextOutput_lo * hover_plant_sil_P.noise_true +
      hover_plant_sil_P.accel.bias[2] * hover_plant_sil_P.g *
      hover_plant_sil_P.noise_true;
  }

  /* Gain: '<S1>/Accel Noise Scaling' */
  T_idx_1 *= hover_plant_sil_P.accel.vibration * hover_plant_sil_P.g;

  /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
  if (tmp) {
    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1_m[0] + hover_plant_sil_Y.accel_ideal[0]) +
      T_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (T_idx_0 > hover_plant_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[0] =
        hover_plant_sil_P.AccelRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[0] =
        hover_plant_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[0] = T_idx_0;
    }

    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1_m[1] + hover_plant_sil_Y.accel_ideal[1]) +
      T_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (T_idx_0 > hover_plant_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[1] =
        hover_plant_sil_P.AccelRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[1] =
        hover_plant_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[1] = T_idx_0;
    }

    /* Sum: '<S1>/Sum' incorporates:
     *  Sum: '<S1>/Sum2'
     */
    T_idx_0 = (hover_plant_sil_B.Sum1_m[2] + hover_plant_sil_Y.accel_ideal[2]) +
      T_idx_1;

    /* Saturate: '<S1>/Accel Range' */
    if (T_idx_0 > hover_plant_sil_P.AccelRange_UpperSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[2] =
        hover_plant_sil_P.AccelRange_UpperSat;
    } else if (T_idx_0 < hover_plant_sil_P.AccelRange_LowerSat) {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[2] =
        hover_plant_sil_P.AccelRange_LowerSat;
    } else {
      /* ZeroOrderHold: '<S1>/Accel Sample Rate' */
      hover_plant_sil_B.AccelSampleRate[2] = T_idx_0;
    }
  }

  if (tmp_0) {
    /* Outport: '<Root>/accel_measured' incorporates:
     *  ZeroOrderHold: '<Root>/Accelerometer sample'
     *  ZeroOrderHold: '<S1>/Accel Sample Rate'
     */
    hover_plant_sil_Y.accel_measured[0] = hover_plant_sil_B.AccelSampleRate[0];
    hover_plant_sil_Y.accel_measured[1] = hover_plant_sil_B.AccelSampleRate[1];
    hover_plant_sil_Y.accel_measured[2] = hover_plant_sil_B.AccelSampleRate[2];
  }

  /* Outport: '<Root>/gyro_ideal' incorporates:
   *  Integrator: '<S10>/Integrator'
   */
  hover_plant_sil_Y.gyro_ideal[0] = hover_plant_sil_X.Integrator_CSTATE[9];
  hover_plant_sil_Y.gyro_ideal[1] = hover_plant_sil_X.Integrator_CSTATE[10];
  hover_plant_sil_Y.gyro_ideal[2] = hover_plant_sil_X.Integrator_CSTATE[11];
}

/* Model update function */
void hover_plant_sil_update(void)
{
  if (rtmIsMajorTimeStep(hover_plant_sil_M) &&
      hover_plant_sil_M->Timing.TaskCounters.TID[2] == 0) {
    /* Update for RandomNumber: '<S7>/White Noise' */
    hover_plant_sil_DW.NextOutput = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed) * hover_plant_sil_P.WhiteNoise_StdDev +
      hover_plant_sil_P.WhiteNoise_Mean;
  }

  if (rtmIsMajorTimeStep(hover_plant_sil_M) &&
      hover_plant_sil_M->Timing.TaskCounters.TID[3] == 0) {
    /* Update for RandomNumber: '<S8>/White Noise' */
    hover_plant_sil_DW.NextOutput_l = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed_e) * hover_plant_sil_P.WhiteNoise_StdDev_i +
      hover_plant_sil_P.WhiteNoise_Mean_p;
  }

  if (rtmIsMajorTimeStep(hover_plant_sil_M) &&
      hover_plant_sil_M->Timing.TaskCounters.TID[4] == 0) {
    /* Update for RandomNumber: '<S6>/White Noise' */
    hover_plant_sil_DW.NextOutput_lo = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed_j) * hover_plant_sil_P.WhiteNoise_StdDev_c +
      hover_plant_sil_P.WhiteNoise_Mean_a;
  }

  if (rtmIsMajorTimeStep(hover_plant_sil_M)) {
    rt_ertODEUpdateContinuousStates(&hover_plant_sil_M->solverInfo);
  }

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The absolute time is the multiplication of "clockTick0"
   * and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
   * overflow during the application lifespan selected.
   */
  ++hover_plant_sil_M->Timing.clockTick0;
  hover_plant_sil_M->Timing.t[0] = rtsiGetSolverStopTime
    (&hover_plant_sil_M->solverInfo);

  {
    /* Update absolute timer for sample time: [6.25E-5s, 0.0s] */
    /* The "clockTick1" counts the number of times the code of this task has
     * been executed. The resolution of this integer timer is 6.25E-5, which is the step size
     * of the task. Size of "clockTick1" ensures timer will not overflow during the
     * application lifespan selected.
     */
    hover_plant_sil_M->Timing.clockTick1++;
  }

  rate_scheduler();
}

/* Derivatives for root system: '<Root>' */
void hover_plant_sil_derivatives(void)
{
  XDot_hover_plant_sil_T *_rtXdot;
  _rtXdot = ((XDot_hover_plant_sil_T *) hover_plant_sil_M->derivs);

  /* Derivatives for Integrator: '<S10>/Integrator' */
  memcpy(&_rtXdot->Integrator_CSTATE[0], &hover_plant_sil_B.dx[0], 12U * sizeof
         (real_T));

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn_CSTATE = hover_plant_sil_P.TransferFcn_A *
    hover_plant_sil_X.TransferFcn_CSTATE;
  _rtXdot->TransferFcn_CSTATE += hover_plant_sil_U.motor_delta[0];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn1' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn1_CSTATE = hover_plant_sil_P.TransferFcn1_A *
    hover_plant_sil_X.TransferFcn1_CSTATE;
  _rtXdot->TransferFcn1_CSTATE += hover_plant_sil_U.motor_delta[1];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn2' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn2_CSTATE = hover_plant_sil_P.TransferFcn2_A *
    hover_plant_sil_X.TransferFcn2_CSTATE;
  _rtXdot->TransferFcn2_CSTATE += hover_plant_sil_U.motor_delta[2];

  /* Derivatives for TransferFcn: '<S2>/Transfer Fcn3' incorporates:
   *  Inport: '<Root>/motor_delta'
   */
  _rtXdot->TransferFcn3_CSTATE = hover_plant_sil_P.TransferFcn3_A *
    hover_plant_sil_X.TransferFcn3_CSTATE;
  _rtXdot->TransferFcn3_CSTATE += hover_plant_sil_U.motor_delta[3];
}

/* Model initialize function */
void hover_plant_sil_initialize(void)
{
  /* Registration code */
  {
    /* Setup solver object */
    rtsiSetSimTimeStepPtr(&hover_plant_sil_M->solverInfo,
                          &hover_plant_sil_M->Timing.simTimeStep);
    rtsiSetTPtr(&hover_plant_sil_M->solverInfo, &rtmGetTPtr(hover_plant_sil_M));
    rtsiSetStepSizePtr(&hover_plant_sil_M->solverInfo,
                       &hover_plant_sil_M->Timing.stepSize0);
    rtsiSetdXPtr(&hover_plant_sil_M->solverInfo, &hover_plant_sil_M->derivs);
    rtsiSetContStatesPtr(&hover_plant_sil_M->solverInfo, (real_T **)
                         &hover_plant_sil_M->contStates);
    rtsiSetNumContStatesPtr(&hover_plant_sil_M->solverInfo,
      &hover_plant_sil_M->Sizes.numContStates);
    rtsiSetNumPeriodicContStatesPtr(&hover_plant_sil_M->solverInfo,
      &hover_plant_sil_M->Sizes.numPeriodicContStates);
    rtsiSetPeriodicContStateIndicesPtr(&hover_plant_sil_M->solverInfo,
      &hover_plant_sil_M->periodicContStateIndices);
    rtsiSetPeriodicContStateRangesPtr(&hover_plant_sil_M->solverInfo,
      &hover_plant_sil_M->periodicContStateRanges);
    rtsiSetContStateDisabledPtr(&hover_plant_sil_M->solverInfo, (boolean_T**)
      &hover_plant_sil_M->contStateDisabled);
    rtsiSetErrorStatusPtr(&hover_plant_sil_M->solverInfo, (&rtmGetErrorStatus
      (hover_plant_sil_M)));
    rtsiSetRTModelPtr(&hover_plant_sil_M->solverInfo, hover_plant_sil_M);
  }

  rtsiSetSimTimeStep(&hover_plant_sil_M->solverInfo, MAJOR_TIME_STEP);
  rtsiSetIsMinorTimeStepWithModeChange(&hover_plant_sil_M->solverInfo, false);
  rtsiSetIsContModeFrozen(&hover_plant_sil_M->solverInfo, false);
  hover_plant_sil_M->intgData.y = hover_plant_sil_M->odeY;
  hover_plant_sil_M->intgData.f[0] = hover_plant_sil_M->odeF[0];
  hover_plant_sil_M->intgData.f[1] = hover_plant_sil_M->odeF[1];
  hover_plant_sil_M->intgData.f[2] = hover_plant_sil_M->odeF[2];
  hover_plant_sil_M->intgData.f[3] = hover_plant_sil_M->odeF[3];
  hover_plant_sil_M->intgData.f[4] = hover_plant_sil_M->odeF[4];
  hover_plant_sil_M->intgData.f[5] = hover_plant_sil_M->odeF[5];
  hover_plant_sil_M->contStates = ((X_hover_plant_sil_T *) &hover_plant_sil_X);
  hover_plant_sil_M->contStateDisabled = ((XDis_hover_plant_sil_T *)
    &hover_plant_sil_XDis);
  hover_plant_sil_M->Timing.tStart = (0.0);
  rtsiSetSolverData(&hover_plant_sil_M->solverInfo, (void *)
                    &hover_plant_sil_M->intgData);
  rtsiSetSolverName(&hover_plant_sil_M->solverInfo,"ode5");
  rtmSetTPtr(hover_plant_sil_M, &hover_plant_sil_M->Timing.tArray[0]);
  hover_plant_sil_M->Timing.stepSize0 = 6.25E-5;

  {
    real_T tmp;
    uint32_T r;
    uint32_T t;
    uint32_T tseed;

    /* InitializeConditions for Integrator: '<S10>/Integrator' */
    memcpy(&hover_plant_sil_X.Integrator_CSTATE[0], &hover_plant_sil_P.X0[0],
           12U * sizeof(real_T));

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn' */
    hover_plant_sil_X.TransferFcn_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn1' */
    hover_plant_sil_X.TransferFcn1_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn2' */
    hover_plant_sil_X.TransferFcn2_CSTATE = 0.0;

    /* InitializeConditions for TransferFcn: '<S2>/Transfer Fcn3' */
    hover_plant_sil_X.TransferFcn3_CSTATE = 0.0;

    /* InitializeConditions for RandomNumber: '<S7>/White Noise' */
    tmp = floor(hover_plant_sil_P.WingThrustUncertainty_seed);
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
    hover_plant_sil_DW.RandSeed = ((((tseed - (r << 16U)) + t) << 16U) + t) + r;
    if (hover_plant_sil_DW.RandSeed < 1U) {
      hover_plant_sil_DW.RandSeed = 1144108930U;
    } else if (hover_plant_sil_DW.RandSeed > 2147483646U) {
      hover_plant_sil_DW.RandSeed = 2147483646U;
    }

    hover_plant_sil_DW.NextOutput = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed) * hover_plant_sil_P.WhiteNoise_StdDev +
      hover_plant_sil_P.WhiteNoise_Mean;

    /* End of InitializeConditions for RandomNumber: '<S7>/White Noise' */

    /* InitializeConditions for RandomNumber: '<S8>/White Noise' */
    tmp = floor(hover_plant_sil_P.GyroWhiteNoise_seed);
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
    hover_plant_sil_DW.RandSeed_e = ((((tseed - (r << 16U)) + t) << 16U) + t) +
      r;
    if (hover_plant_sil_DW.RandSeed_e < 1U) {
      hover_plant_sil_DW.RandSeed_e = 1144108930U;
    } else if (hover_plant_sil_DW.RandSeed_e > 2147483646U) {
      hover_plant_sil_DW.RandSeed_e = 2147483646U;
    }

    hover_plant_sil_DW.NextOutput_l = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed_e) * hover_plant_sil_P.WhiteNoise_StdDev_i +
      hover_plant_sil_P.WhiteNoise_Mean_p;

    /* End of InitializeConditions for RandomNumber: '<S8>/White Noise' */

    /* InitializeConditions for RandomNumber: '<S6>/White Noise' */
    tmp = floor(hover_plant_sil_P.AccelWhiteNoise_seed);
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
    hover_plant_sil_DW.RandSeed_j = ((((tseed - (r << 16U)) + t) << 16U) + t) +
      r;
    if (hover_plant_sil_DW.RandSeed_j < 1U) {
      hover_plant_sil_DW.RandSeed_j = 1144108930U;
    } else if (hover_plant_sil_DW.RandSeed_j > 2147483646U) {
      hover_plant_sil_DW.RandSeed_j = 2147483646U;
    }

    hover_plant_sil_DW.NextOutput_lo = hover_plant_sil_rt_nra_NCYE4nEi
      (&hover_plant_sil_DW.RandSeed_j) * hover_plant_sil_P.WhiteNoise_StdDev_c +
      hover_plant_sil_P.WhiteNoise_Mean_a;

    /* End of InitializeConditions for RandomNumber: '<S6>/White Noise' */
  }
}

/* Model terminate function */
void hover_plant_sil_terminate(void)
{
  /* (no terminate code required) */
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
