# Makefile for extracting impl.rar to the same directory
# Supports Windows, Linux, and macOS

# Target RAR file
RAR_FILE = ZC23A/GW_PHONE_FPGA/impl.rar
# Extract directory (same as RAR file location)
EXTRACT_DIR = ZC23A/GW_PHONE_FPGA

# Git backup file naming with timestamp
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
GIT_BACKUP_FILE_WINDOWS = git_backup_$(TIMESTAMP).7z
GIT_BACKUP_FILE_UNIX = git_backup_$(TIMESTAMP).tar.gz

# NEORV32_PRJ = ZC23A/GW_PHONE_FPGA/sw/app
# NEORV32_PRJ = ZC23A/GW_PHONE_FPGA/sw/example/hello_world
# NEORV32_PRJ = ZC23A/GW_PHONE_FPGA/sw/example/demo_mfi_iic
# NEORV32_PRJ = ZC23A/GW_PHONE_FPGA/sw/example/demo_usb_wb
NEORV32_PRJ = sw/app

# Python virtual environment path
# PYTHON_VENV = /c/Users/07234zjl/.venv_serial/Scripts/python
# PYTHON_VENV = C:\100-Working\102-Working-Prj\Embedded_Group_Repositories\.venv_serial\Scripts\python
PYTHON_VENV = C:\Users\07234zjl\.venv_serial\Scripts\python

# NEORV32 upload configuration
NEORV32_TERMINAL = scripts/terminal.py
NEORV32_PORT = COM5
NEORV32_BAUDRATE = 115200
NEORV32_EXE_FILE = $(NEORV32_PRJ)/neorv32_exe.bin

# Detect OS
ifeq ($(OS),Windows_NT)
    # Windows
    UNRAR_CMD = where unrar >nul 2>&1 && unrar x -y impl.rar . || where 7z >nul 2>&1 && 7z x -y impl.rar -o.
    DETECT_OS = windows
    # Check if tar is available on Windows
    HAS_TAR := $(shell where tar >nul 2>&1 && echo yes || echo no)
    # Git pack/unpack commands for Windows
    ifeq ($(HAS_TAR),yes)
        GIT_PACK_CMD = tar -czf $(GIT_BACKUP_FILE_UNIX) .git
        GIT_UNPACK_CMD = tar -xzf $(GIT_BACKUP_FILE_UNIX)
        GIT_LIST_BACKUPS = dir /b git_backup_*.tar.gz 2>nul
    else
        GIT_PACK_CMD = 7z a -t7z -mx=9 $(GIT_BACKUP_FILE_WINDOWS) .git
        GIT_UNPACK_CMD = 7z x -y $(GIT_BACKUP_FILE_WINDOWS)
        GIT_LIST_BACKUPS = dir /b git_backup_*.7z 2>nul
    endif
else
    # Unix-like systems (Linux, macOS)
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECT_OS = linux
    endif
    ifeq ($(UNAME_S),Darwin)
        DETECT_OS = macos
    endif
    UNRAR_CMD = which unrar >/dev/null 2>&1 && unrar x -y impl.rar . || which 7z >/dev/null 2>&1 && 7z x -y impl.rar -o.
    # Git pack/unpack commands for Unix-like systems
    GIT_PACK_CMD = tar -czf $(GIT_BACKUP_FILE_UNIX) .git
    GIT_UNPACK_CMD = tar -xzf $(GIT_BACKUP_FILE_UNIX)
    GIT_LIST_BACKUPS = ls -1 git_backup_*.tar.gz 2>/dev/null
endif

.PHONY: extract check-tools help pack unpack neorv32 neorv32_upload neorv32_terminal

# Default target
all: extract

# Extract the RAR file
extract: check-tools
	@echo "Detected OS: $(DETECT_OS)"
	@echo "Extracting $(RAR_FILE) to $(EXTRACT_DIR)..."
	@cd $(EXTRACT_DIR) && $(UNRAR_CMD)

