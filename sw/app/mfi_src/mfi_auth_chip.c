// ================================================================================
// MFi Authentication Chip Operations Implementation
// 芯片操作抽象接口实现文件
// ================================================================================

#include "../mfi_inc/mfi_auth_chip.h"
#include "mfi_iic/mfi_iic.h"
#include "../mfi_inc/mfi_auth_utils.h"
#include "../inc/debug.h"

// 全局芯片操作接口
static mfi_chip_operations_t g_chip_ops = {0};
static int g_chip_initialized = 0;

// ================================================================================
// 默认IIC实现 (internal - static)
// ================================================================================

static mfi_chip_error_t default_iic_init(void) {
    // return (mfi_iic_init() == MFI_OK) ? MFI_CHIP_OK : MFI_CHIP_ERROR_INIT;
    mfi_gpio_init();
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_get_status(mfi_chip_status_t *status) {
    if (status == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    mfi_status_t iic_status;
    mfi_error_t result = mfi_check_challenge_status(&iic_status);
    
    if (result != MFI_OK) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    status->chip_id = 0;  // 默认值，可根据实际情况读取
    status->firmware_version = 1;
    status->cert_length = 0;  // 需要时可以通过mfi_read_certificate获取
    status->challenge_length = 0;  // 需要时可以通过mfi_read_challenge获取
    status->challenge_ready = iic_status.challenge_ready;
    status->auth_status = 0;
    
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_read_certificate(uint8_t *buffer, 
                                                   uint16_t buffer_size, 
                                                   uint16_t *cert_len) {
    if (buffer == NULL || cert_len == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    mfi_error_t result = mfi_read_certificate(buffer, buffer_size, cert_len);
    return (result == MFI_OK) ? MFI_CHIP_OK : MFI_CHIP_ERROR_COMM;
}

static mfi_chip_error_t default_iic_write_challenge(const uint8_t *data, uint16_t length) {
    if (data == NULL || length == 0 || length > 255) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 参考代码流程：
    // 1. 写入挑战数据长度到0x20寄存器（1字节）
    uint8_t len_byte = (uint8_t)length;
    mfi_error_t result = mfi_iic_write(0x20, &len_byte, 1);
    if (result != MFI_OK) {
        DEBUG_INFO("[CHIP] Failed to write challenge length\n");
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 2. 写入挑战数据到0x21寄存器
    result = mfi_iic_write(0x21, data, length);
    if (result != MFI_OK) {
        DEBUG_INFO("[CHIP] Failed to write challenge data\n");
        return MFI_CHIP_ERROR_COMM;
    }
    
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_start_challenge_generation(void) {
    // 参考代码流程：写入0x10寄存器，值为1，启动加密处理
    uint8_t cmd = 0x01;
    mfi_error_t result = mfi_iic_write(0x10, &cmd, 1);
    if (result != MFI_OK) {
        DEBUG_INFO("[CHIP] Failed to start challenge generation\n");
        return MFI_CHIP_ERROR_COMM;
    }
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_check_challenge_status(uint8_t *ready) {
    if (ready == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 参考代码流程：读取0x10寄存器，检查bit4（0x10）是否置位
    uint8_t status = 0;
    mfi_error_t result = mfi_iic_read(0x10, &status, 1);
    
    if (result != MFI_OK) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 检查bit4是否置位（0x10表示处理完成）
    *ready = ((status & 0x10) == 0x10) ? 1 : 0;
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_read_challenge_response(uint8_t *buffer, 
                                                          uint16_t buffer_size, 
                                                          uint16_t *resp_len) {
    if (buffer == NULL || resp_len == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 参考代码流程：
    // 1. 读取0x11寄存器获取响应长度（2字节，大端序）
    uint8_t len_buf[2] = {0};
    mfi_error_t result = mfi_iic_read(0x11, len_buf, 2);
    if (result != MFI_OK) {
        DEBUG_INFO("[CHIP] Failed to read response length\n");
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 解析长度（大端序）
    *resp_len = (len_buf[0] << 8) | len_buf[1];
    DEBUG_INFO("[CHIP] Response length: %d bytes\n", *resp_len);
    
    // 验证长度有效性
    if (*resp_len == 0 || *resp_len > buffer_size || *resp_len > 1024) {
        DEBUG_INFO("[CHIP] Invalid response length: %d\n", *resp_len);
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 2. 读取0x12寄存器获取响应数据
    result = mfi_iic_read(0x12, buffer, *resp_len);
    if (result != MFI_OK) {
        DEBUG_INFO("[CHIP] Failed to read response data\n");
        return MFI_CHIP_ERROR_COMM;
    }
    
    DEBUG_INFO("[CHIP] Challenge response read successfully\n");
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_write_param(const uint8_t *param_data, uint16_t param_length) {
    if (param_data == NULL || param_length == 0) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    mfi_error_t result = mfi_write_param(param_data, param_length);
    return (result == MFI_OK) ? MFI_CHIP_OK : MFI_CHIP_ERROR_COMM;
}

static mfi_chip_error_t default_iic_reset(void) {
    // 实现芯片复位逻辑
    return MFI_CHIP_OK;
}

static mfi_chip_error_t default_iic_sleep(void) {
    // 实现芯片睡眠逻辑
    return MFI_CHIP_OK;
}

// 默认操作结构体
static const mfi_chip_operations_t g_default_iic_ops = {
    .init = default_iic_init,
    .get_status = default_iic_get_status,
    .read_certificate = default_iic_read_certificate,
    .write_challenge = default_iic_write_challenge,
    .start_challenge_generation = default_iic_start_challenge_generation,
    .check_challenge_status = default_iic_check_challenge_status,
    .read_challenge_response = default_iic_read_challenge_response,
    .write_param = default_iic_write_param,
    .reset = default_iic_reset,
    .sleep = default_iic_sleep,
    .user_data = NULL
};

// ================================================================================
// 公共接口实现
// ================================================================================

mfi_chip_error_t mfi_auth_chip_init(void) {
    // 如果没有注册操作接口，使用默认IIC实现
    if (g_chip_ops.init == NULL) {
        g_chip_ops = g_default_iic_ops;
    }
    
    mfi_chip_error_t result = g_chip_ops.init();
    if (result == MFI_CHIP_OK) {
        g_chip_initialized = 1;
    }
    
    return result;
}

mfi_chip_error_t mfi_auth_chip_read_certificate(uint8_t *buffer, 
                                              uint16_t buffer_size, 
                                              uint16_t *cert_len) {
    if (!g_chip_initialized) {
        return MFI_CHIP_ERROR_INIT;
    }
    
    if (g_chip_ops.read_certificate == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    return g_chip_ops.read_certificate(buffer, buffer_size, cert_len);
}

mfi_chip_error_t mfi_auth_chip_generate_challenge_response(
    const uint8_t *challenge_data, uint16_t challenge_len,
    uint8_t *response_buffer, uint16_t response_buffer_size, uint16_t *response_len) {
    
    if (!g_chip_initialized) {
        return MFI_CHIP_ERROR_INIT;
    }
    
    if (g_chip_ops.write_challenge == NULL || 
        g_chip_ops.start_challenge_generation == NULL ||
        g_chip_ops.check_challenge_status == NULL ||
        g_chip_ops.read_challenge_response == NULL) {
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 1. 写入挑战数据
    mfi_chip_error_t result = g_chip_ops.write_challenge(challenge_data, challenge_len);
    if (result != MFI_CHIP_OK) {
        return result;
    }
    
    // 2. 启动生成
    result = g_chip_ops.start_challenge_generation();
    if (result != MFI_CHIP_OK) {
        return result;
    }
    
    // 3. 等待生成完成（参考代码：轮询200次，每次延时500us，总计100ms）
    uint32_t retry_count = 0;
    const uint32_t max_retries = 200; // 最大轮询次数
    
    uint8_t ready = 0;
    DEBUG_INFO("[CHIP] Waiting for challenge processing (max 100ms)...\n");
    
    while (!ready && retry_count < max_retries) {
        result = g_chip_ops.check_challenge_status(&ready);
        if (result != MFI_CHIP_OK) {
            // 读取失败，延时后重试
            mfi_delay_us(500); // 500us延时（参考代码）
            retry_count++;
            continue;
        }
        
        if (ready) {
            DEBUG_INFO("[CHIP] Challenge processing completed (retry: %d)\n", retry_count);
            break;
        }
        
        // 未完成，延时500us后继续轮询
        mfi_delay_us(500);
        retry_count++;
    }
    
    if (!ready) {
        DEBUG_INFO("[CHIP] Challenge processing timeout (retries: %d)\n", retry_count);
        return MFI_CHIP_ERROR_COMM;
    }
    
    // 4. 读取响应
    result = g_chip_ops.read_challenge_response(response_buffer, response_buffer_size, response_len);
    return result;
}