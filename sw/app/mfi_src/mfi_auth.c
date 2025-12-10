// ================================================================================
// MFi Authentication Module Implementation
// 主模块实现文件
// ================================================================================

#include "../mfi_inc/mfi_auth.h"
#include "../mfi_inc/mfi_auth_utils.h"
#include "../mfi_inc/mfi_auth_protocol.h"
#include "../mfi_inc/mfi_auth_params.h"
#include "../mfi_inc/mfi_auth_chip.h"
#include "../mfi_inc/mfi_config.h"
#include "mfi_iic/mfi_iic.h"
#include "mfi_usb/mfi_usb.h"
#include "../inc/debug.h"
#include <neorv32.h>
#include <string.h>

// 外部变量声明
extern volatile uint32_t timer0_flag;
extern volatile uint32_t timer0_count;

// ================================================================================
// 私有宏定义
// ================================================================================

// Use unified debug macros from debug.h
// MFI_AUTH_LOG uses DEBUG_INFO for general authentication flow
// MFI_AUTH_DETAIL_LOG uses DEBUG_DEBUG for detailed packet/data dumps
#define MFI_AUTH_LOG(...) DEBUG_INFO(__VA_ARGS__)
#define MFI_AUTH_DETAIL_LOG(...) DEBUG_DEBUG(__VA_ARGS__)

// 缓冲区大小 (优化后)
#define IAP2_PACKET_MAX_LEN 1024  // 减小从 1600
#define CERT_BUF_SIZE 1024        // 静态全局缓冲区
#define CHALLENGE_BUF_SIZE 128    // 静态全局缓冲区

// 超时配置
#define SYN_MAX_RETRY 10
#define DETECT_TIMEOUT_MS 500
#define USB_READ_TIMEOUT_MS 100

// ================================================================================
// 私有数据结构
// ================================================================================

// 协议状态枚举 (内部使用)
typedef enum {
    IAP2_STATE_DETECT = 0,
    IAP2_STATE_NEGOTIATE = 1,
    IAP2_STATE_AUTH = 2,
    IAP2_STATE_READY = 3,
    IAP2_STATE_ANDROID = 4  // 新增：Android设备状态
} iap2_state_internal_t;

// 标志位定义
#define MFI_FLAG_AUTH_SUCCEEDED    (1 << 0)
#define MFI_FLAG_APP_LAUNCH_PENDING (1 << 1)

// MFi认证上下文 (优化后 - 减少约2600字节)
typedef struct {
    // 状态机管理 (紧凑布局)
    uint8_t state;              // 1 byte (was enum = 4 bytes)
    uint8_t device_type;         // 1 byte (新增：存储 MFI_DEVICE_xxx)
    uint8_t tx_packet_seq;      // 1 byte
    uint8_t rx_packet_seq;      // 1 byte
    uint8_t syn_retry_count;    // 1 byte (was int = 4 bytes)
    uint8_t flags;              // 1 byte (合并 auth_succeeded, app_launch_pending)
    
    // 缓冲区管理 (减小尺寸)
    uint8_t tx_buf[256];        // 256 bytes (was 512)
    uint8_t rx_buf[IAP2_PACKET_MAX_LEN];  // 1024 bytes (was 1600)
    
    // 证书数据 (使用静态全局缓冲区)
    uint16_t cert_len;
    uint8_t *cert_data_ptr;     // 指向全局缓冲区
    
    // 挑战响应数据 (使用静态全局缓冲区)
    uint16_t challenge_resp_len;
    uint8_t *challenge_resp_ptr;
    
    // 回调函数
    mfi_auth_event_callback_t event_callback;
    
    // 时间记录 (合并为单个时间戳)
    uint32_t last_action_time;  // 合并 state_entry_time, last_detect_time, last_syn_time
} mfi_auth_context_t;

// ================================================================================
// 全局变量
// ================================================================================

static mfi_auth_context_t g_context = {0};
static int g_module_initialized = 0;

// 静态全局缓冲区 (用于证书和挑战响应数据复用)
static uint8_t g_cert_buffer[CERT_BUF_SIZE];
static uint8_t g_challenge_buffer[CHALLENGE_BUF_SIZE];

// ================================================================================
// 私有函数声明
// ================================================================================

// 工具函数 (internal - static)
static inline uint32_t mfi_auth_get_current_time_ms(void);
static void mfi_auth_log_packet(const char *prefix, const uint8_t *data, uint16_t len);

// 协议包处理 (internal - static)
static void mfi_auth_send_detect_packet(mfi_auth_context_t *ctx);
static void mfi_auth_send_syn_packet(mfi_auth_context_t *ctx);
static void mfi_auth_send_ack_packet(mfi_auth_context_t *ctx);
static int mfi_auth_send_certificate_packet(mfi_auth_context_t *ctx);
static void mfi_auth_send_challenge_response_packet(mfi_auth_context_t *ctx);
static void mfi_auth_send_identification_packet(mfi_auth_context_t *ctx);
static void mfi_auth_send_app_launch_packet(mfi_auth_context_t *ctx);

