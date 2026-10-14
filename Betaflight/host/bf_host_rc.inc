/* SPDX-License-Identifier: GPL-3.0-or-later
 * Included only at the end of upstream fc/rc.c for the simulator host build.
 * Uses that translation unit's current applyRates function and runtime profile.
 */
#include "bf_host.h"

float bfHostAngleToRate(int axis, float targetDegrees)
{
    const float limit = currentPidProfile->angle_limit;
    if (axis < 0 || axis >= 2 || limit <= 0) return 0;
    const float angle = constrainf(targetDegrees, -limit, limit);
    return angle / limit * getMaxRcRate(axis);
}

uint16_t bfHostRateToPwm(int axis, float targetDps)
{
    if (axis < 0 || axis >= 3 || !applyRates) return rxConfig()->midrc;
    const float maxRate = fminf(fabsf(applyRates(axis, 1.0f, 1.0f)),
        (float)currentControlRateProfile->rate_limit[axis]);
    const float desired = fminf(fabsf(targetDps), maxRate);
    float low = 0, high = 1;
    for (unsigned iteration = 0; iteration < 30; iteration++) {
        const float middle = 0.5f*(low+high);
        const float rate = fabsf(applyRates(axis, middle, middle));
        if (rate < desired) low = middle;
        else high = middle;
    }
    const float deflection = desired > 0 ? 0.5f*(low+high) : 0;
    const float deadband = axis == FD_YAW ? rcControlsConfig()->yaw_deadband : rcControlsConfig()->deadband;
    const float divider = axis == FD_YAW ? rcCommandYawDivider : rcCommandDivider;
    float command = deflection > 0 ? deflection * divider + deadband : 0;
    if (targetDps < 0) command = -command;
    if (axis == FD_YAW) command *= -GET_DIRECTION(rcControlsConfig()->yaw_control_reversed);
    const float calibratedPulse = rxConfig()->midrc + command;
    /* Undo configured receiver endpoint calibration before injecting raw RC. */
    const rxChannelRangeConfig_t *range = rxChannelRangeConfigs(axis);
    const float rawPulse = range->min + (calibratedPulse-1000.0f) * (range->max-range->min) / 1000.0f;
    return (uint16_t)lrintf(constrainf(rawPulse, 750.0f, 2250.0f));
}