# Check for required tools
check-tools:
ifeq ($(OS),Windows_NT)
	@where unrar >nul 2>&1 && echo "Found: unrar" || where 7z >nul 2>&1 && echo "Found: 7z" || (echo "Error: Neither unrar nor 7z found. Please install WinRAR or 7-Zip." && exit 1)
else
	@which unrar >/dev/null 2>&1 && echo "Found: unrar" || which 7z >/dev/null 2>&1 && echo "Found: 7z" || (echo "Error: Neither unrar nor 7z found. Please install unrar or p7zip." && exit 1)
endif

# Pack the .git directory
pack: check-git-tools
	@echo "Detected OS: $(DETECT_OS)"
	@echo "Packing .git directory..."
ifeq ($(OS),Windows_NT)
ifeq ($(HAS_TAR),yes)
	@echo "Creating backup file: $(GIT_BACKUP_FILE_UNIX)"
	@$(GIT_PACK_CMD) && echo "Successfully packed .git to $(GIT_BACKUP_FILE_UNIX)" || (echo "Error: Failed to pack .git directory" && exit 1)
else
	@echo "Creating backup file: $(GIT_BACKUP_FILE_WINDOWS)"
	@$(GIT_PACK_CMD) && echo "Successfully packed .git to $(GIT_BACKUP_FILE_WINDOWS)" || (echo "Error: Failed to pack .git directory" && exit 1)
endif
else
	@echo "Creating backup file: $(GIT_BACKUP_FILE_UNIX)"
	@$(GIT_PACK_CMD) && echo "Successfully packed .git to $(GIT_BACKUP_FILE_UNIX)" || (echo "Error: Failed to pack .git directory" && exit 1)
endif

# Unpack the .git directory
unpack:
	@echo "Detected OS: $(DETECT_OS)"
	@echo "Unpacking .git directory..."
	@echo "Looking for backup files..."
	@$(GIT_LIST_BACKUPS)
	@echo ""
	@echo "Please specify the backup file to unpack:"
	@echo "Example: make unpack FILE=git_backup_20231119_143022.tar.gz"
	@echo "Extracting from git_backup_20251119_161837.tar.gz..."
	@C:\Software\msys64\usr\bin\tar.exe -xzf git_backup_20251119_161837.tar.gz
	@echo "Successfully unpacked .git from git_backup_20251119_161837.tar.gz"

# Check for required tools for git operations
check-git-tools:
ifeq ($(OS),Windows_NT)
	@where tar >nul 2>&1 && echo "Found: tar" || where 7z >nul 2>&1 && echo "Found: 7z" || (echo "Error: Neither tar nor 7z found. Please install tar (included with Windows 10+) or 7-Zip and add to PATH." && exit 1)
else
	@which tar >/dev/null 2>&1 && echo "Found: tar" || (echo "Error: tar not found. Please install tar." && exit 1)
endif

# Show help
help:
	@echo "Makefile for extracting impl.rar, managing .git backups and compiling NEORV32 software"
	@echo ""
	@echo "Usage:"
	@echo "  make          - Extract impl.rar to current directory"
	@echo "  make extract  - Same as 'make'"
	@echo "  make pack     - Pack .git directory to a timestamped archive"
	@echo "  make unpack   - Unpack .git directory from a specified archive"
	@echo "  make neorv32        - Compile NEORV32 software (enter ZC23A/GW_PHONE_FPGA/sw/app and run make exe)"
	@echo "  make neorv32_upload - Upload NEORV32 software via bootloader using Python virtual environment"
	@echo "  make neorv32_terminal - Start NEORV32 interactive terminal using Python virtual environment"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Git Backup Examples:"
	@echo "  make pack                    # Creates git_backup_YYYYMMDD_HHMMSS.tar.gz"
	@echo "  make unpack FILE=backup.tar.gz  # Extracts from the specified backup file"
	@echo ""
	@echo "NEORV32 Compilation:"
	@echo "  make neorv32                # Compiles the NEORV32 software in $(NEORV32_PRJ)"
	@echo ""
	@echo "NEORV32 Upload:"
	@echo "  make neorv32_upload         # Uploads the compiled software to the device via bootloader"
	@echo "                              # Uses Python virtual environment: $(PYTHON_VENV)"
	@echo "                              # Default port: $(NEORV32_PORT), baudrate: $(NEORV32_BAUDRATE)"
	@echo ""
	@echo "NEORV32 Terminal:"
	@echo "  make neorv32_terminal       # Starts interactive terminal for communicating with NEORV32"
	@echo "                              # Uses Python virtual environment: $(PYTHON_VENV)"
	@echo "                              # Default port: $(NEORV32_PORT), baudrate: $(NEORV32_BAUDRATE)"
	@echo ""
	@echo "Requirements:"
	@echo "  - For RAR extraction: unrar or 7z (7-Zip) must be installed"
	@echo "  - For Git operations: tar (included with Windows 10+, Linux, macOS) or 7z (Windows)"
	@echo "  - For NEORV32 compilation: RISC-V toolchain must be installed"
	@echo "  - Windows: tar is included with Windows 10+, or install 7-Zip and add to PATH"
	@echo "  - Linux: sudo apt-get install unrar or p7zip-full"
	@echo "  - macOS: brew install unrar or brew install p7zip"

