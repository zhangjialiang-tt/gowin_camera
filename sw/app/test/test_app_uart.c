#include "../app/inc/app_uart.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>

// 模拟一个简单的测试断言（便于调试）
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

app_uart_handle_t uart_handle;

void test_uart_init(void)
{
    app_uart_config_t config = {
        .port = HAL_UART_PORT_0,
        .baud_rate = 19200,
        .parity = HAL_UART_PARITY_NONE,
        .hw_flow_control = false};

    uart_handle = app_uart_init(&config);
    TEST_ASSERT(uart_handle != NULL);
}

void test_uart_print(void)
{
    hal_uart_status_t ret = app_uart_print(uart_handle, "Hello from app_uart!\r\n");
    TEST_ASSERT(ret == HAL_UART_OK);
}

void test_uart_printf(void)
{
    hal_uart_status_t ret = app_uart_printf(uart_handle, "Formatted value: %d\r\n", 1234);
    TEST_ASSERT(ret == HAL_UART_OK);
}

void test_uart_hex_byte(void)
{
    hal_uart_status_t ret = app_uart_print_hex_byte(uart_handle, 0xAB);
    TEST_ASSERT(ret == HAL_UART_OK);
}

void test_uart_hex_buffer(void)
{
    uint8_t buf[] = {0xDE, 0xAD, 0xBE, 0xEF};
    hal_uart_status_t ret = app_uart_print_hex_buffer(uart_handle, buf, sizeof(buf));
    TEST_ASSERT(ret == HAL_UART_OK);
}

void test_uart_data_available(void)
{
    bool available = app_uart_data_available(uart_handle);
    // 不强制判断 true/false，只验证接口不崩溃
    app_uart_printf(uart_handle, "Data available: %s\r\n", available ? "YES" : "NO");
}

void test_uart_getc(void)
{
    char ch;
    hal_uart_status_t ret = app_uart_getc(uart_handle, &ch);
    if (ret == HAL_UART_OK)
    {
        app_uart_printf(uart_handle, "Received char: %c\r\n", ch);
    }
}

void test_uart_scan(void)
{
    char buffer[32];
    app_uart_print(uart_handle, "Please type something and press Enter:\r\n");
    int len = app_uart_scan(uart_handle, buffer, sizeof(buffer), true);
    app_uart_printf(uart_handle, "You typed (%d chars): %s\r\n", len, buffer);
}

int main(void)
{
    // 初始化 UART 测试
    test_uart_init();

    // 执行各功能测试
    test_uart_print();
    test_uart_printf();
    test_uart_hex_byte();
    test_uart_hex_buffer();
    test_uart_data_available();
    test_uart_getc();
    test_uart_scan();

    app_uart_print(uart_handle, "✅ All tests completed.\r\n");

    while (1)
    {
        // 可选：回显输入
        char ch;
        if (app_uart_getc(uart_handle, &ch) == HAL_UART_OK)
        {
            app_uart_print(uart_handle, "Echo: ");
            app_uart_print_hex_byte(uart_handle, (uint8_t)ch);
            app_uart_print(uart_handle, "\r\n");
        }
    }
}
