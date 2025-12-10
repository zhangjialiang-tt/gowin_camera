
#ifndef TEMPERATURE_H
#define TEMPERATURE_H
#include <type.h>
//三个挡位区间
#define TEMPCOMPENSATEGEARS0  80          
#define TEMPCOMPENSATEGEARS1  300
#define TEMPCOMPENSATEGEARS2  0

#define TEMPKADDRSSEL0        0
#define TEMPKADDRSSEL1        1
#define TEMPKADDRSSEL2        2
#define TEMPKADDRSSEL3        3
#define TEMPKADDRSSEL4        4  
#define TEMPKADDRSSEL5        5
#define TEMPKADDRSSEL6        6   

typedef struct takparams
{
    u8              u8TempKSelEn ;
    u8              u8kaddrsnow  ;
    u8              u8kloadstate ;  // 添加缺失的分号
} SYSTEM_K_PARAM_S;

extern SYSTEM_K_PARAM_S stSyskparam;


void GteApbTemp(u16 u16Sel);    
s32 GetApbLensTemp(void);   //获取镜头温度
s32 GetApbShutterTemp(void);//获取快门温度
s32 GetApbSensorTemp(void); //获取sensor焦平面温度
void GetCompensateSensorTemp(u8 u8Sel);
#endif // TEMPERATURE_H