# Compile NEORV32 software
neorv32:
	@echo "Compiling NEORV32 software..."
	@cd $(NEORV32_PRJ) && $(MAKE) clean && $(MAKE) exe

# Clean extracted files (optional)
clean:
	@echo "Cleaning extracted files..."
	@cd $(dir $(RAR_FILE)) && find . -type f -not -name '$(RAR_FILE)' -not -name 'Makefile' -delete 2>/dev/null || true
# Upload NEORV32 software via bootloader (automatic mode)
neorv32_upload:
	@echo "INFO: Uploading NEORV32 software to $(NEORV32_PORT) (baudrate: $(NEORV32_BAUDRATE))..."
	@echo "INFO: Using Python virtual environment: $(PYTHON_VENV)"
	@echo "INFO: Terminal script: $(NEORV32_TERMINAL)"
	@echo "INFO: Executable file: $(NEORV32_EXE_FILE)"
	@if [ ! -f "$(NEORV32_EXE_FILE)" ]; then \
		echo "ERROR: Executable file not found: $(NEORV32_EXE_FILE)"; \
		echo "Please run 'make neorv32' first to compile the software."; \
		exit 1; \
	fi
	$(PYTHON_VENV) $(NEORV32_TERMINAL) -p $(NEORV32_PORT) -b $(NEORV32_BAUDRATE) -f $(NEORV32_EXE_FILE)
	@echo "INFO: NEORV32 software upload completed."

# Start NEORV32 interactive terminal
neorv32_terminal:
	@echo "INFO: Starting NEORV32 interactive terminal on $(NEORV32_PORT) (baudrate: $(NEORV32_BAUDRATE))..."
	@echo "INFO: Using Python virtual environment: $(PYTHON_VENV)"
	@echo "INFO: Terminal script: $(NEORV32_TERMINAL)"
	@echo "INFO: Press Ctrl+C to exit the terminal"
	@echo "INFO: Executable file: $(NEORV32_EXE_FILE)"
	@echo "INFO: Type 'u' in interactive mode to upload executable file"
	@if [ ! -f "$(NEORV32_EXE_FILE)" ]; then \
		echo "WARNING: Executable file not found: $(NEORV32_EXE_FILE)"; \
		echo "Run 'make neorv32' first to compile software, or 'u' command won't work."; \
		echo "Starting terminal without file upload capability..."; \
		$(PYTHON_VENV) $(NEORV32_TERMINAL) -p $(NEORV32_PORT) -b $(NEORV32_BAUDRATE) -i; \
	else \
		$(PYTHON_VENV) $(NEORV32_TERMINAL) -p $(NEORV32_PORT) -b $(NEORV32_BAUDRATE) -i -f $(NEORV32_EXE_FILE); \
	fi
	@echo "INFO: NEORV32 terminal session ended."
