/*
 ******************************************************************************************
 * @file      GOWIN_M1_it.c
 * @author    GowinSemicoductor
 * @device    Gowin_EMPU_M1
 * @brief     Main Interrupt Service Routines.
 *            This file provides template for all exceptions handler and
 *            peripherals interrupt service routine.
 ******************************************************************************************
 */
#include "../../inc/system.h"

#define FRAME_RATE 30
#define BYTES_NUM 1055
#define TIME_5MINS 5*60*FRAME_RATE	//5分钟
#define TIME_1MINS 1*60*FRAME_RATE	//1分钟
#define TIME_2SEC 20*FRAME_RATE		//20s 600*33ms = 660ms
// uint8_t tx_buffer[BYTES_NUM] = {0};	//Write data
// uint8_t rx_buffer[BYTES_NUM] = {0};	//Read data
static s32 s32writedata = 0;
static u16 timer3mins = 0;
/* Private functions ---------------------------------------------------------*/
static u8 GetIrqSel(void); 
static void Irq15Open(u32 u32Data) ;
static void interrupt(void);
static void IrTime0Looping(void);
static void GPIO0_1_Handler(void);
ST_API_T st_api =
{
    .interrupt  = interrupt,
    .usb_rx_interrupt = GPIO0_1_Handler
};
static void IrTime0Looping(void)
{
	GteApbTemp(FRAME_RATE);	//定时获取温度 25*40ms == 1s
	if(timer3mins <=TIME_5MINS)
	{
		if(timer3mins == TIME_5MINS)
		{
			DEBUG_INFO("time shuterr Compensate --> %d end ,go to %d\r\n",TIME_2SEC,TIME_1MINS);
		}
		ShutterTmod(TIME_2SEC);	//定时打快门 本底补偿 25*60*40==1min
		timer3mins++;
	}
	else 
	{
		ShutterTmod(TIME_1MINS);	//定时打快门 本底补偿 25*60*40==1min
	}
	ImageComp(&stSysFlag); 
	CompensateExec(&stSysFlag); //补偿执行  
}
static void interrupt(void)
{
	// s32 s32readdata = 0;
	IrTime0Looping();
	// apb_write(APB_REG_ADDR_RD_BUS0,s32writedata);
	// apb_read(APB_REG_ADDR_RD_BUS0,&s32readdata);
	// DEBUG_INFO("s32writedata = %d,s32readdata = %d\n\r",s32writedata,s32readdata);
	// s32writedata++;
}

/******************************************************************************/
/*            Cortex-M1 Processor Exceptions Handlers                         */
/******************************************************************************/
void IrqGpio15Init(void)
{
  u32 u32ApbIrqCmd;
  u32ApbIrqCmd = 0x80000000;
  apb_write(APB_REG_IRQ_SEL  , u32ApbIrqCmd);
  u32ApbIrqCmd = 0x00000000;
  apb_write(APB_REG_IRQ_SEL  , u32ApbIrqCmd); 
  Irq15Open(0x01);
  DEBUG_INFO("IrqGpio15Init\n\r");
}

static void Irq15Open(u32 u32Data) 
{
  u32 u32ApbIrqCmd;
  u32ApbIrqCmd = (u32Data&0x03)<<9;
  apb_write(APB_REG_IRQ_SEL  , u32ApbIrqCmd); 
}

static u8 GetIrqSel(void) 
{
  u32 u32ApbIrqCmd;
  u32 u32ApbReadData;
  apb_read(APB_REG_IRQ_SEL  , &u32ApbIrqCmd);
  apb_write(APB_REG_IRQ_SEL  , 0x003);
  switch (u32ApbIrqCmd)
  {
  case 1: 
        apb_read(APB_REG_ADDR_USB_ORDER   , &u32ApbReadData);
        Write_RingBuff(u32ApbReadData);
        apb_write(APB_REG_IRQ_SEL  , 0x101);
    break;
  case 2:
        apb_write(APB_REG_IRQ_SEL  , 0x102);
    break;
  case 4:
        apb_write(APB_REG_IRQ_SEL  , 0x104);
    break;
  case 8:
        apb_write(APB_REG_IRQ_SEL  , 0x108);
    break;
  case 16:
        apb_write(APB_REG_IRQ_SEL  , 0x110);
    break;
  case 32:
        apb_write(APB_REG_IRQ_SEL  , 0x120);
    break;
  case 64:
        apb_write(APB_REG_IRQ_SEL  , 0x140);
    break;
  case 128:
        apb_write(APB_REG_IRQ_SEL  , 0x180);
    break;
  
  default:
        apb_write(APB_REG_IRQ_SEL  , 0x100);
        DEBUG_INFO("IRQ SEL ERROR!!\n\r");
    break;
  }
  return 0;
}

/**
  * @brief  This function handles GPIO0_1 interrupt request.
  * @param  none
  * @retval none
  */
static void GPIO0_1_Handler(void)
{
  GetIrqSel(); 
	DEBUG_INFO("usb rx interrupt\n\r");
	// GPIO_IntClear(GPIO0, GPIO_Pin_15);
}