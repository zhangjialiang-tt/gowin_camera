
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "../../inc/system.h"

SYSTEM_K_PARAM_S stSyskparam =
{
     .u8TempKSelEn = 0,
     .u8kaddrsnow  = 0,
     .u8kloadstate = 0  
};

static u16 u16TempTimeCnt= 0;

static s32 CalcLensTemp(s32 s32Data);
static s32 CalcShutteremp(s32 s32Data);
static s32 CalcSensorTemp(s32 s32Data);
static u8 KAddrsSel(u32 *u32Addrs,s32 s32Temp,SYSTEM_FLAG_PARAM_S *SYSFlagParam);
static u8 kAddrs14Sel(u32 *u32Addrs,s32 s32Temp,u8 u8Switch,SYSTEM_K_PARAM_S *Kparam);
static u8 kAddrs10Sel(u32 *u32Addrs, s32 s32Temp,u8 u8Switch,SYSTEM_K_PARAM_S *Kparam);

static s32 s32SensorTempPre0 = 0;
static s32 s32SensorTempPre1 = 0;
static s32 s32SensorTempPre2 = 0;

void GteApbTemp(u16 u16Sel)
{ 
     s32 lens_temp = 0;
     s32 shutter_temp = 0;
    s32 sensor_temp = 0;
    s32 sensor_temp_diff0 = 0;
    s32 sensor_temp_diff1 = 0;
    s32 sensor_temp_diff2 = 0;
    u32 u32kaddrs;
    u32 u32ApbData;
    if(u16Sel == 0)
    {
        DEBUG_INFO("u16Sel -->'0' error\n\r");
        return;
    }
    if(u16TempTimeCnt == 0)
    {
        lens_temp = GetApbLensTemp();   
        shutter_temp = GetApbShutterTemp();
        sensor_temp = GetApbSensorTemp(); 
     //    if(stSyskparam.u8TempKSelEn == 0x01)
     //    {
     //           if(0x01 == KAddrsSel(&u32kaddrs,sensor_temp,&stSysFlag))        //切K
     //           {
     //                NucKSel(0x01,u32kaddrs);
     //                apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData);
     //                if((u32ApbData&0x00040000) == 0x00040000)
     //                {
     //                     NucKSel(0x00,0x00000000);
     //                }
     //           }  
     //    }
        if((stSysFlag.u8StartBootFlag == 1) && (stSysFlag.u8CompensateSteer == NO_COMPENSATE))      //温升补偿  不进行场景补偿
        {
                sensor_temp_diff0 =  abs(sensor_temp - s32SensorTempPre0);
                sensor_temp_diff1 =  abs(sensor_temp - s32SensorTempPre1);
                sensor_temp_diff2 =  abs(sensor_temp - s32SensorTempPre2);
                if((sensor_temp_diff2 >= TEMPCOMPENSATEGEARS2) 
                && ((TEMPCOMPENSATEGEARS2 > TEMPCOMPENSATEGEARS1) && (TEMPCOMPENSATEGEARS2 > TEMPCOMPENSATEGEARS0) && (TEMPCOMPENSATEGEARS2 != 0)))
                {
                    stSysFlag.u8CompensateSteer = SHUTTER_RAADJ_NUC_BASE_COMPENSATE;
                    DEBUG_INFO("sensor_temp --> %d s32SensorTempPre --> %d sensor_temp_diff --> %d TEMPCOMPENSATEGEARS --> %d\n\r",sensor_temp,s32SensorTempPre2,sensor_temp_diff2,TEMPCOMPENSATEGEARS2);
                }
                else if(((sensor_temp_diff1 >= TEMPCOMPENSATEGEARS1) && (sensor_temp_diff1 < TEMPCOMPENSATEGEARS2))
                     && ((TEMPCOMPENSATEGEARS2 > TEMPCOMPENSATEGEARS1) && (TEMPCOMPENSATEGEARS1 > TEMPCOMPENSATEGEARS0) && (TEMPCOMPENSATEGEARS1 != 0)))
                     {
                      stSysFlag.u8CompensateSteer = SHUTTER_NUC_BASE_COMPENSATE;
                DEBUG_INFO("sensor_temp --> %d s32SensorTempPre --> %d sensor_temp_diff --> %d TEMPCOMPENSATEGEARS --> %d\n\r",sensor_temp,s32SensorTempPre1,sensor_temp_diff1,TEMPCOMPENSATEGEARS1);        
                     }
                else if(((sensor_temp_diff0 >= TEMPCOMPENSATEGEARS0) && (sensor_temp_diff0 < TEMPCOMPENSATEGEARS1))
                     && ((TEMPCOMPENSATEGEARS0 < TEMPCOMPENSATEGEARS1) && (TEMPCOMPENSATEGEARS0 < TEMPCOMPENSATEGEARS2) && (TEMPCOMPENSATEGEARS0 != 0))
                )
                {
                    stSysFlag.u8CompensateSteer = SHUTTER_BASE_COMPENSATE;
                    DEBUG_INFO("sensor_temp --> %d s32SensorTempPre --> %d sensor_temp_diff --> %d TEMPCOMPENSATEGEARS --> %d\n\r",sensor_temp,s32SensorTempPre0,sensor_temp_diff0,TEMPCOMPENSATEGEARS0);
                }
        }
    }
    if(u16TempTimeCnt >= (u16Sel-1))
    {
        u16TempTimeCnt = 0;
    }
    else 
    {
        u16TempTimeCnt++;

    }
}

