// ================================================================================ //
// MFI USB-Wishbone Bridge 实现文件
// 基于 NEORV32 软核的 MFI 认证芯片 USB 接口
// ================================================================================ //

#include "mfi_usb.h"
#include "../../inc/debug.h"
#include "../../mfi_inc/mfi_auth_utils.h"

// USB module uses unified debug macros from debug.h
// Detailed USB debugging uses DEBUG_DEBUG level
#define MFI_USB_DETAIL_LOG(...) DEBUG_DEBUG(__VA_ARGS__)

// 默认超时时间(毫秒)
#define MFI_USB_DEFAULT_TIMEOUT_MS 5000

// ================================================================================
// 私有函数声明
// ================================================================================

/**
 * @brief 写入数据寄存器
 * @param data 要写入的数据字节
 */
static void usb_wb_write_data(uint8_t data)
{
    neorv32_cpu_store_unsigned_word(WB_USB_BASE + REG_DATA, (uint32_t)data);
}

/**
 * @brief 读取数据寄存器
 * @return 读取的数据字节
 */
static uint8_t usb_wb_read_data(void)
{
    return (uint8_t)neorv32_cpu_load_unsigned_word(WB_USB_BASE + REG_DATA);
}

/**
 * @brief 获取状态寄存器
 * @return 状态寄存器值
 */
static uint32_t usb_wb_get_status_reg(void)
{
    return neorv32_cpu_load_unsigned_word(WB_USB_BASE + REG_STATUS);
}

/**
 * @brief 获取WB签名寄存器
 * @return WB签名值
 */
static uint32_t usb_wb_get_signature_reg(void)
{
    return neorv32_cpu_load_unsigned_word(WB_USB_BASE + REG_SIGNATURE);
}

/**
 * @brief 设置TX长度寄存器并触发传输
 * @param len 要发送的数据长度
 */
static void usb_wb_set_txlen(uint16_t len)
{
    neorv32_cpu_store_unsigned_word(WB_USB_BASE + REG_TXLEN, (uint32_t)len);
}


// ================================================================================
// 公共函数实现
// ================================================================================

/**
 * @brief 初始化 MFI USB-WB 接口
 * @return 错误码
 */
mfi_usb_error_t mfi_usb_init(void)
{
    
    // 检查USB-WB Bridge签名寄存器
    uint32_t signature = usb_wb_get_signature_reg();
    DEBUG_INFO("[USB_DEBUG] WB_SIGNATURE value: 0x%X\n", (unsigned long)signature);
    
    // 检查签名是否正确：期望值为0x57425247 ("WRG")
    if (signature != 0x57425247)
    {
        return MFI_USB_ERROR_INIT;
    }
    
    // 默认设置为Apple设备
    return mfi_usb_set_os_type(0);
}

/**
 * @brief 设置OS类型
 * @param is_android 1表示Android，0表示Apple
 * @return 错误码
 */
mfi_usb_error_t mfi_usb_set_os_type(int is_android)
{
    uint32_t val = is_android ? CTRL_OS_TYPE : 0UL;
    neorv32_cpu_store_unsigned_word(WB_USB_BASE + REG_CTRL, val);
    return MFI_USB_OK;
}

/**
 * @brief 读取USB数据
 * @param buffer 用于存储接收数据的缓冲区
 * @param buffer_size 缓冲区大小
 * @param received_size 实际接收到的数据长度
 * @param timeout_ms 超时时间(毫秒)
 * @return 错误码
 */
mfi_usb_error_t mfi_usb_read(uint8_t *buffer, uint16_t buffer_size, uint16_t *received_size, uint32_t timeout_ms)
{
    if (!buffer || !received_size || buffer_size == 0)
    {
        return MFI_USB_ERROR_INVALID_PARAM;
    }
    
    *received_size = 0;
    
    // 获取初始计数值
    extern volatile uint32_t timer0_count;
    uint32_t start_time = timer0_count;
    uint32_t timeout_count = timeout_ms; // 直接使用毫秒作为计数单位
    
    // 等待数据可用，使用timer0_delay_ms实现超时判断
    while (!(usb_wb_get_status_reg() & STATUS_RX_NOT_EMPTY))
    {
        // 检查是否超时
        uint32_t elapsed = timer0_count - start_time;
        if (elapsed >= timeout_count)
        {
            return MFI_USB_ERROR_TIMEOUT;
        }
        
        // 使用timer0_delay_ms进行延时，每次延时1毫秒
        timer0_delay_ms(1);
        // mfi_auth_delay_ms(1);
        
    }
    
    // 读取数据
    uint16_t count = 0;
    while ((usb_wb_get_status_reg() & STATUS_RX_NOT_EMPTY) && (count < buffer_size))
    {
        buffer[count] = usb_wb_read_data();
        count++;
    }
    
    *received_size = count;
    
    if (count == 0)
    {
        return MFI_USB_ERROR_RX_EMPTY;
    }
    
    return MFI_USB_OK;
}

