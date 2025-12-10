/**
 * @file app_uart.h
 * @brief Application-level UART interface
 */

#ifndef APP_UART_H
#define APP_UART_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>
#include "../../hal/inc/hal_uart.h"

    /* ========================================== */
    /*              类型定义                      */
    /* ========================================== */

    /**
     * @brief 应用UART句柄类型
     */
    typedef struct app_uart_instance *app_uart_handle_t;

    /**
     * @brief 应用UART配置结构体
     */
    typedef struct
    {
        hal_uart_port_t port;     /**< UART端口号 */
        uint32_t baud_rate;       /**< 波特率 */
        hal_uart_parity_t parity; /**< 校验位 */
        bool hw_flow_control;     /**< 硬件流控制 */
    } app_uart_config_t;

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 初始化应用UART
     * @param config: UART配置
     * @return UART句柄
     */
    app_uart_handle_t app_uart_init(const app_uart_config_t *config);

    /**
     * @brief 反初始化应用UART
     * @param handle: UART句柄
     * @return HAL status
     */
    hal_uart_status_t app_uart_deinit(app_uart_handle_t handle);

    /**
     * @brief 打印字符串
     * @param handle: UART句柄
     * @param str: 要打印的字符串
     * @return HAL status
     */
    hal_uart_status_t app_uart_print(app_uart_handle_t handle, const char *str);

    /**
     * @brief 打印格式化字符串
     * @param handle: UART句柄
     * @param format: 格式字符串
     * @param ...: 可变参数
     * @return HAL status
     */
    hal_uart_status_t app_uart_printf(app_uart_handle_t handle, const char *format, ...);

    /**
     * @brief 打印十六进制字节
     * @param handle: UART句柄
     * @param data: 要打印的字节
     * @return HAL status
     */
    hal_uart_status_t app_uart_print_hex_byte(app_uart_handle_t handle, uint8_t data);

    /**
     * @brief 打印十六进制缓冲区
     * @param handle: UART句柄
     * @param data: 数据缓冲区
     * @param length: 数据长度
     * @return HAL status
     */
    hal_uart_status_t app_uart_print_hex_buffer(app_uart_handle_t handle, const uint8_t *data, uint16_t length);

    /**
     * @brief 读取字符
     * @param handle: UART句柄
     * @param data: 接收数据指针
     * @return HAL status
     */
    hal_uart_status_t app_uart_getc(app_uart_handle_t handle, char *data);

    /**
     * @brief 检查是否有数据可读
     * @param handle: UART句柄
     * @return true if data available, false otherwise
     */
    bool app_uart_data_available(app_uart_handle_t handle);

    /**
     * @brief 扫描输入字符串
     * @param handle: UART句柄
     * @param buffer: 缓冲区指针
     * @param max_size: 最大长度
     * @param echo: 是否回显
     * @return 实际读取长度
     */
    int app_uart_scan(app_uart_handle_t handle, char *buffer, int max_size, bool echo);

#ifdef __cplusplus
}
#endif

#endif /* APP_UART_H */