s32 GetApbLensTemp(void)
{
    s32 s32ApbReadData;
    s32 s32Temp;
    apb_read(APB_REG_ADDR_LENS_TEMP    		, &s32ApbReadData);
    s32Temp = CalcLensTemp(s32ApbReadData);
    apb_write(APB_REG_ADDR_CALC_LENS_TEMP		,	s32Temp);
    return s32Temp;
}

s32 GetApbShutterTemp(void)
{
    s32 s32ApbReadData;
    s32 s32Temp;  
    apb_read(APB_REG_ADDR_SHUTTER_TEMP    		, &s32ApbReadData);
    s32Temp = CalcShutteremp(s32ApbReadData);
    apb_write(APB_REG_ADDR_CALC_SHUTTER_TEMP		,	s32Temp);
    return s32Temp;
}

s32 GetApbSensorTemp(void)
{
    s32 s32ApbReadData;
    s32 s32Temp;
    apb_read(APB_REG_ADDR_FPA_TEMP    		, &s32ApbReadData);
    s32Temp = CalcSensorTemp(s32ApbReadData);
    apb_write(APB_REG_ADDR_CALC_FPA_TEMP	,s32Temp);
    return s32Temp;
}

//获取补偿完成时的sensor温度
void GetCompensateSensorTemp(u8 u8Sel)
{
    switch (u8Sel)
    {
    case SHUTTER_BASE_COMPENSATE:
        s32SensorTempPre0  = GetApbSensorTemp();
        break;
    case SHUTTER_NUC_BASE_COMPENSATE:
        s32SensorTempPre0  = GetApbSensorTemp();
        s32SensorTempPre1  = s32SensorTempPre0 ;
        break;
    case SHUTTER_RAADJ_NUC_BASE_COMPENSATE:
        s32SensorTempPre0  = GetApbSensorTemp();
        s32SensorTempPre1  = s32SensorTempPre0 ;
        s32SensorTempPre2  = s32SensorTempPre1 ;
        break;

    default:
        DEBUG_INFO("GetCompensateSensorTemp u8Sel error\n\r");
        break;
    }

}

static s32 CalcLensTemp(s32 s32Data)
{
    s32 s32temp;
    s32temp = (short) (12736.1304901973000 - (0.0000000040235 * s32Data * s32Data * s32Data) + (0.0001218402729 * s32Data * s32Data) - (1.8218076216914 * s32Data));
    return s32temp;
}


static s32 CalcShutteremp(s32 s32Data)
{
    s32 s32temp;
    s32temp = (short) (12736.1304901973000 - (0.0000000040235 * s32Data * s32Data * s32Data) + (0.0001218402729 * s32Data * s32Data) - (1.8218076216914 * s32Data));
    return s32temp;
}

static s32 CalcSensorTemp(s32 s32Data)
{
    s32 s32temp;
    s32temp = (short) (1.25 * s32Data - 15800);
    return s32temp;
}


