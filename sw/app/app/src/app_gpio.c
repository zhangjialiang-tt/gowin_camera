/**
 * @file app_gpio.c
 * @brief Application-level GPIO implementation
 */

#include <stdlib.h>
#include "app_gpio.h"

/* ========================================== */
/*              私有数据结构                  */
/* ========================================== */

typedef struct app_gpio_instance
{
    hal_gpio_pin_t pin;                   /**< 引脚号 */
    app_gpio_direction_t direction;       /**< 方向 */
    hal_gpio_trigger_t irq_trigger;       /**< 中断触发方式 */
    bool irq_enabled;                     /**< 中断是否启用 */
    app_gpio_irq_callback_t user_callback; /**< 用户中断回调 */
    bool is_initialized;                  /**< 实例是否已初始化 */
} app_gpio_instance_t;

/* ========================================== */
/*              静态变量                      */
/* ========================================== */

static app_gpio_instance_t s_gpio_instances[32] = {0}; // 最大支持32个引脚

/* ========================================== */
/*              私有函数声明                  */
/* ========================================== */

static hal_gpio_status_t configure_pin_irq(app_gpio_handle_t handle);

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

app_gpio_handle_t app_gpio_init(const app_gpio_config_t *config)
{
    if (config == NULL || config->pin >= 32)
    {
        return NULL;
    }

    // 检查引脚是否已被占用
    if (s_gpio_instances[config->pin].is_initialized)
    {
        return NULL;
    }

    // 检查 GPIO 外设是否可用
    if (!hal_gpio_is_available())
    {
        return NULL;
    }

    // 初始化实例
    app_gpio_instance_t *instance = &s_gpio_instances[config->pin];
    instance->pin = config->pin;
    instance->direction = config->direction;
    instance->irq_trigger = config->irq_trigger;
    instance->irq_enabled = config->enable_irq;
    instance->user_callback = NULL;
    instance->is_initialized = true;

    // 设置初始电平（输出模式）
    if (config->direction == APP_GPIO_DIR_OUTPUT)
    {
        hal_gpio_status_t status = hal_gpio_write_pin(config->pin, config->initial_level);
        if (status != HAL_GPIO_OK)
        {
            instance->is_initialized = false;
            return NULL;
        }
    }

    // 配置中断（如果启用）
    if (config->enable_irq)
    {
        hal_gpio_status_t status = configure_pin_irq(instance);
        if (status != HAL_GPIO_OK)
        {
            instance->is_initialized = false;
            return NULL;
        }
    }

    return instance;
}

hal_gpio_status_t app_gpio_deinit(app_gpio_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return HAL_GPIO_ERROR;
    }

    // 禁用中断
    if (handle->irq_enabled)
    {
        hal_gpio_disable_irq(1U << handle->pin);
    }

    // 清除实例状态
    handle->is_initialized = false;
    handle->user_callback = NULL;
    handle->irq_enabled = false;

    return HAL_GPIO_OK;
}

hal_gpio_status_t app_gpio_set_level(app_gpio_handle_t handle, hal_gpio_level_t level)
{
    if (handle == NULL || !handle->is_initialized || 
        handle->direction != APP_GPIO_DIR_OUTPUT)
    {
        return HAL_GPIO_ERROR;
    }

    return hal_gpio_write_pin(handle->pin, level);
}

hal_gpio_status_t app_gpio_get_level(app_gpio_handle_t handle, hal_gpio_level_t *level)
{
    if (handle == NULL || !handle->is_initialized || level == NULL ||
        handle->direction != APP_GPIO_DIR_INPUT)
    {
        return HAL_GPIO_ERROR;
    }

    return hal_gpio_read_pin(handle->pin, level);
}

hal_gpio_status_t app_gpio_toggle(app_gpio_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized || 
        handle->direction != APP_GPIO_DIR_OUTPUT)
    {
        return HAL_GPIO_ERROR;
    }

    return hal_gpio_toggle_pin(handle->pin);
}

hal_gpio_status_t app_gpio_enable_irq(app_gpio_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized || 
        handle->direction != APP_GPIO_DIR_INPUT)
    {
        return HAL_GPIO_ERROR;
    }

    handle->irq_enabled = true;
    return hal_gpio_enable_irq(1U << handle->pin);
}

hal_gpio_status_t app_gpio_disable_irq(app_gpio_handle_t handle)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return HAL_GPIO_ERROR;
    }

    handle->irq_enabled = false;
    return hal_gpio_disable_irq(1U << handle->pin);
}

hal_gpio_status_t app_gpio_register_irq_callback(app_gpio_handle_t handle, app_gpio_irq_callback_t callback)
{
    if (handle == NULL || !handle->is_initialized)
    {
        return HAL_GPIO_ERROR;
    }

    handle->user_callback = callback;
    return HAL_GPIO_OK;
}

hal_gpio_status_t app_gpio_led_on(app_gpio_handle_t handle)
{
    return app_gpio_set_level(handle, HAL_GPIO_HIGH);
}

hal_gpio_status_t app_gpio_led_off(app_gpio_handle_t handle)
{
    return app_gpio_set_level(handle, HAL_GPIO_LOW);
}

hal_gpio_status_t app_gpio_led_toggle(app_gpio_handle_t handle)
{
    return app_gpio_toggle(handle);
}

bool app_gpio_button_is_pressed(app_gpio_handle_t handle)
{
    hal_gpio_level_t level;
    if (app_gpio_get_level(handle, &level) != HAL_GPIO_OK)
    {
        return false;
    }
    return (level == HAL_GPIO_HIGH);
}

bool app_gpio_button_is_released(app_gpio_handle_t handle)
{
    return !app_gpio_button_is_pressed(handle);
}

/* ========================================== */
/*               私有辅助函数                 */
/* ========================================== */

static hal_gpio_status_t configure_pin_irq(app_gpio_handle_t handle)
{
    // 配置中断触发方式
    hal_gpio_status_t status = hal_gpio_config_irq(handle->pin, handle->irq_trigger);
    if (status != HAL_GPIO_OK)
    {
        return status;
    }

    // 启用中断
    return hal_gpio_enable_irq(1U << handle->pin);
}

/* ========================================== */
/*              全局中断处理                  */
/* ========================================== */

/**
 * @brief GPIO 全局中断处理函数
 * @note 这个函数应该在 HAL 层的中断服务例程中被调用
 */
void app_gpio_global_irq_handler(uint32_t pending_mask)
{
    for (int i = 0; i < 32; i++)
    {
        if (pending_mask & (1U << i))
        {
            app_gpio_handle_t handle = &s_gpio_instances[i];
            if (handle->is_initialized && handle->user_callback != NULL)
            {
                handle->user_callback((hal_gpio_pin_t)i);
            }
        }
    }
}