// 协议解析 (internal - static)
static void mfi_auth_process_packet(mfi_auth_context_t *ctx, uint8_t *buf, uint16_t len);
static void mfi_auth_handle_control_session(mfi_auth_context_t *ctx, uint8_t *payload, uint16_t len);

// 状态机管理 (internal - static)
static void mfi_auth_state_machine(mfi_auth_context_t *ctx);
static void mfi_auth_update_state(mfi_auth_context_t *ctx, iap2_state_internal_t new_state);

// 外设接口 (internal - static)
static int mfi_auth_send_usb_data(uint8_t *data, uint16_t len);

// 初始化 (internal - static)
static mfi_auth_error_t mfi_auth_init_context(mfi_auth_context_t *ctx);
static mfi_auth_error_t mfi_auth_load_certificate(mfi_auth_context_t *ctx);

// ================================================================================
// 公共API实现
// ================================================================================

mfi_auth_error_t mfi_auth_init(void) {
    mfi_auth_context_t *ctx = &g_context;
    
    // 1. 初始化上下文
    mfi_auth_error_t result = mfi_auth_init_context(ctx);
    if (result != MFI_AUTH_OK) {
        return result;
    }
    
    // 2. 初始化外设
    mfi_gpio_init();
    // if (mfi_gpio_init() != MFI_OK) {
    //     return MFI_AUTH_ERROR_COMM;
    // }
    
    if (mfi_usb_init() != MFI_USB_OK) {
        return MFI_AUTH_ERROR_COMM;
    }
    
    // 3. 初始化芯片操作
    if (mfi_auth_chip_init() != MFI_CHIP_OK) {
        return MFI_AUTH_ERROR_INIT;
    }
    
    // 4. 加载证书
    result = mfi_auth_load_certificate(ctx);
    if (result != MFI_AUTH_OK) {
        return result;
    }
    
    g_module_initialized = 1;
    MFI_AUTH_LOG("MFi Auth Module Initialized Successfully\n");
    
    return MFI_AUTH_OK;
}

mfi_auth_error_t mfi_auth_start(void) {
    if (!g_module_initialized) {
        return MFI_AUTH_ERROR_INIT;
    }
    
    mfi_auth_context_t *ctx = &g_context;
    mfi_auth_update_state(ctx, IAP2_STATE_DETECT);
    ctx->tx_packet_seq = 7; // Initial seq
    
    MFI_AUTH_LOG("MFi Auth Started\n");
    return MFI_AUTH_OK;
}

mfi_auth_error_t mfi_auth_process(void) {
    if (!g_module_initialized) {
        return MFI_AUTH_ERROR_INIT;
    }
    
    mfi_auth_context_t *ctx = &g_context;
    
    // 1. 检查USB连接状态
    if (mfi_usb_check_availability() != MFI_USB_OK) {
        if (ctx->state != IAP2_STATE_DETECT) {
            MFI_AUTH_LOG("[USB] Connection lost, reverting to DETECT\n");
            mfi_auth_update_state(ctx, IAP2_STATE_DETECT);
        }
        return MFI_AUTH_OK;
    }
    
    // 2. 状态机处理（主动发送）
    mfi_auth_state_machine(ctx);
    
    // 3. 非阻塞读取接收数据（关键修复：使用短超时避免阻塞）
    uint16_t rx_len = 0;
    mfi_usb_error_t usb_err = mfi_usb_read(ctx->rx_buf, IAP2_PACKET_MAX_LEN, 
                                           &rx_len, 10); // 10ms短超时
    
    if (usb_err == MFI_USB_OK && rx_len > 0) {
        mfi_auth_log_packet("[RX]", ctx->rx_buf, rx_len);
        mfi_auth_process_packet(ctx, ctx->rx_buf, rx_len);
    } else if (usb_err != MFI_USB_ERROR_TIMEOUT && usb_err != MFI_USB_ERROR_RX_EMPTY) {
        // 仅记录非超时/空FIFO的错误
        MFI_AUTH_LOG("[PROCESS] USB read error: %d\n", usb_err);
    }
    
    return MFI_AUTH_OK;
}

mfi_auth_state_t mfi_auth_get_state(void) {
    if (!g_module_initialized) {
        return MFI_AUTH_STATE_ERROR;
    }
    
    mfi_auth_context_t *ctx = &g_context;
    
    // 转换内部状态为公共状态
    switch (ctx->state) {
        case IAP2_STATE_DETECT:
            return MFI_AUTH_STATE_DETECT;
        case IAP2_STATE_NEGOTIATE:
            return MFI_AUTH_STATE_NEGOTIATE;
        case IAP2_STATE_AUTH:
            return MFI_AUTH_STATE_AUTH;
        case IAP2_STATE_READY:
            return MFI_AUTH_STATE_READY;
        default:
            return MFI_AUTH_STATE_ERROR;
    }
}

int mfi_auth_is_authenticated(void) {
    if (!g_module_initialized) {
        return 0;
    }
    
    mfi_auth_context_t *ctx = &g_context;
    return (ctx->state == IAP2_STATE_READY && (ctx->flags & MFI_FLAG_AUTH_SUCCEEDED));
}

