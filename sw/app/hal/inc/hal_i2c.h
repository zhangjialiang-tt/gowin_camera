/**
 * @file hal_i2c.h
 * @brief I2C HAL interface for NEORV32 TWI controller
 */

#ifndef HAL_I2C_H
#define HAL_I2C_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>

    /* ========================================== */
    /*              类型定义与枚举                */
    /* ========================================== */

    /**
     * @brief I2C 状态码
     */
    typedef enum
    {
        HAL_I2C_OK = 0,         /**< 操作成功 */
        HAL_I2C_ERROR = -1,     /**< 一般错误 */
        HAL_I2C_NOT_AVAIL = -2, /**< I2C控制器不可用 */
        HAL_I2C_BUSY = -3,      /**< 总线忙 */
        HAL_I2C_TIMEOUT = -4,   /**< 超时 */
        HAL_I2C_NACK = -5,      /**< NACK 错误 */
        HAL_I2C_ARBIT_LOST = -6 /**< 仲裁丢失 */
    } hal_i2c_status_t;

    /**
     * @brief I2C 时钟速度
     */
    typedef enum
    {
        HAL_I2C_SPEED_STANDARD = 100000,  /**< 标准模式 100 kHz */
        HAL_I2C_SPEED_FAST = 400000,      /**< 快速模式 400 kHz */
        HAL_I2C_SPEED_FAST_PLUS = 1000000 /**< 快速模式+ 1 MHz */
    } hal_i2c_speed_t;

    /**
     * @brief I2C 地址模式
     */
    typedef enum
    {
        HAL_I2C_ADDR_7BIT = 0, /**< 7位地址模式 */
        HAL_I2C_ADDR_10BIT = 1 /**< 10位地址模式 */
    } hal_i2c_addr_mode_t;

    /**
     * @brief I2C 配置结构体
     */
    typedef struct
    {
        hal_i2c_speed_t speed;         /**< I2C 时钟速度 */
        hal_i2c_addr_mode_t addr_mode; /**< 地址模式 */
        bool clock_stretch;            /**< 是否允许时钟拉伸 */
        uint8_t slave_addr;            /**< 从设备地址(7位) */
    } hal_i2c_config_t;

    /**
     * @brief I2C 传输方向
     */
    typedef enum
    {
        HAL_I2C_DIRECTION_WRITE = 0, /**< 写操作 */
        HAL_I2C_DIRECTION_READ = 1   /**< 读操作 */
    } hal_i2c_direction_t;

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 检查 I2C 控制器是否可用
     * @return true if available, false otherwise
     */
    bool hal_i2c_is_available(void);

    /**
     * @brief 初始化 I2C 控制器
     * @param config: I2C 配置参数
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_init(const hal_i2c_config_t *config);

    /**
     * @brief 复位 I2C 控制器
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_deinit(void);

    /**
     * @brief 使能 I2C 控制器
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_enable(void);

    /**
     * @brief 禁用 I2C 控制器
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_disable(void);

    /**
     * @brief 检查 I2C 总线是否忙
     * @return true if busy, false otherwise
     */
    bool hal_i2c_is_busy(void);

    /**
     * @brief 获取 FIFO 深度
     * @return FIFO depth (0 if not available)
     */
    int hal_i2c_get_fifo_depth(void);

    /**
     * @brief 生成 START 条件
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_generate_start(void);

    /**
     * @brief 生成 STOP 条件
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_generate_stop(void);

    /**
     * @brief 发送单个字节
     * @param data: 要发送的数据
     * @param send_ack: 是否发送ACK(true)/NACK(false)
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_send_byte(uint8_t data, bool send_ack);

    /**
     * @brief 接收单个字节
     * @param data: 接收到的数据指针
     * @param send_ack: 是否发送ACK(true)/NACK(false)
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_receive_byte(uint8_t *data, bool send_ack);

    /**
     * @brief I2C 主机写操作
     * @param slave_addr: 从设备地址
     * @param data: 要写入的数据缓冲区
     * @param size: 数据大小
     * @param timeout_ms: 超时时间(毫秒)
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_master_write(uint8_t slave_addr, const uint8_t *data, uint16_t size, uint32_t timeout_ms);

    /**
     * @brief I2C 主机读操作
     * @param slave_addr: 从设备地址
     * @param data: 读取数据的缓冲区
     * @param size: 要读取的数据大小
     * @param timeout_ms: 超时时间(毫秒)
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_master_read(uint8_t slave_addr, uint8_t *data, uint16_t size, uint32_t timeout_ms);

    /**
     * @brief I2C 主机写-读操作(复合传输)
     * @param slave_addr: 从设备地址
     * @param write_data: 要写入的数据缓冲区
     * @param write_size: 写入数据大小
     * @param read_data: 读取数据的缓冲区
     * @param read_size: 要读取的数据大小
     * @param timeout_ms: 超时时间(毫秒)
     * @return HAL status
     */
    hal_i2c_status_t hal_i2c_master_write_read(uint8_t slave_addr,
                                               const uint8_t *write_data, uint16_t write_size,
                                               uint8_t *read_data, uint16_t read_size,
                                               uint32_t timeout_ms);

    /**
     * @brief 检查从设备是否存在
     * @param slave_addr: 从设备地址
     * @return HAL status (HAL_I2C_OK 表示设备存在)
     */
    hal_i2c_status_t hal_i2c_probe_device(uint8_t slave_addr);

    /**
     * @brief 获取 SCL 线路状态
     * @return true if SCL is high, false if low
     */
    bool hal_i2c_get_scl_state(void);

    /**
     * @brief 获取 SDA 线路状态
     * @return true if SDA is high, false if low
     */
    bool hal_i2c_get_sda_state(void);

    /**
     * @brief 微秒级延时函数
     * @param us: 延时微秒数
     */
    void hal_i2c_delay_us(uint32_t us);

    /**
     * @brief 毫秒级延时函数
     * @param ms: 延时毫秒数
     */
    void hal_i2c_delay_ms(uint32_t ms);

    /**
     * @brief 扫描I2C总线上的设备
     * @param found_devices: 存储找到的设备地址的数组
     * @param max_devices: 数组最大大小
     * @return 找到的设备数量
     */
    int hal_i2c_bus_scan(uint8_t *found_devices, int max_devices);

    hal_i2c_status_t hal_i2c_probe_device_timeout(uint8_t slave_addr, uint32_t timeout_ms);

#ifdef __cplusplus
}
#endif

#endif /* HAL_I2C_H */
