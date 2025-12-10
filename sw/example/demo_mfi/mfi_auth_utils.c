// ================================================================================
// MFi Authentication Utility Functions Implementation
// 工具函数模块实现文件
// ================================================================================

// #include <neorv32.h>
#include "mfi_auth_utils.h"
#include <neorv32_aux.h>
#include <string.h>

// ================================================================================
// 延时函数
// ================================================================================

void mfi_auth_delay_ms(uint32_t ms) {
    // 假设系统时钟为60MHz，可根据实际情况调整
    // neorv32_aux_delay_ms(NEORV32_SYSINFO->CLK, ms);
    timer0_delay_ms(ms);
}

// 全局定时器计数变量声明
extern volatile uint32_t timer0_count;

void timer0_delay_ms(uint32_t ms) {
    if (ms == 0) return;
    
    volatile uint32_t *tcount = &timer0_count;  // 确保volatile
    uint32_t start_count = *tcount;
    uint32_t target_delta = ms;  // 每ms +1，直接用ms
    
    // 方式1: 减法比较（wrap around安全）
    while ((*tcount - start_count) < target_delta) {
        // 短延时防CPU 100%占用（可选，~1us）
        // asm volatile("nop; nop;");  // 或 delay_us(1);
    }
    
    // 方式2: 目标值比较（更直观，但wrap需小心）
    // uint32_t target = start_count + ms;
    // while (*tcount < target || (*tcount - start_count) >= ms) { /* wrap处理 */ }
}


// ================================================================================
// 校验和计算
// ================================================================================

// mfi_auth_calc_checksum() 已移至头文件作为内联函数以优化性能