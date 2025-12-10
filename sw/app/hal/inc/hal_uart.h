/**
 * @file hal_uart.h
 * @brief UART HAL interface definition
 */

#ifndef HAL_UART_H
#define HAL_UART_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>

    /* ========================================== */
    /*              类型定义与枚举                */
    /* ========================================== */

    /**
     * @brief UART 端口号定义
     */
    typedef enum
    {
        HAL_UART_PORT_0 = 0,
        HAL_UART_PORT_1 = 1
    } hal_uart_port_t;

    /**
     * @brief UART 数据位定义
     */
    typedef enum
    {
        HAL_UART_DATA_BITS_5 = 5,
        HAL_UART_DATA_BITS_6 = 6,
        HAL_UART_DATA_BITS_7 = 7,
        HAL_UART_DATA_BITS_8 = 8
    } hal_uart_data_bits_t;

    /**
     * @brief UART 停止位定义
     */
    typedef enum
    {
        HAL_UART_STOP_BITS_1 = 1,
        HAL_UART_STOP_BITS_2 = 2
    } hal_uart_stop_bits_t;

    /**
     * @brief UART 校验位定义
     */
    typedef enum
    {
        HAL_UART_PARITY_NONE = 0,
        HAL_UART_PARITY_EVEN = 1,
        HAL_UART_PARITY_ODD = 2
    } hal_uart_parity_t;

    /**
     * @brief UART 中断类型
     */
    typedef enum
    {
        HAL_UART_IRQ_RX_NOT_EMPTY = 0,
        HAL_UART_IRQ_RX_HALF_FULL,
        HAL_UART_IRQ_RX_FULL,
        HAL_UART_IRQ_TX_EMPTY,
        HAL_UART_IRQ_TX_HALF_EMPTY,
        HAL_UART_IRQ_TX_NOT_FULL
    } hal_uart_irq_type_t;

    /**
     * @brief UART 状态码
     */
    typedef enum
    {
        HAL_UART_OK = 0,
        HAL_UART_ERROR = -1,
        HAL_UART_BUSY = -2,
        HAL_UART_TIMEOUT = -3,
        HAL_UART_OVERRUN = -4
    } hal_uart_status_t;

    /**
     * @brief UART 配置结构体
     */
    typedef struct
    {
        uint32_t baudrate;
        hal_uart_data_bits_t data_bits;
        hal_uart_stop_bits_t stop_bits;
        hal_uart_parity_t parity;
        bool hw_flow_control; // RTS/CTS 使能
    } hal_uart_config_t;

    /**
     * @brief UART 中断回调函数指针
     */
    typedef void (*hal_uart_irq_callback_t)(hal_uart_port_t port, hal_uart_irq_type_t irq_type);

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 初始化 UART 模块
     * @param port: UART 端口号
     * @param config: 配置参数
     * @return HAL status
     */
    hal_uart_status_t hal_uart_init(hal_uart_port_t port, const hal_uart_config_t *config);

    /**
     * @brief 检查 UART 是否可用
     * @param port: UART 端口号
     * @return true if available, false otherwise
     */
    bool hal_uart_is_available(hal_uart_port_t port);

    /**
     * @brief 获取 RX FIFO 深度
     * @param port: UART 端口号
     * @return FIFO 深度，返回 0 表示不可用
     */
    uint32_t hal_uart_get_rx_fifo_depth(hal_uart_port_t port);

    /**
     * @brief 获取 TX FIFO 深度
     * @param port: UART 端口号
     * @return FIFO 深度，返回 0 表示不可用
     */
    uint32_t hal_uart_get_tx_fifo_depth(hal_uart_port_t port);

    /**
     * @brief 启用 UART
     * @param port: UART 端口号
     * @return HAL status
     */
    hal_uart_status_t hal_uart_enable(hal_uart_port_t port);

    /**
     * @brief 禁用 UART
     * @param port: UART 端口号
     * @return HAL status
     */
    hal_uart_status_t hal_uart_disable(hal_uart_port_t port);

    /**
     * @brief 发送单个字符
     * @param port: UART 端口号
     * @param data: 要发送的字符
     * @return HAL status
     */
    hal_uart_status_t hal_uart_transmit(hal_uart_port_t port, char data);

    /**
     * @brief 接收单个字符
     * @param port: UART 端口号
     * @param data: 接收到的字符指针
     * @return HAL status
     */
    hal_uart_status_t hal_uart_receive(hal_uart_port_t port, char *data);

    /**
     * @brief 发送字符串
     * @param port: UART 端口号
     * @param str: 要发送的字符串
     * @return HAL status
     */
    hal_uart_status_t hal_uart_transmit_string(hal_uart_port_t port, const char *str);

    /**
     * @brief 格式化输出字符串
     * @param port: UART 端口号
     * @param format: 格式化字符串
     * @param ...: 可变参数
     * @return HAL status
     */
    hal_uart_status_t hal_uart_printf(hal_uart_port_t port, const char *format, ...);

    /**
     * @brief 格式化输出字符串（va_list 版本）
     * @param port: UART 端口号
     * @param format: 格式化字符串
     * @param args: 可变参数列表
     * @return HAL status
     */
    hal_uart_status_t hal_uart_vprintf(hal_uart_port_t port, const char *format, va_list args);

    /**
     * @brief 扫描输入字符串
     * @param port: UART 端口号
     * @param buffer: 缓冲区指针
     * @param max_size: 最大长度
     * @param echo: 是否回显
     * @return 实际读取长度
     */
    int hal_uart_scan(hal_uart_port_t port, char *buffer, int max_size, bool echo);

    /**
     * @brief 清空 RX FIFO
     * @param port: UART 端口号
     * @return HAL status
     */
    hal_uart_status_t hal_uart_flush_rx(hal_uart_port_t port);

    /**
     * @brief 清空 TX FIFO
     * @param port: UART 端口号
     * @return HAL status
     */
    hal_uart_status_t hal_uart_flush_tx(hal_uart_port_t port);

    /**
     * @brief 检查发送器是否忙碌
     * @param port: UART 端口号
     * @return true if busy, false otherwise
     */
    bool hal_uart_is_tx_busy(hal_uart_port_t port);

    /**
     * @brief 检查是否有字符可接收
     * @param port: UART 端口号
     * @return true if available, false otherwise
     */
    bool hal_uart_is_data_available(hal_uart_port_t port);

    /**
     * @brief 启用指定中断
     * @param port: UART 端口号
     * @param irq_type: 中断类型
     * @return HAL status
     */
    hal_uart_status_t hal_uart_irq_enable(hal_uart_port_t port, hal_uart_irq_type_t irq_type);

    /**
     * @brief 禁用指定中断
     * @param port: UART 端口号
     * @param irq_type: 中断类型
     * @return HAL status
     */
    hal_uart_status_t hal_uart_irq_disable(hal_uart_port_t port, hal_uart_irq_type_t irq_type);

    /**
     * @brief 注册中断回调函数
     * @param port: UART 端口号
     * @param callback: 回调函数指针
     * @return HAL status
     */
    hal_uart_status_t hal_uart_register_irq_callback(hal_uart_port_t port, hal_uart_irq_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif /* HAL_UART_H */
