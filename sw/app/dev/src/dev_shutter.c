/*
 * sensor_gst212w.c
 *
 *  Created on: 2022年6月29日
 *      Author: chain
 */

#include "../../inc/system.h"

void shutter_ctrl(char control);//control:0关闭,1打开  DEV_SHUTTER_TIME:电平持续时间

ST_DEV_SHUTTER_T st_dev_shutter =
{
	.shutter	=	shutter_ctrl
};

void shutter_ctrl(char control) //control:1关闭,0打开  DEV_SHUTTER_TIME:电平持续时间
{
	// st_drv_apb.write(APB_REG_ADDR_CTRL_SHUTTER,0x0004);
	if (control == SHUTTER_OPEN)
	{
		// neorv32_gpio_pin_set(SHUTTER_SLEEP, GPIO_TRIG_LEVEL_HIGH);
		neorv32_gpio_pin_set(SHUTTER_A, GPIO_TRIG_LEVEL_LOW);
		neorv32_gpio_pin_set(SHUTTER_B, GPIO_TRIG_LEVEL_HIGH);
		neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), DEV_SHUTTER_TIME);
		// DEBUG_INFO("neorv32_sysinfo_get_clk() = %d\r\n",neorv32_sysinfo_get_clk());
		neorv32_gpio_pin_set(SHUTTER_A, GPIO_TRIG_LEVEL_LOW);
		neorv32_gpio_pin_set(SHUTTER_B, GPIO_TRIG_LEVEL_LOW);
	}
	else if (control == SHUTTER_CLOSE)
	{
		// neorv32_gpio_pin_set(SHUTTER_SLEEP, GPIO_TRIG_LEVEL_HIGH);
		neorv32_gpio_pin_set(SHUTTER_A, GPIO_TRIG_LEVEL_HIGH);
		neorv32_gpio_pin_set(SHUTTER_B, GPIO_TRIG_LEVEL_LOW);
		neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), DEV_SHUTTER_TIME);
		neorv32_gpio_pin_set(SHUTTER_A, GPIO_TRIG_LEVEL_LOW);
		neorv32_gpio_pin_set(SHUTTER_B, GPIO_TRIG_LEVEL_LOW);
	}
	else if (control == SHUTTER_STOP)
	{
		neorv32_gpio_pin_set(SHUTTER_A, GPIO_TRIG_LEVEL_LOW);
		neorv32_gpio_pin_set(SHUTTER_B, GPIO_TRIG_LEVEL_LOW);
	}
}