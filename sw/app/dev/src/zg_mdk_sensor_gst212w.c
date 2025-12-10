/**********************************************************
* 文件名称：zg_mdk_sensor_gst212w.c
* 文件标识：
* 内容摘要：GST212W非制冷红外探测器初始化、配置、闭环实现
* 其它说明：模块提供不同应用和机制下的驱动函数
* 当前版本：V1.0
* 创建作者：07082lgd
* 创建日期：[2022/04/07]
* 其它说明：
*
* 修改记录1：
* 修改日期：
* 版本号：
* 修改人
* 修改内容
**********************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "sensor_ctrl.h"
#include "type.h"
#include "zg_mdk_sensor_gst212w.h"
#include "sdram_addrs_define.h"
#include "../../inc/system.h"

static u16 RAADJ_High = 511;
static u16 RAADJ_LOW = 0;
static u16 GSK_High = 47;
static u16 GSK_LOW = 24;
static u16 u16StepNum = 0;
/************************模块变量初始化**********************************/
/************************************gst212w************************************/
SYSTEM_FLAG_PARAM_S stSysFlag=
{
    .u8StartBootFlag         = 0,  //初始化完成标志为 分可见光[0] 红外[1]       
    .u8BCompensate           = 0,     
    .u8NUCCompensate         = 0,      
    .u8RaadjCompensate       = 0,
    .u8CompensateState       = 0,
    .u8CompensateSteer       = NO_COMPENSATE,
    .u8USBCompensateSteer    = NO_COMPENSATE,
    .u8TmGearSwitch          = TEMPSWITCHLOW,
    .u8KNum                  = 1
};

SENSOR_PARAM_S stSensorParam =
{
    // cur
    .u16int_set                =75,
    .u16gain                   =3,
    .u16gsk_ref                =30,
    .u16gsk                    =35,
    .u16vbus                   =64,
    .u16vbus_ref               =64,
    .u16rd_rc                  =36,
    .u16gfid                   =0,
    .u16csize                  =22,
    .u16occ_value              =8,
    .u16occ_step               =1,
    .u16occ_thres_up           =4200,
    .u16occ_thres_down         =3200,
    .u16ra                     =18,
    .u16ra_thres_high          =7000,
    .u16ra_thres_low           =1000,
    .u16raadj                  =256,
    .u16raadj_thres_high       =4200,
    .u16raadj_thres_low        =3200,
    .u16rasel                  =0,
    .u16rasel_thres_high       =0,
    .u16rasel_thres_low        =0,
    .u16hssd                   =0,
    .u16hssd_thres_high        =0,
    .u16hssd_thres_low         =0,
    .u16gsk_thres_high         =4400,
    .u16gsk_thres_low          =3000,
    .u16nuc_low_step           =50,
    // low
    .u16_low_int_set                =75,
    .u16_low_gain                   =3,
    .u16_low_gsk_ref                =30,
    .u16_low_gsk                    =35,
    .u16_low_vbus                   =64,
    .u16_low_vbus_ref               =64,
    .u16_low_rd_rc                  =36,
    .u16_low_gfid                   =0,
    .u16_low_csize                  =22,
    .u16_low_occ_value              =8,
    .u16_low_occ_step               =1,
    .u16_low_occ_thres_up           =4200,
    .u16_low_occ_thres_down         =3200,
    .u16_low_ra                     =18,
    .u16_low_ra_thres_high          =7000,
    .u16_low_ra_thres_low           =1000,
    .u16_low_raadj                  =256,
    .u16_low_raadj_thres_high       =4200,
    .u16_low_raadj_thres_low        =3200,
    .u16_low_rasel                  =0,
    .u16_low_rasel_thres_high       =0,
    .u16_low_rasel_thres_low        =0,
    .u16_low_hssd                   =0,
    .u16_low_hssd_thres_high        =0,
    .u16_low_hssd_thres_low         =0,
    .u16_low_gsk_thres_high         =4400,
    .u16_low_gsk_thres_low          =3000,
    .u16nuc_low_step                = 50,

    // high
    .u16_high_int_set               =60,
    .u16_high_gain                  =3,
    .u16_high_gsk_ref               =30,
    .u16_high_gsk                   =35,
    .u16_high_vbus                  =64,
    .u16_high_vbus_ref              =64,
    .u16_high_rd_rc                 =36,
    .u16_high_gfid                  =0,
    .u16_high_csize                 =22,
    .u16_high_occ_value             =8,
    .u16_high_occ_step              =1,
    .u16_high_occ_thres_up          =4200,
    .u16_high_occ_thres_down        =3200,
    .u16_high_ra                    =18,
    .u16_high_ra_thres_high         =7000,
    .u16_high_ra_thres_low          =1000,
    .u16_high_raadj                 =256,
    .u16_high_raadj_thres_high      =4200,
    .u16_high_raadj_thres_low       =3200,
    .u16_high_rasel                 =0,
    .u16_high_rasel_thres_high      =0,
    .u16_high_rasel_thres_low       =0,
    .u16_high_hssd                  =0,
    .u16_high_hssd_thres_high       =0,
    .u16_high_hssd_thres_low        =0,
    .u16_high_gsk_thres_high        =4400,
    .u16_high_gsk_thres_low         =3000,
    .u16nuc_high_step               = 210

};

/************************接口函数定义**********************************/
s32 ZG_MDK_SENSOR_InitConfig0();/* 探测器MC时序配置初始化*/
s32 ZG_MDK_SENSOR_InitConfig1(); /* 等待初始化配置锁存后进行其他配置 */ 
static void ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_E u8ParamType, u16 u16ParamVal);
static void SensorGSKLoop(SENSOR_PARAM_S *SetParam,u8 *StateFlag);
static void SensorGainSet(u8 u8Gain);               /*Gain的配置*/
static void SensorIntSet(u16 u16Int);               /*INT的配置*/
static void SensorRAADJLoop(SENSOR_PARAM_S *SetParam,u8 *StateFlag);            /*RASEL的配置*/
static void SensorHssdSet(u16 u16Hssd);             /*Hssd的配置*/
static void SensorRaSet(u8 u8Ra);                   /*Ra的配置*/
static void SensorGskRefSet(u8 u8Gsk_Ref);          /*Gsk_Ref的配置*/
static void SensorGskSet(u8 u8Gsk);                 /*Gsk的配置*/
static void SensorVbusSet(u8 u8Vbus);               /*Vbus的配置*/
static void SensorVbusRefSet(u8 u8VbusRef);         /*VbusRef的配置*/
static void SensorPollSet(u16 u16Poll);             /*Poll的配置*/
static void SensorRaadjSet(u16 u16AdNumSet);        /*RASEL的配置*/
static void SensorNucHighSet(u16 u16NucHigh);       /*Nuc上限配置*/
static void SensorNucLowSet(u16 u16NucLow);         /*Nuc下限配置*/
static void SensorNucStepSet(u16 u16NucStep);       /*NucStep步进配置*/
static void SensorNucInitSet(u8 u8InitData);        /*全屏NUC初始化配置*/
static void GetSensorBadCol(void);                  /*读取探测器内部坏列*/
static void SensorSetReg(u8 u8RegAddr, u8 u8Data);  /*SENSOR IIC 配置*/
static void SensorGetReg(u8 u8RegAddr, u8 *pu8Data);
static void ZGSensorTestImage(u8 u8sel);

