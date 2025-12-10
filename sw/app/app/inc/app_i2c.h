/**
 * @file app_i2c.h
 * @brief Application-level I2C interface
 */

#ifndef APP_I2C_H
#define APP_I2C_H

#ifdef __cplusplus
extern "C" {
#endif

#include "../inc/hal_i2c.h"
#include <stdint.h>
#include <stdbool.h>

/* ========================================== */
/*              类型定义与枚举                */
/* ========================================== */

/**
 * @brief I2C 设备句柄
 */
typedef void* app_i2c_handle_t;

/**
 * @brief I2C 配置结构体
 */
typedef struct {
    hal_i2c_speed_t speed;         /**< I2C 时钟速度 */
    bool clock_stretch;            /**< 是否允许时钟拉伸 */
} app_i2c_config_t;

/**
 * @brief I2C 设备信息
 */
typedef struct {
    uint8_t address;               /**< 设备地址 */
    const char* name;              /**< 设备名称 */
    uint8_t id_reg;                /**< ID寄存器地址 */
    uint8_t id_value;              /**< ID寄存器期望值 */
} app_i2c_device_info_t;

/**
 * @brief I2C 操作结果
 */
typedef enum {
    APP_I2C_OK = 0,               /**< 操作成功 */
    APP_I2C_ERROR = -1,           /**< 一般错误 */
    APP_I2C_DEVICE_NOT_FOUND = -2,/**< 设备未找到 */
    APP_I2C_BUSY = -3,            /**< 总线忙 */
    APP_I2C_TIMEOUT = -4,         /**< 超时 */
    APP_I2C_NACK = -5             /**< NACK 错误 */
} app_i2c_status_t;

/* ========================================== */
/*               常用I2C设备地址              */
/* ========================================== */

#define APP_I2C_ADDR_BMP280       0x76    /**< BMP280气压传感器 */
#define APP_I2C_ADDR_SSD1306      0x3C    /**< SSD1306 OLED显示 */
#define APP_I2C_ADDR_AT24C32      0x50    /**< AT24C32 EEPROM */
#define APP_I2C_ADDR_MPU6050      0x68    /**< MPU6050陀螺仪 */
#define APP_I2C_ADDR_SI7021       0x40    /**< SI7021温湿度传感器 */
#define APP_I2C_ADDR_PCF8574      0x20    /**< PCF8574 IO扩展器 */

/* ========================================== */
/*                API 函数声明                */
/* ========================================== */

/**
 * @brief 初始化I2C控制器
 * @param config I2C配置参数
 * @return app_i2c_handle_t I2C句柄
 */
app_i2c_handle_t app_i2c_init(const app_i2c_config_t *config);

/**
 * @brief 反初始化I2C控制器
 * @param handle I2C句柄
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_deinit(app_i2c_handle_t handle);

/**
 * @brief 检查I2C设备是否存在
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @return true 设备存在，false 设备不存在
 */
bool app_i2c_probe_device(app_i2c_handle_t handle, uint8_t slave_addr);

/**
 * @brief 扫描I2C总线上的设备
 * @param handle I2C句柄
 * @param found_devices 存储找到的设备地址
 * @param max_devices 最大设备数量
 * @return int 找到的设备数量
 */
int app_i2c_scan_bus(app_i2c_handle_t handle, uint8_t *found_devices, int max_devices);

/**
 * @brief 向设备写入数据
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param data 要写入的数据
 * @param size 数据大小
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_write_reg(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, const uint8_t *data, 
                                  uint16_t size, uint32_t timeout_ms);

/**
 * @brief 从设备读取数据
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param data 读取数据的缓冲区
 * @param size 要读取的数据大小
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_reg(app_i2c_handle_t handle, uint8_t slave_addr, 
                                 uint8_t reg_addr, uint8_t *data, 
                                 uint16_t size, uint32_t timeout_ms);

/**
 * @brief 向设备写入单个字节
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param value 要写入的值
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_write_byte(app_i2c_handle_t handle, uint8_t slave_addr, 
                                   uint8_t reg_addr, uint8_t value, 
                                   uint32_t timeout_ms);

/**
 * @brief 从设备读取单个字节
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param value 读取到的值
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_byte(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, uint8_t *value, 
                                  uint32_t timeout_ms);

/**
 * @brief 向设备写入16位数据
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param value 要写入的16位值
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_write_word(app_i2c_handle_t handle, uint8_t slave_addr, 
                                   uint8_t reg_addr, uint16_t value, 
                                   uint32_t timeout_ms);

/**
 * @brief 从设备读取16位数据
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param reg_addr 寄存器地址
 * @param value 读取到的16位值
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_word(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, uint16_t *value, 
                                  uint32_t timeout_ms);

/**
 * @brief 设备写入-读取操作
 * @param handle I2C句柄
 * @param slave_addr 从设备地址
 * @param write_reg 要写入的寄存器地址
 * @param write_data 要写入的数据
 * @param write_size 写入数据大小
 * @param read_reg 要读取的寄存器地址
 * @param read_data 读取数据的缓冲区
 * @param read_size 要读取的数据大小
 * @param timeout_ms 超时时间
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_write_then_read(app_i2c_handle_t handle, uint8_t slave_addr,
                                        uint8_t write_reg, const uint8_t *write_data, uint16_t write_size,
                                        uint8_t read_reg, uint8_t *read_data, uint16_t read_size,
                                        uint32_t timeout_ms);

/**
 * @brief 获取I2C总线状态
 * @param handle I2C句柄
 * @return bool true-总线忙，false-总线空闲
 */
bool app_i2c_is_busy(app_i2c_handle_t handle);

/**
 * @brief 重置I2C总线
 * @param handle I2C句柄
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_reset_bus(app_i2c_handle_t handle);

/**
 * @brief 设备特定函数：读取温度传感器
 * @param handle I2C句柄
 * @param slave_addr 传感器地址
 * @param temperature 温度值(摄氏度)
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_temperature(app_i2c_handle_t handle, uint8_t slave_addr, float *temperature);

/**
 * @brief 设备特定函数：读取湿度传感器
 * @param handle I2C句柄
 * @param slave_addr 传感器地址
 * @param humidity 湿度值(百分比)
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_humidity(app_i2c_handle_t handle, uint8_t slave_addr, float *humidity);

/**
 * @brief 设备特定函数：读取气压传感器
 * @param handle I2C句柄
 * @param slave_addr 传感器地址
 * @param pressure 气压值(hPa)
 * @return app_i2c_status_t 操作状态
 */
app_i2c_status_t app_i2c_read_pressure(app_i2c_handle_t handle, uint8_t slave_addr, float *pressure);

#ifdef __cplusplus
}
#endif

#endif /* APP_I2C_H */