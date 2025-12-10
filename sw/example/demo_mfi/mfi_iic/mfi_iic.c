#include "../debug.h"
#include "mfi_iic.h"
#include <neorv32_uart.h>
#include <neorv32_gpio.h>

// =========================================================
// 延时函数实现
// =========================================================

// 基于 neorv32_aux_delay_ms 改写的微秒延时
// 60MHz 时钟下，1us = 60 cycles。
// ASM循环大约需要 4-5 cycles (addi, bne, branch penalty)。
// 60 / 4 = 15 iterations per us.
void mfi_delay_us(uint32_t us) {
    uint32_t iterations = us * 15; 
    
    asm volatile (
        " __mfi_delay_us_start:                   \n"
        " beq  %[cnt_r], zero, __mfi_delay_us_end \n"
        " addi %[cnt_w], %[cnt_r], -1             \n"
        " j    __mfi_delay_us_start               \n"
        " __mfi_delay_us_end:                     \n"
        : [cnt_w] "=r" (iterations) : [cnt_r] "r" (iterations)
    );
}

void mfi_delay_ms(uint32_t ms) {
    neorv32_aux_delay_ms(NEORV32_SYSINFO->CLK, ms);
}

// =========================================================
// GPIO 模拟 IIC 底层操作
// =========================================================

static void sda_out(int val) {
    neorv32_gpio_pin_set(I2C_SDA_GPIO, val);
}

static void scl_out(int val) {
    neorv32_gpio_pin_set(I2C_SCL_GPIO, val);
}

static int sda_in(void) {
    return (neorv32_gpio_pin_get(I2C_SDA_GPIO) != 0);
}

// 配置 SDA 为输入模式 (实际上是输出高，依靠外部上拉，同时允许从机拉低)
static void sda_set_input(void) {
    sda_out(1);
}

void mfi_gpio_init(void) {
    // 初始状态：SCL/SDA 拉高 (空闲)
    sda_out(1);
    scl_out(1);
}

static void i2c_start(void) {
    // 确保空闲
    sda_out(1);
    scl_out(1);
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    // SDA 下降沿
    sda_out(0);
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    // SCL 拉低，钳住总线准备发送
    scl_out(0);
    mfi_delay_us(1); // Hold time
}

static void i2c_stop(void) {
    // 确保 SCL 为低，SDA 为低
    scl_out(0);
    sda_out(0);
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    // SCL 上升
    scl_out(1);
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    // SDA 上升
    sda_out(1);
    mfi_delay_us(I2C_CLK_DELAY_US);
}

// 发送一个字节，返回 ACK(0) 或 NACK(1)
static int i2c_send_byte(uint8_t data) {
    int i;
    int ack;

    for (i = 7; i >= 0; i--) {
        // 准备数据
        if ((data >> i) & 0x01) {
            sda_out(1);
        } else {
            sda_out(0);
        }
        mfi_delay_us(1); // Data setup

        // SCL High (Sample)
        scl_out(1);
        mfi_delay_us(I2C_CLK_DELAY_US);

        // SCL Low (Next bit)
        scl_out(0);
        mfi_delay_us(I2C_CLK_DELAY_US);
    }

    // 接收 ACK
    sda_set_input(); // 释放 SDA
    mfi_delay_us(1);
    
    scl_out(1);      // SCL High
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    ack = sda_in();  // Sample ACK
    
    scl_out(0);      // SCL Low
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    // 恢复 SDA 输出高 (Idle)
    sda_out(1);
    
    return ack; // 0=ACK, 1=NACK
}

// 读取一个字节，send_ack=0 发送 ACK，send_ack=1 发送 NACK
static uint8_t i2c_read_byte(int send_nack) {
    int i;
    uint8_t data = 0;

    sda_set_input(); // 释放 SDA 为输入

    for (i = 7; i >= 0; i--) {
        mfi_delay_us(1); 
        
        scl_out(1); // SCL High
        mfi_delay_us(I2C_CLK_DELAY_US);
        
        if (sda_in()) {
            data |= (1 << i);
        }
        
        scl_out(0); // SCL Low
        mfi_delay_us(I2C_CLK_DELAY_US);
    }

    // 发送 ACK/NACK
    if (send_nack) {
        sda_out(1); // NACK
    } else {
        sda_out(0); // ACK
    }
    mfi_delay_us(1);

    scl_out(1); // SCL High
    mfi_delay_us(I2C_CLK_DELAY_US);
    
    scl_out(0); // SCL Low
    mfi_delay_us(I2C_CLK_DELAY_US);

    sda_out(1); // Release
    return data;
}

