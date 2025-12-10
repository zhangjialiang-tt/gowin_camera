#ifndef HAL_GPIO_IIC_H
#define HAL_GPIO_IIC_H

#include <stdint.h>

// --- 用户配置区 ---

// 定义用于I2C通信的GPIO引脚 (4线单向)
#define I2C_SCL_O_PIN (6+0)  // SCL线 输出
#define I2C_SDA_O_PIN (6+1)  // SDA线 输出
#define I2C_SCL_I_PIN (6+0)  // SCL线 输入 (用于时钟同步)
#define I2C_SDA_I_PIN (6+1)  // SDA线 输入

// I2C总线时钟半周期延时（单位：微秒）
// 5us -> 100kHz I2C clock
// 2us -> 250kHz I2C clock
// 1us -> 500kHz I2C clock
#define I2C_HALF_PERIOD_US   (5) 

// --- 状态码定义 ---
#define I2C_OK      (0)   // 操作成功
#define I2C_ERROR   (-1)  // 操作失败 (例如，未收到ACK)


/**
 * @brief 初始化模拟I2C所使用的GPIO引脚
 */
void hal_iic_init(void);

/**
 * @brief 向I2C从设备写入一个字节数据
 *
 * @param device_addr 从设备7位地址
 * @param reg_addr 目标寄存器地址
 * @param data 要写入的数据
 * @return int8_t 操作状态, 0为成功, -1为失败
 */
int8_t hal_i2c_write_reg(uint8_t device_addr, uint8_t reg_addr, uint8_t data);

/**
 * @brief 从I2C从设备读取一个字节数据
 *
 * @param device_addr 从设备7位地址
 * @param reg_addr 目标寄存器地址
 * @param data 用于存放读取数据的指针
 * @return int8_t 操作状态, 0为成功, -1为失败
 */
int8_t hal_i2c_read_reg(uint8_t device_addr, uint8_t reg_addr, uint8_t *data);

#endif // HAL_GPIO_IIC_H
