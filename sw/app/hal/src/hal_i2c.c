/**
 * @file hal_i2c.c
 * @brief I2C HAL implementation for NEORV32 TWI controller
 */

// #include "hal_i2c.h"
// #include "../../lib/include/neorv32_twi.h" // 引入底层 BSP 接口
// #include "../../lib/include/neorv32.h"     // 引入底层 BSP 接口
// #include "../../lib/include/neorv32_uart.h" // 引入底层 BSP 接口
#include "../../inc/system.h" // 假设你用前面测试过的 app_uart 作输出

/* ========================================== */
/*              私有变量与宏定义              */
/* ========================================== */

// 检查控制器是否可用
#define IS_I2C_AVAILABLE() (neorv32_twi_available() != 0)

/* ========================================== */
/*              私有函数声明                  */
/* ========================================== */

static hal_i2c_status_t hal_i2c_wait_not_busy(uint32_t timeout_ms);

/* ========================================== */
/*                 API 实现                   */
/* ========================================== */

bool hal_i2c_is_available(void)
{
    return IS_I2C_AVAILABLE();
}

hal_i2c_status_t hal_i2c_init(const hal_i2c_config_t *config)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    if (config == NULL)
    {
        return HAL_I2C_ERROR;
    }

    // 计算预分频器和时钟分频值
    int prsc = 0; // 预分频器 (0-7)
    int cdiv = 0; // 时钟分频器 (0-15)

    // 根据目标速度计算分频值
    // TWI clock = f_main / (2 * prescaler * (1 + cdiv))
    uint32_t main_freq = NEORV32_SYSINFO->CLK;
    uint32_t target_freq = config->speed;

    // 尝试不同的预分频器值
    for (prsc = 0; prsc <= 7; prsc++)
    {
        uint32_t prescaler = 1U << prsc;
        // cdiv = (f_main / (2 * prescaler * target_freq)) - 1
        if (prescaler > 0 && target_freq > 0)
        {
            uint32_t temp_cdiv = (main_freq / (2U * prescaler * target_freq)) - 1U;

            if (temp_cdiv <= 15U)
            {
                cdiv = (int)temp_cdiv;
                break;
            }
        }
    }

    if (prsc > 7)
    {
        prsc = 7;  // 使用最大预分频器
        cdiv = 15; // 使用最大分频器
    }

    // 初始化 TWI 控制器
    neorv32_twi_setup(CLK_PRSC_128, 8, 0);
    // neorv32_twi_setup(prsc, cdiv, config->clock_stretch ? 1 : 0);
    
    neorv32_uart0_printf("i2c config: %d,%d\r\n", prsc, cdiv);

    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_deinit(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    neorv32_twi_disable();
    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_enable(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    neorv32_twi_enable();
    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_disable(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    neorv32_twi_disable();
    return HAL_I2C_OK;
}

bool hal_i2c_is_busy(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return false;
    }

    return (neorv32_twi_busy() != 0);
}

int hal_i2c_get_fifo_depth(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return 0;
    }

    return neorv32_twi_get_fifo_depth();
}

