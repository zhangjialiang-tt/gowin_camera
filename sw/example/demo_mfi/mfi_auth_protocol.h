// ================================================================================
// MFi Authentication Protocol Header
// iAP2协议处理模块头文件
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - mfi_auth_utils.h: Utility functions (checksum calculation)
//
// PURPOSE:
//   This module defines the iAP2 (iPod Accessory Protocol 2) packet structures,
//   control flags, and command IDs used in MFi authentication. The actual packet
//   construction and parsing is performed directly in mfi_auth.c for optimization.
//
// NOTE:
//   Packet constructor and parser functions have been removed as they were unused.
//   Packet construction is done inline in mfi_auth.c for better performance.
//
// ================================================================================

#ifndef MFI_AUTH_PROTOCOL_H
#define MFI_AUTH_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>
#include "mfi_auth_utils.h"

#ifdef __cplusplus
extern "C" {
#endif

// ================================================================================
// iAP2 协议包类型定义
// ================================================================================

typedef enum {
    IAP2_PACKET_DETECT = 0xFF55,
    IAP2_PACKET_DATA = 0xFF5A
} iap2_packet_type_t;

typedef enum {
    IAP2_CTRL_SYN = 0x80,
    IAP2_CTRL_ACK = 0x40,
    IAP2_CTRL_RST = 0x10
} iap2_control_flag_t;

typedef enum {
    IAP2_SESSION_CONTROL = 0xC1,
    IAP2_SESSION_DATA = 0x40
} iap2_session_type_t;

// 命令ID定义
typedef enum {
    IAP2_CMD_CERT_REQUEST = 0xAA00,
    IAP2_CMD_CHALLENGE_REQUEST = 0xAA02,
    IAP2_CMD_AUTH_SUCCESS = 0xAA05,
    IAP2_CMD_AUTH_FAILED = 0xAA06,
    IAP2_CMD_IDENT_REQUEST = 0x1D00,
    IAP2_CMD_IDENT_ACCEPTED = 0x1D02,
    IAP2_CMD_APP_LAUNCH = 0xEA02
} iap2_command_id_t;

// ================================================================================
// iAP2 协议包结构定义
// ================================================================================

typedef struct {
    uint16_t start_marker;    // 0xFF55 or 0xFF5A
    uint16_t length;          // 包长度
    uint8_t control;          // 控制标志
    uint8_t tx_seq;           // 发送序列号
    uint8_t rx_seq;           // 接收序列号
    uint8_t session;          // 会话类型
    uint8_t header_checksum;  // 头部校验和
} iap2_header_t;

typedef struct {
    uint16_t token;           // 令牌 (通常为0x4040)
    uint16_t payload_length;  // 载荷长度
    uint8_t message_type;     // 消息类型
    uint8_t command_id;       // 命令ID
} iap2_control_header_t;

typedef struct {
    uint16_t param_id;        // 参数ID
    uint16_t param_length;    // 参数长度
    uint8_t *param_data;      // 参数数据
} iap2_parameter_t;

typedef struct {
    iap2_header_t header;
    union {
        uint8_t raw_data[512];
        iap2_control_header_t ctrl_header;
        uint8_t detect_data[2];
    } payload;
    uint8_t checksum;
} iap2_packet_t;

// Note: All packet constructor, parser, and transport functions have been removed
// as they are unused. Packet construction is done directly in mfi_auth.c.

#ifdef __cplusplus
}
#endif

#endif // MFI_AUTH_PROTOCOL_H