static void SensorGetReg(u8 u8RegAddr, u8 *pu8Data)
{
//    *pu8Data = I2C_ReceiveByte(I2C,I2C_SENSOR_ADDR,u8RegAddr);
   app_sensor_read_reg(u8RegAddr,pu8Data);    
}


static void SensorSetReg(u8 u8RegAddr, u8 u8Data)
{
    // u8 rdData;
    // I2C_SendByte(I2C, I2C_SENSOR_ADDR,u8RegAddr, u8Data); 
    app_sensor_write_reg(u8RegAddr, u8Data);
    // hal_i2c_delay_ms(10);
    // SensorGetReg(u8RegAddr, &rdData);
    // DEBUG_INFO("write u8RegAddr -->%x u8Data -->%x\n\r",u8RegAddr,u8Data);
    // DEBUG_INFO("read u8RegAddr -->%x rdData -->%x\n\r",u8RegAddr,rdData);
}

static void ZGSensorTestImage(u8 u8sel)
{
    u8 rddata;
    if(u8sel == 0x01)
    {
        SensorSetReg(0x7c, 0xa9);
        SensorSetReg(0x2F, 0x80);
        SensorSetReg(0x7c, 0xa8);
        DEBUG_INFO("open sensor test image!\n\r");
    }
    else
    {
        SensorSetReg(0x7c, 0xa9);
        SensorSetReg(0x2F, 0x00);
        SensorSetReg(0x7c, 0xa8);
        DEBUG_INFO("close sensor test image!\n\r");
    }
}


void SensorParamSet(SENSOR_PARAM_S *SetParam)
{
    u16 u16rdrc;
    u8 u8Rd = 1;
    u8 u8Rc = 4;
    u16rdrc = SetParam->u16rd_rc;
    u8Rd = (u16rdrc>>4) & 0x000f;
    u8Rc = u16rdrc & 0x000f;

    DEBUG_INFO("u8Rd --> %d u8Rc --> %d\n\r",u8Rd,u8Rc);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_INT, 				SetParam->u16int_set		); // 45
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GAIN, 			SetParam->u16gain			); // 4
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GSK, 				SetParam->u16gsk			);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GSK_REF, 			SetParam->u16gsk_ref		);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_VBUS, 			SetParam->u16vbus			);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_RA, 				SetParam->u16ra		        ); // 18
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_RC, 				u8Rc				   	    );
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_RD, 				u8Rd				        );
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_VBUS_REF, 		SetParam->u16vbus_ref		); // vbus_ref等同于hssd
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_RA_ADJ, 			SetParam->u16raadj			); // ra_adj等同于rasel
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_OCC_THRES_UP, 	SetParam->u16occ_thres_up   );
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_OCC_THRES_DOWN, 	SetParam->u16occ_thres_down );
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_OCC_VALUE, 		SetParam->u16occ_value		);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GSK_THRES_HIGH, 	SetParam->u16gsk_thres_high );
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GSK_THRES_LOW, 	SetParam->u16gsk_thres_low	);
    ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_NUC_STEP, 	    SetParam->u16nuc_step	    );
    // DEBUG_INFO("stSensorParam.u16int_set  %d\r\n",stSensorParam.u16int_set);
    // DEBUG_INFO("stSensorParam.u16gain	  %d\r\n",stSensorParam.u16gain	);
    // DEBUG_INFO("stSensorParam.u16gsk	  %d\r\n",stSensorParam.u16gsk	);
    // DEBUG_INFO("stSensorParam.u16gsk_ref  %d\r\n",stSensorParam.u16gsk_ref);
    // DEBUG_INFO("stSensorParam.u16vbus	  %d\r\n",stSensorParam.u16vbus	);
    // DEBUG_INFO("stSensorParam.u16ra		  %d\r\n",stSensorParam.u16ra		 );
    // DEBUG_INFO("stSensorParam.u16rd_rc  %d\r\n",stSensorParam.u16rd_rc);
    // DEBUG_INFO("stSensorParam.u16vbus_ref		 %d\r\n",stSensorParam.u16vbus_ref		);
    // DEBUG_INFO("stSensorParam.u16raadj		     %d\r\n",stSensorParam.u16raadj			);
    // DEBUG_INFO("stSensorParam.u16occ_thres_up    %d\r\n",stSensorParam.u16occ_thres_up  );
    // DEBUG_INFO("stSensorParam.u16occ_thres_down  %d\r\n",stSensorParam.u16occ_thres_down);
    // DEBUG_INFO("stSensorParam.u16occ_value	     %d\r\n",stSensorParam.u16occ_value		);
    // DEBUG_INFO("stSensorParam.u16gsk_thres_high  %d\r\n",stSensorParam.u16gsk_thres_high);
    // DEBUG_INFO("stSensorParam.u16gsk_thres_low   %d\r\n",stSensorParam.u16gsk_thres_low);
    // DEBUG_INFO("stSensorParam.u16nuc_step	     %d\r\n",stSensorParam.u16nuc_step	   );

}