hal_i2c_status_t hal_i2c_generate_start(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    // 等待总线空闲
    if (hal_i2c_wait_not_busy(100) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    neorv32_twi_generate_start();
    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_generate_stop(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    neorv32_twi_generate_stop();
    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_send_byte(uint8_t data, bool send_ack)
{
    neorv32_uart0_printf("i2c send address_mark2: 0x%02X\r\n", data);
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    neorv32_uart0_printf("i2c send address_mark3: 0x%02X\r\n", *(&data));
    int result = neorv32_twi_transfer(&data, send_ack ? 1 : 0);
    neorv32_uart0_printf("i2c send address_mark4: 0x%02X\r\n", *(&data));

    if (result == 0)
    {
        return HAL_I2C_OK; // ACK received
    }
    else if (result == 1)
    {
        return HAL_I2C_NACK; // NACK received
    }
    else
    {
        return HAL_I2C_ERROR; // Other error
    }
}

hal_i2c_status_t hal_i2c_receive_byte(uint8_t *data, bool send_ack)
{
    if (!IS_I2C_AVAILABLE() || data == NULL)
    {
        return HAL_I2C_NOT_AVAIL;
    }

    uint8_t received_data = 0xFF; // 发送虚拟数据以产生时钟

    // 在主接收模式下, neorv32_twi_transfer 会产生时钟,
    // 从从机接收一个字节, 并将其存储在提供的指针中。
    // 'send_ack' 标志决定接收后是发送 ACK 还是 NACK。
    // neorv32_twi_transfer(&received_data, send_ack ? 1 : 0);
    neorv32_uart0_printf("i2c write_mark11: 0x%02X\r\n", received_data);
    uint8_t st_ack = neorv32_twi_get(&received_data);
    neorv32_uart0_printf("i2c write_mark12: 0x%02X\r\n", st_ack);
    neorv32_uart0_printf("i2c write_mark13: 0x%02X\r\n", received_data);
    

    *data = received_data;

    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_master_write(uint8_t slave_addr, const uint8_t *data, uint16_t size, uint32_t timeout_ms)
{
    
    neorv32_uart0_printf("---write reg---\r\n");
    if (!IS_I2C_AVAILABLE() || data == NULL || size == 0)
    {
        return HAL_I2C_ERROR;
    }

    // 等待总线空闲
    if (hal_i2c_wait_not_busy(timeout_ms) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    // 生成 START 条件和从设备地址
    uint8_t addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_WRITE & 0x01);

    neorv32_uart0_printf("write reg-write address: 0x%02X\r\n", addr_byte);
    // 发送 START + 地址
    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }
    neorv32_twi_send_nonblocking(addr_byte, true);
    // if (hal_i2c_send_byte(addr_byte, true) != HAL_I2C_OK)
    // {
    //     (void)hal_i2c_generate_stop();
    //     return HAL_I2C_NACK; // 设备未响应
    // }
    neorv32_uart0_printf("write reg-write done\r\n");

    // 发送数据
    for (uint16_t i = 0; i < size; i++)
    {
        
        neorv32_twi_send_nonblocking(data[i], true);
        neorv32_uart0_printf("i2c write_mark8: 0x%02X\r\n", data[i]);
        // if (hal_i2c_send_byte(data[i], true) != HAL_I2C_OK)
        // {
        //     (void)hal_i2c_generate_stop();
        //     return HAL_I2C_NACK;
        // }
    }

    // 生成 STOP 条件
    if (hal_i2c_generate_stop() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_master_read(uint8_t slave_addr, uint8_t *data, uint16_t size, uint32_t timeout_ms)
{
    if (!IS_I2C_AVAILABLE() || data == NULL || size == 0)
    {
        return HAL_I2C_ERROR;
    }

    // 等待总线空闲
    if (hal_i2c_wait_not_busy(timeout_ms) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    // 生成 START 条件和从设备地址
    uint8_t addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_READ & 0x01);

    // 发送 START + 地址
    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    if (hal_i2c_send_byte(addr_byte, true) != HAL_I2C_OK)
    {
        (void)hal_i2c_generate_stop();
        return HAL_I2C_NACK; // 设备未响应
    }

    // 接收数据
    for (uint16_t i = 0; i < size; i++)
    {
        bool send_ack = (i < (size - 1)); // 最后一个字节发送 NACK
        if (hal_i2c_receive_byte(&data[i], send_ack) != HAL_I2C_OK)
        {
            (void)hal_i2c_generate_stop();
            return HAL_I2C_ERROR;
        }
    }

    // 生成 STOP 条件
    if (hal_i2c_generate_stop() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_master_write_read(uint8_t slave_addr,
                                           const uint8_t *write_data, uint16_t write_size,
                                           uint8_t *read_data, uint16_t read_size,
                                           uint32_t timeout_ms)
{
    if (!IS_I2C_AVAILABLE() || write_data == NULL || read_data == NULL ||
        write_size == 0 || read_size == 0)
    {
        return HAL_I2C_ERROR;
    }

    // 等待总线空闲
    if (hal_i2c_wait_not_busy(timeout_ms) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    // 第一阶段：写操作
    uint8_t addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_WRITE & 0x01);
    
    uint8_t fifo_deepth  = neorv32_twi_get_fifo_depth();
    neorv32_uart0_printf("write address: 0x%02X\r\n", fifo_deepth);
    neorv32_uart0_printf("---read reg :first stage---\r\n");
    neorv32_uart0_printf("write address: 0x%02X\r\n", addr_byte);
    neorv32_uart0_printf("write reg: 0x%02X\r\n", write_data[0]);

    // 发送 START + 地址
    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    neorv32_twi_send_nonblocking(addr_byte, true);
    // if (hal_i2c_send_byte(addr_byte, true) != HAL_I2C_OK)
    // {
    //     (void)hal_i2c_generate_stop();
    //     return HAL_I2C_NACK;
    // }

    // 发送写数据
    for (uint16_t i = 0; i < write_size; i++)
    {
        neorv32_twi_send_nonblocking(write_data[i], true);
        // if (hal_i2c_send_byte(write_data[i], true) != HAL_I2C_OK)
        // {
        //     (void)hal_i2c_generate_stop();
        //     return HAL_I2C_NACK;
        // }
    }

    neorv32_uart0_printf("---read reg :first stage done---\r\n", addr_byte);
    // 第二阶段：读操作 (重复START)
    addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_READ & 0x01);
    neorv32_uart0_printf("---second stage---\r\n");
    neorv32_uart0_printf("read address: 0x%02X\r\n", addr_byte);


    // 发送重复 START + 地址
    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        (void)hal_i2c_generate_stop();
        return HAL_I2C_ERROR;
    }
    neorv32_uart0_printf("read address_mark1: 0x%02X\r\n", addr_byte);
    
    // neorv32_twi_send_nonblocking(addr_byte, true);
    if (hal_i2c_send_byte(addr_byte, true) != HAL_I2C_OK)
    {
        (void)hal_i2c_generate_stop();
        return HAL_I2C_NACK;
    }
    neorv32_uart0_printf("read address_mark18: 0x%02X\r\n", addr_byte);
    neorv32_uart0_printf("read address-device id send done\r\n");
    neorv32_uart0_printf("i2c send size_mark6: 0x%02X\r\n", read_size);
    // 接收读数据
    // for (uint16_t i = 0; i < read_size; i++)
    // {
    //     bool send_ack = (i < (read_size - 1)); // 最后一个字节发送 NACK
    //     neorv32_uart0_printf("i2c send size_mark7: 0x%02X\r\n", i < (read_size - 1));
    //     if (hal_i2c_receive_byte(&read_data[i], send_ack) != HAL_I2C_OK)
    //     {
    //         (void)hal_i2c_generate_stop();
    //         return HAL_I2C_ERROR;
    //     }
    //     neorv32_uart0_printf("i2c read data_mark9: 0x%02X\r\n", read_data[i]);
    // }

    // 生成 STOP 条件
    if (hal_i2c_generate_stop() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    return HAL_I2C_OK;
}

hal_i2c_status_t hal_i2c_probe_device(uint8_t slave_addr)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    // 等待总线空闲
    if (hal_i2c_wait_not_busy(100) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    // 发送 START + 地址
    uint8_t addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_WRITE & 0x01);

    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    hal_i2c_status_t result = hal_i2c_send_byte(addr_byte, true);

    // 生成 STOP 条件
    (void)hal_i2c_generate_stop();

    return result;
}

bool hal_i2c_get_scl_state(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return false;
    }

    return (neorv32_twi_sense_scl() != 0);
}

bool hal_i2c_get_sda_state(void)
{
    if (!IS_I2C_AVAILABLE())
    {
        return false;
    }

    return (neorv32_twi_sense_sda() != 0);
}

void hal_i2c_delay_us(uint32_t us)
{
    if (us == 0)
        return;

    uint32_t cycles = us * (NEORV32_SYSINFO->CLK / 1000000U);
    if (cycles == 0)
        cycles = 1; // 至少等待一个周期

    uint32_t start = neorv32_cpu_get_cycle();

    while ((neorv32_cpu_get_cycle() - start) < cycles)
    {
        // 空循环等待
    }
}

void hal_i2c_delay_ms(uint32_t ms)
{
    for (uint32_t i = 0; i < ms; i++)
    {
        hal_i2c_delay_us(1000);
    }
}

int hal_i2c_bus_scan(uint8_t *found_devices, int max_devices)
{
    if (!IS_I2C_AVAILABLE() || found_devices == NULL || max_devices <= 0)
    {
        return 0;
    }

    int num_devices = 0;

    // 遍历所有可能的7位地址
    for (uint8_t addr = 0; addr < 128; addr++)
    {
        // 跳过保留地址
        if ((addr >= 0x00 && addr <= 0x07) || (addr >= 0x78 && addr <= 0x7F))
        {
            continue;
        }

        // 生成START条件
        if (hal_i2c_generate_start() != HAL_I2C_OK)
        {
            continue;
        }

        // 准备设备地址(写操作)
        uint8_t addr_rw = (addr << 1) | 0;

        // 尝试传输地址并检查ACK
        hal_i2c_status_t result = hal_i2c_send_byte(addr_rw, true);

        // 生成STOP条件
        (void)hal_i2c_generate_stop();

        // 如果收到ACK，设备存在
        if (result == HAL_I2C_OK)
        {
            if (num_devices < max_devices)
            {
                found_devices[num_devices] = addr;
            }
            num_devices++;
        }

        // 短暂延时避免总线过载
        hal_i2c_delay_us(100);
    }

    return (num_devices > max_devices) ? max_devices : num_devices;
}

/* ========================================== */
/*              私有函数实现                  */
/* ========================================== */

static hal_i2c_status_t hal_i2c_wait_not_busy(uint32_t timeout_ms)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    uint32_t timeout_cycles;
    uint32_t start_time;
    
    if (timeout_ms == 0)
    {
        // 无超时等待 - 添加安全计数器防止无限循环
        uint32_t max_wait_cycles = 1000000; // 安全限制
        uint32_t counter = 0;
        
        while (neorv32_twi_busy() && counter < max_wait_cycles)
        {
            counter++;
        }
        
        if (counter >= max_wait_cycles)
        {
            return HAL_I2C_TIMEOUT;
        }
        return HAL_I2C_OK;
    }

    timeout_cycles = timeout_ms * (NEORV32_SYSINFO->CLK / 1000U);
    start_time = neorv32_cpu_get_cycle();

    while (neorv32_twi_busy())
    {
        // 检查超时
        if ((neorv32_cpu_get_cycle() - start_time) > timeout_cycles)
        {
            return HAL_I2C_TIMEOUT;
        }
    }

    return HAL_I2C_OK;
}
hal_i2c_status_t hal_i2c_probe_device_timeout(uint8_t slave_addr, uint32_t timeout_ms)
{
    if (!IS_I2C_AVAILABLE())
    {
        return HAL_I2C_NOT_AVAIL;
    }

    // 等待总线空闲（带超时）
    if (hal_i2c_wait_not_busy(timeout_ms) != HAL_I2C_OK)
    {
        return HAL_I2C_BUSY;
    }

    // 发送 START + 地址
    uint8_t addr_byte = (slave_addr << 1) | (uint8_t)(HAL_I2C_DIRECTION_WRITE & 0x01);

    if (hal_i2c_generate_start() != HAL_I2C_OK)
    {
        return HAL_I2C_ERROR;
    }

    hal_i2c_status_t result = hal_i2c_send_byte(addr_byte, true);

    // 生成 STOP 条件
    (void)hal_i2c_generate_stop();

    return result;
}