void mfi_auth_register_callback(mfi_auth_event_callback_t callback, void *user_data) {
    (void)user_data; // 不再存储 user_data
    if (!g_module_initialized) {
        return;
    }
    
    mfi_auth_context_t *ctx = &g_context;
    ctx->event_callback = callback;
}

// ================================================================================
// 私有函数实现
// ================================================================================

static mfi_auth_error_t mfi_auth_init_context(mfi_auth_context_t *ctx) {
    if (ctx == NULL) {
        return MFI_AUTH_ERROR_INIT;
    }
    
    memset(ctx, 0, sizeof(mfi_auth_context_t));
    ctx->state = IAP2_STATE_DETECT;
    ctx->device_type = MFI_DEVICE_UNKNOWN; // 初始化为未知
    ctx->tx_packet_seq = 7; // Initial seq
    ctx->rx_packet_seq = 0;
    ctx->flags = 0;
    
    // 使用全局静态缓冲区
    ctx->cert_data_ptr = g_cert_buffer + 19;
    
    // 预填充证书缓存的静态头部
    g_cert_buffer[0] = 0xff;
    g_cert_buffer[1] = 0x5a;
    g_cert_buffer[4] = 0x40;
    g_cert_buffer[7] = 0xc1;
    g_cert_buffer[9] = 0x40;
    g_cert_buffer[10] = 0x40;
    g_cert_buffer[13] = 0xaa;
    g_cert_buffer[14] = 0x01; // ID: Certificate
    
    return MFI_AUTH_OK;
}

static mfi_auth_error_t mfi_auth_load_certificate(mfi_auth_context_t *ctx) {
    if (ctx == NULL) {
        return MFI_AUTH_ERROR_INIT;
    }
    
    mfi_chip_error_t result = mfi_auth_chip_read_certificate(ctx->cert_data_ptr, 
                                                           CERT_BUF_SIZE - 20, 
                                                           &ctx->cert_len);
    if (result != MFI_CHIP_OK) {
        return MFI_AUTH_ERROR_COMM;
    }
    
    // 更新证书包头部的长度字段
    uint32_t total_cert_pkt_len = ctx->cert_len + 20;
    g_cert_buffer[2] = (total_cert_pkt_len >> 8) & 0xFF;
    g_cert_buffer[3] = total_cert_pkt_len & 0xFF;
    
    uint16_t payload_len = ctx->cert_len + 10;
    g_cert_buffer[11] = (payload_len >> 8) & 0xFF;
    g_cert_buffer[12] = payload_len & 0xFF;
    
    uint16_t cert_desc_len = ctx->cert_len + 4;
    g_cert_buffer[15] = (cert_desc_len >> 8) & 0xFF;
    g_cert_buffer[16] = cert_desc_len & 0xFF;
    g_cert_buffer[17] = 0;
    g_cert_buffer[18] = 0;
    
    MFI_AUTH_LOG("Certificate loaded: %d bytes\n", ctx->cert_len);
    return MFI_AUTH_OK;
}

static void mfi_auth_update_state(mfi_auth_context_t *ctx, iap2_state_internal_t new_state) {
    if (ctx == NULL) {
        return;
    }

    if (ctx->state != new_state) {
        // 状态转换打印，映射为可读状态名
        static const char * const state_names[] = {"DETECT", "NEGOTIATE", "AUTH", "READY", "ANDROID"};
        const char *from = (ctx->state <= 4) ? state_names[ctx->state] : "UNKNOWN";
        const char *to = (new_state <= 4) ? state_names[new_state] : "UNKNOWN";

        MFI_AUTH_LOG("\n=== [STATE] %s -> %s ===\n\n", from, to);

        // 更新状态
        ctx->state = new_state;
        ctx->last_action_time = mfi_auth_get_current_time_ms();

        // 重置状态相关的计数器
        if (new_state == IAP2_STATE_NEGOTIATE) {
            ctx->syn_retry_count = 0;
        }

        // 触发状态变更回调
        if (ctx->event_callback) {
            mfi_auth_state_t public_state = (mfi_auth_state_t)new_state;
            ctx->event_callback(public_state, NULL);
        }
    }
}

static void mfi_auth_state_machine(mfi_auth_context_t *ctx) {
    if (ctx == NULL) {
        return;
    }
    
    uint32_t current_time = mfi_auth_get_current_time_ms();
    
    switch (ctx->state) {
        case IAP2_STATE_DETECT:
            // 检测阶段：定期发送检测包
            if (current_time - ctx->last_action_time >= 200) { // 200ms间隔
                mfi_auth_send_detect_packet(ctx);
                ctx->last_action_time = current_time;
            }
            break;

        case IAP2_STATE_NEGOTIATE:
            // 协商阶段：定期发送SYN包，带重试限制
            if (current_time - ctx->last_action_time >= 200) { // 200ms间隔
                if (ctx->syn_retry_count >= SYN_MAX_RETRY) {
                    MFI_AUTH_LOG("[SYN] Failed after %d retries\n", SYN_MAX_RETRY);
                    mfi_auth_update_state(ctx, IAP2_STATE_DETECT);
                } else {
                    mfi_auth_send_syn_packet(ctx);
                    ctx->syn_retry_count++;
                    ctx->last_action_time = current_time;
                }
            }
            break;
            
        case IAP2_STATE_AUTH:
            // 认证状态主要依赖接收处理，无需主动发送
            break;
            
        case IAP2_STATE_READY:
            // 就绪状态处理应用启动
            if (ctx->flags & MFI_FLAG_APP_LAUNCH_PENDING) {
                mfi_auth_send_app_launch_packet(ctx);
                ctx->flags &= ~MFI_FLAG_APP_LAUNCH_PENDING;
            }
            break;

        case IAP2_STATE_ANDROID:
            // Android 状态
            // 在此状态下，不主动发送任何 MFi 数据包。
            // 硬件层 (mfi_usb) 已经切换了 OS Type，
            // 此时可以认为是 Passthrough 模式或 AOA 模式等待。
            break;
            
        default:
            break;
    }
}

