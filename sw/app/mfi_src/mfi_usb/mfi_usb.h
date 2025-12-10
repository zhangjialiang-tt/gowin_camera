// ================================================================================ //
// MFI USB-Wishbone Bridge 接口头文件
// 基于 NEORV32 软核的 MFI 认证芯片 USB 接口
// ================================================================================ //
//
// MODULE DEPENDENCIES:
//   - neorv32.h: NEORV32 CPU load/store functions for Wishbone access
//   - mfi_auth_utils.h: Timer delay functions
//   - debug.h: Debug logging macros
//
// PURPOSE:
//   This module provides an interface to the USB-Wishbone bridge hardware.
//   It handles USB data transmission and reception through memory-mapped
//   registers, managing TX/RX FIFOs and status flags. The USB interface
//   is used for all communication with the iOS device during authentication.
//
// ================================================================================ //

#ifndef MFI_USB_H
#define MFI_USB_H

#include <neorv32.h>

// 类型定义
#ifndef uint8_t
#define uint8_t unsigned char
#endif
#ifndef uint16_t
#define uint16_t unsigned short
#endif
#ifndef uint32_t
#define uint32_t unsigned long
#endif

// ================================================================================
// 错误码定义
// ================================================================================
typedef enum {
    MFI_USB_OK = 0,
    MFI_USB_ERROR_INIT,
    MFI_USB_ERROR_BUSY,
    MFI_USB_ERROR_TIMEOUT,
    MFI_USB_ERROR_INVALID_PARAM,
    MFI_USB_ERROR_TX_FULL,
    MFI_USB_ERROR_RX_EMPTY,
    MFI_USB_ERROR_UNKNOWN
} mfi_usb_error_t;

// ================================================================================
// USB-WB Bridge寄存器定义
// ================================================================================
#define WB_USB_BASE 0xF2000000UL // USB-WB Bridge基地址
#define REG_DATA 0x00UL          // 数据端口 (R/W): 写入TX FIFO，读取RX FIFO
#define REG_STATUS 0x04UL        // 状态寄存器 (R): [0]=RX非空, [1]=TX满, [2]=TX忙
#define REG_TXLEN 0x08UL         // TX长度/触发寄存器 (W): 写入长度值触发USB发送
#define REG_CTRL 0x0CUL          // 控制寄存器 (R/W): [0]=OS Type (0=Apple, 1=Android)
#define REG_SIGNATURE 0x10UL          // WB签名寄存器 (R): 返回wb设备签名 : 0x57425247)

// 状态寄存器位定义
#define STATUS_RX_NOT_EMPTY (1UL << 0) // RX FIFO非空
#define STATUS_TX_FULL (1UL << 1)      // TX FIFO满
#define STATUS_TX_BUSY (1UL << 2)      // TX忙

// 控制寄存器位定义
#define CTRL_OS_TYPE (1UL << 0) // OS类型: 0=Apple, 1=Android

// ================================================================================
// 公共函数声明
// ================================================================================

/**
 * @brief Initialize the MFI USB-Wishbone bridge interface
 * 
 * Verifies the USB-WB bridge is present by checking the signature register
 * (expected value: 0x57425247 "WRG") and sets the default OS type to Apple.
 * 
 * @return MFI_USB_OK on success, MFI_USB_ERROR_INIT if bridge not found
 */
mfi_usb_error_t mfi_usb_init(void);

/**
 * @brief Set the OS type for USB communication
 * 
 * Configures the USB bridge to operate in Apple or Android mode.
 * This affects the USB descriptor and protocol behavior.
 * 
 * @param is_android 1 for Android mode, 0 for Apple mode
 * @return MFI_USB_OK on success
 */
mfi_usb_error_t mfi_usb_set_os_type(int is_android);

/**
 * @brief Read data from USB RX FIFO
 * 
 * Reads available data from the USB receive FIFO with timeout support.
 * This function will wait up to timeout_ms for data to become available.
 * 
 * @param buffer Buffer to store received data
 * @param buffer_size Maximum size of buffer
 * @param received_size Pointer to store actual bytes received
 * @param timeout_ms Timeout in milliseconds (0 = no wait)
 * @return MFI_USB_OK on success, MFI_USB_ERROR_TIMEOUT if no data within timeout
 */
mfi_usb_error_t mfi_usb_read(unsigned char *buffer, unsigned short buffer_size, unsigned short *received_size, unsigned long timeout_ms);

/**
 * @brief Write data to USB TX FIFO
 * 
 * Writes data to the USB transmit FIFO and triggers transmission.
 * This function handles FIFO full conditions and returns immediately
 * after triggering the transfer (asynchronous operation).
 * 
 * @param buffer Data buffer to transmit
 * @param length Number of bytes to transmit
 * @param timeout_ms Timeout for FIFO operations (not for transmission completion)
 * @return MFI_USB_OK on success, error code otherwise
 */
mfi_usb_error_t mfi_usb_write(const unsigned char *buffer, unsigned short length);

/**
 * @brief Check if USB interface is available and operational
 * 
 * Verifies the USB-WB bridge is responding by checking the signature
 * register and status register for valid values.
 * 
 * @return MFI_USB_OK if available, error code otherwise
 */
mfi_usb_error_t mfi_usb_check_availability(void);

/**
 * @brief Get the current USB status register value
 * 
 * Reads the status register which contains:
 * - Bit 0: RX FIFO not empty
 * - Bit 1: TX FIFO full
 * - Bit 2: TX busy
 * 
 * @return Status register value
 */
unsigned long mfi_usb_get_status(void);

/**
 * @brief Print human-readable error message
 * 
 * Outputs a descriptive error message for the given error code.
 * 
 * @param error Error code to print
 */
void mfi_usb_print_error(mfi_usb_error_t error);

#endif // MFI_USB_H