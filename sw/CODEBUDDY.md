# CODEBUDDY.md

This file provides essential information for CodeBuddy Code to work effectively in this NEORV32 RISC-V processor software framework repository.

## Build System and Common Commands

This project uses a Make-based build system with a central makefile (`common/common.mk`) that provides standardized targets for all applications.

### Building Applications

Navigate to any application directory (e.g., `app/`, `example/hello_world/`, etc.) and use these commands:

```bash
# Build ELF executable
make elf

# Build bootloader-compatible executable 
make exe

# Build all formats (ELF, assembly, executable, hex, binary, memory images)
make all

# Build and install VHDL memory image to RTL core
make install

# Clean build artifacts
make clean

# Clean everything including image generator
make clean_all

# Show build configuration
make info

# Check toolchain installation
make check

# Start GDB debugging session
make gdb

# Run simulation using GHDL testbench
make sim
```

### Memory Image Formats

The build system can generate multiple memory image formats:
- `make hex` - Intel HEX format
- `make bin` - Raw binary format  
- `make coe` - Xilinx COE format
- `make mem` - Verilog MEM format
- `make mif` - Altera MIF format

### Bootloader Development

For bootloader-specific builds:
```bash
# Build bootloader VHDL image
make bl_image

# Build and install bootloader to RTL
make bootloader
```

## Architecture Overview

### Directory Structure

- **`common/`** - Central build system, linker scripts, and startup code
  - `common.mk` - Main makefile with all build targets and toolchain configuration
  - `crt0.S` - RISC-V startup/boot code
  - `neorv32.ld` - Linker script for memory layout

- **`lib/`** - NEORV32 core library and Hardware Abstraction Layer (HAL)
  - `include/neorv32.h` - Main HAL header with peripheral definitions
  - `source/` - Driver implementations for all NEORV32 peripherals

- **`app/`** - Main application with custom HAL layer
  - Custom HAL design with `hal/`, `dev/`, `app/` subdirectories
  - Provides higher-level abstractions over core NEORV32 drivers
  - State machine architecture in `main.c` with initial/pooling states

- **`example/`** - Demo applications and test programs
  - Each subdirectory contains a complete example with its own makefile
  - Examples include GPIO, UART, SPI, PWM, and peripheral demos

- **`bootloader/`** - Default NEORV32 bootloader source
- **`image_gen/`** - Executable image generator tool (compiled automatically)
- **`openocd/`** - OpenOCD configuration for JTAG debugging
- **`ocd-firmware/`** - On-chip debugger firmware

### Build Configuration

Applications configure builds through local makefiles that include `common/common.mk`:

Key variables:
- `APP_SRC` - Application source files
- `APP_INC` - Include directories  
- `MARCH` - RISC-V architecture (default: rv32i_zicsr_zifencei)
- `MABI` - ABI specification (default: ilp32)
- `EFFORT` - Optimization level (default: -Os)
- `USER_FLAGS` - Custom compiler/linker flags
- `NEORV32_HOME` - Path to NEORV32 root directory

### Toolchain Requirements

- RISC-V GCC toolchain with prefix `riscv-none-elf-`
- Default architecture: RV32I with Zicsr and Zifencei extensions
- Native GCC for building image generator tool

### Hardware Abstraction

The project uses a two-layer HAL approach:
1. **Core HAL** (`lib/`) - Low-level peripheral drivers matching hardware registers
2. **Application HAL** (`app/hal/`) - Higher-level abstractions for common operations

The application HAL encapsulates GPIO, UART, I2C operations and provides application-specific pin mappings and simplified interfaces.

### Memory Layout

Applications use the NEORV32 linker script which defines:
- ROM/IMEM for program code
- RAM/DMEM for data and stack
- Memory sizes configurable via linker symbols (`__neorv32_rom_size`, `__neorv32_ram_size`)

### Debugging and Simulation

- GDB debugging via OpenOCD and JTAG interface
- GHDL-based simulation using default testbench in `sim/` directory
- Assembly listings generated for debugging (`make asm`)