static void mfi_auth_send_detect_packet(mfi_auth_context_t *ctx) {
    (void)ctx; // 避免未使用参数警告
    uint8_t pkt[] = {0xff, 0x55, 0x02, 0x00, 0xee, 0x10};
    mfi_auth_log_packet("[TX] Detect", pkt, sizeof(pkt));
    mfi_auth_send_usb_data(pkt, sizeof(pkt));
}

static void mfi_auth_send_syn_packet(mfi_auth_context_t *ctx) {
    uint8_t *buf = ctx->tx_buf;
    uint16_t len = 26 - 3; // 23 bytes

    // Header
    buf[0] = 0xff;
    buf[1] = 0x5a;
    buf[2] = (len >> 8) & 0xFF;
    buf[3] = len & 0xFF;
    buf[4] = 0x80; // SYN
    buf[5] = ctx->tx_packet_seq; // SYN包不递增序列号（参考原代码）
    buf[6] = 0x00;
    buf[7] = 0x00;
    buf[8] = mfi_auth_calc_checksum(buf, 8);

    // Payload (Link Negotiation)
    uint8_t payload[] = {
        0x01, 0x01, 0x04, 0x00, 0x07, 0xd0, 0x03, 0x15, // Params
        0x0a, 0x01, 0xc1, 0x00, 0x01, 0xe1, 0x02, 0x01, 0x47};
    memcpy(&buf[9], payload, sizeof(payload)); // 17 bytes

    // Payload Checksum
    buf[len - 1] = mfi_auth_calc_checksum(buf + 9, len - 10);

    mfi_auth_log_packet("[TX] SYN", buf, len);
    mfi_auth_send_usb_data(buf, len);
    MFI_AUTH_DETAIL_LOG("[TX_DETAIL] SYN (Retry: %d/%d)\n", ctx->syn_retry_count, SYN_MAX_RETRY);
    // SYN包不递增序列号（参考原代码）
}

static void mfi_auth_send_ack_packet(mfi_auth_context_t *ctx) {
    uint8_t buf[9];
    buf[0] = 0xff;
    buf[1] = 0x5a;
    buf[2] = 0x00;
    buf[3] = 0x09;
    buf[4] = 0x40; // ACK
    buf[5] = ctx->tx_packet_seq;
    buf[6] = ctx->rx_packet_seq;
    buf[7] = 0x00;
    buf[8] = mfi_auth_calc_checksum(buf, 8);

    mfi_auth_log_packet("[TX] ACK", buf, 9);
    mfi_auth_send_usb_data(buf, 9);
    // ACK不打印，避免刷屏（在接收处理中会打印）
    // 关键修复：ACK包不递增序列号（参考原代码）
}

static int mfi_auth_send_certificate_packet(mfi_auth_context_t *ctx) {
    // 从预计算的包头读取总长度
    uint32_t total_len = (g_cert_buffer[2] << 8) | g_cert_buffer[3];
    
    // 更新动态字段（序列号递增）
    g_cert_buffer[5] = ++ctx->tx_packet_seq;   // 发送序列号
    g_cert_buffer[6] = ctx->rx_packet_seq;     // 接收序列号
    g_cert_buffer[8] = mfi_auth_calc_checksum(g_cert_buffer, 8); // 头部校验和
    
    // 计算载荷校验和
    g_cert_buffer[total_len - 1] = mfi_auth_calc_checksum(
        g_cert_buffer + 9,   // 载荷起始（令牌）
        total_len - 10       // 载荷长度（排除头部9字节+末尾校验和1字节）
    );

    MFI_AUTH_DETAIL_LOG("[CERT_DETAIL] TX Seq: %d, RX Seq: %d, Cert: %d bytes, Total: %d bytes\n",
                       ctx->tx_packet_seq, ctx->rx_packet_seq, ctx->cert_len, total_len);

    mfi_auth_log_packet("[TX] Certificate", g_cert_buffer, total_len);
    int result = mfi_auth_send_usb_data(g_cert_buffer, total_len);
    MFI_AUTH_LOG("[TX] Certificate (%d bytes) %s\n", total_len, (result==0)?"OK":"FAILED");
    return result;
}

