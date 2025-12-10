// ================================================================================
// MFi Authentication Parameters Builder Header
// iAP2参数构建模块头文件
// ================================================================================
//
// MODULE DEPENDENCIES:
//   - None (standalone parameter serialization)
//
// PURPOSE:
//   This module provides functions and macros for building iAP2 protocol
//   parameter structures. It handles nested parameter groups and serializes
//   them into the binary format required by the iAP2 protocol for
//   identification and app launch messages.
//
// ================================================================================

#ifndef MFI_AUTH_PARAMS_H
#define MFI_AUTH_PARAMS_H

#include <stdint.h>

// ================================================================================
// Type Definitions (from usb.c)
// ================================================================================

struct IAP2_ParamGroup; // Forward declaration

typedef struct {
    uint16_t id;
    uint16_t len;
    uint8_t* value;
    const struct IAP2_ParamGroup* group;
} IAP2_Param;

typedef struct IAP2_ParamGroup {
    int count;
    const IAP2_Param* params;
} IAP2_ParamGroup;

// ================================================================================
// Helper Macros (from usb.c)
// ================================================================================

#define countof(x) (sizeof(x) / sizeof(x[0]))

// DEF_PARAM_STR: Defines a string parameter, including the null terminator in length.
#define DEF_PARAM_STR(param_id, str_literal)     { .id = param_id, .len = sizeof(str_literal), .value = (uint8_t *)(str_literal), .group = NULL }

// DEF_PARAM_BTR: Defines a byte string parameter, excluding the null terminator from length.
#define DEF_PARAM_BTR(param_id, str_literal)     { .id = param_id, .len = sizeof(str_literal) - 1, .value = (uint8_t *)(str_literal), .group = NULL }

// DEF_PARAM_BIN: Defines a binary data parameter from a compound literal.
#define DEF_PARAM_BIN(param_id, ...)   { .id = param_id, .len = sizeof((uint8_t []){__VA_ARGS__}), .value = (uint8_t []){__VA_ARGS__}, .group = NULL }

// DEF_PARAM_GRP: Defines a nested parameter group.
#define DEF_PARAM_GRP(param_id, grp_ptr) { .id = param_id, .len = 0, .value = 0, .group = grp_ptr }

// DEF_PARAM_EMPTY: Defines a parameter with no value (length 0).
#define DEF_PARAM_EMPTY(param_id)      { .id = param_id, .len = 0, .value = 0, .group = NULL }

// ================================================================================
// Function Declarations
// ================================================================================

/**
 * @brief Builds a parameter buffer from a parameter group definition.
 * @param dst The destination buffer to write the serialized parameters into.
 * @param len The maximum length of the destination buffer.
 * @param group A pointer to the IAP2_ParamGroup to serialize.
 * @return The total length of the serialized parameters written to the buffer, or 0 on failure.
 */
int BuildParamsBuf(uint8_t* dst, uint16_t len, const IAP2_ParamGroup* group);

#endif // MFI_AUTH_PARAMS_H
