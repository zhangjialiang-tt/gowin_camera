/**
 * @file app_sensor.c
 * @brief Application-level implementation for IR sensor communication over I2C
 */
#include "../../inc/system.h"

// === 配置宏 ===
#define IR_ADDR_BASE (0x2C)
#define IR_ADDR_WRITE ((IR_ADDR_BASE << 1) | 0x00)
#define IR_ADDR_READ ((IR_ADDR_BASE << 1) | 0x01)

// === 内部辅助函数 ===

// === 内部辅助函数 ===
/* 延迟 TWI tick */
// static void app_sensor_delay_ticks(int tick_count)
// {
//     for (int i = 0; i < tick_count; i++)
//     {
//         while (NEORV32_TWI->CTRL & (1 << TWI_CTRL_TX_FULL))
//             ;
//         NEORV32_TWI->DCMD = (uint32_t)(TWI_CMD_NOP << TWI_DCMD_CMD_LO);
//     }
//     while (NEORV32_TWI->CTRL & (1 << TWI_CTRL_BUSY))
//         ;
// }

app_sensor_status_t app_sensor_init(void)
{
    if (neorv32_twi_available() == 0)
    {
        DEBUG_INFO("function dev_i2c_init : I2C unavailable\r\n");
        return -1;
    }
    neorv32_twi_setup(CLK_PRSC_128, 16, 0);
    neorv32_twi_enable();
    return 0;
}

/**
 * @brief 向 IR 传感器指定寄存器写入数据
 */
app_sensor_status_t app_sensor_write_reg(uint8_t reg, uint8_t data)
{
    neorv32_twi_generate_start(); // S
    uint8_t buf;

    buf = IR_ADDR_WRITE;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_WRITE_FAILED;

    buf = reg;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_WRITE_FAILED;

    buf = data;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_WRITE_FAILED;

    neorv32_twi_generate_stop(); // P

    return APP_SENSOR_OK;
}

/**
 * @brief 从 IR 传感器指定寄存器读取数据
 */
app_sensor_status_t app_sensor_read_reg(uint8_t reg, uint8_t *data)
{
    if (!data)
        return APP_SENSOR_ERROR_READ_FAILED;

    neorv32_twi_generate_start(); // S
    uint8_t buf;

    buf = IR_ADDR_WRITE;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_READ_FAILED;

    buf = reg;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_READ_FAILED;

    neorv32_twi_generate_start(); // Sr

    buf = IR_ADDR_READ;
    if (neorv32_twi_transfer(&buf, 0) != 0)
        return APP_SENSOR_ERROR_READ_FAILED;

    buf = 0xFF;
    if (neorv32_twi_transfer(&buf, 1) != 0)
        return APP_SENSOR_ERROR_READ_FAILED;

    neorv32_twi_generate_stop(); // P

    *data = buf;

    // app_sensor_delay_ticks(1000); // delay before next read
    neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), 1);
    return APP_SENSOR_OK;
}