static u8 KAddrsSel(u32 *u32Addrs,s32 s32Temp,SYSTEM_FLAG_PARAM_S *SYSFlagParam)
{
     u8  u8StateFlag = 0;
     u32 u32AddrsReg ;
    if(SYSFlagParam->u8KNum == 0x01)    //10套
    {
          u8StateFlag =   kAddrs10Sel(&u32AddrsReg,s32Temp,SYSFlagParam->u8TmGearSwitch,&stSyskparam);
    }
    else if(SYSFlagParam->u8KNum == 0x02)   //14套
    {
          u8StateFlag =   kAddrs14Sel(&u32AddrsReg,s32Temp,SYSFlagParam->u8TmGearSwitch,&stSyskparam);
    }
    else 
    {
        if(stSyskparam.u8kaddrsnow == 0x00)
        {
          u32AddrsReg = DSRAM_KL_ADDRS0;
          stSyskparam.u8kaddrsnow = 0x01;
          u8StateFlag = 0x01;
        }
        DEBUG_INFO("u8KNum input error!\n\r");
    }
    *u32Addrs = u32AddrsReg;
    return u8StateFlag;
}

static u8 kAddrs14Sel(u32 *u32Addrs,s32 s32Temp,u8 u8Switch,SYSTEM_K_PARAM_S *Kparam)
{
     u8 u8StateFlag = 0;
    if((TEMPKADDRSSEL0 >= TEMPKADDRSSEL1) || (TEMPKADDRSSEL1 >= TEMPKADDRSSEL2) ||
       (TEMPKADDRSSEL2 >= TEMPKADDRSSEL3) || (TEMPKADDRSSEL3 >= TEMPKADDRSSEL4) ||
       (TEMPKADDRSSEL4 >= TEMPKADDRSSEL5) )
       {  
          if(Kparam->u8kaddrsnow == 0x00)
          {    
               *u32Addrs = DSRAM_KL_ADDRS0;
               Kparam->u8kaddrsnow = 0x01;
               u8StateFlag = 0x01;
          }
          DEBUG_INFO("TEMPKADDRSSEL input error!\n\r");
       }
       else
       {
            if(u8Switch == TEMPSWITCHLOW)    //低温
            {
               if(s32Temp <= TEMPKADDRSSEL0)
               {
                    if(Kparam->u8kaddrsnow == 0x01)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS0;
                         Kparam->u8kaddrsnow = 0x01;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL1)
               {
                    if(Kparam->u8kaddrsnow == 0x02)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS1;
                         Kparam->u8kaddrsnow = 0x02;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL2)
               {
                    if(Kparam->u8kaddrsnow == 0x03)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS2;
                         Kparam->u8kaddrsnow = 0x03;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL3)
               {
                    if(Kparam->u8kaddrsnow == 0x04)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS3;
                         Kparam->u8kaddrsnow = 0x04;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL4)
               {
                    if(Kparam->u8kaddrsnow == 0x05)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS4;
                         Kparam->u8kaddrsnow = 0x05;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL5)
               {
                    if(Kparam->u8kaddrsnow == 0x06)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS5;
                         Kparam->u8kaddrsnow = 0x06;
                         u8StateFlag = 0x1;
                    }
               }
               else 
               {
                    if(Kparam->u8kaddrsnow == 0x07)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS6;
                         Kparam->u8kaddrsnow = 0x07;
                         u8StateFlag = 0x1;
                    }
               }

            }
            else if(u8Switch == TEMPSWITCHHIGH) //高温
            {
               if(s32Temp <= TEMPKADDRSSEL0)
               {
                    if(Kparam->u8kaddrsnow == 0x08)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS0;
                         Kparam->u8kaddrsnow = 0x08;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL1)
               {
                    if(Kparam->u8kaddrsnow == 0x09)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS1;
                         Kparam->u8kaddrsnow = 0x09;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL2)
               {
                    if(Kparam->u8kaddrsnow == 0x0a)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS2;
                         Kparam->u8kaddrsnow = 0x0a;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL3)
               {
                    if(Kparam->u8kaddrsnow == 0x0b)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS3;
                         Kparam->u8kaddrsnow = 0x0b;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL4)
               {
                    if(Kparam->u8kaddrsnow == 0x0c)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS4;
                         Kparam->u8kaddrsnow = 0x0c;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL5)
               {
                    if(Kparam->u8kaddrsnow == 0x0d)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS5;
                         Kparam->u8kaddrsnow = 0x0d;
                         u8StateFlag = 0x1;
                    }
               }
               else 
               {
                    if(Kparam->u8kaddrsnow == 0x0e)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS6;
                         Kparam->u8kaddrsnow = 0x0e;
                         u8StateFlag = 0x1;
                    }
               }
               
            }
            else 
            {
               if(Kparam->u8kaddrsnow == 0x00)
               {    
                    *u32Addrs = DSRAM_KL_ADDRS0;
                    Kparam->u8kaddrsnow = 0x01;
                    u8StateFlag = 0x01;
               }
                DEBUG_INFO("u8Switch input error!\n\r");
            }
       }

       return u8StateFlag;

}