// =========================================================
// 基础IIC读写函数
// =========================================================

/**
 * @brief 基础IIC写函数
 * @param reg_addr 寄存器地址
 * @param data 要写入的数据
 * @param len 数据长度
 * @return 错误码
 */
mfi_error_t mfi_iic_write(uint8_t reg_addr, const uint8_t *data, uint32_t len) {
    int retry = 50;
    uint32_t i;

    if (data == NULL || len == 0) return MFI_ERR;

retry_write:
    if (retry-- <= 0) return MFI_ERR;

    i2c_start();

    // Slave Addr (Write)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x00) != 0) {
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write;
    }

    // Reg Addr
    if (i2c_send_byte(reg_addr) != 0) {
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write;
    }

    // Data
    for (i = 0; i < len; i++) {
        if (i2c_send_byte(data[i]) != 0) {
            i2c_stop();
            mfi_delay_us(NACK_RETRY_DELAY_US);
            goto retry_write;
        }
    }

    i2c_stop();
    return MFI_OK;
}

/**
 * @brief 基础IIC读函数
 * @param reg_addr 寄存器地址
 * @param data 读取数据的缓冲区
 * @param len 要读取的数据长度
 * @return 错误码
 */
mfi_error_t mfi_iic_read(uint8_t reg_addr, uint8_t *data, uint32_t len) {
    int retry_write = 50;
    int retry_read = 50;

    if (data == NULL || len == 0) return MFI_ERR;

    // Phase 1: Write Reg Addr
retry_write_step:
    if (retry_write-- <= 0) return MFI_ERR;

    i2c_start();

    // Send Slave Addr (Write)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x00) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write_step;
    }

    // Send Reg Addr
    if (i2c_send_byte(reg_addr) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write_step;
    }

    // Stop required before Read Phase according to RTL doc
    i2c_stop();
    // RTL: Wait 10ms between Write Addr and Read Data
    mfi_delay_ms(10);

    // Phase 2: Read Data
retry_read_step:
    if (retry_read-- <= 0) return MFI_ERR;

    i2c_start();

    // Send Slave Addr (Read)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x01) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_read_step;
    }

    // Read Bytes
    for (uint32_t i = 0; i < len; i++) {
        // Last byte sends NACK (1), others ACK (0)
        data[i] = i2c_read_byte((i == len - 1) ? 1 : 0);
    }

    i2c_stop();
    return MFI_OK;
}

// =========================================================
// MFI 协议层 (移植自参考代码)
// =========================================================

/**
 * 核心读取函数：Start -> Addr(W) -> Reg -> Start -> Addr(R) -> Data
 * 包含严格的 NACK 处理：NACK -> Stop -> Wait 500us -> Goto Start
 */
static mfi_error_t auth30cp_read(uint8_t reg_addr, uint8_t *data, uint32_t len) {
    int retry_write = 50; // 增加重试次数
    int retry_read = 50;

    if (data == NULL || len == 0) return MFI_ERR;

    // Phase 1: Write Reg Addr
retry_write_step:
    if (retry_write-- <= 0) return MFI_ERR;

    i2c_start();

    // Send Slave Addr (Write)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x00) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write_step;
    }

    // Send Reg Addr
    if (i2c_send_byte(reg_addr) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write_step;
    }

    // Stop required before Read Phase according to RTL doc
    i2c_stop();
    // RTL: Wait 10ms between Write Addr and Read Data
    mfi_delay_ms(10); 

    // Phase 2: Read Data
retry_read_step:
    if (retry_read-- <= 0) return MFI_ERR;

    i2c_start();

    // Send Slave Addr (Read)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x01) != 0) { // NACK
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_read_step;
    }

    // Read Bytes
    for (uint32_t i = 0; i < len; i++) {
        // Last byte sends NACK (1), others ACK (0)
        data[i] = i2c_read_byte((i == len - 1) ? 1 : 0);
    }

    i2c_stop();
    return MFI_OK;
}

/**
 * 核心写入函数
 */
