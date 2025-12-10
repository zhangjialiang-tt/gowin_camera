/**
 * @file hal_uart.c
 * @brief UART HAL implementation for NEORV32
 */

#include "../inc/hal_uart.h"
// #include "../../lib/include/neorv32_uart.h" // 引入底层 BSP 接口
#include "../../inc/system.h"      // 引入底层 BSP 接口
#include <string.h>
#include <stdio.h>

/* ========================================== */
/*              私有变量与宏定义              */
/* ========================================== */

// 最大支持的 UART 端口数
#define HAL_UART_MAX_PORTS 2

// 中断回调函数数组
static hal_uart_irq_callback_t s_uart_irq_callbacks[HAL_UART_MAX_PORTS] = {NULL};

// UART 端口映射表
static neorv32_uart_t *const s_uart_handles[HAL_UART_MAX_PORTS] = {
    NEORV32_UART0,
    NEORV32_UART1};

/* ========================================== */
/*              私有辅助函数                  */
/* ========================================== */

/**
 * @brief 检查端口号是否合法
 */
static inline bool is_valid_port(hal_uart_port_t port)
{
    return (port < HAL_UART_MAX_PORTS);
}

/**
 * @brief NEORV32 特定的波特率计算函数
 */
// static uint32_t calculate_baud_divisor(uint32_t baudrate)
// {
//     // 假设系统时钟为 100MHz，实际应从配置或系统信息获取

//     uint32_t sys_clk = neorv32_sysinfo_get_clk(); // 100000000UL;
//     return sys_clk / (baudrate * 8) - 1;
// }

/**
 * @brief NEORV32 特定的中断类型映射
 */
static uint32_t map_irq_type_to_bit(hal_uart_irq_type_t irq_type)
{
    switch (irq_type)
    {
    case HAL_UART_IRQ_RX_NOT_EMPTY:
        return 1U << UART_CTRL_IRQ_RX_NEMPTY;
    // case HAL_UART_IRQ_RX_HALF_FULL:
    //     return 1U << UART_CTRL_IRQ_RX_HALF;
    case HAL_UART_IRQ_RX_FULL:
        return 1U << UART_CTRL_IRQ_RX_FULL;
    case HAL_UART_IRQ_TX_EMPTY:
        return 1U << UART_CTRL_IRQ_TX_EMPTY;
    // case HAL_UART_IRQ_TX_HALF_EMPTY:
    //     return 1U << UART_CTRL_IRQ_TX_NHALF;
    case HAL_UART_IRQ_TX_NOT_FULL:
        return 1U << UART_CTRL_IRQ_TX_NFULL;
    default:
        return 0;
    }
}

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */
hal_uart_status_t hal_uart_init(hal_uart_port_t port, const hal_uart_config_t *config)
{
    if (!is_valid_port(port) || config == NULL)
    {
        return HAL_UART_ERROR;
    }
    neorv32_uart_t *uart = s_uart_handles[port];

    // 禁用 UART
    neorv32_uart_disable(uart);

    // 直接传递标准波特率值，让 NEORV32 内部处理
    neorv32_uart_setup(uart, config->baudrate, 0);

    // 设置硬件流控
    if (config->hw_flow_control)
    {
        neorv32_uart_rtscts_enable(uart);
    }
    else
    {
        neorv32_uart_rtscts_disable(uart);
    }

    // 启用 UART
    neorv32_uart_enable(uart);

    return HAL_UART_OK;
}

bool hal_uart_is_available(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return false;
    }

    return neorv32_uart_available(s_uart_handles[port]);
}

uint32_t hal_uart_get_rx_fifo_depth(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return 0;
    }

    return neorv32_uart_get_rx_fifo_depth(s_uart_handles[port]);
}

uint32_t hal_uart_get_tx_fifo_depth(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return 0;
    }

    return neorv32_uart_get_tx_fifo_depth(s_uart_handles[port]);
}