static void mfi_auth_send_challenge_response_packet(mfi_auth_context_t *ctx) {
    // challenge_resp_buf 结构: [Header 9][Token 6][Len 4][Data ...][Checksum 1]
    uint32_t total_len = ctx->challenge_resp_len + 20;
    if (total_len > CHALLENGE_BUF_SIZE) {
        MFI_AUTH_LOG("[ERR] Challenge response too large: %d bytes (max %d)\n",
                     ctx->challenge_resp_len, CHALLENGE_BUF_SIZE - 20);
        return;
    }

    // Header
    g_challenge_buffer[0] = 0xff;
    g_challenge_buffer[1] = 0x5a;
    g_challenge_buffer[2] = (total_len >> 8) & 0xFF;
    g_challenge_buffer[3] = total_len & 0xFF;
    g_challenge_buffer[4] = 0x40; // Data
    g_challenge_buffer[5] = ++ctx->tx_packet_seq;
    g_challenge_buffer[6] = ctx->rx_packet_seq;
    g_challenge_buffer[7] = 0xc1; // Control Session
    g_challenge_buffer[8] = mfi_auth_calc_checksum(g_challenge_buffer, 8);

    // Payload Header
    g_challenge_buffer[9] = 0x40;
    g_challenge_buffer[10] = 0x40;
    uint16_t payload_len = ctx->challenge_resp_len + 10; // 6(Token)+4(LenDesc)+Data
    g_challenge_buffer[11] = (payload_len >> 8) & 0xFF;
    g_challenge_buffer[12] = payload_len & 0xFF;
    g_challenge_buffer[13] = 0xaa;
    g_challenge_buffer[14] = 0x03; // ID: Challenge Response

    // Length Descriptor
    uint16_t data_desc_len = ctx->challenge_resp_len + 4;
    g_challenge_buffer[15] = (data_desc_len >> 8) & 0xFF;
    g_challenge_buffer[16] = data_desc_len & 0xFF;
    g_challenge_buffer[17] = 0x00;
    g_challenge_buffer[18] = 0x00;

    g_challenge_buffer[total_len - 1] = mfi_auth_calc_checksum(
        g_challenge_buffer + 9,  // From payload start (token)
        total_len - 10           // Up to 1 byte before end of packet
    );

    mfi_auth_log_packet("[TX] Challenge Response", g_challenge_buffer, total_len);
    mfi_auth_send_usb_data(g_challenge_buffer, total_len);
    MFI_AUTH_LOG("[TX] Challenge Response (%d bytes)\n", ctx->challenge_resp_len);
}

static void mfi_auth_send_identification_packet(mfi_auth_context_t *ctx) {
    uint8_t *buf = ctx->tx_buf;
    uint8_t *params_buf = buf + 9 + 6; // Parameters start after Main Header (9) and Token Header (6)
    uint16_t params_max_len = sizeof(ctx->tx_buf) - (9 + 6 + 1); // Reserve space for headers and checksum

    // Define parameter groups exactly as in usb.c
    // SupportedExternalAccessoryProtocol Group (Param 10)
    IAP2_Param SupportedEAPParams[] = {
        DEF_PARAM_BIN(0, 1),
        DEF_PARAM_STR(1, MFI_EAP_INTERFACE_STRING),
        DEF_PARAM_BIN(2, 1),
        DEF_PARAM_BIN(3, 0x00, 0x01)
    };
    const IAP2_ParamGroup SupportedEAPParamGroup = {
        countof(SupportedEAPParams), SupportedEAPParams
    };

    // USBHostTransportComponent Group (Param 16)
    IAP2_Param USBHostTPParams[] = {
        DEF_PARAM_BIN(0, 0x00, 0x01),
        DEF_PARAM_STR(1, "iAP2 Accessory"),
        DEF_PARAM_EMPTY(2)
    };
    const IAP2_ParamGroup USBHostTPParamGroup = {
        countof(USBHostTPParams), USBHostTPParams
    };

    // Main Identification Parameters Group
    IAP2_Param IdentificationParams[] = {
        DEF_PARAM_STR(0, MFI_USBD_PRODUCT_STRING),
        DEF_PARAM_STR(1, MFI_USBD_PRODUCT_STRING),
        DEF_PARAM_STR(2, MFI_USBD_MANUFACTURER_STRING),
        DEF_PARAM_STR(3, MFI_USBD_SERIALNUMBER_STRING),
        DEF_PARAM_STR(4, MFI_FIRMWARE_VERSION),
        DEF_PARAM_STR(5, MFI_HARDWARE_VERSION),
        DEF_PARAM_BIN(6, 0xEA, 0x02),
        DEF_PARAM_BTR(7, ""), // CRITICAL FIX: Use BTR for 0-length string, was STR
        DEF_PARAM_BIN(8, 0),
        DEF_PARAM_BIN(9, 0, 100),
        DEF_PARAM_GRP(10, &SupportedEAPParamGroup),
        DEF_PARAM_STR(11, MFI_TEAM_ID),
        DEF_PARAM_STR(12, MFI_LANGUAGE),
        DEF_PARAM_STR(13, MFI_LANGUAGE),
        DEF_PARAM_GRP(16, &USBHostTPParamGroup),
        DEF_PARAM_STR(34, "de8f4b2daeb94f0a")
    };
    const IAP2_ParamGroup IdentificationGroup = {
        countof(IdentificationParams), IdentificationParams
    };

    // Build the parameters into the buffer
    int params_total_len = BuildParamsBuf(params_buf, params_max_len, &IdentificationGroup);
    if (params_total_len <= 0) {
        MFI_AUTH_LOG("[ERR] Failed to build identification params!\n");
        return;
    }

    uint16_t payload_len = params_total_len + 6; // 6 for Token Header
    uint16_t total_len = payload_len + 9 + 1;    // 9 for Main Header, 1 for checksum

    // Header
    buf[0] = 0xff;
    buf[1] = 0x5a;
    buf[2] = (total_len >> 8) & 0xFF;
    buf[3] = total_len & 0xFF;
    buf[4] = 0x40;
    buf[5] = ++ctx->tx_packet_seq;
    buf[6] = ctx->rx_packet_seq;
    buf[7] = 0xc1;
    buf[8] = mfi_auth_calc_checksum(buf, 8);

    // Token Header
    buf[9] = 0x40;
    buf[10] = 0x40;
    buf[11] = (payload_len >> 8) & 0xFF;
    buf[12] = payload_len & 0xFF;
    buf[13] = 0x1d;
    buf[14] = 0x01; // ID: Identification Information

    // Payload checksum
    buf[total_len - 1] = mfi_auth_calc_checksum(buf + 9, total_len - 10);

    mfi_auth_log_packet("[TX] Identification", buf, total_len);
    mfi_auth_send_usb_data(buf, total_len);
    MFI_AUTH_LOG("[TX] Identification (%d bytes)\n", total_len);
}

