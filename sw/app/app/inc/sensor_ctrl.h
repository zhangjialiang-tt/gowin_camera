#ifndef __SENSOR_CTRL_H__
#define __SENSOR_CTRL_H__
// #include "GOWIN_M1_gpio.h"
// #include "delay.h"
#include "type.h"
#include "zg_mdk_sensor_gst212w.h"

// void SensorPowerOn(void);
void SensorInit(void);
u32 GetADMeanValue(void);
void ShutterTmod(u16 u16TimeSel);
void CompensateExec(SYSTEM_FLAG_PARAM_S *SYSFlagParam);
void ImageComp(SYSTEM_FLAG_PARAM_S *SYSFlagParam);
void SensorIRTVPowerApbCtrlAll(void);
u8 InitkState(void);
void NucKSel(u8 u8Sel,u32 u32kAddrs);
#endif
