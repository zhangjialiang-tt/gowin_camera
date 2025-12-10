#include "inc/system.h"
#include "mfi_auth.h"
#include "mfi_auth_utils.h"

// #define                 ZC23A

static u32 u32writedata = 0;

// MFi 认证相关变量
static mfi_auth_state_t g_mfi_current_state = MFI_AUTH_STATE_DETECT;
static int g_mfi_auth_completed = 0;

// MFi 事件回调函数
static void mfi_auth_event_callback(mfi_auth_state_t state, void *user_data) {
    g_mfi_current_state = state;

    DEBUG_INFO("MFi Auth State: %d\n", state);

    switch (state) {
        case MFI_AUTH_STATE_DETECT:
            DEBUG_INFO(">>> MFi Detection Phase\n");
            break;

        case MFI_AUTH_STATE_NEGOTIATE:
            DEBUG_INFO(">>> MFi Negotiation Phase\n");
            break;

        case MFI_AUTH_STATE_AUTH:
            DEBUG_INFO(">>> MFi Authentication Phase\n");
            break;

        case MFI_AUTH_STATE_READY:
            DEBUG_INFO(">>> MFi Ready - Authentication Successful!\n");
            g_mfi_auth_completed = 1;
            break;

        case MFI_AUTH_STATE_ERROR:
            DEBUG_INFO(">>> MFi Error Occurred\n");
            break;
    }
}

// 场中断初始化函数
void vsync_interrupt_init(void)
{
    hal_interrupt_init();
    // 设置GPIO0和GPIO1的中断触发方式
    // 设置GPIO0的中断触发方式
    neorv32_gpio_irq_setup(0, GPIO_TRIG_EDGE_RISING);  // GPIO0上升沿触发
    // 设置GPIO1的中断触发方式
    neorv32_gpio_irq_setup(1, GPIO_TRIG_EDGE_RISING);  // GPIO1上升沿触发
    // 使能GPIO0和GPIO1的中断
    neorv32_gpio_irq_enable((1 << 0) | (1 << 1));

    // 注册GPIO中断处理函数
    hal_interrupt_register_handler(HAL_INTERRUPT_GPIO, vsync_interrupt_handler);
    // 使能GPIO中断
    hal_interrupt_enable(HAL_INTERRUPT_GPIO);
    // 使能全局中断
    hal_interrupt_enable_global();
}
int main(void)
{
    unsigned char system_state = 0;  //0:initial  1:pooling

	DEBUG_INFO("========neorv32 start!========\n\r");
	u32 u32readdata = 0;

	vsync_interrupt_init();	//vsync中断初始化

	// setup UART at default baud rate, no interrupts
	neorv32_uart0_setup(115200, 0);	// say hello

	// MFi 认证模块初始化
	DEBUG_INFO("=== MFi Authentication Module Initialization ===\n");
	mfi_auth_error_t mfi_result = mfi_auth_init();
	if (mfi_result != MFI_AUTH_OK) {
		DEBUG_INFO("MFi Auth Init Failed: %d\n", mfi_result);
		// neorv32_uart0_printf("MFi Auth Init Failed: %d\n", mfi_result);
		while (1) { /* 停止 */ }
	}
	DEBUG_INFO("MFi Auth Module Initialized\n");
	// neorv32_uart0_printf("MFi Auth Module Initialized\n");

	// 注册 MFi 事件回调
	mfi_auth_register_callback(mfi_auth_event_callback, NULL);

	// 启动 MFi 认证流程
	mfi_result = mfi_auth_start();
	if (mfi_result != MFI_AUTH_OK) {
		DEBUG_INFO("MFi Auth Start Failed: %d\n", mfi_result);
		// neorv32_uart0_printf("MFi Auth Start Failed: %d\n", mfi_result);
		while (1) { /* 停止 */ }
	}
	DEBUG_INFO("MFi Auth Process Started\n");
	// neorv32_uart0_printf("MFi Auth Process Started\n");
  	#if 0
	neorv32_uart0_puts("----------Hello world!-----------\n");
	while (1)
	{
		apb_write(APB_REG_ADDR_SENSOR_PARA0, u32writedata);
		hal_i2c_delay_ms(1);
		apb_read(APB_REG_ADDR_SENSOR_PARA0, &u32readdata);
		DEBUG_INFO("u32writedata = %d, u32readdata = %d\n\r", u32writedata, u32readdata);
		u32writedata++;
		hal_i2c_delay_ms(40);
  		DEBUG_INFO("----------+++++++++++++++-----------\n");
	}
	#endif
	#if 1
	IrqGpio15Init();
	// delay_ms(7000);
	if(0x01 == ParameLoad())
	{
		NucKSel(0x00,0x000000ff);	//加载初K
		DEBUG_INFO("Load Param Fail!\n\r");
	}
	else 
	{	//logic load k data		 
		FlashAndDdrDataTRFCtrl(LOW_TEMP_K_ADDRS,DSRAM_KL_ADDRS0,0x0003c000,0x00);	//调试暂时加载一帧
	}
    /********************************************* 上电时序控制 ******************************************/
	SensorIRTVPowerApbCtrlAll();	//TV IR sensor 上电
	SensorInit();
	if(0x01 == InitkState())
	{
		FlashAndDdrDataTRFCtrl(LOW_TEMP_K_ADDRS,DSRAM_KH_ADDRS0,0x0003c000,0x00);
	}
	// FlashAndDdrDataTRFCtrl(0x00100000,DSRAM_KH_ADDRS0,0x0003c000,0x00);
	gc2145_dvp_yuv_800X600_logic_inst();
	ProgramVersion(0x0d);	//下发版本号和设备编号
	//用户功能监控
	while(1)
	{
		if(timer0_flag == 0x01)	//25帧-->40ms
		{
			st_api.interrupt();
			timer0_flag = 0x00;
		}
		UsbLooping();

		// 处理 MFi 认证（必须在循环中持续调用）
		mfi_auth_process();

#ifndef ZC23A // 如果定义了DEBUG宏，则编译下面的代码
		gc2145_dvp_yuv_800X600_init(0x927c0,&stSysFlag.u8StartBootFlag);	//20ms (30M/(1000ms/20ms) = 600000 = 0x927c0)
#else
		stSysFlag.u8StartBootFlag = 0x01;
#endif
	}
	#endif

    return 0; 
}