static mfi_error_t auth30cp_write(uint8_t reg_addr, const uint8_t *data, uint32_t len) {
    int retry = 50;
    uint32_t i;

    if (data == NULL || len == 0) return MFI_ERR;

retry_write:
    if (retry-- <= 0) return MFI_ERR;

    i2c_start();

    // Slave Addr (Write)
    if (i2c_send_byte((MFI_ADDR << 1) | 0x00) != 0) {
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write;
    }

    // Reg Addr
    if (i2c_send_byte(reg_addr) != 0) {
        i2c_stop();
        mfi_delay_us(NACK_RETRY_DELAY_US);
        goto retry_write;
    }

    // Data
    for (i = 0; i < len; i++) {
        if (i2c_send_byte(data[i]) != 0) {
            i2c_stop();
            mfi_delay_us(NACK_RETRY_DELAY_US);
            goto retry_write;
        }
    }

    i2c_stop();
    return MFI_OK;
}

// =========================================================
// 高级 API 封装
// =========================================================

mfi_error_t mfi_check_availability(void) {
    uint8_t dummy;
    // 尝试读 0x10 寄存器
    return auth30cp_read(MFI_REG_STATUS, &dummy, 1);
}

mfi_error_t mfi_read_certificate(uint8_t *buffer, uint16_t buffer_size, uint16_t *cert_length) {
    uint8_t len_buf[2];
    
    // 1. Read Length (Reg 0x30)
    if (auth30cp_read(MFI_REG_CERT_LEN_H, len_buf, 2) != MFI_OK) return MFI_ERR;
    
    uint16_t len = (len_buf[0] << 8) | len_buf[1];
    *cert_length = len;

    if (len == 0 || len > 2048) {
        DEBUG_INFO("Invalid Cert Len: %d\r\n", len);
        return MFI_ERR;
    }
    
    if (len > buffer_size) return MFI_ERR;

    DEBUG_INFO("Cert Len Read: %d. Waiting 15ms...\r\n", len);
    mfi_delay_ms(15); // RTL IIC_DELAY1

    // 2. Read Data (Reg 0x31)
    // MFI requires reading chunk by chunk if buffer limited, but here we try full read
    // RTL logic reads full length in one go
    if (auth30cp_read(MFI_REG_CERT_DATA, buffer, len) != MFI_OK) return MFI_ERR;
    
    return MFI_OK;
}

mfi_error_t mfi_write_param(const uint8_t *param_data, uint16_t param_length) {
    // 0x20: Length (1 byte)
    // 0x21: Data
    
    // Note: RTL logic: 
    // 1. Write Length -> Wait
    // 2. Write Data -> Wait
    
    uint8_t len = (uint8_t)param_length;
    if (auth30cp_write(MFI_REG_PARAM_LEN, &len, 1) != MFI_OK) return MFI_ERR;
    
    mfi_delay_ms(15);

    if (auth30cp_write(MFI_REG_PARAM_DATA, param_data, param_length) != MFI_OK) return MFI_ERR;
    
    mfi_delay_ms(15);
    return MFI_OK;
}

mfi_error_t mfi_start_challenge_generation(void) {
    uint8_t val = 0x01;
    return auth30cp_write(MFI_REG_STATUS, &val, 1);
}

mfi_error_t mfi_check_challenge_status(mfi_status_t *status) {
    if (auth30cp_read(MFI_REG_STATUS, &status->status_reg, 1) != MFI_OK) return MFI_ERR;
    status->challenge_ready = ((status->status_reg >> 4) & 0x07) == 0x01;
    return MFI_OK;
}

mfi_error_t mfi_read_challenge(uint8_t *buffer, uint16_t buffer_size, uint16_t *challenge_length) {
    uint8_t len_buf[2];
    
    if (auth30cp_read(MFI_REG_CHALLENGE_LEN_H, len_buf, 2) != MFI_OK) return MFI_ERR;
    
    uint16_t len = (len_buf[0] << 8) | len_buf[1];
    *challenge_length = len;
    
    if (len > buffer_size) return MFI_ERR;
    
    mfi_delay_ms(15);

    if (auth30cp_read(MFI_REG_CHALLENGE_DATA, buffer, len) != MFI_OK) return MFI_ERR;
    return MFI_OK;
}