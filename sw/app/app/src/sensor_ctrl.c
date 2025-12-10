
#include "../../inc/system.h"


static u16 u16ShutterTimeCnt = 0;
static u8  u8calc_cnt = 0;
static u8 u8Shuttercnt = 0;
static u8 u8CompStep = 0;
static u8 u8Fcnt = 0;


static void CalcB(u32 u32addrs,u8 u8fnum,u8 *u8CalcbState);
static  u8 ShutterClose(u8 u8FreezeSel);
static  u8 ShutterOpen(u8 u8FreezeSel);
static void ImageFreeze(u8 u8freeze,u8 u8sel);
static void TmGearSwitchInit(u8 u8Switch );
//u8freeze 1:冻结 0:释放 u8sel 1:红外 0：可见光
static void ImageFreeze(u8 u8freeze,u8 u8sel)
{
    u32 u32Apbdata;
    if((u8sel > 0x01) || (u8freeze > 0x01))
    {
        DEBUG_INFO("ImageFreeze input error!\n\r");
    }
    else if(u8sel == 0x00)  //可见光冻结
    {
        apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata); 
        if(u8freeze == 0x00)    
        {
           apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata&0xffefffff)); 
        }
        else 
        {
            apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x00100000));
        }
    }
    else    //红外冻结
    {
        apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata); 
        if(u8freeze == 0x00)    
        {
           apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata&0xffdfffff)); 
        }
        else 
        {
            apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x00200000));
        }
    }
}
//上电时序
//可见光 红外同时上电
void SensorIRTVPowerApbCtrlAll(void)
{
    u32 u32Apbdata;
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata&0x003fffff));//初始化等待
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 20);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x44000000));//上电 ir-->avdd tv-->pwr_en 
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 20);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x82000000));//上电 ir-->vdet tv-->xclk 
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 20);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x21800000));//ir-->addr/sleep tv-->pwdn
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 20);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x10400000));//上电ir -->mc tv -->rst
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 10);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32Apbdata);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32Apbdata|0x08000000));//上电ir -->rst
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 10);
    //II2C初始化
    // hal_iic_init();
    app_sensor_status_t sensor_result = app_sensor_init();
    if (sensor_result != APP_SENSOR_OK)
    {
        DEBUG_INFO("iic init failed: %d\r\n", sensor_result);
    }
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 10);
}


void SensorInit(void)
{
	u8 u8gskflag = 0;
	ZG_MDK_SENSOR_InitConfig0();
    ZG_MDK_SENSOR_InitConfig1();  
    TmGearSwitchInit(0x01);
    stSysFlag.u8CompensateSteer = SHUTTER_RAADJ_NUC_BASE_COMPENSATE; //执行所有的闭环操作
	DEBUG_INFO("sensor init pass\n\r");
}

u32 GetADMeanValue(void)
{
	u32 DataMeanValue ;
	apb_read(APB_REG_ADDR_AD_VALUE_AVERAGE_TOTAL , &DataMeanValue);
    return DataMeanValue;
}


static void CalcB(u32 u32addrs,u8 u8fnum,u8 *u8CalcbState)
{
	u8 fnum ;
	switch (u8fnum) //多等待一帧
	{
	case 0X01: fnum = 4+1;break;
	case 0X02: fnum = 8+1;break;
	case 0X04: fnum = 16+1;break;
	case 0X08: fnum = 32+1;break;
	
	default: DEBUG_INFO("CALC b ERROR\n\r");
			 *u8CalcbState = 2;
		break;
	}
    if(*u8CalcbState != 2)
    {
            if(u8calc_cnt == 0)
        {
            DEBUG_INFO("CALC b START\n\r");
	        apb_write(APB_REG_ADDR_B_ADDRESS	,	u32addrs);
	        apb_write(APB_REG_ADDR_CALC_B_NUM	,	u8fnum);
	        apb_write(APB_REG_ADDR_B_CAL		,	1);
	        neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 10);
            apb_write(APB_REG_ADDR_B_CAL		,	0);
        }

        if(u8calc_cnt >= fnum)
        {
            u8calc_cnt = 0;
            *u8CalcbState = 1;
            // DEBUG_INFO("CALC b PASS\n\r");
        }
        else 
        {
            u8calc_cnt++;
            *u8CalcbState = 0;
        }
    }
}

