/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_linear_sil_types.h
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

#ifndef hover_linear_sil_types_h_
#define hover_linear_sil_types_h_
#include "rtwtypes.h"
#ifndef DEFINED_TYPEDEF_FOR_struct_IG7iew4hCkKOXTEkHXx6zC_
#define DEFINED_TYPEDEF_FOR_struct_IG7iew4hCkKOXTEkHXx6zC_

typedef struct {
  real_T range;
  real_T resolution_bits;
  real_T BW;
  real_T LPF_set;
  real_T sample_rate;
  real_T noise_density;
  real_T bias[3];
  real_T vibration;
  real_T resolution_LSB;
  real_T alpha;
  real_T tau;
} struct_IG7iew4hCkKOXTEkHXx6zC;

#endif

/* Parameters (default storage) */
typedef struct P_hover_linear_sil_T_ P_hover_linear_sil_T;

/* Forward declaration for rtModel */
typedef struct tag_RTM_hover_linear_sil_T RT_MODEL_hover_linear_sil_T;

#endif                                 /* hover_linear_sil_types_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
