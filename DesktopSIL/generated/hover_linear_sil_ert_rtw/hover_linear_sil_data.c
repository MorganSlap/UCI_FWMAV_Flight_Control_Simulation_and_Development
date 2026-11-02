/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_linear_sil_data.c
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

/* Block parameters (default storage) */
P_hover_linear_sil_T hover_linear_sil_P = {
  /* Variable: accel
   * Referenced by:
   *   '<S1>/Accel Bias'
   *   '<S1>/Accel Noise Scaling'
   */
  {
    4.0,
    16.0,
    740.0,
    5.0,
    1600.0,
    0.00016,

    { 0.02, 0.02, 0.02 },
    0.1,
    0.0005987548828125,
    0.0077927773041500366,
    0.00021507424742148022
  },

  /* Variable: gyro
   * Referenced by:
   *   '<S3>/Gyro Bias'
   *   '<S3>/Gyro Noise Scaling'
   */
  {
    1000.0,
    16.0,
    751.0,
    5.0,
    3200.0,
    0.007,

    { 0.5, 0.5, 0.5 },
    3.7,
    0.00053263221801584768,
    0.0077927773041500366,
    0.00021192402542196453
  },

  /* Variable: A
   * Referenced by: '<S10>/Full State Lin Sim'
   */
  { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.3542908986787667, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.3542908986787667, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -0.94800362907513658,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.81, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -9.81, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -0.408828310258883, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -0.40673175482165796, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -0.20982193701117274 },

  /* Variable: Ax
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.24321958996679888,

  /* Variable: Ay
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.24321958996679888,

  /* Variable: Az
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.1702537129767592,

  /* Variable: B
   * Referenced by: '<S10>/Full State Lin Sim'
   */
  { 0.0, 0.0, 0.0, 0.0, 0.0, -0.0041636363636363641, 0.0, 0.0, 0.0, 0.0,
    0.025835897435897436, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.0041636363636363641,
    0.0, 0.0, 0.0, -0.025969072164948453, 0.0, -0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    -0.0041636363636363641, 0.0, 0.0, 0.0, 0.0, -0.025835897435897436, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, -0.0041636363636363641, 0.0, 0.0, 0.0,
    0.025969072164948453, 0.0, -0.0 },

  /* Variable: C11
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.000458,

  /* Variable: CDx
   * Referenced by: '<Root>/MATLAB Function'
   */
  1.0,

  /* Variable: CDy
   * Referenced by: '<Root>/MATLAB Function'
   */
  1.0,

  /* Variable: CDz
   * Referenced by: '<Root>/MATLAB Function'
   */
  1.0,

  /* Variable: X0
   * Referenced by: '<S10>/Full State Lin Sim'
   */
  { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },

  /* Variable: Xu
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.14897199885466433,

  /* Variable: Yv
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.14897199885466433,

  /* Variable: Zw
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.10428039919826503,

  /* Variable: g
   * Referenced by:
   *   '<Root>/MATLAB Function'
   *   '<S1>/Accel Bias'
   *   '<S1>/Accel Noise Scaling'
   */
  9.81,

  /* Variable: m
   * Referenced by: '<Root>/MATLAB Function'
   */
  0.11,

  /* Variable: noise_true
   * Referenced by:
   *   '<Root>/Noise Option'
   *   '<S1>/Noise Option'
   *   '<S1>/Noise Option1'
   *   '<S2>/Noise Option'
   *   '<S3>/Noise Option'
   *   '<S3>/Noise Option1'
   */
  1.0,

  /* Variable: rho
   * Referenced by: '<Root>/MATLAB Function'
   */
  1.225,

  /* Variable: sil_accel_noise_power
   * Referenced by: '<S6>/Output'
   */
  { 0.0018230966784000004, 0.0018230966784000004, 0.0018230966784000004 },

  /* Variable: sil_gyro_noise_power
   * Referenced by: '<S8>/Output'
   */
  { 1.1209616430731088E-5, 1.1209616430731088E-5, 1.1209616430731088E-5 },

  /* Variable: imu_nonlinear
   * Referenced by: '<Root>/MATLAB Function'
   */
  false,

  /* Mask Parameter: WingThrustUncertainty_Cov
   * Referenced by: '<S7>/Output'
   */
  { 1.566122567E-6, 1.566122567E-6, 1.566122567E-6, 1.566122567E-6 },

  /* Mask Parameter: WingThrustUncertainty_seed
   * Referenced by: '<S7>/White Noise'
   */
  23341.0,

  /* Mask Parameter: GyroWhiteNoise_seed
   * Referenced by: '<S8>/White Noise'
   */
  23341.0,

  /* Mask Parameter: AccelWhiteNoise_seed
   * Referenced by: '<S6>/White Noise'
   */
  23341.0,

  /* Expression: eye(12)
   * Referenced by: '<S10>/Full State Lin Sim'
   */
  { 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0 },

  /* Expression: 0
   * Referenced by: '<S7>/White Noise'
   */
  0.0,

  /* Computed Parameter: WhiteNoise_StdDev
   * Referenced by: '<S7>/White Noise'
   */
  1.0,

  /* Computed Parameter: TransferFcn_A
   * Referenced by: '<S2>/Transfer Fcn'
   */
  -22.0,

  /* Computed Parameter: TransferFcn_C
   * Referenced by: '<S2>/Transfer Fcn'
   */
  22.0,

  /* Computed Parameter: TransferFcn1_A
   * Referenced by: '<S2>/Transfer Fcn1'
   */
  -22.0,

  /* Computed Parameter: TransferFcn1_C
   * Referenced by: '<S2>/Transfer Fcn1'
   */
  22.0,

  /* Computed Parameter: TransferFcn2_A
   * Referenced by: '<S2>/Transfer Fcn2'
   */
  -22.0,

  /* Computed Parameter: TransferFcn2_C
   * Referenced by: '<S2>/Transfer Fcn2'
   */
  22.0,

  /* Computed Parameter: TransferFcn3_A
   * Referenced by: '<S2>/Transfer Fcn3'
   */
  -22.0,

  /* Computed Parameter: TransferFcn3_C
   * Referenced by: '<S2>/Transfer Fcn3'
   */
  22.0,

  /* Expression: 0
   * Referenced by: '<S8>/White Noise'
   */
  0.0,

  /* Computed Parameter: WhiteNoise_StdDev_i
   * Referenced by: '<S8>/White Noise'
   */
  1.0,

  /* Expression: 1
   * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  1.0,

  /* Expression: 0
   * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  0.0,

  /* Expression: 2*pi*24
   * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  150.79644737231007,

  /* Expression: 0
   * Referenced by: '<Root>/Wing Disturbance (Unit Amplitude)'
   */
  0.0,

  /* Expression: 1000*(pi/180)
   * Referenced by: '<S3>/Gyro Range'
   */
  17.453292519943297,

  /* Expression: -1000*(pi/180)
   * Referenced by: '<S3>/Gyro Range'
   */
  -17.453292519943297,

  /* Expression: 0
   * Referenced by: '<S6>/White Noise'
   */
  0.0,

  /* Computed Parameter: WhiteNoise_StdDev_c
   * Referenced by: '<S6>/White Noise'
   */
  1.0,

  /* Expression: 4*9.81
   * Referenced by: '<S1>/Accel Range'
   */
  39.24,

  /* Expression: -4*9.81
   * Referenced by: '<S1>/Accel Range'
   */
  -39.24
};

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
