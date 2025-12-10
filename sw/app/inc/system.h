#include "../app/inc/GOWIN_M1_it.h"
#include "../app/inc/apb.h"
#include "../app/inc/app_sensor.h"
// #include "../app/inc/app_gpio.h"
#include "../app/inc/sensor_ctrl.h"
#include "../app/inc/temperature.h"
#include "../app/inc/user_spi_flash.h"
#include "../app/inc/usb_process.h"

// #include "../app/inc/app_uart.h"
// #include "../app/inc/bit_ops.h"

#include "../hal/inc/hal_gpio.h"
#include "../hal/inc/hal_i2c.h"
#include "../hal/inc/hal_interrupt.h"
#include "../hal/inc/hal_uart.h"
#include "../hal/inc/i2c_apb.h"

#include "../dev/inc/zg_mdk_sensor_gst212w.h"
#include "../dev/inc/dev_shutter.h"
#include "../dev/inc/gc2145_cmos.h"

#include "system_video.h"
#include "debug.h"
#include "type.h"
#include "sdram_addrs_define.h"
#include "apb_reg_define.h"


#include "../../lib/include/neorv32.h"
#include "../../lib/include/neorv32_uart.h"
#include "../../lib/include/neorv32_gpio.h"
#include "../../lib/include/neorv32_twi.h" // 引入底层 BSP 接口
// #include "../lib/include/neorv32_gpio.h"
// #include "../lib/include/neorv32_aux.h"
// #include "../lib/include/neorv32_sysinfo.h"