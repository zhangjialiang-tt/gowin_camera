// ================================================================================
// MFi Authentication Utility Functions Header
// 工具函数模块头文件
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - neorv32_aux.h: NEORV32 auxiliary functions for delay
//
// PURPOSE:
//   This module provides utility functions used throughout the MFi authentication
//   system, including delay functions and checksum calculation. The checksum
//   function is inlined for performance optimization as it's called frequently
//   in the packet processing hot path.
//
// ================================================================================

#ifndef MFI_AUTH_UTILS_H
#define MFI_AUTH_UTILS_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ================================================================================
// 工具函数接口
// ================================================================================

/**
 * @brief Millisecond delay function
 * 
 * Provides a blocking delay for the specified number of milliseconds.
 * Uses timer0_delay_ms internally for accurate timing.
 * 
 * @param ms Number of milliseconds to delay
 */
void mfi_auth_delay_ms(uint32_t ms);

/**
 * @brief Timer0-based millisecond delay
 * 
 * Implements millisecond delay using the timer0_count global variable.
 * This function is wrap-around safe and uses subtraction comparison
 * to handle timer overflow correctly.
 * 
 * @param ms Number of milliseconds to delay
 */
void timer0_delay_ms(uint32_t ms);

/**
 * @brief Calculate iAP2 protocol checksum
 * 
 * Computes the checksum for iAP2 packet headers and payloads.
 * The checksum algorithm is: checksum = 0x100 - sum(all_bytes)
 * 
 * This function is inlined for performance optimization as it's called
 * frequently in the packet processing hot path (every packet sent/received).
 * 
 * @param buffer Data buffer to calculate checksum for
 * @param len Length of data in buffer
 * @return Calculated checksum value (8-bit)
 */
static inline uint8_t mfi_auth_calc_checksum(uint8_t *buffer, uint32_t len) {
    if (buffer == NULL || len == 0) {
        return 0;
    }
    
    uint8_t checksum = 0;
    for (uint32_t i = 0; i < len; i++) {
        checksum += buffer[i];
    }
    return (uint8_t)(0x100 - checksum);
}

#ifdef __cplusplus
}
#endif

#endif // MFI_AUTH_UTILS_H