static u8 ShutterClose(u8 u8FreezeSel)
{
    u8 cnt_wait = 2;
    u8 u8StateFlag = 0;
    if(u8FreezeSel == 0x1)
    {
        cnt_wait = 3;
    }
    if((u8FreezeSel == 0x1) &&  (u8Shuttercnt == 0x00))
    {
        ImageFreeze(0x01,0x01);
        neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 25);
        DEBUG_INFO("APB_REG_ADDR_FREEZE -->'1' \n\r");
    }
    else if((u8FreezeSel == 0x1) &&  (u8Shuttercnt == 0x01))
    {
        st_dev_shutter.shutter(SHUTTER_CLOSE);
        DEBUG_INFO("SHUTTER_CLOSE \n\r");
    }
    else if(u8Shuttercnt == 0x00)
    {
        st_dev_shutter.shutter(SHUTTER_CLOSE);
        DEBUG_INFO("SHUTTER_CLOSE \n\r");
    }

    if(u8Shuttercnt >= cnt_wait )
    {
        u8Shuttercnt = 0;
        u8StateFlag = 1;
    }
    else 
    {
        u8Shuttercnt++;
    }
    return u8StateFlag;
}

static u8 ShutterOpen(u8 u8FreezeSel)
{
    u8 u8StateFlag = 0;
    if(u8Shuttercnt == 0x00)
    {
        st_dev_shutter.shutter(SHUTTER_OPEN);
        DEBUG_INFO("SHUTTER_OPEN \n\r");
    }

    if(u8FreezeSel != 0x00)
    {
        u8Shuttercnt = 0;
        u8StateFlag = 1;
    }
    else if(u8Shuttercnt >= 2)
    {
        u8Shuttercnt = 0;
        ImageFreeze(0x00,0x01);
        neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 25);
        DEBUG_INFO("APB_REG_ADDR_FREEZE -->'0' \n\r");
        u8StateFlag = 1;
    }
    else 
    {
        u8Shuttercnt++;
    }
    return u8StateFlag;
}

void ShutterTmod(u16 u16TimeSel)
{
    if(u16TimeSel == 0)
    {
        DEBUG_INFO("u16TimeSel -->'0' error\n\r");
        return;
    }
    if(stSysFlag.u8CompensateSteer != NO_COMPENSATE)            //快门补偿执行时 定时补偿定时计数清零
    {
        u16ShutterTimeCnt = 1;
    }
    else if((u16ShutterTimeCnt == 0) && (stSysFlag.u8CompensateSteer == NO_COMPENSATE))  //快门本底补偿
    {
        DEBUG_INFO("time shuterr Compensate --> %d\n\r",u16TimeSel);
        stSysFlag.u8CompensateSteer = SHUTTER_BASE_COMPENSATE;
    }

    if(u16ShutterTimeCnt >= (u16TimeSel-1))
    {
        u16ShutterTimeCnt = 0;
    }
    else 
    {
        u16ShutterTimeCnt++;
    }
}

//闭环控制补偿

