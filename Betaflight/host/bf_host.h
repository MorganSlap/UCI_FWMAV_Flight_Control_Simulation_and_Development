/* SPDX-License-Identifier: GPL-3.0-or-later */
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <pthread.h>

/* Host-only boundary. Flight algorithms remain in the upstream firmware. */
void bfHostInit(void);
void bfHostRun(void);
void bfHostShutdown(void);
bool bfHostParseArgument(int argc, char **argv, int *index);
uint64_t bfHostMicros(void);
void bfHostDelayUs(uint64_t duration);
void bfHostWriteMotor(uint8_t index, float pwm);
void bfHostNoteTask(void);
uint16_t bfHostRateToPwm(int axis, float targetDps);
float bfHostAngleToRate(int axis, float targetDegrees);

