/**
 * @file app_sensor.h
 * @brief Application-level sensor driver abstraction for IR sensor via I2C.
 */

#ifndef APP_SENSOR_H
#define APP_SENSOR_H

#include <stdint.h>
// #include "hal/hal_i2c.h"

#ifdef __cplusplus
extern "C"
{
#endif

    // === 类型定义 ===
    typedef enum
    {
        APP_SENSOR_OK = 0,
        APP_SENSOR_ERROR_INIT_FAILED,
        APP_SENSOR_ERROR_WRITE_FAILED,
        APP_SENSOR_ERROR_READ_FAILED,
    } app_sensor_status_t;

    // === API 接口声明 ===

    /**
     * @brief 初始化 IR 传感器
     * @return APP_SENSOR_OK 表示成功；其他值为错误码
     */
    app_sensor_status_t app_sensor_init(void);

    /**
     * @brief 向 IR 传感器指定寄存器写入一个字节数据
     * @param reg 寄存器地址
     * @param data 要写入的数据
     * @return APP_SENSOR_OK 表示成功；其他值为错误码
     */
    app_sensor_status_t app_sensor_write_reg(uint8_t reg, uint8_t data);

    /**
     * @brief 从 IR 传感器指定寄存器读取一个字节数据
     * @param reg 寄存器地址
     * @param data 输出参数，指向读取结果存储位置
     * @return APP_SENSOR_OK 表示成功；其他值为错误码
     */
    app_sensor_status_t app_sensor_read_reg(uint8_t reg, uint8_t *data);

#ifdef __cplusplus
}
#endif

#endif /* APP_SENSOR_H */
