# Application Hardware Abstraction Layer (HAL) Design

This document outlines the design of the Hardware Abstraction Layer (HAL) for user applications located in the `@sw/app` directory. The purpose of this HAL is to provide a simplified and consistent interface to the underlying NEORV32 hardware peripherals, shielding the application developer from low-level register manipulations and specific implementation details.

## 1. Introduction

The NEORV32 core library (`lib`) provides a comprehensive set of drivers for all peripherals. However, for application development, it can be beneficial to create a higher-level abstraction layer tailored to the specific needs of the project. This HAL aims to:

*   Encapsulate common peripheral operations (GPIO, UART, Delay) into easy-to-use functions.
*   Define application-specific constants (e.g., pin assignments) in one place.
*   Provide a stable interface that can potentially adapt to changes in the underlying hardware or core library with minimal impact on the application code.

## 2. HAL Components

The HAL is structured into two main files within the `@sw/app` directory:

*   `hal.h`: The header file containing function prototypes, constant definitions (like pin mappings), and necessary includes.
*   `hal.c`: The source file containing the implementations of the HAL functions, leveraging the NEORV32 core library (`lib`).

### 2.1. GPIO Abstraction

**Objective:** Simplify control and reading of General Purpose Input/Output (GPIO) pins.

**Defined Constants (in `hal.h`):**
*   `LED_PIN`: Example mapping for an LED to a specific GPIO pin number.
*   `BUTTON_PIN`: Example mapping for a button to a specific GPIO pin number.
*   *(More application-specific pin definitions can be added here)*

**Provided Functions (in `hal.h` and implemented in `hal.c`):**
*   `void hal_init(void)`: Initializes the HAL. By default, all GPIO pins are inputs. This function can be modified to set initial output states.
*   `void hal_gpio_set_pin(uint8_t pin)`: Sets a single GPIO pin high.
*   `void hal_gpio_clear_pin(uint8_t pin)`: Clears a single GPIO pin (sets it low).
*   `void hal_gpio_toggle_pin(uint8_t pin)`: Toggles the state of a single GPIO pin.
*   `int hal_gpio_get_pin(uint8_t pin)`: Reads the state (high/low) of a single GPIO pin.
*   `void hal_gpio_set_port(uint32_t value)`: Writes a 32-bit value to the entire GPIO output port.
*   `uint32_t hal_gpio_get_port(void)`: Reads the 32-bit value from the entire GPIO input port.

**Implementation Details:**
*   The implementation in `hal.c` directly accesses the `NEORV32_GPIO` peripheral registers.
*   The functions for single-pin manipulation use bitwise operations (`|=`, `&=~`, `^=`) for efficiency.
*   It includes checks for valid pin numbers (0-31).

### 2.2. UART Abstraction

**Objective:** Provide a simple interface for serial communication via UART0.

**Defined Constants (in `hal.h`):**
*   `HAL_UART_BAUD_DEFAULT`: A default baud rate for UART0 initialization.

**Provided Functions (in `hal.h` and implemented in `hal.c`):**
*   `void hal_uart0_init(void)`: Initializes UART0 peripheral with the default baud rate and standard settings (8 data bits, no parity, 1 stop bit).
*   `void hal_uart0_print(const char *s)`: Prints a null-terminated string via UART0.
*   `void hal_uart0_putc(char c)`: Transmits a single character via UART0.
*   `char hal_uart0_getc(void)`: Receives a single character from UART0 (blocking call).

**Implementation Details:**
*   The implementation in `hal.c` utilizes the existing NEORV32 UART driver functions from `neorv32_uart.c`.
*   It wraps these calls to provide a consistent naming scheme (`hal_uart0_*`).

### 2.3. Delay Abstraction

**Objective:** Offer a basic blocking delay function.

**Provided Functions (in `hal.h` and implemented in `hal.c`):**
*   `void hal_delay_ms(uint32_t ms)`: Creates a blocking delay for a specified number of milliseconds.

**Implementation Details:**
*   Leverages the `neorv32_aux_delay_ms` function from the core library, which provides a simple busy-wait delay.

## 3. Usage

1.  Include `hal.h` in your application C files: `#include "hal.h"`
2.  Call `hal_init()` at the beginning of your `main()` function to initialize the HAL and underlying peripherals.
3.  Use the provided `hal_*` functions in your application logic.

**Example from `main.c`:**

```c
#include "hal.h"

int main(void)
{
    // Initialize the HAL layer
    hal_init();

    // Print a message via UART
    hal_uart0_print("Hello from custom HAL!\n");

    // Main application loop
    while (1)
    {
        // Toggle the LED
        hal_gpio_toggle_pin(LED_PIN);

        // Delay for 500 milliseconds
        hal_delay_ms(500);
    }

    return 0;
}
```

## 4. Extending the HAL

This HAL provides a basic foundation. To add support for other peripherals (like SPI, TWI, PWM, etc.):

1.  Define relevant constants in `hal.h`.
2.  Declare function prototypes in `hal.h`.
3.  Implement the functions in `hal.c`, utilizing the corresponding NEORV32 core library drivers (e.g., `neorv32_spi.h/.c`).
4.  Update this design document accordingly.

This approach centralizes peripheral access and makes the application code cleaner and more maintainable.
