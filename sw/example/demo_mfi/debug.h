// ================================================================================
// Debug Macros Header
// Unified debug interface for MFi authentication system
// ================================================================================
//
// USAGE:
//   - Set DEBUG=0 in makefile for production builds (zero overhead)
//   - Set DEBUG=1 in makefile for development builds (full debug logging)
//   - Use DEBUG_ERROR() for critical errors
//   - Use DEBUG_WARN() for warnings
//   - Use DEBUG_INFO() for general information
//   - Use DEBUG_DEBUG() for detailed debugging (packet dumps, etc.)
//
// REQUIREMENTS:
//   - Validates Requirements 2.4, 6.1, 6.2, 6.3, 6.4
//   - All debug code uses #if DEBUG instead of #ifdef DEBUG
//   - Debug code produces zero overhead when DEBUG=0
//   - Unified debug macro interface (DEBUG_INFO, DEBUG_ERROR, etc.)
//
// ================================================================================

#ifndef DEBUG_H
#define DEBUG_H

#include "neorv32_uart.h"

// Debug level definitions
#define DEBUG_LEVEL_NONE 0
#define DEBUG_LEVEL_ERROR 1
#define DEBUG_LEVEL_WARN 2
#define DEBUG_LEVEL_INFO 3
#define DEBUG_LEVEL_DEBUG 4

// Master debug switch - set to 0 for production builds
// This is controlled by the makefile: make DEBUG=0 for production
#ifndef DEBUG
#define DEBUG 1
#endif

// Set current debug level (only active when DEBUG=1)
#if DEBUG
#define DEBUG_LEVEL DEBUG_LEVEL_INFO
#else
#define DEBUG_LEVEL DEBUG_LEVEL_NONE
#endif

#if DEBUG_LEVEL >= DEBUG_LEVEL_ERROR
#define DEBUG_ERROR(...) neorv32_uart0_printf("[ERROR] " __VA_ARGS__)
#else
#define DEBUG_ERROR(...) \
    do                   \
    {                    \
    } while (0)
#endif

#if DEBUG_LEVEL >= DEBUG_LEVEL_WARN
#define DEBUG_WARN(...) neorv32_uart0_printf("[WARN] " __VA_ARGS__)
#else
#define DEBUG_WARN(...) \
    do                  \
    {                   \
    } while (0)
#endif

#if DEBUG_LEVEL >= DEBUG_LEVEL_INFO
#define DEBUG_INFO(...) neorv32_uart0_printf("[INFO] " __VA_ARGS__)
#define DEBUG_INFO_NO_PREFIX(...) neorv32_uart0_printf(__VA_ARGS__)
#else
#define DEBUG_INFO(...) \
    do                  \
    {                   \
    } while (0)
#define DEBUG_INFO_NO_PREFIX(...) \
    do                  \
    {                   \
    } while (0)
#endif

#if DEBUG_LEVEL >= DEBUG_LEVEL_DEBUG
#define DEBUG_DEBUG(...) neorv32_uart0_printf("[DEBUG] " __VA_ARGS__)
#else
#define DEBUG_DEBUG(...) \
    do                   \
    {                    \
    } while (0)
#endif

#endif // DEBUG_H
