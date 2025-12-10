#ifndef __ZG_MDK_SENSOR_GST212W_H__
#define __ZG_MDK_SENSOR_GST212W_H__

#include "type.h"

#ifdef __cplusplus
extern "C"{
#endif /* __cplusplus */

#define SENSOR_TYPE_212W


/* 探测器I2C配置 */
#define I2C_SENSOR_ADDR         (0x2C)              /* 探测器I2C地址 */


/* 快门状态控制 */
#define SHUTTER_CLOSE                           0x02            /* 闭合 */
#define SHUTTER_OPEN                            0x01            /* 打开 */
#define SHUTTER_STOP                            0x00           

/* 快门补偿模式 */
#define NO_COMPENSATE                           0x00            /* 无补偿，状态清0 */
#define SCENE_COMPENSATE                        0x01            /* 场景补偿 */
#define SHUTTER_BASE_COMPENSATE                 0x02            /* 快门base补偿 */  
#define SHUTTER_NUC_BASE_COMPENSATE             0x03            /* 快门base+NUC 补偿 */  
#define SHUTTER_RAADJ_NUC_BASE_COMPENSATE       0x04            /* 快门base+NUC+ 补偿 */  

//温度挡位
#define TEMPSWITCHLOW                            0x01          
#define TEMPSWITCHHIGH                           0x02        

/**********探测器闭环可选类型**********/
typedef enum enSensorLoopType
{
    LOOP_TYPE_RASEL 	= 1,/*探测器RASEL闭环*/
    LOOP_TYPE_HSSD 		= 2,/*探测器HSSD闭环*/
    LOOP_TYPE_GSKNUM 	= 3,/*探测器GSK_TEST_NUM闭环*/
	LOOP_TYPE_NUCLOOP 	= 4,/*探测器NUC LOOP闭环*/

    LOOP_TYPE_BUT
}LOOP_TYPE_E;

// /**********影响响应率参数**********/
typedef enum enSensorParamType
{

    PARAM_TYPE_INT = 0,                /*探测器INT值*/
    PARAM_TYPE_GAIN = 1,               /*探测器GAIN值*/
    PARAM_TYPE_GSK_REF = 2,            /*探测器GSK_REF值*/
    PARAM_TYPE_GSK = 3,                /*探测器GSK值*/
    PARAM_TYPE_VBUS = 4,               /*探测器VBUS值*/
    PARAM_TYPE_VBUS_REF = 5,           /*探测器VBUS_REF值*/
    PARAM_TYPE_RC = 6,                 /*探测器RC值*/
    PARAM_TYPE_RD = 7,                 /*探测器RD值*/
    PARAM_TYPE_GFID = 8,               /*探测器GFID值*/
    PARAM_TYPE_CSIZE = 9,              /*探测器CSIZE值*/
    PARAM_TYPE_OCC_VALUE = 10,         /*探测器OCC_VALUE值*/
    PARAM_TYPE_OCC_STEP = 11,          /*探测器OCC_STEP值*/
    PARAM_TYPE_OCC_THRES_UP = 12,      /*探测器OCC_THRES_UP值*/
    PARAM_TYPE_OCC_THRES_DOWN = 13,    /*探测器OCC_THRES_DOWN值*/
    PARAM_TYPE_RA = 14,                /*探测器RA值*/
    PARAM_TYPE_RA_THRES_HIGH = 15,     /*探测器RA_THRES_HIGH值*/
    PARAM_TYPE_RA_THRES_LOW = 16,      /*探测器RA_THRES_LOW值*/
    PARAM_TYPE_RA_ADJ = 17,            /*探测器RA_ADJ值*/
    PARAM_TYPE_RA_ADJ_THRES_HIGH = 18, /*探测器RA_ADJ_THRES_HIGH值*/
    PARAM_TYPE_RA_ADJ_THRES_LOW = 19,  /*探测器RA_ADJ_THRES_LOW值*/
    PARAM_TYPE_RASEL = 20,             /*探测器RASEL值*/
    PARAM_TYPE_RASEL_THRES_HIGH = 21,  /*探测器RASEL_THRES_HIGH值*/
    PARAM_TYPE_RASEL_THRES_LOW = 22,   /*探测器RASEL_THRES_LOW值*/
    PARAM_TYPE_HSSD = 23,              /*探测器HSSD值*/
    PARAM_TYPE_HSSD_THRES_HIGH = 24,   /*探测器HSSD_THRES_HIGH值*/
    PARAM_TYPE_HSSD_THRES_LOW = 25,    /*探测器HSSD_THRES_LOW值*/
    PARAM_TYPE_GSK_THRES_HIGH = 26,    /*探测器GSK_THRES_HIGH值*/
    PARAM_TYPE_GSK_THRES_LOW = 27,     /*探测器GSK_THRES_LOW值*/

    PARAM_TYPE_NUC_STEP = 28,

    PARAM_TYPE_BUT
}PARAM_TYPE_E;
typedef struct tagSensorParam
{

    // cur
    u16 u16int_set;
    u16 u16gain;
    u16 u16gsk_ref;
    u16 u16gsk;
    u16 u16vbus;
    u16 u16vbus_ref;
    u16 u16rd_rc;
    u16 u16gfid;
    u16 u16csize;
    u16 u16occ_value;
    u16 u16occ_step;
    u16 u16occ_thres_up;
    u16 u16occ_thres_down;
    u16 u16ra;
    u16 u16ra_thres_high;
    u16 u16ra_thres_low;
    u16 u16raadj;
    u16 u16raadj_thres_high;
    u16 u16raadj_thres_low;
    u16 u16rasel;
    u16 u16rasel_thres_high;
    u16 u16rasel_thres_low;
    u16 u16hssd;
    u16 u16hssd_thres_high;
    u16 u16hssd_thres_low;
    u16 u16gsk_thres_high;
    u16 u16gsk_thres_low;
    u16 u16nuc_step;
    // low
    u16 u16_low_int_set;
    u16 u16_low_gain;
    u16 u16_low_gsk_ref;
    u16 u16_low_gsk;
    u16 u16_low_vbus;
    u16 u16_low_vbus_ref;
    u16 u16_low_rd_rc;
    u16 u16_low_gfid;
    u16 u16_low_csize;
    u16 u16_low_occ_value;
    u16 u16_low_occ_step;
    u16 u16_low_occ_thres_up;
    u16 u16_low_occ_thres_down;
    u16 u16_low_ra;
    u16 u16_low_ra_thres_high;
    u16 u16_low_ra_thres_low;
    u16 u16_low_raadj;
    u16 u16_low_raadj_thres_high;
    u16 u16_low_raadj_thres_low;
    u16 u16_low_rasel;
    u16 u16_low_rasel_thres_high;
    u16 u16_low_rasel_thres_low;
    u16 u16_low_hssd;
    u16 u16_low_hssd_thres_high;
    u16 u16_low_hssd_thres_low;
    u16 u16_low_gsk_thres_high;
    u16 u16_low_gsk_thres_low;
    u16 u16nuc_low_step;
    // high
    u16 u16_high_int_set;
    u16 u16_high_gain;
    u16 u16_high_gsk_ref;
    u16 u16_high_gsk;
    u16 u16_high_vbus;
    u16 u16_high_vbus_ref;
    u16 u16_high_rd_rc;
    u16 u16_high_gfid;
    u16 u16_high_csize;
    u16 u16_high_occ_value;
    u16 u16_high_occ_step;
    u16 u16_high_occ_thres_up;
    u16 u16_high_occ_thres_down;
    u16 u16_high_ra;
    u16 u16_high_ra_thres_high;
    u16 u16_high_ra_thres_low;
    u16 u16_high_raadj;
    u16 u16_high_raadj_thres_high;
    u16 u16_high_raadj_thres_low;
    u16 u16_high_rasel;
    u16 u16_high_rasel_thres_high;
    u16 u16_high_rasel_thres_low;
    u16 u16_high_hssd;
    u16 u16_high_hssd_thres_high;
    u16 u16_high_hssd_thres_low;
    u16 u16_high_gsk_thres_high;
    u16 u16_high_gsk_thres_low;
    u16 u16nuc_high_step;

 
}SENSOR_PARAM_S;

extern SENSOR_PARAM_S stSensorParam;

/* 系统相关标志位 */
typedef struct tagSystemFlagParam
{
    u8               u8StartBootFlag;        //开机标志位 
    u8               u8BCompensate;          //本底补偿   
    u8               u8NUCCompensate;        //NUC补偿 
    u8               u8RaadjCompensate;      //Raadj补偿 
    u8               u8CompensateState;      //补偿状态 
    u8               u8CompensateSteer;
    u8               u8USBCompensateSteer;
    u8               u8TmGearSwitch;
    u8               u8KNum;                 //1：10套K(高温档 5套 低温档 5套)2：14套K(高温档 7套 低温档 7套)
} SYSTEM_FLAG_PARAM_S;

extern SYSTEM_FLAG_PARAM_S stSysFlag;



void SensorParamUpdate(SENSOR_PARAM_S *SetParam,u8 u8Sel);
s32 ZG_MDK_SENSOR_InitConfig0();/* 探测器MC时序配置初始化*/
s32 ZG_MDK_SENSOR_InitConfig1(); /* 等待初始化配置锁存后进行其他配置 */ 
void SensorParamSet(SENSOR_PARAM_S *SetParam);
void SensorParamUpdate(SENSOR_PARAM_S *SetParam,u8 u8Sel);
s32 ZG_MDK_SENSOR_LoopSet(LOOP_TYPE_E u8LoopType,u8 u8LoopEn,u8 *u8LoopState);/* 使能探测器的闭环,u16FieldCnt为每次闭环间隔时间 */ 


#endif