static void mfi_auth_send_app_launch_packet(mfi_auth_context_t *ctx) {
    uint8_t *buf = ctx->tx_buf;
    uint8_t *params_buf = buf + 9 + 6;
    uint16_t params_max_len = sizeof(ctx->tx_buf) - (9 + 6 + 1);

            // Define App Launch parameters manually with a hardcoded length to be certain.

            IAP2_Param AppLaunchParams[] = {

                { .id = 0, .len = 16, .value = (uint8_t *)MFI_EAP_APPBUNDLE_ID, .group = NULL }

            };

            const IAP2_ParamGroup AppLaunchGroup = { countof(AppLaunchParams), AppLaunchParams };

    int params_total_len = BuildParamsBuf(params_buf, params_max_len, &AppLaunchGroup);
    if (params_total_len <= 0) {
        MFI_AUTH_LOG("[ERR] Failed to build App Launch params!\n");
        return;
    }

    uint16_t payload_len = params_total_len + 6;
    uint16_t total_len = payload_len + 9 + 1;

    // Header
    buf[0] = 0xff;
    buf[1] = 0x5a;
    buf[2] = (total_len >> 8) & 0xFF;
    buf[3] = total_len & 0xFF;
    buf[4] = 0x40;
    buf[5] = ++ctx->tx_packet_seq;
    buf[6] = ctx->rx_packet_seq;
    buf[7] = 0xc1;
    buf[8] = mfi_auth_calc_checksum(buf, 8);

    // Token
    buf[9] = 0x40;
    buf[10] = 0x40;
    buf[11] = (payload_len >> 8) & 0xFF;
    buf[12] = payload_len & 0xFF;
    buf[13] = 0xea;
    buf[14] = 0x02; // App Launch

    // Payload checksum
    buf[total_len - 1] = mfi_auth_calc_checksum(buf + 9, total_len - 10);

    mfi_auth_log_packet("[TX] App Launch", buf, total_len);
    mfi_auth_send_usb_data(buf, total_len);
    MFI_AUTH_LOG("[TX] App Launch (Bundle: %s)\n", MFI_EAP_APPBUNDLE_ID);
}

