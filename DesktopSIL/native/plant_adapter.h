#pragma once
#include "hover_plant_sil.h"
#include "hover_linear_sil.h"
extern ExtY_hover_plant_sil_T plantOutputValues;
void plantInitialize(int linear,const double *a,const double *b);
void plantOutputs(int controllerHit,int gyroHit,int accelHit);
void plantInputs(const double *delta);
void plantAdvance(double nextTime,double step);
void plantTerminate(void);
