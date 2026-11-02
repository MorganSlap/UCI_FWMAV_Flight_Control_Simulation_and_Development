/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: hover_linear_sil_private.h
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

#ifndef hover_linear_sil_private_h_
#define hover_linear_sil_private_h_
#include "rtwtypes.h"
#include "hover_linear_sil_types.h"

/* Private macros used by the generated code to access rtModel */
#ifndef rtmIsMajorTimeStep
#define rtmIsMajorTimeStep(rtm)        (((rtm)->Timing.simTimeStep) == MAJOR_TIME_STEP)
#endif

#ifndef rtmIsMinorTimeStep
#define rtmIsMinorTimeStep(rtm)        (((rtm)->Timing.simTimeStep) == MINOR_TIME_STEP)
#endif

#ifndef rtmSetTPtr
#define rtmSetTPtr(rtm, val)           ((rtm)->Timing.t = (val))
#endif

extern real_T hover_linear_sil_rt_ur_uOkk5MrH(uint32_T *u);
extern real_T hover_linear_sil_rt_nr_Wisg0zun(uint32_T *u);

/* private model entry point functions */
extern void hover_linear_sil_derivatives(void);

#endif                                 /* hover_linear_sil_private_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
