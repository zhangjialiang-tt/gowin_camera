// ================================================================================ //
// The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              //
// Copyright (c) NEORV32 contributors.                                              //
// Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  //
// Licensed under the BSD-3-Clause license, see LICENSE for details.                //
// SPDX-License-Identifier: BSD-3-Clause                                            //
// ================================================================================ //


/**********************************************************************//**
 * @file demo_twi/main.c
 * @brief TWI AT24C04 EEPROM test program with integrated GPIO interrupt handling.
 **************************************************************************/

#include <neorv32.h>
#include <string.h>


/**********************************************************************//**
 * @name User configuration
 **************************************************************************/
/**@}*/
/** UART BAUD rate */
#define BAUD_RATE 19200
/** I2C device address of the AT24C04 EEPROM.
 * This assumes the address pins A1 and A2 are grounded. */
#define EEPROM_DEVICE_ADDR 0b1010000
/** GPIO pin for interrupt */
#define GPIO_IRQ_PIN 1
/**@}*/


// Globals for GPIO interrupt
volatile uint32_t timestamp;
volatile uint32_t gpio_irq_fired;


// Prototypes
void bus_scan(void);
int eeprom_write_byte(uint16_t address, uint8_t data);
int eeprom_read_byte(uint16_t address, uint8_t *data);
void print_hex_byte(uint8_t data);
void gpio_interrupt_handler(void);
static void puth(uint32_t num);


/**********************************************************************//**
 * Simple bus-wait helper.
 *
 * @param[in] time_ms Time in ms to wait (unsigned 32-bit).
 **************************************************************************/
void delay_ms(uint32_t time_ms) {
  neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), time_ms);
}


/**********************************************************************//**
 * GPIO interrupt handler from temp.c
 **************************************************************************/
void gpio_interrupt_handler(void) {
  neorv32_uart0_printf(" ns\n----------------------------------------\n");
  neorv32_gpio_irq_clr(1 << GPIO_IRQ_PIN); // clear only the specific pin's IRQ flag
  uint32_t current = (uint32_t)neorv32_clint_time_get();
  uint32_t delta = current - timestamp;
  
  neorv32_uart0_printf("\n--- GPIO INTERRUPT (pin %d, rising edge) ---\n", GPIO_IRQ_PIN);
  neorv32_uart0_printf("Time since last interrupt: ");
  puth(delta);
  neorv32_uart0_printf(" ns\n----------------------------------------\n");

  timestamp = current;
  gpio_irq_fired = 1; // set flag for main loop
}


/**********************************************************************//**
 * Main function.
 **************************************************************************/
int main() {

  // capture all exceptions and give debug info via UART
  neorv32_rte_setup();

  // check if UART unit is implemented at all
  if (neorv32_uart0_available() == 0) {
    return 1;
  }

  // clear GPIO output (set all bits to 0)
  neorv32_gpio_port_set(0);
  // setup UART at default baud rate, no interrupts
  neorv32_uart0_setup(BAUD_RATE, 0);

  // intro
  neorv32_uart0_printf("\n--- TWI AT24C04 EEPROM Test with GPIO Interrupt ---\n\n");

  // ----------------------------------------------------------
  // GPIO Interrupt Setup (Ported from temp.c)
  // ----------------------------------------------------------
  neorv32_uart0_printf("Setting up GPIO interrupt on pin %d (rising edge)...", GPIO_IRQ_PIN);

  // check if GPIO unit is implemented
  if (neorv32_gpio_available() == 0) {
    neorv32_uart0_printf("ERROR! GPIO controller not available!\n");
    return 1;
  }

  // Install our GPIO interrupt handler
  neorv32_rte_handler_install(GPIO_TRAP_CODE, gpio_interrupt_handler);
  // Enable GPIO FIRQ channel in CPU
  neorv32_cpu_csr_set(CSR_MIE, 1 << GPIO_FIRQ_ENABLE);
  // Enable global interrupts
  neorv32_cpu_csr_set(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);
  
  // Configure interrupt for rising edge on our specific pin
  // neorv32_gpio_irq_setup(GPIO_IRQ_PIN, GPIO_TRIG_EDGE_RISING);
  neorv32_gpio_irq_setup(GPIO_IRQ_PIN, GPIO_TRIG_EDGE_FALLING);
  
  // Enable interrupt for the specific GPIO pin
  neorv32_gpio_irq_enable(1 << GPIO_IRQ_PIN);
  
  
  
  neorv32_uart0_printf("GPIO interrupt configured. \n\n");
  // ----------------------------------------------------------


  // check if TWI unit is implemented at all
  if (neorv32_twi_available() == 0) {
    neorv32_uart0_printf("ERROR! TWI controller not available!\n");
    return 1;
  }

  // Configure TWI for 100kHz operation
  neorv32_twi_setup(CLK_PRSC_128, 1, 0);

  // Diagnostic Step 1: Scan the bus
  neorv32_uart0_printf("--- Starting I2C Bus Scan ---\n");
  bus_scan();
  neorv32_uart0_printf("--- Scan Complete ---\n\n");


  // Test sequence
  uint16_t test_addr = 0x0042; // eeprom address to write to
  uint8_t tx_data = 0xCA;      // data to write
  uint8_t rx_data = 0;         // data to read

  // Write byte
  neorv32_uart0_printf("Writing 0x");
  print_hex_byte(tx_data);
  neorv32_uart0_printf(" to EEPROM address 0x%x...", test_addr);

  if (eeprom_write_byte(test_addr, tx_data) == 0) {
    neorv32_uart0_printf(" OK\n");
  }
  else {
    neorv32_uart0_printf(" FAILED!\n");
    neorv32_uart0_printf("Test halted.\n");
    return 1;
  }

  // Read byte back
  neorv32_uart0_printf("Reading from EEPROM address 0x%x...", test_addr);

  if (eeprom_read_byte(test_addr, &rx_data) == 0) {
    neorv32_uart0_printf(" OK\n");
  }
  else {
    neorv32_uart0_printf(" FAILED!\n");
    neorv32_uart0_printf("Test halted.\n");
    return 1;
  }

  // Verify
  neorv32_uart0_printf("\nTX data: 0x");
  print_hex_byte(tx_data);
  neorv32_uart0_printf(", RX data: 0x");
  print_hex_byte(rx_data);
  neorv32_uart0_printf("\n");

  if (tx_data == rx_data) {
    neorv32_uart0_printf("SUCCESS! Data matches.\n");
  }
  else {
    neorv32_uart0_printf("ERROR! Data mismatch!\n");
  }

  neorv32_uart0_printf("\nI2C test complete. Program will now wait for GPIO interrupts.\n");

  // Wait for GPIO interrupts indefinitely
  int cnt = 0;
  while(1) {
    neorv32_gpio_port_set(cnt++ & 0xFF); // increment counter and mask for lowest 8 bit
    delay_ms(250); // wait 250ms using busy wait
    // you can put other non-blocking code here
  }

  return 0;
}


