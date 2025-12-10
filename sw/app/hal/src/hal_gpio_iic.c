#include "../inc/hal_gpio_iic.h"
#include <neorv32.h>

// 内部延时函数
// 使用基于系统时钟的精确延时，替代简单的循环计数
static void i2c_delay(void) {
    //! 为了减小编译后文件的体积使用硬编码-31
    // 使用来自 neorv32_aux.c 的精确延时循环方法，但调整为微秒级
    // uint32_t clock_hz = neorv32_sysinfo_get_clk();
    // uint64_t wait_cycles = (uint64_t)clock_hz * I2C_HALF_PERIOD_US / 1000000;//500;//
    // uint32_t iterations = (uint32_t)(wait_cycles >> 4); // 每个循环约16个周期

    // if (iterations == 0) {
    //     iterations = 1; // 确保至少有最小延时
    // }
    volatile uint32_t iterations = 31;
    asm volatile (
      " __iic_delay_start_%=:                   \n"
      " beq  %[cnt_r], zero, __iic_delay_end_%= \n" 
      " bne  zero,     zero, __iic_delay_end_%= \n" 
      " addi %[cnt_w], %[cnt_r], -1          \n"
      " nop                                  \n"
      " j    __iic_delay_start_%=               \n"
      " __iic_delay_end_%=:                     \n"
      : [cnt_w] "=r" (iterations) : [cnt_r] "r" (iterations)
    );
}

// SCL和SDA引脚操作的封装
static void sda_set(int value) {
    neorv32_gpio_pin_set(I2C_SDA_O_PIN, value);
}

static void scl_set(int value) {
    neorv32_gpio_pin_set(I2C_SCL_O_PIN, value);
}

static uint32_t sda_get(void) {
    return neorv32_gpio_pin_get(I2C_SDA_I_PIN);
}

// I2C起始信号: SCL为高时，SDA由高变低
static void i2c_start(void) {
    sda_set(1);
    scl_set(1);
    i2c_delay();
    sda_set(0);
    i2c_delay();
    scl_set(0);
    i2c_delay();
}

// I2C停止信号: SCL为高时，SDA由低变高
static void i2c_stop(void) {
    scl_set(0);
    sda_set(0);
    i2c_delay();
    scl_set(1);
    i2c_delay();
    sda_set(1);
    i2c_delay();
}

// 发送一个字节
static void i2c_send_byte(uint8_t byte) {
    uint8_t i;
    for (i = 0; i < 8; i++) {
        scl_set(0);
        i2c_delay();
        if (byte & 0x80) {
            sda_set(1);
        } else {
            sda_set(0);
        }
        byte <<= 1;
        i2c_delay();
        scl_set(1);
        i2c_delay();
    }
    scl_set(0);
}

// 等待应答信号 (ACK)
// 返回 0 表示收到ACK, -1 表示收到NACK
static int8_t i2c_wait_ack(void) {
    scl_set(0);
    sda_set(1); // 主机释放SDA总线
    i2c_delay();
    scl_set(1);
    i2c_delay();
  
    int8_t ack = sda_get() ? I2C_ERROR : I2C_OK; // 读取SDA电平，低电平为ACK

    scl_set(0);
    i2c_delay();
    return ack;
}

// 主机发送非应答信号 (NACK)
static void i2c_send_nack(void) {
    scl_set(0);
    sda_set(1);
    i2c_delay();
    scl_set(1);
    i2c_delay();
    scl_set(0);
    i2c_delay();
}

// 读取一个字节
static uint8_t i2c_read_byte(void) {
    uint8_t i;
    uint8_t byte = 0;

    sda_set(1); // 释放SDA，准备接收
    for (i = 0; i < 8; i++) {
        scl_set(0);
        i2c_delay();
        scl_set(1);
        i2c_delay();
        byte <<= 1;
        if (sda_get()) {
            byte |= 0x01;
        }
    }
    scl_set(0);
    return byte;
}

// 初始化函数
void hal_iic_init(void) {
    if (!neorv32_gpio_available()) {
        // 在实际项目中，这里应该有错误处理机制
        while(1);
    }
    // 初始状态下，SCL和SDA输出都应为高电平 (释放总线)
    neorv32_gpio_pin_set(I2C_SCL_O_PIN, 1);
    neorv32_gpio_pin_set(I2C_SDA_O_PIN, 1);
}

// 写入寄存器
int8_t hal_i2c_write_reg(uint8_t device_addr, uint8_t reg_addr, uint8_t data) {
    i2c_start();

    // 1. 发送设备地址 + 写指令(0)
    i2c_send_byte((device_addr << 1) | 0);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }

    // 2. 发送寄存器地址
    i2c_send_byte(reg_addr);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }

    // 3. 发送数据
    i2c_send_byte(data);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }

    i2c_stop();
    return I2C_OK;
}

// 读取寄存器
int8_t hal_i2c_read_reg(uint8_t device_addr, uint8_t reg_addr, uint8_t *data) {
    // 阶段1: 写操作，告诉传感器要读取哪个寄存器
    i2c_start();
  
    // 1. 发送设备地址 + 写指令(0)
    i2c_send_byte((device_addr << 1) | 0);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }
  
    // 2. 发送寄存器地址
    i2c_send_byte(reg_addr);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }

    // 阶段2: 读操作，使用重复起始信号
    i2c_start(); // 重复起始信号 (Sr)

    // 3. 发送设备地址 + 读指令(1)
    i2c_send_byte((device_addr << 1) | 1);
    if (i2c_wait_ack() != I2C_OK) {
        i2c_stop();
        return I2C_ERROR;
    }

    // 4. 读取数据
    *data = i2c_read_byte();

    // 5. 主机发送NACK，表示读取结束
    i2c_send_nack();

    i2c_stop();
    return I2C_OK;
}