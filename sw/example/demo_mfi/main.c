// ================================================================================
// Simple MFi Authentication Demo
// 简单的MFi认证演示程序
// ================================================================================

#include <neorv32.h>
#include "mfi_auth.h"
#include "mfi_auth_utils.h"
#include "debug.h"

// 全局状态变量
static mfi_auth_state_t g_current_state = MFI_AUTH_STATE_DETECT;
static int g_auth_completed = 0;
// 全局定时器标志位
volatile uint32_t timer0_flag = 0;
// 全局定时器计数
volatile uint32_t timer0_count = 0;

// 函数声明
void vsync_interrupt_handler(void);
void vsync_interrupt_init(void);

// 事件回调函数
static void auth_event_callback(mfi_auth_state_t state, void *user_data) {
    g_current_state = state;
    
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
            g_auth_completed = 1;
            break;
            
        case MFI_AUTH_STATE_ERROR:
            DEBUG_INFO(">>> MFi Error Occurred\n");
            break;
    }
}

// 应用程序入口点
int main(void) {
    // 1. 系统初始化
    neorv32_rte_setup();
    neorv32_uart0_setup(115200, 0);
    
    // 2. 初始化外部中断
    vsync_interrupt_init();
    
    // 等待一段时间确保中断系统初始化完成
    DEBUG_INFO("Waiting for interrupt system initialization...\n");
    // DEBUG_INFO("Interrupt system initialization completed\n");
    mfi_auth_delay_ms(5000);
    DEBUG_INFO("\n=== MFi Authentication Demo ===\n");
    
    // 3. MFi模块初始化
    mfi_auth_error_t result = mfi_auth_init();
    if (result != MFI_AUTH_OK) {
        DEBUG_INFO("MFi Auth Init Failed: %d\n", result);
        while (1) { /* 停止 */ }
    }
    
    DEBUG_INFO("MFi Auth Module Initialized\n");
    
    // 3. 注册事件回调
    mfi_auth_register_callback(auth_event_callback, NULL);
    
    
    // 5. 启动认证流程
    result = mfi_auth_start();
    if (result != MFI_AUTH_OK) {
        DEBUG_INFO("MFi Auth Start Failed: %d\n", result);
        while (1) { /* 停止 */ }
    }
    
    
    while (1) {
        mfi_auth_process();  // This must be called continuously.

        // Add a short, consistent delay in the loop to prevent aggressive polling 
        // and to align with reference implementations that have small sleeps.
        mfi_auth_delay_ms(1);
    }
    
    return 0;
}

// 场中断处理函数
void vsync_interrupt_handler(void) {
   
    // 获取pending的中断
    uint32_t pending = neorv32_gpio_irq_get();
      // 检查GPIO1的中断
    if (pending & (1 << 1)) {
        // 处理GPIO1中断事件
        // st_api.usb_rx_interrupt();
        
        // 清除GPIO1中断标志
        neorv32_gpio_irq_clr(1 << 1);
    }
    // 检查是否是GPIO0的中断（场中断）
    if (pending & (1 << 0)) {
        // 增加20ms计数
        timer0_count += 33;
        // 10mins reached
        // if (timer0_count < 6010000) {
        //     timer0_count = timer0_count+20;
        //     timer0_flag = 0;
        //     timer0_count = 0; // 重置计数器，避免溢出/无限累加
        // }
        timer0_flag = 1;
        // 处理场同步事件
        // 清除中断标志
        neorv32_gpio_irq_clr(1 << 0);
    }

   
}

void vsync_interrupt_init(void)
{
    DEBUG_INFO("Initializing GPIO interrupts...\n");
    
    // 设置GPIO0和GPIO1的中断触发方式
    neorv32_gpio_irq_setup(0, GPIO_TRIG_EDGE_RISING);  // GPIO0上升沿触发
    neorv32_gpio_irq_setup(1, GPIO_TRIG_EDGE_RISING);  // GPIO1上升沿触发
    DEBUG_INFO("GPIO interrupt triggers configured\n");
    
    // 使能GPIO0和GPIO1的中断
    neorv32_gpio_irq_enable((1 << 0) | (1 << 1));
    DEBUG_INFO("GPIO interrupts enabled\n");

    // 注册GPIO中断处理函数
    neorv32_rte_handler_install(GPIO_TRAP_CODE, vsync_interrupt_handler);
    DEBUG_INFO("GPIO interrupt handler installed\n");
    
    // 使能GPIO中断
    neorv32_cpu_csr_set(CSR_MIE, 1 << GPIO_FIRQ_ENABLE);
    DEBUG_INFO("GPIO FIRQ enabled\n");
    
    // 启用机器模式中断
    neorv32_cpu_csr_set(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);
    DEBUG_INFO("Machine mode interrupts enabled\n");
    
    DEBUG_INFO("GPIO interrupt initialization completed\n");
}