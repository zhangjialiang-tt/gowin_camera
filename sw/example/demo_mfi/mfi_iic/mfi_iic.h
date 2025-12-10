// ================================================================================
// MFi I2C Communication Module Header
// MFi芯片I2C通信接口头文件
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - neorv32.h: NEORV32 GPIO and system functions
//   - neorv32_uart.h: UART for debug output
//   - neorv32_gpio.h: GPIO pin control for bit-banged I2C
//
// PURPOSE:
//   This module implements bit-banged I2C communication with the Apple MFi
//   authentication coprocessor. It provides low-level I2C read/write functions
//   and high-level APIs for certificate reading, challenge-response operations,
//   and parameter writing.
//
// ================================================================================

#ifndef MFI_IIC_H
#define MFI_IIC_H

#include <stdint.h>
#include <neorv32.h>

// =========================================================
// 引脚定义 (需与 FPGA 约束一致)
// =========================================================
#define I2C_SDA_GPIO    8
#define I2C_SCL_GPIO    9

// MFI 地址
#define MFI_ADDR        0x10

// 寄存器地址
#define MFI_REG_STATUS          0x10
#define MFI_REG_CHALLENGE_LEN_H 0x11
#define MFI_REG_CHALLENGE_DATA  0x12
#define MFI_REG_PARAM_LEN       0x20
#define MFI_REG_PARAM_DATA      0x21
#define MFI_REG_CERT_LEN_H      0x30
#define MFI_REG_CERT_DATA       0x31

// 延时参数
#define MFI_PWR_DELAY_MS      5000
#define NACK_RETRY_DELAY_US   500  // NACK后等待时间
#define I2C_CLK_DELAY_US      5    // 半周期延时 (5us -> ~100kHz)

// 缓冲区大小
#define MFI_CERT_BUFFER_SIZE      1024
#define MFI_CHALLENGE_BUFFER_SIZE 256

// 错误码
typedef enum {
    MFI_OK = 0,
    MFI_ERR = -1
} mfi_error_t;

typedef struct {
    uint8_t status_reg;
    uint8_t challenge_ready;
} mfi_status_t;

// API 声明
void mfi_gpio_init(void);
void mfi_delay_us(uint32_t us);
void mfi_delay_ms(uint32_t ms);

// 基础IIC读写函数
mfi_error_t mfi_iic_write(uint8_t reg_addr, const uint8_t *data, uint32_t len);
mfi_error_t mfi_iic_read(uint8_t reg_addr, uint8_t *data, uint32_t len);

// 高级API函数
mfi_error_t mfi_check_availability(void);
mfi_error_t mfi_read_certificate(uint8_t *buffer, uint16_t buffer_size, uint16_t *cert_length);
mfi_error_t mfi_write_param(const uint8_t *param_data, uint16_t param_length);
mfi_error_t mfi_start_challenge_generation(void);
mfi_error_t mfi_check_challenge_status(mfi_status_t *status);
mfi_error_t mfi_read_challenge(uint8_t *buffer, uint16_t buffer_size, uint16_t *challenge_length);

#endif // MFI_IIC_H