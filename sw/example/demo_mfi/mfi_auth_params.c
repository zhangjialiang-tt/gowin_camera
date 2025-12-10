#include <neorv32.h>
#include "mfi_auth_params.h"
#include <string.h> // For memcpy
#include "debug.h"   // For MFI_AUTH_LOG

/**
 * @brief Builds a parameter buffer from a parameter group definition. (Copied from usb.c)
 * @param dst The destination buffer to write the serialized parameters into.
 * @param len The maximum length of the destination buffer.
 * @param group A pointer to the IAP2_ParamGroup to serialize.
 * @return The total length of the serialized parameters written to the buffer, or 0 on failure.
 */
int BuildParamsBuf(uint8_t* dst, uint16_t len, const IAP2_ParamGroup* group) {
    if (dst == NULL || len == 0 || group == NULL) {
        return 0;
    }

    int ret = 0;
    const IAP2_Param* param = group->params;
    uint8_t* buf = dst;

    for (int i = 0; i < group->count; i++) {
        DEBUG_INFO("[BuildParams] Param ID: %d, Initial param->len: %d\n", param->id, param->len);

        int size = param->len;

        // Check if there is enough space for the parameter header (4 bytes)
        if (len < 4) {
            break;
        }

        if (param->group != NULL) {
            // Recursively build nested parameter group
            size = BuildParamsBuf(buf + 4, len - 4, param->group);
            if (size <= 0) {
                // If the nested group is empty but should be included (like an empty group param),
                // it should return 0, but we still need to write its header.
                // For simplicity, we assume if it returns <=0, it's an error or truly empty.
                // Let's stick to the original logic for now.
            }
        }
        
        // Total size for this parameter = data length + 4-byte header
        int total_param_size = size + 4;
        
        DEBUG_INFO("[BuildParams] Final size: %d, total_param_size: %d\n", size, total_param_size);

        if (len < total_param_size) {
            break; // Not enough space in the destination buffer
        }

        // Write parameter header: Length (2 bytes) and ID (2 bytes)
        buf[0] = (total_param_size >> 8) & 0xFF;
        buf[1] = total_param_size & 0xFF;
        buf[2] = (param->id >> 8) & 0xFF;
        buf[3] = param->id & 0xFF;

        if (param->group == NULL && param->value != NULL && param->len > 0) {
            memcpy(buf + 4, param->value, param->len);
        }

        buf += total_param_size;
        ret += total_param_size;
        len -= total_param_size;
        param++;
    }

    return ret;
}
