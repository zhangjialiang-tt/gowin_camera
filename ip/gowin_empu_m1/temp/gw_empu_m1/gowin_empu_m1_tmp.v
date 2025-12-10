//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.02 (64-bit)
//Part Number: GW2ANR-LV18QN88C8/I7
//Device: GW2ANR-18
//Device Version: C
//Created Time: Mon Jun 23 13:29:02 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Gowin_EMPU_M1_Top your_instance_name(
		.LOCKUP(LOCKUP), //output LOCKUP
		.GPIOIN(GPIOIN), //input [15:0] GPIOIN
		.GPIOOUT(GPIOOUT), //output [15:0] GPIOOUT
		.GPIOOUTEN(GPIOOUTEN), //output [15:0] GPIOOUTEN
		.UART0RXD(UART0RXD), //input UART0RXD
		.UART0TXD(UART0TXD), //output UART0TXD
		.TIMER0EXTIN(TIMER0EXTIN), //input TIMER0EXTIN
		.APB1PADDR(APB1PADDR), //output [31:0] APB1PADDR
		.APB1PENABLE(APB1PENABLE), //output APB1PENABLE
		.APB1PWRITE(APB1PWRITE), //output APB1PWRITE
		.APB1PSTRB(APB1PSTRB), //output [3:0] APB1PSTRB
		.APB1PPROT(APB1PPROT), //output [2:0] APB1PPROT
		.APB1PWDATA(APB1PWDATA), //output [31:0] APB1PWDATA
		.APB1PSEL(APB1PSEL), //output APB1PSEL
		.APB1PRDATA(APB1PRDATA), //input [31:0] APB1PRDATA
		.APB1PREADY(APB1PREADY), //input APB1PREADY
		.APB1PSLVERR(APB1PSLVERR), //input APB1PSLVERR
		.APB1PCLK(APB1PCLK), //output APB1PCLK
		.APB1PRESET(APB1PRESET), //output APB1PRESET
		.SCL(SCL), //inout SCL
		.SDA(SDA), //inout SDA
		.FLASH_SPI_HOLDN(FLASH_SPI_HOLDN), //inout FLASH_SPI_HOLDN
		.FLASH_SPI_CSN(FLASH_SPI_CSN), //inout FLASH_SPI_CSN
		.FLASH_SPI_MISO(FLASH_SPI_MISO), //inout FLASH_SPI_MISO
		.FLASH_SPI_MOSI(FLASH_SPI_MOSI), //inout FLASH_SPI_MOSI
		.FLASH_SPI_WPN(FLASH_SPI_WPN), //inout FLASH_SPI_WPN
		.FLASH_SPI_CLK(FLASH_SPI_CLK), //inout FLASH_SPI_CLK
		.HCLK(HCLK), //input HCLK
		.hwRstn(hwRstn) //input hwRstn
	);

//--------Copy end-------------------
