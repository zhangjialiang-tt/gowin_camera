/**
 * @file hal_gpio.h
 * @brief GPIO HAL interface definition for NEORV32
 */

#ifndef HAL_GPIO_H
#define HAL_GPIO_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>
#include "type.h"
    /* ========================================== */
    /*              类型定义与枚举                */
    /* ========================================== */

    /**
     * @brief GPIO 引脚编号定义 (0-31)
     */
    typedef uint8_t hal_gpio_pin_t;

    /**
     * @brief GPIO 引脚电平定义
     */
    typedef enum
    {
        HAL_GPIO_LOW = 0,
        HAL_GPIO_HIGH = 1
    } hal_gpio_level_t;

    /**
     * @brief GPIO 中断触发类型
     */
    typedef enum
    {
        HAL_GPIO_TRIG_LEVEL_LOW = 0,    // 低电平触发
        HAL_GPIO_TRIG_LEVEL_HIGH = 1,   // 高电平触发
        HAL_GPIO_TRIG_EDGE_FALLING = 2, // 下降沿触发
        HAL_GPIO_TRIG_EDGE_RISING = 3   // 上升沿触发
    } hal_gpio_trigger_t;

    /**
     * @brief GPIO 状态码
     */
    typedef enum
    {
        HAL_GPIO_OK = 0,
        HAL_GPIO_ERROR = -1,
        HAL_GPIO_NOT_AVAIL = -2
    } hal_gpio_status_t;

    /**
     * @brief GPIO 中断回调函数指针
     */
    typedef void (*hal_gpio_irq_callback_t)(hal_gpio_pin_t pin);

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 检查 GPIO 模块是否可用
     * @return true if available, false otherwise
     */
    bool hal_gpio_is_available(void);

    /**
     * @brief 设置单个 GPIO 引脚输出电平
     * @param pin: 引脚编号 (0-31)
     * @param level: 电平状态
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_write_pin(hal_gpio_pin_t pin, hal_gpio_level_t level);

    /**
     * @brief 切换单个 GPIO 引脚输出电平
     * @param pin: 引脚编号 (0-31)
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_toggle_pin(hal_gpio_pin_t pin);

    /**
     * @brief 读取单个 GPIO 引脚输入电平
     * @param pin: 引脚编号 (0-31)
     * @param level: 电平状态指针
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_read_pin(hal_gpio_pin_t pin, hal_gpio_level_t *level);

    /**
     * @brief 设置多个 GPIO 引脚输出电平
     * @param pin_mask: 引脚掩码 (bit0对应pin0, bit1对应pin1...)
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_write_port(uint32_t pin_mask);

    /**
     * @brief 切换多个 GPIO 引脚输出电平
     * @param pin_mask: 引脚掩码
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_toggle_port(uint32_t pin_mask);

    /**
     * @brief 读取所有 GPIO 引脚输入电平
     * @param pin_mask: 引脚电平掩码指针
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_read_port(uint32_t *pin_mask);

    /**
     * @brief 配置单个 GPIO 引脚中断触发类型
     * @param pin: 引脚编号 (0-31)
     * @param trigger: 触发类型
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_config_irq(hal_gpio_pin_t pin, hal_gpio_trigger_t trigger);

    /**
     * @brief 启用指定 GPIO 引脚中断
     * @param pin_mask: 引脚掩码
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_enable_irq(uint32_t pin_mask);

    /**
     * @brief 禁用指定 GPIO 引脚中断
     * @param pin_mask: 引脚掩码
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_disable_irq(uint32_t pin_mask);

    /**
     * @brief 获取当前中断状态
     * @param pending_mask: 中断挂起掩码指针
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_get_irq_status(uint32_t *pending_mask);

    /**
     * @brief 清除指定 GPIO 引脚中断标志
     * @param pin_mask: 引脚掩码
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_clear_irq(uint32_t pin_mask);

    /**
     * @brief 注册 GPIO 中断回调函数
     * @param callback: 回调函数指针
     * @return HAL status
     */
    hal_gpio_status_t hal_gpio_register_irq_callback(hal_gpio_irq_callback_t callback);

    void vsync_interrupt_handler(void);
    extern u8 timer0_flag;
#ifdef __cplusplus
}
#endif

#endif /* HAL_GPIO_H */