void SensorParamUpdate(SENSOR_PARAM_S *SetParam,u8 u8Sel)
{
    switch (u8Sel)
    {
        case 0x01:
            SensorSetReg(0x7c, 0xab); //to page3;
            SensorSetReg(0x1a, 0x32);
            SensorSetReg(0x00, 0xbf); //VRD_OPL=1/VRD_OPH=2
            SensorSetReg(0x7c, 0xa8); //to page0;

            SensorSetReg(0x7c, 0xa9); //to page1;
            SensorSetReg(0x06, 0x4a);
            SensorSetReg(0x7c, 0xa8); //to page0;

            SensorSetReg(0x7c, 0xab); //to page3;
            SensorSetReg(0x0e, 0x0d);
            SensorSetReg(0x0f, 0x0f);
            SensorSetReg(0x18, 0x01);
            SensorSetReg(0x7c, 0xa8); //to page0;
            NucKSel(0x01,DSRAM_KL_ADDRS1);	

            SetParam->u16int_set	        =  SetParam->u16_low_int_set	        ;
            SetParam->u16gain		        =  SetParam->u16_low_gain		        ;
            SetParam->u16gsk		        =  SetParam->u16_low_gsk		        ;
            SetParam->u16gsk_ref	        =  SetParam->u16_low_gsk_ref	        ;
            SetParam->u16vbus		        =  SetParam->u16_low_vbus		        ;
            SetParam->u16vbus_ref	        =  SetParam->u16_low_vbus_ref	        ;
            SetParam->u16rd_rc	            =  SetParam->u16_low_rd_rc	            ;
            SetParam->u16occ_value		    =  SetParam->u16_low_occ_value		    ;
            SetParam->u16occ_thres_up       =  SetParam->u16_low_occ_thres_up       ;
            SetParam->u16occ_thres_down     =  SetParam->u16_low_occ_thres_down     ;
            SetParam->u16ra		            =  SetParam->u16_low_ra		            ;
            SetParam->u16raadj		        =  SetParam->u16_low_raadj		        ;
            SetParam->u16raadj_thres_high   =  SetParam->u16_low_raadj_thres_high   ;
            SetParam->u16raadj_thres_low    =  SetParam->u16_low_raadj_thres_low    ;
            SetParam->u16hssd_thres_high    =  SetParam->u16_low_hssd_thres_high    ;
            SetParam->u16hssd_thres_low     =  SetParam->u16_low_hssd_thres_low     ;
            SetParam->u16gsk_thres_high	    =  SetParam->u16_low_gsk_thres_high     ;
            SetParam->u16gsk_thres_low	    =  SetParam->u16_low_gsk_thres_low	    ;
            SetParam->u16nuc_step           =  SetParam->u16nuc_low_step     	    ;
            apb_write(APB_REG_ADDR_SENSOR_PARA1 , SetParam->u16_low_int_set);
            apb_write(APB_REG_ADDR_SENSOR_PARA2 , SetParam->u16_low_gain);
            apb_write(APB_REG_ADDR_SENSOR_PARA3 , SetParam->u16_low_gsk_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA4 , SetParam->u16_low_gsk);
            apb_write(APB_REG_ADDR_SENSOR_PARA5 , SetParam->u16_low_vbus);
            apb_write(APB_REG_ADDR_SENSOR_PARA6 , SetParam->u16_low_vbus_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA7 , SetParam->u16_low_rd_rc);
            apb_write(APB_REG_ADDR_SENSOR_PARA8 , SetParam->u16_low_gfid);
            apb_write(APB_REG_ADDR_SENSOR_PARA9 , SetParam->u16_low_csize);
            apb_write(APB_REG_ADDR_SENSOR_PARA10, SetParam->u16_low_occ_value);
            apb_write(APB_REG_ADDR_SENSOR_PARA11, SetParam->u16_low_occ_step);
            apb_write(APB_REG_ADDR_SENSOR_PARA12, SetParam->u16_low_occ_thres_up);
            apb_write(APB_REG_ADDR_SENSOR_PARA13, SetParam->u16_low_occ_thres_down);
            apb_write(APB_REG_ADDR_SENSOR_PARA14, SetParam->u16_low_ra);
            apb_write(APB_REG_ADDR_SENSOR_PARA15, SetParam->u16_low_ra_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA16, SetParam->u16_low_ra_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA17, SetParam->u16_low_raadj);
            apb_write(APB_REG_ADDR_SENSOR_PARA18, SetParam->u16_low_raadj_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA19, SetParam->u16_low_raadj_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA20, SetParam->u16_low_rasel);
            apb_write(APB_REG_ADDR_SENSOR_PARA21, SetParam->u16_low_rasel_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA22, SetParam->u16_low_rasel_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA23, SetParam->u16_low_hssd);
            apb_write(APB_REG_ADDR_SENSOR_PARA24, SetParam->u16_low_hssd_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA25, SetParam->u16_low_hssd_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA26, SetParam->u16_low_gsk_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA27, SetParam->u16_low_gsk_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA28, SetParam->u16nuc_low_step); 
            break;
        case 0x02:

            SensorSetReg(0x7c, 0xab); //to page3;
            SensorSetReg(0x1a, 0xf2);

            SensorSetReg(0x00, 0x3f); //VRD_OPL=1/VRD_OPH=2
            SensorSetReg(0x7c, 0xa8); //to page0;

            SensorSetReg(0x7c, 0xa9); //to page1;
            SensorSetReg(0x06, 0x49);
            SensorSetReg(0x7c, 0xa8); //to page0;

            SensorSetReg(0x7c, 0xab); //to page3;
            SensorSetReg(0x0e, 0x0d);
            SensorSetReg(0x0f, 0x0f);
            SensorSetReg(0x18, 0x01);
            SensorSetReg(0x7c, 0xa8); //to page0;
            NucKSel(0x01,DSRAM_KH_ADDRS1);
            SetParam->u16int_set	        =  SetParam->u16_high_int_set	         ;
            SetParam->u16gain		        =  SetParam->u16_high_gain		         ;
            SetParam->u16gsk		        =  SetParam->u16_high_gsk		         ;
            SetParam->u16gsk_ref	        =  SetParam->u16_high_gsk_ref	         ;
            SetParam->u16vbus		        =  SetParam->u16_high_vbus		         ;
            SetParam->u16vbus_ref	        =  SetParam->u16_high_vbus_ref	         ;
            SetParam->u16rd_rc	            =  SetParam->u16_high_rd_rc	             ;
            SetParam->u16occ_value		    =  SetParam->u16_high_occ_value		     ;
            SetParam->u16occ_thres_up       =  SetParam->u16_high_occ_thres_up       ;
            SetParam->u16occ_thres_down     =  SetParam->u16_high_occ_thres_down     ;
            SetParam->u16ra		            =  SetParam->u16_high_ra		         ;
            SetParam->u16raadj		        =  SetParam->u16_high_raadj		         ;
            SetParam->u16raadj_thres_high   =  SetParam->u16_high_raadj_thres_high   ;
            SetParam->u16raadj_thres_low    =  SetParam->u16_high_raadj_thres_low    ;
            SetParam->u16hssd_thres_high    =  SetParam->u16_high_hssd_thres_high    ;
            SetParam->u16hssd_thres_low     =  SetParam->u16_high_hssd_thres_low     ;
            SetParam->u16gsk_thres_high	    =  SetParam->u16_high_gsk_thres_high     ;
            SetParam->u16gsk_thres_low	    =  SetParam->u16_high_gsk_thres_low	     ;
            SetParam->u16nuc_step           =  SetParam->u16nuc_high_step       	 ;

            apb_write(APB_REG_ADDR_SENSOR_PARA1 , SetParam->u16_high_int_set);
            apb_write(APB_REG_ADDR_SENSOR_PARA2 , SetParam->u16_high_gain);
            apb_write(APB_REG_ADDR_SENSOR_PARA3 , SetParam->u16_high_gsk_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA4 , SetParam->u16_high_gsk);
            apb_write(APB_REG_ADDR_SENSOR_PARA5 , SetParam->u16_high_vbus);
            apb_write(APB_REG_ADDR_SENSOR_PARA6 , SetParam->u16_high_vbus_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA7 , SetParam->u16_high_rd_rc);
            apb_write(APB_REG_ADDR_SENSOR_PARA8 , SetParam->u16_high_gfid);
            apb_write(APB_REG_ADDR_SENSOR_PARA9 , SetParam->u16_high_csize);
            apb_write(APB_REG_ADDR_SENSOR_PARA10, SetParam->u16_high_occ_value);
            apb_write(APB_REG_ADDR_SENSOR_PARA11, SetParam->u16_high_occ_step);
            apb_write(APB_REG_ADDR_SENSOR_PARA12, SetParam->u16_high_occ_thres_up);
            apb_write(APB_REG_ADDR_SENSOR_PARA13, SetParam->u16_high_occ_thres_down);
            apb_write(APB_REG_ADDR_SENSOR_PARA14, SetParam->u16_high_ra);
            apb_write(APB_REG_ADDR_SENSOR_PARA15, SetParam->u16_high_ra_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA16, SetParam->u16_high_ra_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA17, SetParam->u16_high_raadj);
            apb_write(APB_REG_ADDR_SENSOR_PARA18, SetParam->u16_high_raadj_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA19, SetParam->u16_high_raadj_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA20, SetParam->u16_high_rasel);
            apb_write(APB_REG_ADDR_SENSOR_PARA21, SetParam->u16_high_rasel_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA22, SetParam->u16_high_rasel_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA23, SetParam->u16_high_hssd);
            apb_write(APB_REG_ADDR_SENSOR_PARA24, SetParam->u16_high_hssd_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA25, SetParam->u16_high_hssd_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA26, SetParam->u16_high_gsk_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA27, SetParam->u16_high_gsk_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA28, SetParam->u16nuc_high_step); 
            break;

    default:
        DEBUG_INFO("SensorParam NULL \n\r");
        break;
    }
}


