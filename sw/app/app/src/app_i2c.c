/**
 * @file app_i2c.c
 * @brief Application-level I2C implementation
 */

#include "../inc/app_i2c.h"
#include <stdlib.h>
#include <string.h>

/* ========================================== */
/*              私有数据结构                  */
/* ========================================== */

typedef struct app_i2c_instance {
    bool is_initialized;           /**< 实例是否已初始化 */
    hal_i2c_config_t hal_config;   /**< HAL层配置 */
    uint32_t timeout;              /**< 默认超时时间 */
} app_i2c_instance_t;

/* ========================================== */
/*              静态变量                      */
/* ========================================== */

static app_i2c_instance_t s_i2c_instance = {0};

/* ========================================== */
/*              常用设备信息                  */
/* ========================================== */

// static const app_i2c_device_info_t s_common_devices[] = {
//     {0x76, "BMP280 Pressure Sensor", 0xD0, 0x58},
//     {0x77, "BMP280 Pressure Sensor", 0xD0, 0x58},
//     {0x3C, "SSD1306 OLED Display", 0x00, 0x00}, // 需要特殊初始化
//     {0x3D, "SSD1306 OLED Display", 0x00, 0x00},
//     {0x50, "AT24C32 EEPROM", 0x00, 0x00},       // 需要特殊检测
//     {0x68, "MPU6050 Gyroscope", 0x75, 0x68},
//     {0x69, "MPU6050 Gyroscope", 0x75, 0x68},
//     {0x40, "SI7021 Temp/Humidity", 0xFC, 0x31},
//     {0x20, "PCF8574 IO Expander", 0x00, 0x00},  // 需要特殊检测
//     {0x21, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x22, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x23, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x24, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x25, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x26, "PCF8574 IO Expander", 0x00, 0x00},
//     {0x27, "PCF8574 IO Expander", 0x00, 0x00}
// };

#define NUM_COMMON_DEVICES (sizeof(s_common_devices) / sizeof(s_common_devices[0]))

/* ========================================== */
/*              私有函数声明                  */
/* ========================================== */

static app_i2c_status_t convert_hal_status(hal_i2c_status_t hal_status);
// static bool is_device_reserved(uint8_t addr);

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

app_i2c_handle_t app_i2c_init(const app_i2c_config_t *config)
{
    if (config == NULL) {
        return NULL;
    }

    // 检查I2C控制器是否可用
    if (!hal_i2c_is_available()) {
        return NULL;
    }

    // 初始化HAL层配置
    hal_i2c_config_t hal_config = {
        .speed = config->speed,
        .addr_mode = HAL_I2C_ADDR_7BIT,
        .clock_stretch = config->clock_stretch,
        .slave_addr = 0
    };

    // 初始化HAL层
    hal_i2c_status_t status = hal_i2c_init(&hal_config);
    if (status != HAL_I2C_OK) {
        return NULL;
    }

    // 使能I2C控制器
    status = hal_i2c_enable();
    if (status != HAL_I2C_OK) {
        hal_i2c_deinit();
        return NULL;
    }

    // 初始化应用层实例
    s_i2c_instance.is_initialized = true;
    s_i2c_instance.hal_config = hal_config;
    s_i2c_instance.timeout = 100; // 默认100ms超时

    return (app_i2c_handle_t)&s_i2c_instance;
}

app_i2c_status_t app_i2c_deinit(app_i2c_handle_t handle)
{
    if (handle == NULL || !s_i2c_instance.is_initialized) {
        return APP_I2C_ERROR;
    }

    // 禁用I2C控制器
    hal_i2c_disable();
    
    // 反初始化HAL层
    hal_i2c_deinit();
    
    // 清除实例状态
    s_i2c_instance.is_initialized = false;
    
    return APP_I2C_OK;
}

bool app_i2c_probe_device(app_i2c_handle_t handle, uint8_t slave_addr)
{
    if (handle == NULL || !s_i2c_instance.is_initialized) {
        return false;
    }

    hal_i2c_status_t status = hal_i2c_probe_device(slave_addr);
    return (status == HAL_I2C_OK);
}

