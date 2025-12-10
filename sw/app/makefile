# Example Application Makefile for Custom HAL

# Add your application C sources here
APP_SRC = main.c

# Add your custom HAL C sources here
APP_SRC += hal/src/hal_interrupt.c
APP_SRC += hal/src/hal_gpio.c
# APP_SRC += hal/src/hal_uart.c
APP_SRC += hal/src/hal_i2c.c
APP_SRC += hal/src/i2c_apb.c
# APP_SRC += hal/src/hal_comp_func.c

APP_SRC += dev/src/gc2145_cmos.c
APP_SRC += dev/src/dev_shutter.c
APP_SRC += dev/src/zg_mdk_sensor_gst212w.c
# APP_SRC += dev/dev_eeprom.c

APP_SRC += app/src/temperature.c
APP_SRC += app/src/app_gpio.c
APP_SRC += app/src/app_sensor.c
APP_SRC += app/src/app_i2c.c
APP_SRC += app/src/GOWIN_M1_it.c
APP_SRC += app/src/apb.c
APP_SRC += app/src/sensor_ctrl.c
APP_SRC += app/src/usb_process.c
APP_SRC += app/src/user_spi_flash.c

# MFi Authentication sources
APP_SRC += mfi_src/mfi_auth.c
APP_SRC += mfi_src/mfi_auth_chip.c
APP_SRC += mfi_src/mfi_auth_params.c
APP_SRC += mfi_src/mfi_auth_protocol.c
APP_SRC += mfi_src/mfi_auth_utils.c
APP_SRC += mfi_src/mfi_iic/mfi_iic.c
APP_SRC += mfi_src/mfi_usb/mfi_usb.c

# Add your application include folders (if any, besides the current directory)
APP_INC += -I ./hal/inc
APP_INC += -I ./dev/inc
APP_INC += -I ./app/inc
APP_INC += -I ./inc
APP_INC += -I ./mfi_inc

# Add your application assembly sources (if any)
# APP_SRC += my_asm.S

# Add your application object files (if any, pre-compiled)
# APP_OBJ += my_precompiled_obj.o

# Add your assembly include folders (if any, besides the current directory)
# ASM_INC += -I ./my_asm_include_dir


# CPU architecture and ABI
# The default is rv32i_zicsr_zifencei (integer-only ISA)
# If your application uses floating-point, you might need to change this.
# MARCH = rv32imc_zicsr_zifencei # Example for FPU
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
DEBUG ?= 0
ifeq ($(DEBUG), 1)
USER_FLAGS += -DDEBUG=1
else
USER_FLAGS += -DDEBUG=0
endif

# ================================================================================
# Compiler Flags
# ================================================================================

# Warning flags
USER_FLAGS += -Wall -Wextra

# C standard
USER_FLAGS += -std=gnu99

# Additional sources
#APP_SRC += $(wildcard ./*.c)
#APP_INC += -I .

# Set path to NEORV32 root directory

# Include the main NEORV32 makefile
# This is the heart of the build system.
# Make sure NEORV32_HOME points to the root of your NEORV32 project.
# By default, it looks 3 levels up from the current directory (../../..).
# If that's not correct, redefine it here or via the command line.
# NEORV32_HOME = /path/to/your/neorv32
NEORV32_HOME ?= ../..
include $(NEORV32_HOME)/sw/common/common.mk