//**************************************************************************
////// //InitConfig0 /* 根据探测器类型和MC时序参数进行初始化配置 */ 
//**************************************************************************
s32 ZG_MDK_SENSOR_InitConfig0()
{
    s32 s32Ret = NI_SUCCESS;
    u8 u8HsizeValidSetHigh, u8HsizeValidSetLow = 0;
    u8 u8VsizeValidSetHigh, u8VsizeValidSetLow = 0;
    u8 u8HsizeLastSetHigh, u8HsizeLastSetLow = 0;
    u16 u16HsizeBlank = 0;
    u8 u8HsizeBlankHigh, u8HsizeBlankLow = 0;
    u16 u16VsizeBlank = 0;
    u8 u8VsizeBlankHigh, u8VsizeBlankLow = 0;
    u8 u8RdData = 1;
    u32 i = 0, j = 0;


    unsigned  char u8tmp = 0;
    // 内部ADC初始化
    SensorSetReg(0x7c, 0xa8); // to page0
    SensorSetReg(0x0D, 0x00);
    SensorSetReg(0x2a, 0x84); // 非连续模式
    SensorGetReg(0x2a, &u8tmp);
    DEBUG_INFO("---->InitConfig0 0x2a = %x\n\r",u8tmp);
    SensorSetReg(0x1d, 0x00); // ROW_SEL_DELAY_TIME=4
    SensorSetReg(0x2b, 0x20); // niossysctl.s1_dly_time = 32
    SensorSetReg(0x2c, 0x04); // niossysctl.neg_s1a_time = 4;
    SensorSetReg(0x39, 0x32); // niossysctl.s1adc_time = 50
    SensorSetReg(0x3a, 0x00);

    SensorSetReg(0x7c, 0xa9); // to page1
    SensorSetReg(0x0c, 0x14); // gfid_srst_time = 22
    SensorSetReg(0x0d, 0x00);

    SensorSetReg(0x7c, 0xab); // to page3
    SensorSetReg(0x09, 0x1e); // skim_rst_time =32
    SensorSetReg(0x00, 0xbf);

    SensorSetReg(0x7c, 0xa9); // to page1
    SensorSetReg(0x27, 0xe8);

    SensorSetReg(0x7c, 0xab); // to page3
    SensorSetReg(0x0d, 0x14);

    SensorSetReg(0x7c, 0xa8); // to page0;
    SensorSetReg(0x18, 0x3F); // inputmode

    SensorSetReg(0x0d, 0x00);

    // 开窗配置 25hz
    // u8HsizeValidSetLow = (256) & 0x00ff;
    // u8HsizeValidSetHigh = (256) >> 8;
    // SensorSetReg(0x02, u8HsizeValidSetLow);
    // SensorSetReg(0x03, u8HsizeValidSetHigh);

    // u8VsizeValidSetLow = (200) & 0x00ff;
    // u8VsizeValidSetHigh = (200) >> 8;
    // SensorSetReg(0x04, u8VsizeValidSetLow);
    // SensorSetReg(0x05, u8VsizeValidSetHigh);

    // u16HsizeBlank = 400 - 256;
    // u8HsizeBlankLow = u16HsizeBlank & 0x00ff;
    // u8HsizeBlankHigh = u16HsizeBlank >> 8;
    // SensorSetReg(0x06, u8HsizeBlankLow);
    // SensorSetReg(0x07, u8HsizeBlankHigh);

    // u16VsizeBlank = 300 - 200;
    // u8VsizeBlankLow = u16VsizeBlank & 0x00ff;
    // u8VsizeBlankHigh = u16VsizeBlank >> 8;
    // SensorSetReg(0x08, u8VsizeBlankLow);
    // SensorSetReg(0x09, u8VsizeBlankHigh);

    // u8HsizeLastSetLow = 0 & 0x00ff;
    // u8HsizeLastSetHigh = 0 >> 8;
    // SensorSetReg(0x0a, u8HsizeLastSetLow);
    // SensorSetReg(0x0b, u8HsizeLastSetHigh);

    // 开窗配置 30hz
    u8HsizeValidSetLow = (256) & 0x00ff;
    u8HsizeValidSetHigh = (256) >> 8;
    SensorSetReg(0x02, u8HsizeValidSetLow);
    SensorSetReg(0x03, u8HsizeValidSetHigh);

    u8VsizeValidSetLow = (200) & 0x00ff;
    u8VsizeValidSetHigh = (200) >> 8;
    SensorSetReg(0x04, u8VsizeValidSetLow);
    SensorSetReg(0x05, u8VsizeValidSetHigh);

    u16HsizeBlank = 450 - 256;
    u8HsizeBlankLow = u16HsizeBlank & 0x00ff;
    u8HsizeBlankHigh = u16HsizeBlank >> 8;
    SensorSetReg(0x06, u8HsizeBlankLow);
    SensorSetReg(0x07, u8HsizeBlankHigh);

    u16VsizeBlank = 222 - 200;
    u8VsizeBlankLow = u16VsizeBlank & 0x00ff;
    u8VsizeBlankHigh = u16VsizeBlank >> 8;
    SensorSetReg(0x08, u8VsizeBlankLow);
    SensorSetReg(0x09, u8VsizeBlankHigh);

    u8HsizeLastSetLow = 100 & 0x00ff;
    u8HsizeLastSetHigh = 100 >> 8;
    SensorSetReg(0x0a, u8HsizeLastSetLow);
    SensorSetReg(0x0b, u8HsizeLastSetHigh);

    // 以下按评测配置，暂不清楚配置的什么
    SensorSetReg(0x0e, 0x00);
    SensorSetReg(0x11, 0x60); // MC为6M
    SensorSetReg(0x12, 0x00);
    SensorSetReg(0x22, 0x02); // V3探测器打线正常后，从0x04调整为0x02
    SensorSetReg(0x2D, 0x38); // CTIA //原配置0x38，评测241118_NT修改为0x28
    SensorSetReg(0x2E, 0x00); // CTIA
    SensorSetReg(0x2f, 0x41); // 当MC为6M时对应配置，不同MC需要配置不同值，此处配置为评测算好给的
    SensorSetReg(0x30, 0x8c);
    SensorSetReg(0x31, 0x02);

    //=========================================锁存配置的输出模式==========================================//
    SensorSetReg(0x01, 0x01); // reg_initial_start////锁存 配置的输出模式；启动内部校正

    hal_i2c_delay_ms(10);
    // 等待初始化完成
    // unsigned  char u8tmp = 0;

    u8tmp = 1;
	while((u8tmp == 1) && (i < 200))
	{
        SensorGetReg(0x01, &u8tmp);
		u8tmp = u8tmp & 0x01; 
		i++;

	}
    hal_i2c_delay_ms(3);
    DEBUG_INFO("---->InitConfig0\n\r");
    if((u8tmp == 1) || ( i >= 200))
    {
        s32Ret = NI_FAILURE;
        DEBUG_INFO("reg_initial_start error\n\r");
    }
    else 
    {
        DEBUG_INFO("reg_initial_start pass\n\r");
    }
    ZGSensorTestImage(0);
    return s32Ret;
}