void CompensateExec(SYSTEM_FLAG_PARAM_S *SYSFlagParam)
{
    u8 u8FlagState = 0;
    if(SYSFlagParam->u8RaadjCompensate == 0x01)                     //Raadj 补偿
    {
        if(u8Fcnt == 0x01)    //两帧执行一次
        {
            ZG_MDK_SENSOR_LoopSet(LOOP_TYPE_GSKNUM, 1, &u8FlagState);
        }

        if(u8Fcnt == 0x01)
        {
            u8Fcnt = 0x00;
        }
        else 
        {
            u8Fcnt++;
        }
    }
    else if(SYSFlagParam->u8NUCCompensate == 0x01)                  //NUC 补偿
    {
        ZG_MDK_SENSOR_LoopSet(LOOP_TYPE_NUCLOOP, 1, &u8FlagState);
    }
    else if(SYSFlagParam->u8BCompensate == 0x01)                       //B 补偿
    {
        CalcB(DSRAM_B_ADDRS,0x02,&u8FlagState);
    }
    SYSFlagParam->u8CompensateState = u8FlagState;
}



void ImageComp(SYSTEM_FLAG_PARAM_S *SYSFlagParam)
{
    u32 u32RdApbData;
    if(SYSFlagParam->u8CompensateSteer != NO_COMPENSATE)    //检测是否需要补偿
    {
        switch(u8CompStep)
        {
            case 0: 
                if(SYSFlagParam->u8CompensateSteer == SCENE_COMPENSATE) //区分场景补偿 场景补偿不需要关闭快门
                {
                    u8CompStep = 0x05;
                }
                else 
                {
                    if(0x01 == ShutterClose(0x1))  //闭合快门并冻结
                    {
                        u8CompStep = 0x01;
                    }
                }
                break;

            case 1: //快门闭合
                    if(SYSFlagParam->u8CompensateSteer == SHUTTER_BASE_COMPENSATE)  //快门本底
                    {
                        DEBUG_INFO("SYSFlagParam->u8CompensateSteer --> B \n\r");
                        u8CompStep = 0x05;
                    }
                    else if(SYSFlagParam->u8CompensateSteer == SHUTTER_NUC_BASE_COMPENSATE) //NUC
                    {
                        DEBUG_INFO("SYSFlagParam->u8CompensateSteer --> NUC \n\r");
                        u8CompStep = 0x04;
                    }
                    else if(SYSFlagParam->u8CompensateSteer == SHUTTER_RAADJ_NUC_BASE_COMPENSATE)   //AD均值
                    { 
                        DEBUG_INFO("SYSFlagParam->u8CompensateSteer --> RAADJ \n\r");
                        u8CompStep = 0x02;
                    }
                    else 
                    {   //防止程序卡死
                        SYSFlagParam->u8CompensateSteer == NO_COMPENSATE;
                        u8CompStep = 0x00;
                        DEBUG_INFO("Compensate error cmd NUll \n\r");
                    }
                break;

            case 2: //高低温当位参数设置 只有在切换挡位和第一次补偿执行该闭环
                    SensorParamUpdate(&stSensorParam,SYSFlagParam->u8TmGearSwitch);
                    SensorParamSet(&stSensorParam);
                    u8CompStep = 0x03;
                break;
            case 3: //Raadj补偿  
                if(SYSFlagParam->u8CompensateState != 0x00)
                {
                    SYSFlagParam->u8RaadjCompensate = 0x00;
                    SYSFlagParam->u8CompensateState = 0x00;
                    DEBUG_INFO("go to NUC \n\r");
                    u8CompStep = 0x04;
                }
                else
                {
                    SYSFlagParam->u8RaadjCompensate =0x01;
                }
                break;
           case 4:  //NUC 补偿
                if(SYSFlagParam->u8CompensateState != 0x00)
                {
                    SYSFlagParam->u8NUCCompensate = 0x00;  
                    SYSFlagParam->u8CompensateState = 0x00;
                    DEBUG_INFO("go to B \n\r");
                    u8CompStep = 0x05;
                }
                else 
                {
                    SYSFlagParam->u8NUCCompensate = 0x01;
                }
                break;
           case 5:  //本底 补偿
                if(SYSFlagParam->u8CompensateState != 0x00)
                {
                    SYSFlagParam->u8BCompensate = 0x00;
                    SYSFlagParam->u8CompensateState = 0x00;
                    DEBUG_INFO("CALC DONE \n\r");
                    if(SYSFlagParam->u8CompensateSteer == SCENE_COMPENSATE)
                    {
                    u8CompStep = 0x00;
                    }
                    else
                    {
                    u8CompStep = 0x06;
                    }
                }
                else 
                {
                    SYSFlagParam->u8BCompensate = 0x01;
                }
                break;
           case 6:  //打开快门 释放冻结
                if(0x01 == ShutterOpen(0))
                {
                    GetCompensateSensorTemp(SYSFlagParam->u8CompensateSteer);  //获取sensor焦平面温度 用于计算温升
                    if(SYSFlagParam->u8CompensateSteer == SHUTTER_RAADJ_NUC_BASE_COMPENSATE)
                    {
                        if(((SYSFlagParam->u8StartBootFlag)&0x02) == 0x00)
                        {
                            DEBUG_INFO("+++++Init boot flag %x.\n\r",SYSFlagParam->u8StartBootFlag);
                            apb_write(APB_REG_ADDR_SWITCH_RANGE		,	SYSFlagParam->u8TmGearSwitch);  //先下发一次挡位
                            SYSFlagParam->u8StartBootFlag = ((SYSFlagParam->u8StartBootFlag)|0x02);
                            if(SYSFlagParam->u8StartBootFlag == 0x03)
                            {
                                apb_read(APB_REG_ADDR_SWITCH_RANGE		,	&u32RdApbData);         //初始完成标志位使用高低温挡位复用
                                u32RdApbData = u32RdApbData|0x80;
                                apb_write(APB_REG_ADDR_SWITCH_RANGE		,	u32RdApbData);
                                DEBUG_INFO("+++++Init IR Pass %x.\n\r",u32RdApbData);
                            }
                            DEBUG_INFO("Init Compensate Pass\n\r");
                        }
                        else
                        {
                            apb_read(APB_REG_ADDR_SWITCH_RANGE		,	&u32RdApbData);
                            u32RdApbData = (u32RdApbData & 0xFFFFFFF0)|(SYSFlagParam->u8TmGearSwitch);
                            apb_write(APB_REG_ADDR_SWITCH_RANGE		,	u32RdApbData);
                        }
                    }
                    SYSFlagParam->u8CompensateSteer = NO_COMPENSATE;
                    u8CompStep = 0x00;
                }
                break;

            default:
                u8CompStep = 0x00;
            break;
        }
    }
}