/**********************************************************************//**
 * Scan TWI bus for devices and print results.
 **************************************************************************/
void bus_scan(void) {

  uint8_t i;
  int num_devices = 0;

  for (i=0; i<128; i++) {
    neorv32_twi_generate_start();
    uint8_t addr_rw = (i << 1) | 0; // write address
    int ack = neorv32_twi_transfer(&addr_rw, 0);
    neorv32_twi_generate_stop();

    if (ack == 0) {
      neorv32_uart0_printf(" + Device found at address 0x");
      print_hex_byte(i);
      neorv32_uart0_printf(" (write addr 0x");
      print_hex_byte(addr_rw);
      neorv32_uart0_printf(")\n");
      num_devices++;
    }
  }

  if (num_devices == 0) {
    neorv32_uart0_printf("No devices found. Check wiring, pull-ups and power!\n");
  }
  else {
    neorv32_uart0_printf("Total devices found: %i\n", num_devices);
  }
}


/**********************************************************************//**
 * Write a single byte to EEPROM.
 **************************************************************************/
int eeprom_write_byte(uint16_t address, uint8_t data) {

  uint8_t device_addr_byte = (EEPROM_DEVICE_ADDR << 1) | ((address >> 7) & 0x02) | 0; // LSB=0 for write
  uint8_t word_addr_byte = (uint8_t)address;

  neorv32_twi_generate_start();

  if (neorv32_twi_transfer(&device_addr_byte, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }
  if (neorv32_twi_transfer(&word_addr_byte, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }
  if (neorv32_twi_transfer(&data, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }

  neorv32_twi_generate_stop();
  delay_ms(5);
  return 0;
}


/**********************************************************************//**
 * Read a single byte from EEPROM.
 **************************************************************************/
int eeprom_read_byte(uint16_t address, uint8_t *data) {

  uint8_t device_addr_byte_write = (EEPROM_DEVICE_ADDR << 1) | ((address >> 7) & 0x02) | 0;
  uint8_t device_addr_byte_read  = (EEPROM_DEVICE_ADDR << 1) | ((address >> 7) & 0x02) | 1;
  uint8_t word_addr_byte = (uint8_t)address;
  uint8_t rx_buffer = 0xff;

  neorv32_twi_generate_start();
  if (neorv32_twi_transfer(&device_addr_byte_write, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }
  if (neorv32_twi_transfer(&word_addr_byte, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }

  neorv32_twi_generate_start(); // repeated start
  if (neorv32_twi_transfer(&device_addr_byte_read, 0)) {
    neorv32_twi_generate_stop();
    return 1;
  }
  neorv32_twi_transfer(&rx_buffer, 1); // send NACK to slave
  neorv32_twi_generate_stop();

  *data = rx_buffer;
  return 0;
}


/**********************************************************************//**
 * Print byte as hex chars via UART0.
 **************************************************************************/
void print_hex_byte(uint8_t data) {

  static const char symbols[] = "0123456789abcdef";

  neorv32_uart0_putc(symbols[(data >> 4) & 15]);
  neorv32_uart0_putc(symbols[(data >> 0) & 15]);
}


/**********************************************************************//**
 * Print 32-bit number as hex chars via UART0 (from temp.c)
 **************************************************************************/
static void puth(uint32_t num) {

  int i = 0;
  const char hex_symbols[] = "0123456789ABCDEF";
  for (i=0; i<8; i++) {
    uint32_t index = (num >> (28 - 4*i)) & 0xF;
    neorv32_uart0_putc(hex_symbols[index]);
  }
}
