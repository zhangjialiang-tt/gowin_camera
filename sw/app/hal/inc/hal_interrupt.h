/**
 * @file hal_interrupt.h
 * @brief Interrupt management HAL interface for NEORV32
 */

#ifndef HAL_INTERRUPT_H
#define HAL_INTERRUPT_H

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
     * @brief 中断状态码
     */
    typedef enum
    {
        HAL_INTERRUPT_OK = 0,
        HAL_INTERRUPT_ERROR = -1,
        HAL_INTERRUPT_NOT_AVAIL = -2
    } hal_interrupt_status_t;

    /**
     * @brief 中断类型枚举
     */
    typedef enum
    {
        HAL_INTERRUPT_GPIO = 0,    // GPIO 中断
        HAL_INTERRUPT_UART0 = 1,   // UART0 中断
        HAL_INTERRUPT_UART1 = 2,   // UART1 中断
        HAL_INTERRUPT_SPI = 3,     // SPI 中断
        HAL_INTERRUPT_TWI = 4,     // TWI 中断
        HAL_INTERRUPT_EXT_INT = 5, // 外部中断
        HAL_INTERRUPT_COUNT = 6    // 中断类型总数
    } hal_interrupt_type_t;

    /**
     * @brief 中断处理函数指针类型
     */
    typedef void (*hal_interrupt_handler_t)(void);

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 初始化中断管理系统
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_init(void);

    /**
     * @brief 注册中断处理函数
     * @param type: 中断类型
     * @param handler: 中断处理函数指针
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_register_handler(hal_interrupt_type_t type, hal_interrupt_handler_t handler);

    /**
     * @brief 启用全局中断
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_enable_global(void);

    /**
     * @brief 禁用全局中断
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_disable_global(void);

    /**
     * @brief 启用指定类型的中断
     * @param type: 中断类型
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_enable(hal_interrupt_type_t type);

    /**
     * @brief 禁用指定类型的中断
     * @param type: 中断类型
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_disable(hal_interrupt_type_t type);

    /**
     * @brief 进入睡眠模式等待中断
     * @return HAL status
     */
    hal_interrupt_status_t hal_interrupt_sleep(void);

#ifdef __cplusplus
}
#endif

#endif /* HAL_INTERRUPT_H */