//初始化高低温挡位
static void TmGearSwitchInit(u8 u8Switch )
{
    u32 u32ApbData;
    u32ApbData = u8Switch;
    stSysFlag.u8TmGearSwitch = u8Switch;
}


void NucKSel(u8 u8Sel,u32 u32kAddrs)
{
    u32 u32ApbData;
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    if(u8Sel == 0x00) //使用初K
    {
        if(u32kAddrs == 0x00)
        {
            apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData &0xFFFBFFFF)); 
            DEBUG_INFO("Sel close init k.\n\r");
        }
        else 
        {
            apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData |0x00040000)); 
            DEBUG_INFO("Sel open init k.\n\r");
        }
    }
    else if(u8Sel == 0x01)  //使用计算的K
    {
        apb_write(APB_REG_ADDR_K_ADDRESS, u32kAddrs); //关闭初K
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData &0xfffbffff)); //关闭初K
        DEBUG_INFO("Sel k addrs --> %x.\n\r",u32kAddrs);
    }
    else 
    {
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData |0x00040000)); 
        DEBUG_INFO("NucKSel u8Sel input error! Sel init k.\n\r");
    }
}



u8 InitkState(void)
{
    u32 u32ApbData;
    u8  u8StateFlag = 1;
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    if((u32ApbData&0x00040000) == 0x00040000)
    {
        u8StateFlag = 0;
    }



    return u8StateFlag;
}