//**************************************************************************
////// //InitConfig1 /* 等待内部锁存后再配置其他寄存器 0:成功 1:失败*/ 
//**************************************************************************
s32 ZG_MDK_SENSOR_InitConfig1()
{
    u8 rd_data = 0;

    SensorSetReg(0x7C, 0xA8);//page3
    SensorGetReg(0x23, &rd_data);
    DEBUG_INFO("ID -->%x \n\r",rd_data);  // 0x04  --> W7 sensor
    hal_i2c_delay_ms(10);
	SensorSetReg(0x7c,0xa8); //to page0;
	SensorSetReg(0x33,0x1f); //P_PCLK_ADJ
	SensorSetReg(0x34,0x48); //P_HSYNC_ADJ
	SensorSetReg(0x20,0x04); //VTemp
	SensorSetReg(0x29,0x0b); //VTemp
	SensorSetReg(0x35,0x9e); //VTemp
	SensorSetReg(0x32,0x00);
	SensorSetReg(0x38,0x20); //VTemp
	SensorSetReg(0x2b,0xa0); //niossysctl.s1_dly_time = 160

	SensorSetReg(0x7c,0xab); //to page3;
	SensorSetReg(0x0d,0x10); //VRD_RESL=2
	SensorSetReg(0x02,0x14);//TCR2=20		//*********************************TCR2/TCR1*********
	SensorSetReg(0x01,0x73);//TCR1=115
	SensorSetReg(0x23,0x27);

	SensorSetReg(0x1b,0x15);
	SensorSetReg(0x04,0x88);

	SensorSetReg(0x1e, 0x00);//RA=14
	SensorSetReg(0x20, 0x3f);
	SensorSetReg(0x21, 0xff);

	SensorSetReg(0x22,0xe2);//外置Rbias

	SensorSetReg(0x05,0x42);//VTemp


	SensorSetReg(0x7C,0xA9);//page1

	SensorSetReg(0x06,0x4a);//BIAS_IRAMP_ADJ=3	//Nmidl=1/Vramp=2
	SensorSetReg(0x25,0x22);//
	SensorSetReg(0x07,0x16);
	SensorSetReg(0x3d,0x04);
	SensorSetReg(0x0b,0x84);
	SensorSetReg(0x27,0xe8);//VRD_RESH=4  //SetSENSOR(0x27,0xa8);0xb0
	SensorSetReg(0x20,0x0c);
	SensorSetReg(0x24,0x5a);
	SensorSetReg(0x0a,0x00);	//*********************************ADC_NMIN_USER=1000***
	SensorSetReg(0x0b,0x84);

	SensorSetReg(0x7c,0xaa);//to page2;
	//初始化NUC
	SensorGetReg(0x06,&rd_data);
	rd_data = (rd_data & 0xef) | 0x10;
	SensorSetReg(0x06,rd_data);//nuc_init_en=1
	hal_i2c_delay_ms(1); //usleep(1000);
	SensorGetReg(0x06,&rd_data);
	rd_data = (rd_data & 0xf0) | 0x08;
	SensorSetReg(0x06, rd_data);
	//NUC
	SensorSetReg(0x00, 0x01);//nuc_diapause
	SensorSetReg(0x01,0x51);//nuc_cal_trend=1 auto_nuc_mode=1 nuc_step=1

	SensorSetReg(0x02,0x88);
	SensorSetReg(0x03,0x13);//nuc_thres_up=5000
	SensorSetReg(0x04,0xb8);
	SensorSetReg(0x05,0x0b);//nuc_thres_down=3000


	SensorSetReg(0x7c,0xab);//to page3;
	SensorSetReg(0x00,0xbf); //VRD_OPL=1/VRD_OPH=2
	SensorSetReg(0x1c,0x08); //*********************************外置LDO**************
	SensorSetReg(0x1d,0xce);
	SensorSetReg(0x0a,0x08);//之前未配置

	SensorSetReg(0x1a,0xf2);//NUC_STEP 

	SensorSetReg(0x18,0x12);//VDK=9
	SensorSetReg(0x0e,0x1c);//VDR1=79
	SensorSetReg(0x0f,0x0f);//VDR2=29
	SensorSetReg(0x06, 0x40); //VBUS=65
	SensorSetReg(0x2c, 0x20);//GSK_Ref=32
	SensorSetReg(0x11, 0x0f);//SKIM_NUC_REF_ADJ=15
	SensorSetReg(0x19, 0x24);//RD/RC

	SensorSetReg(0x12, 0x02);

	SensorSetReg(0x7c,0xa8);//to page0;

	SensorSetReg(0x3b, 0x20);//GSK=32
	SensorSetReg(0x3c, 0x40);//HSSD=64

//	SensorSetReg(0x28, 0x24);//V3探测器打线正常后，从0x24调整为0x2c
	SensorSetReg(0x28, 0x2c);//

}

static s32 NucLoop(u8 *u8LoopState)
{
    u32 u32TotalDataAvg = 0;
    u8 u8LoopStateFlag = 0;
    u8 u8RdData = 0;
    u8 u8WrData = 0;


    SensorSetReg(0x7c, 0xaa); // to page2
    SensorGetReg(0x06, &u8RdData);
    u8RdData = (u8RdData & 0xef) | 0x00;
    hal_i2c_delay_ms(1);
    SensorSetReg(0x06, u8RdData); // 关闭occ初始值使能

    SensorGetReg(0x01, &u8RdData);
    u8WrData = (u8RdData & 0x7f) | 0x80;
    hal_i2c_delay_ms(1);
    SensorSetReg(0x01, u8WrData); // 打开occ校准使能

    SensorSetReg(0x7c, 0xa8); // to page0

    hal_i2c_delay_ms(700);

    SensorSetReg(0x7c, 0xaa); // to page2
    SensorGetReg(0x01, &u8RdData);
    u8WrData = (u8RdData & 0x7f) | 0x00;
    hal_i2c_delay_ms(1);
    SensorSetReg(0x01, u8WrData); // 关闭occ校准使能

    SensorGetReg(0x06, &u8RdData);
    u8RdData = (u8RdData & 0xef) | 0x00;
    hal_i2c_delay_ms(1);
    SensorSetReg(0x06, u8RdData); // 关闭occ初始值使能

    SensorSetReg(0x7c, 0xa8); // to page0

    hal_i2c_delay_ms(40);
    u32TotalDataAvg = GetADMeanValue();
    DEBUG_INFO("NUC CALC DONE ADMEAN --> %d\n\r",u32TotalDataAvg);
    u8LoopStateFlag = 0x01;
    *u8LoopState = u8LoopStateFlag;


}

