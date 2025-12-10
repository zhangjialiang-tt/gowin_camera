/**
 * @file app_uart.c
 * @brief Application-level UART implementation
 */

#include "../inc/app_uart.h"

#include <stdarg.h>
#include <string.h>

/* ========================================== */
/*              私有数据结构                  */
/* ========================================== */

typedef struct app_uart_instance
{
    hal_uart_port_t port;
    bool is_initialized;
} app_uart_instance_t;

/* ========================================== */
/*              静态变量                      */
/* ========================================== */

static app_uart_instance_t s_uart_instances[2] = {{0}}; // 最多支持2个UART端口

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

app_uart_handle_t app_uart_init(const app_uart_config_t *config)
{
    if (config == NULL)
    {
        return NULL;
    }

    // 检查端口是否已被使用
    if (s_uart_instances[config->port].is_initialized)
    {
        return NULL;
    }

    // 配置HAL层
    hal_uart_config_t hal_config = {
        .baudrate = config->baud_rate,
        .data_bits = HAL_UART_DATA_BITS_8,
        .stop_bits = HAL_UART_STOP_BITS_1,
        .parity = config->parity,
        .hw_flow_control = config->hw_flow_control};

    hal_uart_status_t result = hal_uart_init(config->port, &hal_config);
    if (result != HAL_UART_OK)
    {
        return NULL;
    }

    // 使能UART
    hal_uart_enable(config->port);

    // 初始化实例
    s_uart_instances[config->port].port = config->port;
    s_uart_instances[config->port].is_initialized = true;

    return &s_uart_instances[config->port];
}

hal_uart_status_t app_uart_deinit(app_uart_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return HAL_UART_ERROR;
    }

    hal_uart_status_t result = hal_uart_disable(handle->port);
    handle->is_initialized = false;

    return result;
}

hal_uart_status_t app_uart_print(app_uart_handle_t handle, const char *str)
{
    if (handle == NULL || !handle->is_initialized || str == NULL)
    {
        return HAL_UART_ERROR;
    }

    return hal_uart_transmit_string(handle->port, str);
}

hal_uart_status_t app_uart_printf(app_uart_handle_t handle, const char *format, ...)
{
    if (handle == NULL || !handle->is_initialized || format == NULL)
    {
        return HAL_UART_ERROR;
    }

    va_list args;
    va_start(args, format);
    hal_uart_status_t result = hal_uart_vprintf(handle->port, format, args);
    va_end(args);

    return result;
}

hal_uart_status_t app_uart_print_hex_byte(app_uart_handle_t handle, uint8_t data)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return HAL_UART_ERROR;
    }

    static const char hex_chars[] = "0123456789ABCDEF";
    char hex_str[3];
    hex_str[0] = hex_chars[(data >> 4) & 0x0F];
    hex_str[1] = hex_chars[data & 0x0F];
    hex_str[2] = '\0';

    return hal_uart_transmit_string(handle->port, hex_str);
}

hal_uart_status_t app_uart_print_hex_buffer(app_uart_handle_t handle, const uint8_t *data, uint16_t length)
{
    if (handle == NULL || !handle->is_initialized || data == NULL)
    {
        return HAL_UART_ERROR;
    }

    hal_uart_status_t result = HAL_UART_OK;

    for (uint16_t i = 0; i < length; i++)
    {
        if (i > 0)
        {
            result = hal_uart_transmit(handle->port, ' ');
            if (result != HAL_UART_OK)
            {
                return result;
            }
        }
        result = app_uart_print_hex_byte(handle, data[i]);
        if (result != HAL_UART_OK)
        {
            return result;
        }
    }

    return HAL_UART_OK;
}

hal_uart_status_t app_uart_getc(app_uart_handle_t handle, char *data)
{
    if (handle == NULL || !handle->is_initialized || data == NULL)
    {
        return HAL_UART_ERROR;
    }

    return hal_uart_receive(handle->port, data);
}

bool app_uart_data_available(app_uart_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return false;
    }

    return hal_uart_is_data_available(handle->port);
}

int app_uart_scan(app_uart_handle_t handle, char *buffer, int max_size, bool echo)
{
    if (handle == NULL || !handle->is_initialized || buffer == NULL || max_size <= 0)
    {
        return -1;
    }

    return hal_uart_scan(handle->port, buffer, max_size, echo);
}
