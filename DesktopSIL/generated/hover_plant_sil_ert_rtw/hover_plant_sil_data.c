/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_plant_sil_data.c
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

/* Block parameters (default storage) */
P_hover_plant_sil_T hover_plant_sil_P = {
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

  /* Variable: C11
   * Referenced by:
   *   '<Root>/MATLAB Function'
   *   '<S10>/Constant6'
   */
  0.000458,

  /* Variable: C21
   * Referenced by: '<S10>/Constant7'
   */
  -0.562,

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

  /* Variable: S
   * Referenced by: '<S10>/Constant3'
   */
  0.11,

  /* Variable: X0
   * Referenced by: '<S10>/Integrator'
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
   *   '<S10>/Constant9'
   */
  9.81,

  /* Variable: m
   * Referenced by:
   *   '<Root>/MATLAB Function'
   *   '<S10>/Constant1'
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
   * Referenced by:
   *   '<Root>/MATLAB Function'
   *   '<S10>/Constant8'
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

  /* Variable: u0
   * Referenced by: '<S10>/Constant'
   */
  1816.1026200873364,

  /* Variable: imu_nonlinear
   * Referenced by: '<Root>/MATLAB Function'
   */
  true,

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

  /* Expression: [Ix, Iy, Iz]'
   * Referenced by: '<S10>/Constant2'
   */
  { 0.00194, 0.0019500000000000001, 0.0037800000000000004 },

  /* Expression: [CDx CDy CDz CDw CDw CDw]'
   * Referenced by: '<S10>/Constant4'
   */
  { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 },

  /* Expression: [Ax Ay Az Aomega Aomega Aomega]'
   * Referenced by: '<S10>/Constant5'
   */
  { 0.24321958996679888, 0.24321958996679888, 0.1702537129767592,
    0.48643917993359775, 0.48643917993359775, 0.48643917993359775 },

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
   * Referenced by: '<S7>/White Noise'
   */
  0.0,

  /* Computed Parameter: WhiteNoise_StdDev
   * Referenced by: '<S7>/White Noise'
   */
  1.0,

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
