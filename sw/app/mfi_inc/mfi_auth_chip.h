// ================================================================================
// MFi Authentication Chip Operations Header
// 芯片操作抽象接口头文件
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - mfi_iic/mfi_iic.h: I2C communication with MFi authentication chip
//   - mfi_auth_utils.h: Utility functions (delay)
//   - debug.h: Debug logging macros
//
// PURPOSE:
//   This module provides an abstraction layer for MFi authentication chip
//   operations. It handles certificate reading and challenge-response generation
//   by communicating with the Apple authentication coprocessor via I2C.
//
// ================================================================================

#ifndef MFI_AUTH_CHIP_H
#define MFI_AUTH_CHIP_H

#include <stdint.h>
#include "mfi_auth_utils.h"

#ifdef __cplusplus
extern "C" {
#endif

// 芯片操作错误码
typedef enum {
    MFI_CHIP_OK = 0,
    MFI_CHIP_ERROR_INIT,
    MFI_CHIP_ERROR_COMM,
} mfi_chip_error_t;

// 芯片状态信息
typedef struct {
    uint8_t chip_id;              // 芯片ID
    uint8_t firmware_version;     // 固件版本
    uint16_t cert_length;         // 证书长度
    uint16_t challenge_length;    // 挑战数据长度
    uint8_t challenge_ready;      // 挑战就绪标志
    uint8_t auth_status;          // 认证状态
    uint32_t operation_time_ms;   // 操作耗时
} mfi_chip_status_t;

// 芯片操作函数指针定义
typedef struct {
    // 初始化函数
    mfi_chip_error_t (*init)(void);
    
    // 状态检查
    mfi_chip_error_t (*get_status)(mfi_chip_status_t *status);
    
    // 证书操作
    mfi_chip_error_t (*read_certificate)(uint8_t *buffer, uint16_t buffer_size, uint16_t *cert_len);
    
    // 挑战响应操作
    mfi_chip_error_t (*write_challenge)(const uint8_t *data, uint16_t length);
    mfi_chip_error_t (*start_challenge_generation)(void);
    mfi_chip_error_t (*check_challenge_status)(uint8_t *ready);
    mfi_chip_error_t (*read_challenge_response)(uint8_t *buffer, uint16_t buffer_size, uint16_t *resp_len);
    
    // 通用参数操作
    mfi_chip_error_t (*write_param)(const uint8_t *param_data, uint16_t param_length);
    
    // 芯片控制
    mfi_chip_error_t (*reset)(void);
    mfi_chip_error_t (*sleep)(void);
    
    void *user_data;  // 用户数据指针
} mfi_chip_operations_t;

// ================================================================================
// 公共接口函数声明
// ================================================================================

/**
 * @brief Initialize the MFi authentication chip
 * 
 * Initializes I2C communication and prepares the authentication chip
 * for certificate reading and challenge-response operations.
 * 
 * @return MFI_CHIP_OK on success, error code otherwise
 */
mfi_chip_error_t mfi_auth_chip_init(void);

/**
 * @brief Read the device certificate from the authentication chip
 * 
 * Reads the Apple-issued device certificate stored in the authentication
 * coprocessor. This certificate is used during the authentication handshake
 * to prove the accessory's authenticity to the iOS device.
 * 
 * @param buffer Buffer to store the certificate data
 * @param buffer_size Size of the buffer (must be at least 1024 bytes)
 * @param cert_len Pointer to store the actual certificate length
 * @return MFI_CHIP_OK on success, error code otherwise
 */
mfi_chip_error_t mfi_auth_chip_read_certificate(uint8_t *buffer, uint16_t buffer_size, uint16_t *cert_len);

/**
 * @brief Generate a challenge response using the authentication chip
 * 
 * Sends the challenge data received from the iOS device to the authentication
 * chip, which performs cryptographic operations to generate a signed response.
 * This process involves:
 * 1. Writing challenge data to chip (register 0x20-0x21)
 * 2. Starting challenge generation (register 0x10)
 * 3. Polling for completion (register 0x10, bit 4)
 * 4. Reading the response (register 0x11-0x12)
 * 
 * @param challenge_data Challenge data from iOS device
 * @param challenge_len Length of challenge data
 * @param response_buffer Buffer to store the generated response
 * @param response_buffer_size Size of response buffer
 * @param response_len Pointer to store actual response length
 * @return MFI_CHIP_OK on success, error code otherwise
 */
mfi_chip_error_t mfi_auth_chip_generate_challenge_response(
    const uint8_t *challenge_data, uint16_t challenge_len,
    uint8_t *response_buffer, uint16_t response_buffer_size, uint16_t *response_len);

#ifdef __cplusplus
}
#endif

#endif // MFI_AUTH_CHIP_H