hal_uart_status_t hal_uart_enable(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    neorv32_uart_enable(s_uart_handles[port]);
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_disable(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    neorv32_uart_disable(s_uart_handles[port]);
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_transmit(hal_uart_port_t port, char data)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    // 等待直到发送 FIFO 有空间（简化处理）
    while (!neorv32_uart_tx_free(s_uart_handles[port]))
    {
        // 可添加超时处理
    }

    neorv32_uart_tx_put(s_uart_handles[port], data);
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_receive(hal_uart_port_t port, char *data)
{
    if (!is_valid_port(port) || data == NULL)
    {
        return HAL_UART_ERROR;
    }

    // 检查是否有数据可接收
    if (!neorv32_uart_char_received(s_uart_handles[port]))
    {
        return HAL_UART_TIMEOUT;
    }

    *data = neorv32_uart_char_received_get(s_uart_handles[port]);
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_transmit_string(hal_uart_port_t port, const char *str)
{
    if (!is_valid_port(port) || str == NULL)
    {
        return HAL_UART_ERROR;
    }

    while (*str)
    {
        hal_uart_status_t status = hal_uart_transmit(port, *str++);
        if (status != HAL_UART_OK)
        {
            return status;
        }
    }

    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_printf(hal_uart_port_t port, const char *format, ...)
{
    if (!is_valid_port(port) || format == NULL)
    {
        return HAL_UART_ERROR;
    }

    va_list args;
    va_start(args, format);
    hal_uart_status_t result = hal_uart_vprintf(port, format, args);
    va_end(args);

    return result;
}

hal_uart_status_t hal_uart_vprintf(hal_uart_port_t port, const char *format, va_list args)
{
    if (!is_valid_port(port) || format == NULL)
    {
        return HAL_UART_ERROR;
    }

    // 使用 NEORV32 的 vprintf 实现
    neorv32_uart_vprintf(s_uart_handles[port], format, args);
    return HAL_UART_OK;
}

int hal_uart_scan(hal_uart_port_t port, char *buffer, int max_size, bool echo)
{
    if (!is_valid_port(port) || buffer == NULL || max_size <= 0)
    {
        return -1;
    }

    return neorv32_uart_scan(s_uart_handles[port], buffer, max_size, echo ? 1 : 0);
}

hal_uart_status_t hal_uart_flush_rx(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    // neorv32_uart_rx_clear(s_uart_handles[port]);
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_flush_tx(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    // neorv32_uart_tx_clear(s_uart_handles[port]);
    return HAL_UART_OK;
}

bool hal_uart_is_tx_busy(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return false;
    }

    return neorv32_uart_tx_busy(s_uart_handles[port]) != 0;
}

bool hal_uart_is_data_available(hal_uart_port_t port)
{
    if (!is_valid_port(port))
    {
        return false;
    }

    return neorv32_uart_char_received(s_uart_handles[port]) != 0;
}

hal_uart_status_t hal_uart_irq_enable(hal_uart_port_t port, hal_uart_irq_type_t irq_type)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    uint32_t irq_bit = map_irq_type_to_bit(irq_type);
    if (irq_bit == 0)
    {
        return HAL_UART_ERROR;
    }

    s_uart_handles[port]->CTRL |= irq_bit;
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_irq_disable(hal_uart_port_t port, hal_uart_irq_type_t irq_type)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    uint32_t irq_bit = map_irq_type_to_bit(irq_type);
    if (irq_bit == 0)
    {
        return HAL_UART_ERROR;
    }

    s_uart_handles[port]->CTRL &= ~irq_bit;
    return HAL_UART_OK;
}

hal_uart_status_t hal_uart_register_irq_callback(hal_uart_port_t port, hal_uart_irq_callback_t callback)
{
    if (!is_valid_port(port))
    {
        return HAL_UART_ERROR;
    }

    s_uart_irq_callbacks[port] = callback;
    return HAL_UART_OK;
}

/* ========================================== */
/*            中断服务例程(ISR)               */
/* ========================================== */

/**
 * @brief UART0 中断服务例程
 * @note 实际使用时应根据芯片具体中断向量表进行映射
 */
void HAL_UART0_IRQHandler(void)
{
    if (s_uart_irq_callbacks[HAL_UART_PORT_0] != NULL)
    {
        neorv32_uart_t *uart = NEORV32_UART0;
        uint32_t ctrl = uart->CTRL;

        if (ctrl & (1U << UART_CTRL_IRQ_RX_NEMPTY))
        {
            s_uart_irq_callbacks[HAL_UART_PORT_0](HAL_UART_PORT_0, HAL_UART_IRQ_RX_NOT_EMPTY);
        }
        if (ctrl & (1U << UART_CTRL_IRQ_TX_EMPTY))
        {
            s_uart_irq_callbacks[HAL_UART_PORT_0](HAL_UART_PORT_0, HAL_UART_IRQ_TX_EMPTY);
        }
        // 其他中断类型可类似处理
    }
}

/**
 * @brief UART1 中断服务例程
 * @note 实际使用时应根据芯片具体中断向量表进行映射
 */
void HAL_UART1_IRQHandler(void)
{
    if (s_uart_irq_callbacks[HAL_UART_PORT_1] != NULL)
    {
        neorv32_uart_t *uart = NEORV32_UART1;
        uint32_t ctrl = uart->CTRL;

        if (ctrl & (1U << UART_CTRL_IRQ_RX_NEMPTY))
        {
            s_uart_irq_callbacks[HAL_UART_PORT_1](HAL_UART_PORT_1, HAL_UART_IRQ_RX_NOT_EMPTY);
        }
        if (ctrl & (1U << UART_CTRL_IRQ_TX_EMPTY))
        {
            s_uart_irq_callbacks[HAL_UART_PORT_1](HAL_UART_PORT_1, HAL_UART_IRQ_TX_EMPTY);
        }
        // 其他中断类型可类似处理
    }
}