int app_i2c_scan_bus(app_i2c_handle_t handle, uint8_t *found_devices, int max_devices)
{
    if (handle == NULL || !s_i2c_instance.is_initialized || found_devices == NULL || max_devices <= 0) {
        return 0;
    }

    return hal_i2c_bus_scan(found_devices, max_devices);
}

app_i2c_status_t app_i2c_write_reg(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, const uint8_t *data, 
                                  uint16_t size, uint32_t timeout_ms)
{
    if (handle == NULL || !s_i2c_instance.is_initialized || data == NULL || size == 0) {
        return APP_I2C_ERROR;
    }

    // 创建包含寄存器地址和数据的数据缓冲区
    uint8_t *write_data = (uint8_t*)malloc(size + 1);
    if (write_data == NULL) {
        return APP_I2C_ERROR;
    }

    write_data[0] = reg_addr;
    memcpy(&write_data[1], data, size);

    // 执行写操作
    hal_i2c_status_t status = hal_i2c_master_write(slave_addr, write_data, size + 1, 
                                                  timeout_ms ? timeout_ms : s_i2c_instance.timeout);

    free(write_data);
    return convert_hal_status(status);
}

app_i2c_status_t app_i2c_read_reg(app_i2c_handle_t handle, uint8_t slave_addr, 
                                 uint8_t reg_addr, uint8_t *data, 
                                 uint16_t size, uint32_t timeout_ms)
{
    if (handle == NULL || !s_i2c_instance.is_initialized || data == NULL || size == 0) {
        return APP_I2C_ERROR;
    }

    // 先写入寄存器地址，然后读取数据
    hal_i2c_status_t status = hal_i2c_master_write_read(slave_addr, 
                                                       &reg_addr, 1, 
                                                       data, size, 
                                                       timeout_ms ? timeout_ms : s_i2c_instance.timeout);

    return convert_hal_status(status);
}

app_i2c_status_t app_i2c_write_byte(app_i2c_handle_t handle, uint8_t slave_addr, 
                                   uint8_t reg_addr, uint8_t value, 
                                   uint32_t timeout_ms)
{
    return app_i2c_write_reg(handle, slave_addr, reg_addr, &value, 1, 
                            timeout_ms ? timeout_ms : s_i2c_instance.timeout);
}

app_i2c_status_t app_i2c_read_byte(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, uint8_t *value, 
                                  uint32_t timeout_ms)
{
    return app_i2c_read_reg(handle, slave_addr, reg_addr, value, 1, 
                           timeout_ms ? timeout_ms : s_i2c_instance.timeout);
}

app_i2c_status_t app_i2c_write_word(app_i2c_handle_t handle, uint8_t slave_addr, 
                                   uint8_t reg_addr, uint16_t value, 
                                   uint32_t timeout_ms)
{
    uint8_t data[2] = {(uint8_t)(value >> 8), (uint8_t)(value & 0xFF)};
    return app_i2c_write_reg(handle, slave_addr, reg_addr, data, 2, 
                            timeout_ms ? timeout_ms : s_i2c_instance.timeout);
}

app_i2c_status_t app_i2c_read_word(app_i2c_handle_t handle, uint8_t slave_addr, 
                                  uint8_t reg_addr, uint16_t *value, 
                                  uint32_t timeout_ms)
{
    uint8_t data[2];
    app_i2c_status_t status = app_i2c_read_reg(handle, slave_addr, reg_addr, data, 2, 
                                              timeout_ms ? timeout_ms : s_i2c_instance.timeout);
    
    if (status == APP_I2C_OK) {
        *value = (data[0] << 8) | data[1];
    }
    
    return status;
}