/**
 * @brief 写入USB数据
 * @param buffer 要发送的数据缓冲区
 * @param length 数据长度
 * @param timeout_ms 超时时间(毫秒)
 * @return 错误码
 */
mfi_usb_error_t mfi_usb_write(const uint8_t *buffer, uint16_t length)
{
    if (!buffer || length == 0)
    {
        return MFI_USB_ERROR_INVALID_PARAM;
    }
    
    // 获取初始计数值
    extern volatile uint32_t timer0_count;
    uint32_t start_time;
    
    // 简化的等待前一次传输完成（短超时）
    start_time = timer0_count;
    while (usb_wb_get_status_reg() & STATUS_TX_BUSY)
    {
        uint32_t elapsed = timer0_count - start_time;
        if (elapsed >= 50) // 50ms短超时，避免长时间阻塞
        {
            DEBUG_INFO("[USB_WRITE] Previous TX still busy after 50ms\n");
            return MFI_USB_ERROR_BUSY;
        }
        // 使用简单延时避免过度轮询
        for (volatile int i = 0; i < 1000; i++);
    }
    
    // 填充TX FIFO（简化版，无过度超时检查）
    for (uint16_t i = 0; i < length; i++)
    {
        // 简单等待FIFO有空间（短超时）
        start_time = timer0_count;
        while (usb_wb_get_status_reg() & STATUS_TX_FULL)
        {
            uint32_t elapsed = timer0_count - start_time;
            if (elapsed >= 50) // 50ms超时
            {
                DEBUG_INFO("[USB_WRITE] TX FIFO full timeout at byte %d/%d\n", i, length);
                return MFI_USB_ERROR_TX_FULL;
            }
            for (volatile int j = 0; j < 100; j++); // 简单延时
        }
        
        usb_wb_write_data(buffer[i]);
    }
    
    // 触发传输
    // MFI_USB_DETAIL_LOG("[USB_WRITE] Triggering transfer of %d bytes\n", length);
    usb_wb_set_txlen(length);
    
    // 关键修复：不等待传输完成，立即返回（参考原代码的异步模式）
    // 原代码中USB发送是异步的，软件只负责填充FIFO和触发，硬件自动完成传输
    // 过度等待TX_BUSY会导致死锁，因为硬件可能需要主机轮询才能清除busy标志
    
    // MFI_USB_DETAIL_LOG("[USB_WRITE] Transfer triggered successfully\n");
    return MFI_USB_OK;
}

/**
 * @brief 检查USB接口是否可用
 * @return 错误码
 */
mfi_usb_error_t mfi_usb_check_availability(void)
{
    // 检查WB签名寄存器
    uint32_t signature = usb_wb_get_signature_reg();
    // DEBUG_INFO("[USB_DEBUG] mfi_usb_check_availability: signature=0x%x\n", (unsigned long)signature);
    
    // 检查签名是否正确：期望值为0x57425247 ("WRG")
    if (signature != 0x57425247)
    {
        return MFI_USB_ERROR_INIT;
    }
    
    // 尝试读取状态寄存器
    uint32_t status = usb_wb_get_status_reg();
    
    // 如果返回全1，可能表示设备未连接或不可用
    if (status == 0xFFFFFFFF)
    {
        return MFI_USB_ERROR_INIT;
    }
    
    return MFI_USB_OK;
}

/**
 * @brief 获取当前状态
 * @return 状态寄存器值
 */
uint32_t mfi_usb_get_status(void)
{
    return usb_wb_get_status_reg();
}

/**
 * @brief 打印错误信息
 * @param error 错误码
 */
void mfi_usb_print_error(mfi_usb_error_t error)
{
    switch (error)
    {
    case MFI_USB_OK:
        neorv32_uart0_puts("MFI USB: OK\n");
        break;
    case MFI_USB_ERROR_INIT:
        neorv32_uart0_puts("MFI USB: Error - Initialization failed\n");
        break;
    case MFI_USB_ERROR_BUSY:
        neorv32_uart0_puts("MFI USB: Error - Device busy\n");
        break;
    case MFI_USB_ERROR_TIMEOUT:
        neorv32_uart0_puts("MFI USB: Error - Timeout\n");
        break;
    case MFI_USB_ERROR_INVALID_PARAM:
        neorv32_uart0_puts("MFI USB: Error - Invalid parameter\n");
        break;
    case MFI_USB_ERROR_TX_FULL:
        neorv32_uart0_puts("MFI USB: Error - TX FIFO full\n");
        break;
    case MFI_USB_ERROR_RX_EMPTY:
        neorv32_uart0_puts("MFI USB: Error - RX FIFO empty\n");
        break;
    default:
        neorv32_uart0_puts("MFI USB: Error - Unknown error\n");
        break;
    }
}