static void SensorRAADJLoop(SENSOR_PARAM_S *SetParam,u8 *StateFlag)
{
    u32 u32TotalDataAvg = 0;
    u8  u8LoopStateFlag = 0;
    u16 AD_MEAN_MAX = 4200;
    u16 AD_MEAN_MIN = 3200;
    AD_MEAN_MAX =  SetParam->u16raadj_thres_high ;
    AD_MEAN_MIN =   SetParam->u16raadj_thres_low ;

    if ((AD_MEAN_MIN >= AD_MEAN_MAX)||
        (AD_MEAN_MAX > 16383)       ||
        (AD_MEAN_MAX < 0)           ||
        (AD_MEAN_MIN > 16383)       ||
        (AD_MEAN_MIN < 0)               )
    {
        u8LoopStateFlag = 2;
        DEBUG_INFO("SensorRAADJLoop Fail !\r\n");
        DEBUG_INFO("AD_MEAN_MIN %d and AD_MEAN_MAX<%d> error !!\n\r");
    }
    else 
    {
        u32TotalDataAvg = GetADMeanValue();
        if ((u32TotalDataAvg >= AD_MEAN_MIN) && (u32TotalDataAvg <= AD_MEAN_MAX)) // Rasel调整成功标志
        {
            u8LoopStateFlag = 1; // 闭环成功
            u16StepNum = 0;
            RAADJ_High = 511;
            RAADJ_LOW = 0;
            DEBUG_INFO("SensorRAADJLoop Success \n\r");
            DEBUG_INFO("AD_MEAN_MAX --> %d AD_MEAN_MIN --> %d \n\r", AD_MEAN_MAX,AD_MEAN_MIN);

        }
        else
        {
            if (u16StepNum == 10)
            {
                u8LoopStateFlag = 2; // 闭环失败
                u16StepNum = 0;
                RAADJ_High = 511;
                RAADJ_LOW = 0;

                DEBUG_INFO("SensorRAADJLoop Fail !\r\n");
                DEBUG_INFO("u16StepNum = <%d>\r\n", u16StepNum);
                DEBUG_INFO("AD_MEAN_MAX --> %d AD_MEAN_MIN --> %d \n\r", AD_MEAN_MAX,AD_MEAN_MIN);
            }
            else
            {
                if (u32TotalDataAvg > AD_MEAN_MAX) // AD偏大，调大RASEL减小AD
                {
                    RAADJ_LOW = SetParam->u16raadj;
                }
                else if (u32TotalDataAvg < AD_MEAN_MIN) // AD偏小，调小RASEL增大AD
                {
                    RAADJ_High = SetParam->u16raadj;
                }

                SetParam->u16raadj = (RAADJ_High + RAADJ_LOW) / 2;
                ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_RA_ADJ, SetParam->u16raadj);
                u16StepNum++;
                u8LoopStateFlag = 0; // 闭环中
            }
        }
    }
    DEBUG_INFO("total_data_avg = <%d> RAADJ DATA = <%d>\n\r", u32TotalDataAvg,SetParam->u16raadj);
    *StateFlag =  u8LoopStateFlag;
}

static void SensorGSKLoop(SENSOR_PARAM_S *SetParam,u8 *StateFlag)
{
    u32 u32TotalDataAvg = 0;
    u8  u8LoopStateFlag = 0;
    u16 AD_MEAN_MAX = 4200;
    u16 AD_MEAN_MIN = 3200;
    AD_MEAN_MAX =  SetParam->u16gsk_thres_high ;
    AD_MEAN_MIN =   SetParam->u16gsk_thres_low ;

    if ((AD_MEAN_MIN >= AD_MEAN_MAX)||
        (AD_MEAN_MAX > 16383)       ||
        (AD_MEAN_MAX < 0)           ||
        (AD_MEAN_MIN > 16383)       ||
        (AD_MEAN_MIN < 0)               )
    {
        u8LoopStateFlag = 2;
        DEBUG_INFO("SensorGSKLoop Fail !\r\n");
        DEBUG_INFO("AD_MEAN_MIN %d and AD_MEAN_MAX<%d> error !!\n\r");
    }
    else 
    {
        u32TotalDataAvg = GetADMeanValue();
        if ((u32TotalDataAvg >= AD_MEAN_MIN) && (u32TotalDataAvg <= AD_MEAN_MAX)) // Rasel调整成功标志
        {
            u8LoopStateFlag = 1; // 闭环成功
            u16StepNum = 0;
            GSK_High = 47;
            GSK_LOW = 24;
            DEBUG_INFO("SensorRAADJLoop Success \n\r");
            DEBUG_INFO("AD_MEAN_MAX --> %d AD_MEAN_MIN --> %d \n\r", AD_MEAN_MAX,AD_MEAN_MIN);

        }
        else
        {
            if (u16StepNum == 10)
            {
                u8LoopStateFlag = 2; // 闭环失败
                u16StepNum = 0;
                GSK_High = 47;
                GSK_LOW = 24;

                DEBUG_INFO("SensorGSKLoop Fail !\r\n");
                DEBUG_INFO("u16StepNum = <%d>\r\n", u16StepNum);
                DEBUG_INFO("AD_MEAN_MAX --> %d AD_MEAN_MIN --> %d \n\r", AD_MEAN_MAX,AD_MEAN_MIN);
            }
            else
            {
                if (u32TotalDataAvg > AD_MEAN_MAX) 
                {
                    GSK_High = SetParam->u16gsk;
                }
                else if (u32TotalDataAvg < AD_MEAN_MIN) 
                {
                    GSK_LOW = SetParam->u16gsk;
                }

                SetParam->u16gsk = (GSK_High + GSK_LOW) / 2;
                ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_GSK, SetParam->u16gsk);
                u16StepNum++;
                u8LoopStateFlag = 0; // 闭环中
            }
        }
    }
    DEBUG_INFO("total_data_avg = <%d> GSK DATA = <%d>\n\r", u32TotalDataAvg,SetParam->u16gsk);
    *StateFlag =  u8LoopStateFlag;
}


// //**************************************************************************
// ////// //LoopSet /* 使能探测器的闭环,u16FieldCnt为每次闭环间隔时间  
// //////0:进行中;1:成功完成;2:失败完成;3:null*/  
// //**************************************************************************
s32 ZG_MDK_SENSOR_LoopSet(LOOP_TYPE_E u8LoopType, u8 u8LoopEn, u8 *u8LoopState)
{
    s32 s32Ret = NI_SUCCESS;
    u8 state_flag = 3;

    if(u8LoopEn)
    {
        switch (u8LoopType)
        {
            case LOOP_TYPE_RASEL://RASEL闭环
                 SensorRAADJLoop(&stSensorParam,&state_flag);
                // RaselLoop(u8LoopEn,u16FieldCnt,&state_flag);
            break;
            case LOOP_TYPE_HSSD://HSSD闭环
                // HssdLoop(u8LoopEn,u16FieldCnt,&state_flag);
            break;
            case LOOP_TYPE_GSKNUM://GSK_TEST_NUM闭环
                SensorGSKLoop(&stSensorParam,&state_flag);
            break;
            case LOOP_TYPE_NUCLOOP://NUC_LOOP闭环
                NucLoop(&state_flag);
                // NucLoop(u8LoopEn,u16FieldCnt,&state_flag);
            break;
            default:break;
        }
    }
    *u8LoopState = state_flag;/*0:进行中;1:成功完成;2:失败完成;3:null*/
    return NI_SUCCESS;
}


