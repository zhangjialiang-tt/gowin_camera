/**
 * @file hal_interrupt.c
 * @brief Interrupt management HAL implementation for NEORV32
 */

#include "../inc/hal_interrupt.h"
#include "../../inc/system.h"
// #include "../../lib/include/neorv32.h" // 引入底层 BSP 接口

/* ========================================== */
/*              私有变量与宏定义              */
/* ========================================== */

// 中断处理函数指针数组
static hal_interrupt_handler_t s_interrupt_handlers[HAL_INTERRUPT_COUNT] = {NULL};

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

hal_interrupt_status_t hal_interrupt_init(void)
{
    // 初始化 NEORV32 RTE (运行时环境)
    neorv32_rte_setup();
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_register_handler(hal_interrupt_type_t type, hal_interrupt_handler_t handler)
{
    if (type >= HAL_INTERRUPT_COUNT || handler == NULL)
    {
        return HAL_INTERRUPT_ERROR;
    }

    switch (type)
    {
    case HAL_INTERRUPT_GPIO:
        neorv32_rte_handler_install(GPIO_TRAP_CODE, handler);
        break;
    case HAL_INTERRUPT_UART0:
        neorv32_rte_handler_install(UART0_TRAP_CODE, handler);
        break;
    case HAL_INTERRUPT_UART1:
        neorv32_rte_handler_install(UART1_TRAP_CODE, handler);
        break;
    case HAL_INTERRUPT_SPI:
        neorv32_rte_handler_install(SPI_TRAP_CODE, handler);
        break;
    case HAL_INTERRUPT_TWI:
        neorv32_rte_handler_install(TWI_TRAP_CODE, handler);
        break;
    case HAL_INTERRUPT_EXT_INT:
        neorv32_rte_handler_install(GPIO_TRAP_CODE, handler);
        break;
    default:
        return HAL_INTERRUPT_ERROR;
    }

    s_interrupt_handlers[type] = handler;
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_enable_global(void)
{
    // 启用机器模式中断
    neorv32_cpu_csr_set(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_disable_global(void)
{
    // 禁用机器模式中断
    neorv32_cpu_csr_clr(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_enable(hal_interrupt_type_t type)
{
    uint32_t irq_mask = 0;

    switch (type)
    {
    case HAL_INTERRUPT_GPIO:
        irq_mask = 1 << GPIO_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_UART0:
        irq_mask = 1 << UART0_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_UART1:
        irq_mask = 1 << UART1_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_SPI:
        irq_mask = 1 << SPI_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_TWI:
        irq_mask = 1 << TWI_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_EXT_INT:
        irq_mask = 1 << GPIO_FIRQ_ENABLE;
        break;
    default:
        return HAL_INTERRUPT_ERROR;
    }

    // 启用指定的快速中断通道
    neorv32_cpu_csr_set(CSR_MIE, irq_mask);
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_disable(hal_interrupt_type_t type)
{
    uint32_t irq_mask = 0;

    switch (type)
    {
    case HAL_INTERRUPT_GPIO:
        irq_mask = 1 << GPIO_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_UART0:
        irq_mask = 1 << UART0_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_UART1:
        irq_mask = 1 << UART1_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_SPI:
        irq_mask = 1 << SPI_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_TWI:
        irq_mask = 1 << TWI_FIRQ_ENABLE;
        break;
    case HAL_INTERRUPT_EXT_INT:
        irq_mask = 1 << GPIO_FIRQ_ENABLE;
        break;
    default:
        return HAL_INTERRUPT_ERROR;
    }

    // 禁用指定的快速中断通道
    neorv32_cpu_csr_clr(CSR_MIE, irq_mask);
    return HAL_INTERRUPT_OK;
}

hal_interrupt_status_t hal_interrupt_sleep(void)
{
    // 进入睡眠模式等待中断
    neorv32_cpu_sleep();
    return HAL_INTERRUPT_OK;
}