static void mfi_auth_process_packet(mfi_auth_context_t *ctx, uint8_t *buf, uint16_t len) {
    if (ctx == NULL || buf == NULL || len == 0) {
        return;
    }

    uint16_t start = (buf[0] << 8) | buf[1];
    uint16_t pkt_len = (buf[2] << 8) | buf[3];
    uint8_t ctrl = buf[4];
    uint8_t seq = buf[5];
    uint8_t sess = buf[7];

    // 修复包长度验证
    if (pkt_len > len) {
        pkt_len = len;
    }

    // MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Start=0x%X, Len=%d, Ctrl=0x%X, Seq=%d\n",
    //                    start, pkt_len, ctrl, seq);

    if (start == 0xFF55) {
        // 校验前缀 FF 55 02 00 EE
        if (len >= 6 && buf[4] == 0xEE) {
            uint8_t type_byte = buf[5]; // 第6字节，区分 Apple(0x10) / Android(0x20)
            
            if (type_byte == 0x10) {
                // 检测到 Apple 设备
                if (ctx->device_type != MFI_DEVICE_APPLE) {
                    MFI_AUTH_LOG("[RX] Detect: APPLE Device (0x10)\n");
                    ctx->device_type = MFI_DEVICE_APPLE;
                    
                    // 通知硬件设置为 Apple 模式
                    mfi_usb_set_os_type(0);
                    
                    // 状态机跳转到协商阶段，开始发送 SYN
                    mfi_auth_update_state(ctx, IAP2_STATE_NEGOTIATE);
                    ctx->syn_retry_count = 0;
                }
            }
            else if (type_byte == 0x20) {
                // 检测到 Android 设备
                if (ctx->device_type != MFI_DEVICE_ANDROID) {
                    MFI_AUTH_LOG("[RX] Detect: ANDROID Device (0x20)\n");
                    ctx->device_type = MFI_DEVICE_ANDROID;
                    
                    // 通知硬件设置为 Android 模式
                    mfi_usb_set_os_type(1);
                    
                    // 状态机跳转到 ANDROID 状态，停止 MFi 流程
                    mfi_auth_update_state(ctx, IAP2_STATE_ANDROID);
                }
            }
        }
        return;
    }

    // 如果已确认为 Android 设备，直接忽略后续所有 MFi (FF 5A) 包
    if (ctx->device_type == MFI_DEVICE_ANDROID) {
        return;
    }

    if (start != 0xFF5A) {
        return;
    }

    // 校验 Header
    if (mfi_auth_calc_checksum(buf, 8) != buf[8]) {
        MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Header checksum error\n");
        return;
    }

    ctx->rx_packet_seq = seq; // 更新接收序列号供 ACK 使用

    // SYN + ACK
    if ((ctrl & 0x80) && (ctrl & 0x40)) {
        MFI_AUTH_LOG("[RX] SYN+ACK\n");
        mfi_auth_send_ack_packet(ctx);
        mfi_auth_update_state(ctx, IAP2_STATE_AUTH);
        ctx->flags &= ~MFI_FLAG_AUTH_SUCCEEDED;
        return;
    }

    // RST
    if (ctrl & 0x10) {
        MFI_AUTH_LOG("[RX] RST\n");
        mfi_auth_update_state(ctx, IAP2_STATE_NEGOTIATE);
        ctx->syn_retry_count = 0;
        mfi_auth_send_ack_packet(ctx);
        return;
    }

    // Control Session Data
    if (sess == 0xC1 && pkt_len > 9) {
        // 修复payload长度计算
        uint16_t payload_len = pkt_len - 9;
        if (payload_len > len - 9) {
            payload_len = len - 9;
        }

        // 如果payload长度不足以包含完整命令(最短需要Token(2)+Flags(2)+CmdID(2)=6字节)，直接ACK
        if (payload_len < 6) {
            MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Short control packet (%d bytes), sending ACK\n", payload_len);
            mfi_auth_send_ack_packet(ctx);
            return;
        }

        // 校验 Payload
        if (payload_len > 1 && mfi_auth_calc_checksum(buf + 9, payload_len - 1) != buf[9 + payload_len - 1]) {
            MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Payload checksum error\n");
            return;
        }
        mfi_auth_handle_control_session(ctx, buf + 9, payload_len);
    }
}

static void mfi_auth_handle_control_session(mfi_auth_context_t *ctx, uint8_t *payload, uint16_t len) {
    if (ctx == NULL || payload == NULL || len < 6) {
        return;
    }
    
    uint16_t token = (payload[0] << 8) | payload[1];
    uint16_t cmd_id = (payload[4] << 8) | payload[5];
    uint16_t cmd_len = 0;

    // 根据MFi协议，某些命令（如Request Certificate）没有ParamLen和ParamData字段
    // Payload最小结构: Token(2) + Flags(2) + CmdID(2) = 6字节
    // 完整结构会加上 ParamLen(2) + ParamData + Checksum(1)
    if (len >= 8) {
        cmd_len = (payload[6] << 8) | payload[7];  // 提取ParamLen
    } else {
        cmd_len = 0;  // 没有参数的命令（如Request Certificate）
    }

    if (token != 0x4040) {
        MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Invalid token 0x%X (expected 0x4040)\n", token);
        return;
    }

    switch (cmd_id) {
    case 0xAA00: // Request Certificate
        MFI_AUTH_LOG("[RX] Request Certificate\n");
        mfi_auth_send_certificate_packet(ctx);
        break;

    case 0xAA02: // Request Challenge Response
        {
            uint8_t *challenge_data = (len >= 10) ? payload + 10 : NULL;
            uint16_t challenge_len = (cmd_len > 4) ? cmd_len - 4 : 0;

            MFI_AUTH_LOG("[RX] Request Challenge Response (%d bytes)\n", challenge_len);

            // 使用 MFi 芯片计算响应，写入全局缓冲区
            ctx->challenge_resp_ptr = g_challenge_buffer + 19;
            mfi_chip_error_t chip_result = mfi_auth_chip_generate_challenge_response(
                challenge_data, challenge_len,
                ctx->challenge_resp_ptr,
                CHALLENGE_BUF_SIZE - 20,
                &ctx->challenge_resp_len);

            if (chip_result == MFI_CHIP_OK) {
                mfi_auth_send_challenge_response_packet(ctx);
            } else {
                MFI_AUTH_LOG("[ERR] Challenge generation failed: %d\n", chip_result);
                mfi_auth_send_ack_packet(ctx);
            }
        }
        break;

    case 0xAA05: // Auth Succeeded
        MFI_AUTH_LOG("\n=== [AUTH] ✓ PASSED ===\n\n");
        ctx->flags |= MFI_FLAG_AUTH_SUCCEEDED;
        mfi_auth_send_ack_packet(ctx);
        break;

    case 0xAA06: // Auth Failed
        MFI_AUTH_LOG("\n=== [AUTH] ✗ FAILED ===\n\n");
        ctx->flags &= ~MFI_FLAG_AUTH_SUCCEEDED;
        mfi_auth_update_state(ctx, IAP2_STATE_DETECT);
        mfi_auth_send_ack_packet(ctx);
        break;

    case 0x1D00: // Request Identification
        MFI_AUTH_LOG("[RX] Request Identification\n");
        if (ctx->flags & MFI_FLAG_AUTH_SUCCEEDED) {
            mfi_auth_send_identification_packet(ctx);
        } else {
            MFI_AUTH_DETAIL_LOG("[RX_DETAIL] Auth not complete yet\n");
            mfi_auth_send_ack_packet(ctx);
        }
        break;

    case 0x1D02: // Identification Accepted
        MFI_AUTH_LOG("[RX] Identification Accepted (0x1D02)\n");
        if (ctx->flags & MFI_FLAG_AUTH_SUCCEEDED) {
            mfi_auth_update_state(ctx, IAP2_STATE_READY);
            ctx->flags |= MFI_FLAG_APP_LAUNCH_PENDING;
            mfi_auth_send_ack_packet(ctx);
        }
        break;

    case 0x1D03: // Identification Status Update
        MFI_AUTH_LOG("[RX] Identification Status Update (0x1D03)\n");
        // 某些iOS版本可能发送0x1D03而不是0x1D02
        if (ctx->flags & MFI_FLAG_AUTH_SUCCEEDED) {
            mfi_auth_update_state(ctx, IAP2_STATE_READY);
            ctx->flags |= MFI_FLAG_APP_LAUNCH_PENDING;
        }
        mfi_auth_send_ack_packet(ctx);
        break;

    default:
        MFI_AUTH_LOG("[RX] Unknown Command: 0x%X\n", cmd_id);
        mfi_auth_send_ack_packet(ctx);
        break;
    }
}
// 定义 USB 端点最大包长，通常为 64，如果是高速 USB 可能是 512
#define USB_ENDPOINT_MAX_PACKET_SIZE 512