static u8 kAddrs10Sel(u32 *u32Addrs, s32 s32Temp,u8 u8Switch,SYSTEM_K_PARAM_S *Kparam)
{
     u8 u8StateFlag = 0;
    if((TEMPKADDRSSEL0 >= TEMPKADDRSSEL1) || (TEMPKADDRSSEL1 >= TEMPKADDRSSEL2) ||
       (TEMPKADDRSSEL2 >= TEMPKADDRSSEL3)    )
       {
          if(Kparam->u8kaddrsnow == 0x00)
          {    
               *u32Addrs = DSRAM_KL_ADDRS0;
               Kparam->u8kaddrsnow = 0x01;
               u8StateFlag = 0x01;
          }
          DEBUG_INFO("TEMPKADDRSSEL input error!\n\r");
       }
       else
       {
            if(u8Switch == TEMPSWITCHLOW)    //低温
            {
               if(s32Temp <= TEMPKADDRSSEL0)
               {
                    if(Kparam->u8kaddrsnow == 0x01)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS0;
                         Kparam->u8kaddrsnow = 0x01;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL1)
               {
                    if(Kparam->u8kaddrsnow == 0x02)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS1;
                         Kparam->u8kaddrsnow = 0x02;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL2)
               {
                    if(Kparam->u8kaddrsnow == 0x03)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS2;
                         Kparam->u8kaddrsnow = 0x03;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL3)
               {
                    if(Kparam->u8kaddrsnow == 0x04)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS3;
                         Kparam->u8kaddrsnow = 0x04;
                         u8StateFlag = 0x1;
                    }
               }
               else 
               {
                    if(Kparam->u8kaddrsnow == 0x05)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KL_ADDRS4;
                         Kparam->u8kaddrsnow = 0x05;
                         u8StateFlag = 0x1;
                    }
               }
               

            }
            else if(u8Switch == TEMPSWITCHHIGH) //高温
            {
               if(s32Temp <= TEMPKADDRSSEL0)
               {
                    if(Kparam->u8kaddrsnow == 0x08)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS0;
                         Kparam->u8kaddrsnow = 0x08;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL1)
               {
                    if(Kparam->u8kaddrsnow == 0x09)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS1;
                         Kparam->u8kaddrsnow = 0x09;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL2)
               {
                    if(Kparam->u8kaddrsnow == 0x0a)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS2;
                         Kparam->u8kaddrsnow = 0x0a;
                         u8StateFlag = 0x1;
                    }
               }
               else if(s32Temp <= TEMPKADDRSSEL3)
               {
                    if(Kparam->u8kaddrsnow == 0x0b)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS3;
                         Kparam->u8kaddrsnow = 0x0b;
                         u8StateFlag = 0x1;
                    }
               }
               else 
               {
                    if(Kparam->u8kaddrsnow == 0x0c)
                    {
                         u8StateFlag = 0x0;
                    }
                    else 
                    {
                         *u32Addrs = DSRAM_KH_ADDRS4;
                         Kparam->u8kaddrsnow = 0x0c;
                         u8StateFlag = 0x1;
                    }
               }
            }
            else 
            {
               if(Kparam->u8kaddrsnow == 0x00)
               {    
                    *u32Addrs = DSRAM_KL_ADDRS0;
                    Kparam->u8kaddrsnow = 0x01;
                    u8StateFlag = 0x01;
               }
                DEBUG_INFO("u8Switch input error!\n\r");
            }
       }
       return u8StateFlag;
}