/**
 * @brief Gain的配置
 * @param u8 u8Gain 设置的Gain值
 */
static void SensorGainSet(u8 u8Gain)
{
    u8 u8rd_data = 0;

    if (u8Gain > 7)
    {
        u8Gain = 7;
    }

    SensorSetReg( 0x7c, 0xa8); // to page0
    SensorGetReg( 0x28, &u8rd_data);

    u8rd_data = u8rd_data & 0xf8;
    u8rd_data = u8rd_data | u8Gain;

    SensorSetReg( 0x28, u8rd_data);
    SensorSetReg( 0x7c, 0xa8); // to page0

    // NI_WARN("Gain_Set ok !\n");
}

/**
 * @brief INT配置
 * @param u16 u16Int 设置的Int值
 */
static void SensorIntSet(u16 u16Int)
{
    u8 u8GctiaL = 0;
    u8 u8GctiaH = 0;

    if (u16Int > 184) // 设置最小为4us
    {
        u16Int = 184;
    }
    else if (u16Int < 16) // 设置不超过50 - 4 = 46us
    {
        u16Int = 16;
    }

    u8GctiaL = u16Int & 0x00FF;
    u8GctiaH = (u16Int & 0x0F00) >> 8;

    SensorSetReg( 0x7c, 0xa8);
    SensorSetReg( 0x2d, u8GctiaL);
    SensorSetReg( 0x2e, u8GctiaH);
    SensorSetReg( 0x7c, 0xa8);

    // NI_WARN("Int_Set ok !\n");
}

/**
 * @brief Hssd配置
 * @param u8 u8Hssd 设置的Hssd值
 */
static void SensorHssdSet(u16 u16Hssd)
{
    if (u16Hssd > 127)
    {
        u16Hssd = 127;
    }
    else if (u16Hssd < 0)
    {
        u16Hssd = 0;
    }

    SensorSetReg(0x7C, 0xA8); // page3
    SensorSetReg(0x3C, u16Hssd);
    SensorSetReg(0x7C, 0xA8); // page0

    // NI_WARN("Hssd_Set ok !\n");
}

/**
 * @brief GSK_REF配置
 * @param u8 u8Gsk_Ref 设置的Gsk_Ref值
 */
static void SensorGskRefSet(u8 u8Gsk_Ref)
{
    u8 u8RdData = 0;

    u8Gsk_Ref = u8Gsk_Ref & 0x3f;

    SensorSetReg(0x7c, 0xab); // to page3

    SensorGetReg( 0x2c, &u8RdData);
    u8RdData = u8RdData & 0xc0;
    u8RdData = u8RdData | u8Gsk_Ref;

    SensorSetReg(0x2c, u8RdData);
    SensorSetReg(0x7c, 0xa8); // to page0

    // NI_WARN("Gsk_Ref_Set ok !\n");
}

/**
 * @brief GSK配置
 * @param u8 u8Gsk 设置的Gsk值
 */
static void SensorGskSet(u8 u8Gsk)
{
    u8 u8RdData = 0;

    u8Gsk = u8Gsk & 0x3f;
    SensorSetReg(0x7c, 0xa8); // to page0
    
    SensorGetReg( 0x3b, &u8RdData);
    u8RdData = u8RdData & 0xc0;
    u8RdData = u8RdData | u8Gsk;
    SensorSetReg(0x3b, u8RdData);
    SensorSetReg(0x7c, 0xa8); // to page0

    // NI_WARN("Gsk_Set ok !\n");
}

/**
 * @brief RA配置
 * @param u8 u8Ra 设置的RA值
 */
static void SensorRaSet(u8 u8Ra)
{
    u8 rd_data = 0, wr_data = 0;
    u32 u32ra = 0;

    if (u8Ra > 20)
    {
        u8Ra = 20;
    }
    else if (u8Ra < 0)
    {
        u8Ra = 0;
    }

    u32ra = (1 << u8Ra) - 1;

    SensorSetReg(0x7C, 0xAB); // page3

    wr_data = (u32ra & 0xff);
    SensorSetReg(0x21, wr_data);

    wr_data = (u32ra >> 8) & 0xff;
    SensorSetReg(0x20, wr_data);

    wr_data = (u32ra >> 16) & 0xff;
    SensorSetReg(0x1e, wr_data);

    SensorSetReg(0x7C, 0xA8); // to page0

    // NI_WARN("Ra_Set ok !\n");
}

/**
 * @brief POLL配置
 * @param u16 u16Poll 设置的Poll值
 */
static void SensorPollSet(u16 u16Poll)
{
    u8 u8RdData = 0, u8Wrdata = 0;

    SensorSetReg(0x7C, 0xAB);
    SensorGetReg( 0x14, &u8RdData);
    u8Wrdata = (u8RdData & 0xf0) | (u16Poll & 0x0f);
    SensorSetReg(0x14, u8Wrdata);
    SensorSetReg(0x7C, 0xA8);
}

/**
 * @brief VCM配置
 * @param u8 u8Vcm 设置的Vcm值
 */
static void SensorVcmSet(u8 u8Vcm)
{
    SensorSetReg(0x7c, 0xA8);
    SensorSetReg(0x35, u8Vcm);
    SensorSetReg(0x7C, 0xa8);
}

/**
 * @brief Rc配置
 * @param u8 u8Rc 设置的Rc值
 */
static void SensorRcSet(u8 u8Rc)
{
    u8 u8RdData = 0, u8WrData = 0;

    SensorSetReg(0x7C, 0xAB); // page3
    SensorGetReg( 0x19, &u8RdData);
    u8WrData = (u8RdData & 0xf0) | (u8Rc & 0x0f);
    SensorSetReg(0x19, u8WrData);
    SensorSetReg(0x7C, 0xA8); // page0

    // NI_WARN("Rc_Set Ok!\n");
}

/**
 * @brief Rd配置
 * @param u8 u8Rd 设置的Rd值
 */
static void SensorRdSet(u8 u8Rd)
{
    u8 u8RdData = 0, u8WrData = 0;

    SensorSetReg(0x7C, 0xAB); // page3
    SensorGetReg( 0x19, &u8RdData);
    u8WrData = (u8RdData & 0x0f) | (u8Rd << 4);
    SensorSetReg(0x19, u8WrData);

    SensorSetReg(0x12, u8Rd);
    SensorSetReg(0x7C, 0xA8); // page0

    // NI_WARN("Rd_Set Ok!\n");
}

/**
 * @brief REF_RD配置
 * @param u8 u8ref_rd 设置的ref_rd值
 */
static void SensorRefrdSet(u16 u16ref_rd)
{
    u8 u8rd_data = 0;
    u8 u8wr_data = 0;

    if (u16ref_rd >= 7)
    {
        u16ref_rd = 7;
    }

    SensorSetReg(0x7c, 0xAB); // to page3
    SensorGetReg( 0x12, &u8rd_data);
    u8wr_data = ((u8rd_data & 0xF8) | ((u8)u16ref_rd & 0x07));
    SensorSetReg(0x12, u8wr_data);
    SensorSetReg(0x7C, 0xA8); // to page0
}

