#include "../hal/inc/hal_i2c.h" // 假设你用前面测试过的 app_uart 作输出
#include "../dev/inc/dev_eeprom.h"
#include "../app/inc/app_uart.h" // 假设你用前面测试过的 app_uart 作输出
#include <neorv32.h>  // For neorv32_cpu_load/store functions
#include <assert.h>
#include <string.h>

// 测试用的 UART 句柄
app_uart_handle_t uart_handle;

// 模拟配置
dev_eeprom_config_t eeprom_config = {
    .type = DEV_EEPROM_TYPE_24C02,
    .base_address = 0x50,
};

#define TEST_ASSERT(x)                                        \
    do                                                        \
    {                                                         \
        if (!(x))                                             \
        {                                                     \
            app_uart_print(uart_handle, "[FAIL] " #x "\r\n"); \
            while (1)                                         \
                ;                                             \
        }                                                     \
        else                                                  \
        {                                                     \
            app_uart_print(uart_handle, "[PASS] " #x "\r\n"); \
        }                                                     \
    } while (0)

void test_eeprom_write_byte(void)
{
    uint16_t address = 0x10;
    uint8_t data = 0xAB;
    app_uart_print(uart_handle, "About to call dev_eeprom_write_byte...\r\n");
    hal_i2c_status_t ret = dev_eeprom_write_byte(&eeprom_config, address, data);
    app_uart_printf(uart_handle, "Returned from dev_eeprom_write_byte with status: %d\r\n", ret);
    TEST_ASSERT(ret == HAL_I2C_OK);
}

void test_eeprom_read_byte(void)
{
    uint16_t address = 0x10;
    uint8_t read_data = 0x00;

    hal_i2c_status_t ret = dev_eeprom_read_byte(&eeprom_config, address, &read_data);
    TEST_ASSERT(ret == HAL_I2C_OK);
    TEST_ASSERT(read_data == 0xAB);
}

void test_eeprom_write_buffer(void)
{
    uint16_t address = 0x20;
    uint8_t buffer[] = {0xDE, 0xAD, 0xBE, 0xEF};

    hal_i2c_status_t ret = dev_eeprom_write_buffer(&eeprom_config, address, buffer, sizeof(buffer));
    TEST_ASSERT(ret == HAL_I2C_OK);
}

void test_eeprom_read_buffer(void)
{
    uint16_t address = 0x20;
    uint8_t buffer[4] = {0};

    hal_i2c_status_t ret = dev_eeprom_read_buffer(&eeprom_config, address, buffer, sizeof(buffer));
    TEST_ASSERT(ret == HAL_I2C_OK);

    uint8_t expected[] = {0xDE, 0xAD, 0xBE, 0xEF};
    TEST_ASSERT(memcmp(buffer, expected, sizeof(expected)) == 0);
}

void test_eeprom_read_write_byte_sequence(void)
{
    uint16_t addr1 = 0x50;
    uint16_t addr2 = 0x51;
    uint8_t data1 = 0x11;
    uint8_t data2 = 0x22;

    hal_i2c_status_t ret;

    ret = dev_eeprom_write_byte(&eeprom_config, addr1, data1);
    TEST_ASSERT(ret == HAL_I2C_OK);

    ret = dev_eeprom_write_byte(&eeprom_config, addr2, data2);
    TEST_ASSERT(ret == HAL_I2C_OK);

    uint8_t read1, read2;
    ret = dev_eeprom_read_byte(&eeprom_config, addr1, &read1);
    TEST_ASSERT(ret == HAL_I2C_OK && read1 == data1);

    ret = dev_eeprom_read_byte(&eeprom_config, addr2, &read2);
    TEST_ASSERT(ret == HAL_I2C_OK && read2 == data2);
}

/**********************************************************************//**
 * XBUS Slave Test Functions (adapted from bus_explorer for XBUS at 0x1000_0000)
 **************************************************************************/

#define XBUS_BASE_ADDR 0x10000000
#define XBUS_NUM_REGS  4  // Matches hardware slave

// void test_xbus_write_byte(void)
// {
//     uint32_t address = XBUS_BASE_ADDR;
//     uint32_t data = 0xAB;
//     app_uart_print(uart_handle, "About to write byte to XBUS slave...\r\n");
//     neorv32_cpu_store_unsigned_word(address+(4+0)*4, 0x10A1);
//     neorv32_cpu_store_unsigned_word(address+(4+1)*4, 0x10A2);
//     neorv32_cpu_store_unsigned_word(address+(4+2)*4, 0x10A3);
//     neorv32_cpu_store_unsigned_word(address+(4+3)*4, 0x10A4);
//     // app_uart_printf(uart_handle, "Wrote 0x%02x to XBUS [0x%08x]\r\n", (uint8_t)data, address);
//     // TEST_ASSERT(1);  // Basic write, no error check in simple test
// }

// void test_xbus_read_byte(void)
// {
//     uint32_t address = XBUS_BASE_ADDR;
//     volatile uint32_t read_data = neorv32_cpu_load_unsigned_word(address+4*0);//4*(32/8)
//     neorv32_uart0_printf("Read from XBUS slave %x: %x\r\n", address, read_data);
//     read_data = neorv32_cpu_load_unsigned_word(address+4*1);
//     neorv32_uart0_printf("Read from XBUS slave %x: %x\r\n", address, read_data);
//     // TEST_ASSERT((uint8_t)read_data == 0xAB);
// }

// void test_xbus_write_buffer(void)
// {
//     uint32_t address = XBUS_BASE_ADDR + 4;  // Next register
//     uint32_t buffer[] = {0xDEADBEEF, 0x12345678};
//     app_uart_print(uart_handle, "About to write buffer to XBUS slave...\r\n");

//     neorv32_cpu_store_unsigned_word(address + 0, buffer[0]);
//     neorv32_cpu_store_unsigned_word(address + 4, buffer[1]);

//     app_uart_printf(uart_handle, "Wrote buffer to XBUS [0x%08x]\r\n", address);
//     TEST_ASSERT(1);
// }

// void test_xbus_read_buffer(void)
// {
//     uint32_t address = XBUS_BASE_ADDR + 4;
//     uint32_t buffer[2];
//     buffer[0] = neorv32_cpu_load_unsigned_word(address + 0);
//     buffer[1] = neorv32_cpu_load_unsigned_word(address + 4);

//     uint32_t expected[] = {0xDEADBEEF, 0x12345678};
//     TEST_ASSERT(memcmp(buffer, expected, sizeof(expected)) == 0);

//     app_uart_printf(uart_handle, "Read buffer from XBUS [0x%08x]: 0x%08x 0x%08x\r\n", address, buffer[0], buffer[1]);
// }

// void test_xbus_read_write_sequence(void)
// {
//     uint32_t addr1 = XBUS_BASE_ADDR + 8;  // Third register
//     uint32_t addr2 = XBUS_BASE_ADDR + 12; // Fourth register
//     uint32_t data1 = 0x11111111;
//     uint32_t data2 = 0x22222222;

//     neorv32_cpu_store_unsigned_word(addr1, data1);
//     neorv32_cpu_store_unsigned_word(addr2, data2);

//     uint32_t read1 = neorv32_cpu_load_unsigned_word(addr1);
//     uint32_t read2 = neorv32_cpu_load_unsigned_word(addr2);

//     TEST_ASSERT(read1 == data1 && read2 == data2);

//     app_uart_printf(uart_handle, "XBUS sequence test: Read1=0x%08x, Read2=0x%08x\r\n", read1, read2);
// }

// int main(void)
// {
//     // 初始化 UART（假定你已实现）
//     app_uart_config_t uart_cfg = {
//         .port = HAL_UART_PORT_0,
//         .baud_rate = 19200,
//         .parity = HAL_UART_PARITY_NONE,
//         .hw_flow_control = false};
//     uart_handle = app_uart_init(&uart_cfg);

//     app_uart_print(uart_handle, "🔄 Starting EEPROM Tests...\r\n");

//     // test_eeprom_write_byte();
//     // test_eeprom_read_byte();

//     // test_eeprom_write_buffer();
//     // test_eeprom_read_buffer();

//     // test_eeprom_read_write_byte_sequence();

//     app_uart_print(uart_handle, "✅ All EEPROM tests passed.\r\n");

//     // XBUS Interface Tests (adapted from bus_explorer)
//     app_uart_print(uart_handle, "\n🔄 Starting XBUS Slave Tests...\r\n");

//     // test_xbus_write_byte();
//     // test_xbus_read_byte();

//     // test_xbus_write_buffer();
//     // test_xbus_read_buffer();

//     // test_xbus_read_write_sequence();

//     app_uart_print(uart_handle, "✅ All XBUS tests passed.\r\n");
//     while (1)
//     {
//         // neorv32_uart0_printf("Read from XBUS slave 0x0: %x\r\n",  neorv32_cpu_load_unsigned_byte(0));
//         // neorv32_uart0_printf("Read from XBUS slave 0x1: %x\r\n",  neorv32_cpu_load_unsigned_byte(4));
//         // neorv32_uart0_printf("Read from XBUS slave 0x2: %x\r\n",  neorv32_cpu_load_unsigned_byte(8));
//         // neorv32_uart0_printf("Read from XBUS slave 0x3: %x\r\n",  neorv32_cpu_load_unsigned_byte(c));
//         // test_xbus_write_byte();
//         test_xbus_read_byte();
//         app_uart_print(uart_handle, "✅ All XBUS tests passed.\r\n");
//         test_xbus_write_byte();
//         app_uart_print(uart_handle, "✅ All XBUS tests passed.\r\n");
//         // 可选：等待用户输入或循环打印
//     }
// }