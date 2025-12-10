/**
 * @file app_gpio.h
 * @brief Application-level GPIO interface
 */

#ifndef APP_GPIO_H
#define APP_GPIO_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stdbool.h>
#include "../../inc/system.h"

    /* ========================================== */
    /*              类型定义                      */
    /* ========================================== */

    /**
     * @brief 应用GPIO句柄类型
     */
    typedef struct app_gpio_instance *app_gpio_handle_t;

    /**
     * @brief GPIO方向定义
     */
    typedef enum
    {
        APP_GPIO_DIR_INPUT = 0,  /**< 输入模式 */
        APP_GPIO_DIR_OUTPUT = 1  /**< 输出模式 */
    } app_gpio_direction_t;

    /**
     * @brief GPIO上拉/下拉配置
     */
    typedef enum
    {
        APP_GPIO_PULL_NONE = 0,  /**< 无上拉下拉 */
        APP_GPIO_PULL_UP = 1,    /**< 上拉 */
        APP_GPIO_PULL_DOWN = 2   /**< 下拉 */
    } app_gpio_pull_t;

    /**
     * @brief 应用GPIO配置结构体
     */
    typedef struct
    {
        hal_gpio_pin_t pin;               /**< GPIO引脚号 */
        app_gpio_direction_t direction;   /**< 引脚方向 */
        hal_gpio_level_t initial_level;   /**< 初始电平（输出模式有效） */
        app_gpio_pull_t pull;             /**< 上拉/下拉配置 */
        hal_gpio_trigger_t irq_trigger;   /**< 中断触发方式 */
        bool enable_irq;                  /**< 是否启用中断 */
    } app_gpio_config_t;

    /**
     * @brief GPIO中断回调函数类型
     */
    typedef void (*app_gpio_irq_callback_t)(hal_gpio_pin_t pin);

    /* ========================================== */
    /*                API 函数声明                */
    /* ========================================== */

    /**
     * @brief 初始化应用GPIO
     * @param config: GPIO配置
     * @return GPIO句柄
     */
    app_gpio_handle_t app_gpio_init(const app_gpio_config_t *config);

    /**
     * @brief 反初始化应用GPIO
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_deinit(app_gpio_handle_t handle);

    /**
     * @brief 设置GPIO输出电平
     * @param handle: GPIO句柄
     * @param level: 输出电平
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_set_level(app_gpio_handle_t handle, hal_gpio_level_t level);

    /**
     * @brief 读取GPIO输入电平
     * @param handle: GPIO句柄
     * @param level: 电平读取指针
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_get_level(app_gpio_handle_t handle, hal_gpio_level_t *level);

    /**
     * @brief 翻转GPIO输出电平
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_toggle(app_gpio_handle_t handle);

    /**
     * @brief 启用GPIO中断
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_enable_irq(app_gpio_handle_t handle);

    /**
     * @brief 禁用GPIO中断
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_disable_irq(app_gpio_handle_t handle);

    /**
     * @brief 注册GPIO中断回调函数
     * @param handle: GPIO句柄
     * @param callback: 中断回调函数
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_register_irq_callback(app_gpio_handle_t handle, app_gpio_irq_callback_t callback);

    /**
     * @brief 点亮LED（输出高电平）
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_led_on(app_gpio_handle_t handle);

    /**
     * @brief 关闭LED（输出低电平）
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_led_off(app_gpio_handle_t handle);

    /**
     * @brief 翻转LED状态
     * @param handle: GPIO句柄
     * @return HAL status
     */
    hal_gpio_status_t app_gpio_led_toggle(app_gpio_handle_t handle);

    /**
     * @brief 检查按钮是否按下（输入高电平）
     * @param handle: GPIO句柄
     * @return true if button pressed, false otherwise
     */
    bool app_gpio_button_is_pressed(app_gpio_handle_t handle);

    /**
     * @brief 检查按钮是否释放（输入低电平）
     * @param handle: GPIO句柄
     * @return true if button released, false otherwise
     */
    bool app_gpio_button_is_released(app_gpio_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif /* APP_GPIO_H */