/**
 * @brief GFID配置
 * @param u8 u8Gfid 设置的gfid值
 */
static void SensorGfidSet(u16 u16Gfid)
{
    // NI_WARN("1111111111111111111111111111111111111111111111111111111\n");
    SensorSetReg(0x7c, 0xA8); // to page3
    SensorSetReg(0x1f, (u8)u16Gfid & 0x0f);
}

/**
 * @brief VBUS配置
 * @param u8 u8Vbus 设置的vbus值
 */
static void SensorVbusSet(u8 u8Vbus)
{
    if (u8Vbus > 255)
    {
        u8Vbus = 255;
    }
    else if (u8Vbus < 0)
    {
        u8Vbus = 0;
    }

    SensorSetReg(0x7C, 0xAB); // page3
    SensorSetReg(0x06, u8Vbus);
    SensorSetReg(0x7C, 0xA8); // page0

    // NI_WARN("Vbus_Set ok !\n");
}

/**
 * @brief VBUS_REF配置
 * @param u8 u8VbusRef 设置的vbus_ref值
 */
static void SensorVbusRefSet(u8 u8VbusRef)
{
    if (u8VbusRef > 127)
    {
        u8VbusRef = 127;
    }
    else if (u8VbusRef < 0)
    {
        u8VbusRef = 0;
    }

    SensorSetReg(0x7C, 0xA8); // page3
    SensorSetReg(0x3C, u8VbusRef);
    SensorSetReg(0x7C, 0xA8); // page0

    // NI_WARN("Vbus_Ref_Set ok !\n");
}

/**
 * @brief Ra_adj
 * @param u16 u16Ra_adj 设置的Ra_adj值
 */
static void SensorRaadjSet(u16 u16Ra_adj)
{
    if (u16Ra_adj > 511)
    {
        u16Ra_adj = 511;
    }
    else if (u16Ra_adj < 0)
    {
        u16Ra_adj = 0;
    }

    u8 u8RdData = 0;
    u8 u8WrData = 0;
    SensorSetReg(0x7c, 0xAB);
    u8WrData = (u16Ra_adj & 0xff);
    SensorSetReg(0x01, u8WrData);
    u8WrData = u16Ra_adj >> 1 & 0x80;
    SensorGetReg( 0x02, &u8RdData);
    u8WrData = (u8RdData & 0x7f) | u8WrData;
    SensorSetReg(0x02, u8WrData);
    SensorSetReg(0x7C, 0xA8);
    // NI_WARN("ra_adj_set ok !\n");
}

/**
 * @brief Nuc上限配置
 * @param u16 u16NucHigh 设置NucHigh值
 */
static void SensorNucHighSet(u16 u16NucHigh)
{
    SensorSetReg(0x7c, 0xaa); // to page2;

    SensorSetReg(0x02, u16NucHigh & 0x00ff);      // 上限低8bit
    SensorSetReg(0x03, (u16NucHigh >> 8) & 0xff); // 上限高6bit

    SensorSetReg(0x7c, 0xa8); // to page0;
}

/**
 * @brief Nuc下限配置
 * @param u16 u16NucLow 设置NucLow值
 */
static void SensorNucLowSet(u16 u16NucLow)
{
    // NI_WARN("4444444444444444444\n");
    SensorSetReg(0x7c, 0xaa); // to page2;

    SensorSetReg(0x04, u16NucLow & 0x00ff);      // 下限低8bit
    SensorSetReg(0x05, (u16NucLow >> 8) & 0xff); // 下限高6bit

    SensorSetReg(0x7c, 0xa8); // to page0;
}

/**
 * @brief NucStep步进 配置
 * @param u16 u16NucStep 设置NucStep值
 */
static void SensorNucStepSet(u16 u16NucStep)
{
    SensorSetReg(0x7c, 0xab); // to page2;
    SensorSetReg(0x1a, u16NucStep);
    SensorSetReg(0x7c, 0xa8); // to page0;
}

/**
 * @brief 全屏NUC初始化配置
 * @param u8 u8init_data 设置的全屏NUC的值
 */
static void SensorNucInitSet(u8 u8InitData)
{
    u8 u8RdData = 0;
    SensorSetReg(0x7c, 0xaa); // to page2
    SensorGetReg( 0x06, &u8RdData);
    u8RdData = (u8RdData & 0xef) | 0x10;
    SensorSetReg(0x06, u8RdData); // 打开occ初始值使能

    hal_i2c_delay_ms(1);
    SensorGetReg( 0x06, &u8RdData);
    u8RdData = (u8RdData & 0xf0) | (u8InitData & 0x0f);
    SensorSetReg(0x06, u8RdData); // 写入全局occ值
}


// //**************************************************************************
// ////// //ParamSet /* 单独配置探测器相关参数  0:完成*/  
// //**************************************************************************
static void ZG_MDK_SENSOR_ParamSet(PARAM_TYPE_E u8ParamType, u16 u16ParamVal)
{
    switch (u8ParamType)
    {
    case PARAM_TYPE_INT:
        SensorIntSet(u16ParamVal);
        break;
    case PARAM_TYPE_GAIN:
        SensorGainSet(u16ParamVal);
        break;
    case PARAM_TYPE_GSK_REF:
        SensorGskRefSet(u16ParamVal);
        break;
    case PARAM_TYPE_GSK:
        SensorGskSet(u16ParamVal);
        break;
    case PARAM_TYPE_VBUS:
        SensorVbusSet(u16ParamVal);
        break;
    case PARAM_TYPE_VBUS_REF: // vbus_ref等同于hssd
        SensorVbusRefSet(u16ParamVal);
        break;
    case PARAM_TYPE_RC:
        SensorRcSet(u16ParamVal);
        break;
    case PARAM_TYPE_RD:
        SensorRdSet(u16ParamVal);
        break;
    case PARAM_TYPE_GFID: // 暂时不用
        break;
    case PARAM_TYPE_CSIZE:
        break;
    case PARAM_TYPE_RA:
        SensorRaSet(u16ParamVal);
        break;
    case PARAM_TYPE_RASEL:
        break;
    case PARAM_TYPE_HSSD:
        break;
    case PARAM_TYPE_OCC_VALUE: // OCC_VALUE
        SensorNucInitSet(u16ParamVal);
        break;
    case PARAM_TYPE_RA_ADJ: // Ra_adj等同于RASEL
        SensorRaadjSet(u16ParamVal);
        break;
    case PARAM_TYPE_OCC_THRES_UP: // Occ上限
        SensorNucHighSet(u16ParamVal);
        break;
    case PARAM_TYPE_OCC_THRES_DOWN: // Occ下限
        SensorNucLowSet(u16ParamVal);
        break;
    case PARAM_TYPE_NUC_STEP:
        SensorNucStepSet(u16ParamVal);
        break;
    case PARAM_TYPE_GSK_THRES_HIGH: // GSK上限
        stSensorParam.u16gsk_thres_high	= u16ParamVal;
        break;
    case PARAM_TYPE_GSK_THRES_LOW: // GSK下限
        stSensorParam.u16gsk_thres_low	= u16ParamVal;
        break;

    default:
        break;
    }

}