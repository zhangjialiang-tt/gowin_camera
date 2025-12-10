/**
 * @file hal_gpio.c
 * @brief GPIO HAL implementation for NEORV32
 */
#include "../../inc/system.h"
// #include "hal_gpio.h"
// #include "hal_interrupt.h"
// #include "../../lib/include/neorv32_gpio.h" // 引入底层 BSP 接口
// #include "../../lib/include/neorv32.h"      // 引入底层 BSP 接口

/* ========================================== */
/*              私有变量与宏定义              */
/* ========================================== */

// GPIO 中断回调函数指针
static hal_gpio_irq_callback_t s_gpio_irq_callback = NULL;
u8 timer0_flag = 0;
// 全局定时器计数
volatile uint32_t timer0_count = 0;
// 引脚有效性检查宏
#define IS_VALID_PIN(pin) ((pin) < 32)

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

bool hal_gpio_is_available(void)
{
    return (neorv32_gpio_available() != 0);
}

hal_gpio_status_t hal_gpio_write_pin(hal_gpio_pin_t pin, hal_gpio_level_t level)
{
    if (!IS_VALID_PIN(pin))
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_pin_set(pin, level);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_toggle_pin(hal_gpio_pin_t pin)
{
    if (!IS_VALID_PIN(pin))
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_pin_toggle(pin);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_read_pin(hal_gpio_pin_t pin, hal_gpio_level_t *level)
{
    if (!IS_VALID_PIN(pin) || level == NULL)
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    *level = (hal_gpio_level_t)neorv32_gpio_pin_get(pin);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_write_port(uint32_t pin_mask)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_port_set(pin_mask);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_toggle_port(uint32_t pin_mask)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_port_toggle(pin_mask);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_read_port(uint32_t *pin_mask)
{
    if (pin_mask == NULL)
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    *pin_mask = neorv32_gpio_port_get();
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_config_irq(hal_gpio_pin_t pin, hal_gpio_trigger_t trigger)
{
    if (!IS_VALID_PIN(pin))
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    // 将 HAL 触发类型映射到 NEORV32 枚举
    int neorv32_trigger;
    switch (trigger)
    {
    case HAL_GPIO_TRIG_LEVEL_LOW:
        neorv32_trigger = GPIO_TRIG_LEVEL_LOW;
        break;
    case HAL_GPIO_TRIG_LEVEL_HIGH:
        neorv32_trigger = GPIO_TRIG_LEVEL_HIGH;
        break;
    case HAL_GPIO_TRIG_EDGE_FALLING:
        neorv32_trigger = GPIO_TRIG_EDGE_FALLING;
        break;
    case HAL_GPIO_TRIG_EDGE_RISING:
        neorv32_trigger = GPIO_TRIG_EDGE_RISING;
        break;
    default:
        return HAL_GPIO_ERROR;
    }

    neorv32_gpio_irq_setup(pin, neorv32_trigger);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_enable_irq(uint32_t pin_mask)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_irq_enable(pin_mask);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_disable_irq(uint32_t pin_mask)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_irq_disable(pin_mask);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_get_irq_status(uint32_t *pending_mask)
{
    if (pending_mask == NULL)
    {
        return HAL_GPIO_ERROR;
    }

    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    *pending_mask = neorv32_gpio_irq_get();
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_clear_irq(uint32_t pin_mask)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    neorv32_gpio_irq_clr(pin_mask);
    return HAL_GPIO_OK;
}

hal_gpio_status_t hal_gpio_register_irq_callback(hal_gpio_irq_callback_t callback)
{
    if (!hal_gpio_is_available())
    {
        return HAL_GPIO_NOT_AVAIL;
    }

    s_gpio_irq_callback = callback;
    return HAL_GPIO_OK;
}

/* ========================================== */
/*            中断服务例程(ISR)               */
/* ========================================== */

/**
 * @brief GPIO 中断服务例程
 * @note 这个函数将被 HAL_INTERRUPT 调用
 */
void hal_gpio_irq_handler(void)
{
    // 获取当前中断状态
    uint32_t pending = neorv32_gpio_irq_get();

    // 调用用户注册的回调函数
    if (s_gpio_irq_callback != NULL)
    {
        // 遍历所有挂起的中断引脚
        for (int i = 0; i < 32; i++)
        {
            if (pending & (1U << i))
            {
                s_gpio_irq_callback((hal_gpio_pin_t)i);
            }
        }
    }

    // 清除所有中断标志
    neorv32_gpio_irq_clr(-1);
}
void hal_frame_interrupt_init(void) 
{
    hal_gpio_config_irq(0,HAL_GPIO_TRIG_EDGE_RISING);//初始化GPIO中断，触发方式为上升沿触发
    neorv32_gpio_irq_enable(1 << 0);
}

// 场中断处理函数
void vsync_interrupt_handler(void) {
   
    // 获取pending的中断
    uint32_t pending = neorv32_gpio_irq_get();
      // 检查GPIO1的中断
    if (pending & (1 << 1)) {
        // 处理GPIO1中断事件
        st_api.usb_rx_interrupt();
        
        // 清除GPIO1中断标志
        neorv32_gpio_irq_clr(1 << 1);
    }
    
    // 检查是否是GPIO0的中断（场中断）
    if (pending & (1 << 0)) {
        // frame_count++;
        timer0_flag = 1;
        timer0_count += 20;
        // 处理场同步事件
        // 清除中断标志
        neorv32_gpio_irq_clr(1 << 0);
    }

   
}