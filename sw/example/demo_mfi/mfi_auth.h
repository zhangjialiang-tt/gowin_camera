// ================================================================================
// MFi Authentication Module Header
// 基于 NEORV32 软核的 MFi 认证功能模块
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - mfi_auth_chip.h: MFi authentication chip operations
//   - mfi_auth_protocol.h: iAP2 protocol definitions
//   - mfi_auth_utils.h: Utility functions (checksum, delay)
//   - mfi_usb/mfi_usb.h: USB communication interface
//   - mfi_iic/mfi_iic.h: I2C communication interface
//   - mfi_config.h: Product configuration parameters
//   - debug.h: Debug logging macros
//
// PURPOSE:
//   This module provides the main MFi authentication state machine and public API.
//   It manages the complete authentication flow from device detection through
//   certificate exchange, challenge-response, and identification.
//
// ================================================================================

#ifndef MFI_AUTH_H
#define MFI_AUTH_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ================================================================================
// 错误码定义
// ================================================================================
typedef enum {
    MFI_AUTH_OK = 0,              // 操作成功
    MFI_AUTH_ERROR_INIT,          // 初始化失败
    MFI_AUTH_ERROR_COMM,          // 通信错误（合并USB/IIC）
    MFI_AUTH_ERROR_PROTOCOL,      // 协议错误
    MFI_AUTH_ERROR_AUTH_FAILED,   // 认证失败
} mfi_auth_error_t;

// ================================================================================
// 设备类型枚举
// ================================================================================
typedef enum {
    MFI_DEVICE_UNKNOWN = 0,       // 未知设备
    MFI_DEVICE_APPLE   = 1,       // Apple设备
    MFI_DEVICE_ANDROID = 2        // Android设备
} mfi_device_type_t;

// ================================================================================
// 状态枚举
// ================================================================================
typedef enum {
    MFI_AUTH_STATE_DETECT,        // 检测阶段
    MFI_AUTH_STATE_NEGOTIATE,     // 协商阶段
    MFI_AUTH_STATE_AUTH,          // 认证阶段
    MFI_AUTH_STATE_READY,         // 就绪阶段
    MFI_AUTH_STATE_ERROR          // 错误状态
} mfi_auth_state_t;

// ================================================================================
// 事件回调函数类型定义
// ================================================================================
typedef void (*mfi_auth_event_callback_t)(mfi_auth_state_t state, void *user_data);

// ================================================================================
// 配置结构体 (硬编码，但提供接口扩展能力)
// ================================================================================
typedef struct {
    const char *product_string;     // 产品名称
    const char *manufacturer_string; // 制造商名称
    const char *serial_number;      // 序列号
    const char *firmware_version;   // 固件版本
    const char *hardware_version;   // 硬件版本
    const char *app_bundle_id;      // 应用Bundle ID
    const char *interface_string;   // 接口字符串
    const char *team_id;           // 团队ID
} mfi_auth_config_t;

// ================================================================================
// 公共API函数声明
// ================================================================================

/**
 * @brief Initialize the MFi authentication module
 * 
 * Initializes the authentication context, USB/I2C peripherals, MFi chip,
 * and loads the certificate from the authentication chip into memory.
 * Must be called before any other MFi authentication functions.
 * 
 * @return MFI_AUTH_OK on success, error code otherwise
 */
mfi_auth_error_t mfi_auth_init(void);

/**
 * @brief Start the MFi authentication flow
 * 
 * Transitions the state machine to DETECT state and begins sending
 * detection packets to establish connection with the iOS device.
 * 
 * @return MFI_AUTH_OK on success, MFI_AUTH_ERROR_INIT if not initialized
 */
mfi_auth_error_t mfi_auth_start(void);

/**
 * @brief Process MFi authentication state machine (main loop)
 * 
 * This function should be called repeatedly in the main loop. It handles:
 * - USB connection monitoring
 * - State machine transitions (DETECT -> NEGOTIATE -> AUTH -> READY)
 * - Sending periodic packets based on current state
 * - Receiving and processing incoming packets from iOS device
 * 
 * @return MFI_AUTH_OK on success, error code otherwise
 */
mfi_auth_error_t mfi_auth_process(void);

/**
 * @brief Get the current authentication state
 * 
 * Returns the current state of the authentication state machine.
 * 
 * @return Current authentication state (DETECT, NEGOTIATE, AUTH, READY, or ERROR)
 */
mfi_auth_state_t mfi_auth_get_state(void);

/**
 * @brief Check if authentication has completed successfully
 * 
 * Returns true only when the device has reached READY state and
 * authentication has been confirmed by the iOS device.
 * 
 * @return 1 if authenticated, 0 otherwise
 */
int mfi_auth_is_authenticated(void);

/**
 * @brief Register a callback function for state change events
 *
 * The callback will be invoked whenever the authentication state changes.
 * This allows the application to respond to authentication progress.
 *
 * @param callback Function pointer to be called on state changes
 * @param user_data User-defined data pointer (currently unused)
 */
void mfi_auth_register_callback(mfi_auth_event_callback_t callback, void *user_data);

/**
 * @brief Get the current connected device type
 *
 * Returns the type of device currently connected based on the detection
 * of specific USB packet sequences.
 *
 * @return Device type (MFI_DEVICE_UNKNOWN, MFI_DEVICE_APPLE, or MFI_DEVICE_ANDROID)
 */
int mfi_auth_get_device_type(void);

#ifdef __cplusplus
}
#endif

#endif // MFI_AUTH_H