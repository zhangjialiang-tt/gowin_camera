#ifndef GC2145_CMOS_H
#define GC2145_CMOS_H
#include "type.h"

// #define GPIO_Pin_VIS_AVDD   GPIO_Pin_9
// #define GPIO_Pin_VIS_PWRON  GPIO_Pin_10
// #define GPIO_Pin_VIS_RST    GPIO_Pin_11

#define Gc2145CmosIICADDRS  0x78>>1


#define GC2145MIPI_2Lane
/****************************************************************************
 * extern                                                                   *
 ****************************************************************************/
void gc2145_mipi_yuv_800X600_init(void);
void gc2145_cmos_power_on(void);
void gc2145_cmos_power_off(void);
void gc2145_stream_on(void);
void gc2145_dvp_yuv_800X600_init(u32 u32TimeNum,u8 *u8StateFlag);
void gc2145_dvp_yuv_800X600_logic_inst(void);
#endif