app_i2c_status_t app_i2c_write_then_read(app_i2c_handle_t handle, uint8_t slave_addr,
                                        uint8_t write_reg, const uint8_t *write_data, uint16_t write_size,
                                        uint8_t read_reg, uint8_t *read_data, uint16_t read_size,
                                        uint32_t timeout_ms)
{
    if (handle == NULL || !s_i2c_instance.is_initialized || 
        write_data == NULL || read_data == NULL || 
        write_size == 0 || read_size == 0) {
        return APP_I2C_ERROR;
    }

    // 创建写数据缓冲区（包含写寄存器地址）
    uint8_t *combined_write_data = (uint8_t*)malloc(write_size + 1);
    if (combined_write_data == NULL) {
        return APP_I2C_ERROR;
    }

    combined_write_data[0] = write_reg;
    memcpy(&combined_write_data[1], write_data, write_size);

    // 执行复合操作
    hal_i2c_status_t status = hal_i2c_master_write_read(slave_addr, 
                                                       combined_write_data, write_size + 1,
                                                       read_data, read_size,
                                                       timeout_ms ? timeout_ms : s_i2c_instance.timeout);

    free(combined_write_data);
    return convert_hal_status(status);
}

bool app_i2c_is_busy(app_i2c_handle_t handle)
{
    if (handle == NULL || !s_i2c_instance.is_initialized) {
        return false;
    }

    return hal_i2c_is_busy();
}

app_i2c_status_t app_i2c_reset_bus(app_i2c_handle_t handle)
{
    if (handle == NULL || !s_i2c_instance.is_initialized) {
        return APP_I2C_ERROR;
    }

    // 禁用I2C
    hal_i2c_disable();
    
    // 短暂延时
    hal_i2c_delay_ms(10);
    
    // 重新启用I2C
    hal_i2c_status_t status = hal_i2c_enable();
    
    return convert_hal_status(status);
}

app_i2c_status_t app_i2c_read_temperature(app_i2c_handle_t handle, uint8_t slave_addr, float *temperature)
{
    // 实现特定设备的温度读取逻辑
    // 这里以BMP280为例
    uint8_t data[3];
    app_i2c_status_t status = app_i2c_read_reg(handle, slave_addr, 0xFA, data, 3, s_i2c_instance.timeout);
    
    if (status == APP_I2C_OK) {
        // BMP280温度数据转换（简化版）
        int32_t adc_T = (data[0] << 12) | (data[1] << 4) | (data[2] >> 4);
        // 实际应用中需要根据校准数据进行计算
        *temperature = adc_T / 100.0f;
    }
    
    return status;
}

app_i2c_status_t app_i2c_read_humidity(app_i2c_handle_t handle, uint8_t slave_addr, float *humidity)
{
    // 实现特定设备的湿度读取逻辑
    // 这里以SI7021为例
    uint8_t data[2];
    app_i2c_status_t status = app_i2c_read_reg(handle, slave_addr, 0xE5, data, 2, s_i2c_instance.timeout);
    
    if (status == APP_I2C_OK) {
        // SI7021湿度数据转换
        uint16_t raw_humidity = (data[0] << 8) | data[1];
        *humidity = (125.0f * raw_humidity / 65536.0f) - 6.0f;
    }
    
    return status;
}

app_i2c_status_t app_i2c_read_pressure(app_i2c_handle_t handle, uint8_t slave_addr, float *pressure)
{
    // 实现特定设备的气压读取逻辑
    // 这里以BMP280为例
    uint8_t data[3];
    app_i2c_status_t status = app_i2c_read_reg(handle, slave_addr, 0xF7, data, 3, s_i2c_instance.timeout);
    
    if (status == APP_I2C_OK) {
        // BMP280气压数据转换（简化版）
        int32_t adc_P = (data[0] << 12) | (data[1] << 4) | (data[2] >> 4);
        // 实际应用中需要根据校准数据进行计算
        *pressure = adc_P / 256.0f;
    }
    
    return status;
}

/* ========================================== */
/*              私有函数实现                  */
/* ========================================== */

static app_i2c_status_t convert_hal_status(hal_i2c_status_t hal_status)
{
    switch (hal_status) {
        case HAL_I2C_OK:
            return APP_I2C_OK;
        case HAL_I2C_NACK:
            return APP_I2C_NACK;
        case HAL_I2C_BUSY:
            return APP_I2C_BUSY;
        case HAL_I2C_TIMEOUT:
            return APP_I2C_TIMEOUT;
        default:
            return APP_I2C_ERROR;
    }
}

// static bool is_device_reserved(uint8_t addr)
// {
//     // 检查是否为保留地址
//     return (addr <= 0x07) || (addr >= 0x78 && addr <= 0x7F);
// }