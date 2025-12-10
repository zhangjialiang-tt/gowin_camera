# Application makefile.
# Use this makefile to configure all relevant CPU / compiler options.

# Override the default CPU ISA
MARCH = rv32i_zicsr_zifencei

# Override the default RISC-V GCC prefix
#RISCV_PREFIX ?= riscv-none-elf-

# Override default optimization goal
EFFORT = -Os

# Add extended debug symbols
USER_FLAGS += -ggdb -gdwarf-3

# Optimization flags for code size reduction
USER_FLAGS += -ffunction-sections -fdata-sections
USER_FLAGS += -fno-unwind-tables -fno-asynchronous-unwind-tables

# Enable Link Time Optimization
USER_FLAGS += -flto

# Linker flags for garbage collection of unused sections
USER_FLAGS += -Wl,--gc-sections

# Adjust processor IMEM size
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=32k

# Adjust processor DMEM size
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=8k

# ================================================================================
# Build Configuration
# ================================================================================

# Build target selection
# Available targets: simple, advanced, demo
BUILD_TARGET ?= simple

# Debug configuration
# Set DEBUG=0 for production builds (zero debug overhead)
# Set DEBUG=1 for development builds (full debug logging)
DEBUG ?= 1
ifeq ($(DEBUG), 1)
USER_FLAGS += -DDEBUG=1
else
USER_FLAGS += -DDEBUG=0
endif

# ================================================================================
# Source Files Configuration
# ================================================================================

# Common source files (always included)
COMMON_SRC += $(wildcard ./mfi_auth.c)
COMMON_SRC += $(wildcard ./mfi_auth_utils.c)
COMMON_SRC += $(wildcard ./mfi_auth_protocol.c)
COMMON_SRC += $(wildcard ./mfi_auth_params.c)
COMMON_SRC += $(wildcard ./mfi_auth_chip.c)
COMMON_SRC += ./mfi_iic/mfi_iic.c
COMMON_SRC += ./mfi_usb/mfi_usb.c

# Target-specific source files
ifeq ($(BUILD_TARGET), simple)
APP_SRC += $(wildcard ./main.c)
else ifeq ($(BUILD_TARGET), advanced)
APP_SRC += $(wildcard ./main_advanced.c)
else ifeq ($(BUILD_TARGET), demo)
APP_SRC += $(wildcard ./mfi_auth_flow.c)  # Original demo
else
APP_SRC += $(wildcard ./main.c)   # Default to simple
endif

# Include all sources
APP_SRC += $(COMMON_SRC)

# ================================================================================
# Include Directories
# ================================================================================

APP_INC += -I .
APP_INC += -I ./mfi_iic
APP_INC += -I ./mfi_usb

# ================================================================================
# Compiler Flags
# ================================================================================

# Warning flags
USER_FLAGS += -Wall -Wextra

# C standard
USER_FLAGS += -std=gnu99

# ================================================================================
# Set path to NEORV32 root directory
# ================================================================================

NEORV32_HOME ?= ../../..

# Include the main NEORV32 makefile
include $(NEORV32_HOME)/sw/common/common.mk