static int mfi_auth_send_usb_data(uint8_t *data, uint16_t len) {
    // 检查USB连接状态
    int usb_status = mfi_usb_check_availability();
    if (usb_status != MFI_USB_OK) {
        MFI_AUTH_DETAIL_LOG("[USB_DETAIL] USB unavailable (status: %d), reinitializing\n", usb_status);
        if (mfi_usb_init() != MFI_USB_OK) {
            MFI_AUTH_LOG("[ERR] USB init failed\n");
            return -2;
        }
    }

    uint16_t sent_len = 0;
    uint16_t chunk_len;
    mfi_usb_error_t err;
    int retry_count = 0;
    const int max_retries = 3;

    // 循环分包发送
    while (sent_len < len) {
        chunk_len = (len - sent_len > USB_ENDPOINT_MAX_PACKET_SIZE) ?
                    USB_ENDPOINT_MAX_PACKET_SIZE : (len - sent_len);

        err = mfi_usb_write(&data[sent_len], chunk_len);

        if (err != MFI_USB_OK) {
            // 只在最后一次重试失败时打印错误
            if (++retry_count >= max_retries) {
                MFI_AUTH_LOG("[ERR] USB write failed at offset %d: %d\n", sent_len, err);
                // 尝试重置USB
                if (mfi_usb_init() != MFI_USB_OK) {
                    return -3;
                }
                retry_count = 0;
            }
            continue;
        }

        sent_len += chunk_len;
        retry_count = 0;
    }

    MFI_AUTH_DETAIL_LOG("[USB_DETAIL] Sent %d bytes\n", len);
    return 0;
}

// 获取当前时间（毫秒）
// 内联函数以优化性能（频繁调用的时间获取函数）
static inline uint32_t mfi_auth_get_current_time_ms(void) {
    // 直接使用timer0_count变量获取当前时间
    return timer0_count;
}

static void mfi_auth_log_packet(const char *prefix, const uint8_t *data, uint16_t len) {
#if DEBUG_LEVEL >= DEBUG_LEVEL_DEBUG
    MFI_AUTH_LOG("%s Packet (Len: %d): ", prefix, len);
    uint16_t print_len = (len > 64) ? 64 : len; // Print max 64 bytes
    for (uint16_t i = 0; i < print_len; i++) {
        DEBUG_INFO_NO_PREFIX("%x ", data[i]);
    }
    if (len > 64) {
        DEBUG_INFO_NO_PREFIX("... (truncated)\n");
    } else {
        DEBUG_INFO_NO_PREFIX("\n");
    }
#else
    (void)prefix;
    (void)data;
    (void)len;
#endif
}

// ================================================================================
// 公共API实现 - 设备类型查询
// ================================================================================

int mfi_auth_get_device_type(void) {
    if (!g_module_initialized) return MFI_DEVICE_UNKNOWN; // Unknown
    return g_context.device_type; // 1=Apple, 2=Android
}