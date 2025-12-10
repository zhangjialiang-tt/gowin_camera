#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "usb_process.h"
#include "../../inc/system.h"

/*******************************************全局参数定义************************************************/
RingBuff_t ringBuff = 
{
    .Head = 0,
    .Tail = 0,
    .Lenght = 0
};

static s32 Read_RingBuff(u32 *rData);
static void TmGearSwitch(u16 u16data);
static void usbCompensate(void);
static void ExecuteUsbCmd(void);

void UsbLooping(void)
{
    usbCompensate();        
    ExecuteUsbCmd();
}




//防止USB下发补偿机制时设备在补偿   这里现在只加的切挡补偿
static void usbCompensate(void)
{
    if((stSysFlag.u8USBCompensateSteer != NO_COMPENSATE) && (stSysFlag.u8CompensateSteer == NO_COMPENSATE))
    {
        stSysFlag.u8CompensateSteer = stSysFlag.u8USBCompensateSteer;
        stSysFlag.u8USBCompensateSteer = NO_COMPENSATE;
    }
}


s32 Write_RingBuff(u32 u32data)
{
    if(ringBuff.Lenght>=RINGBUFF_LEN)
    {
        return -1;
    }
    ringBuff.Ring_data[ringBuff.Tail]=u32data;
    ringBuff.Tail = (ringBuff.Tail+1)%RINGBUFF_LEN;//防止越界非法访问
    ringBuff.Lenght++;
    return 0;
}

static s32 Read_RingBuff(u32 *rData)
{
    if(ringBuff.Lenght == 0)//判断非空
    {
        return -1;
    }
    *rData = ringBuff.Ring_data[ringBuff.Head];//先进先出FIFO，从缓冲区头出
    ringBuff.Head = (ringBuff.Head+1)%RINGBUFF_LEN;//防止越界非法访问
    ringBuff.Lenght--;
    return 0;
}

static void TmGearSwitch(u16 u16data)
{
    u8 u8Exec = 1;
    u8 u8Data = 0xff&u16data;
    u32 u32ApbWriteData     ;
    switch (u16data)
    {
    case 0x01: //low
            DEBUG_INFO("TmGearSwitch low\r\n");
        break;
    case 0x02: //
            DEBUG_INFO("TmGearSwitch high\r\n");
        break;
    default:
        DEBUG_INFO("TmGearSwitch NULL\r\n");
        u8Exec = 0;
        break;
    }
    if((u8Exec == 1) && (stSysFlag.u8CompensateSteer == NO_COMPENSATE))
    {
		//nuc+base
        stSysFlag.u8TmGearSwitch = u8Data;
		stSysFlag.u8CompensateSteer = SHUTTER_RAADJ_NUC_BASE_COMPENSATE;

    }
    else if(u8Exec == 1)
    {
        stSysFlag.u8TmGearSwitch = u8Data;
        stSysFlag.u8USBCompensateSteer = SHUTTER_RAADJ_NUC_BASE_COMPENSATE;
    }
}


static void ExecuteUsbCmd(void)
{
    u32 u32RingData;
    u32 u32ApbReadData;
    u16 u16UsbCmd,u16UsbData;
    if(0 == Read_RingBuff(&u32RingData))
    {
        u16UsbCmd = (u32RingData>>16)&0xFFFF;
        u16UsbData = u32RingData&0xFFFF;
        DEBUG_INFO("usb cmd pass Cmd -->0x%x Data -->0x%x\n\r",u16UsbCmd,u16UsbData);
        switch (u16UsbCmd)
        {
        case USB_CMD_SHUTTER_COMPENSATE:
            if(u16UsbData == 0)
            {
              st_dev_shutter.shutter(SHUTTER_CLOSE);//关闭快门
            }
            else if(u16UsbData == 1)
            {
              st_dev_shutter.shutter(SHUTTER_OPEN);//打开快门
            }
            else if(u16UsbData == 2)
            {
              st_dev_shutter.shutter(SHUTTER_STOP);//停止快门
            }
            break;
        case USB_CMD_SHUTTER_BASE_COMPENSATE:
             if(stSysFlag.u8CompensateSteer == NO_COMPENSATE)
            {  
                if(u16UsbData == 0)//无补偿
                {
                    stSysFlag.u8CompensateSteer = NO_COMPENSATE;
                }
                else if(u16UsbData == 1)//场景补偿
                {
                    stSysFlag.u8CompensateSteer = SCENE_COMPENSATE;
                }                
                else if(u16UsbData == 2)//本底补偿
                {
                    stSysFlag.u8CompensateSteer = SHUTTER_BASE_COMPENSATE;
                }
                else if(u16UsbData == 3)//NUC补偿
                {
                    stSysFlag.u8CompensateSteer = SHUTTER_NUC_BASE_COMPENSATE;
                }
                else 
                {
                    DEBUG_INFO("USB_CMD_SHUTTER_BASE_COMPENSATE NULL \n\r");
                }
            }
            break;
        case USB_CMD_UPDATE_PARAM_PACK:
            if(u16UsbData == 0)
            {
                break;
            }
            // apb_write(APB_REG_ADDR_EN_BUS0		, (0x2 | ((u16UsbData - 1) & 0x1)<<2) );
            break;
        case USB_CMD_SET_TEMP_GEAR:
            apb_read(APB_REG_ADDR_SWITCH_RANGE  , &u32ApbReadData);
            if((u32ApbReadData&0x0f) == (u16UsbData&0x0F))
            {
                DEBUG_INFO("SWITCH--> same \n\r");
            }
            else 
            {
                TmGearSwitch(u16UsbData);
            }
            break;
        default:
            DEBUG_INFO("usb cmd NULL \n\r");
            break;
        }
    }
}



































