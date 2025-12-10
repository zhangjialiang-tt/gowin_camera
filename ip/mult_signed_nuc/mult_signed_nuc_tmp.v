//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.01 (64-bit)
//Part Number: GW2ANR-LV18QN88C8/I7
//Device: GW2ANR-18
//Device Version: C
//Created Time: Tue Jun 10 09:56:58 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	mult_signed_nuc your_instance_name(
		.clk(clk), //input clk
		.rstn(rstn), //input rstn
		.mul_a(mul_a), //input [15:0] mul_a
		.mul_b(mul_b), //input [15:0] mul_b
		.product(product) //output [31:0] product
	);

//--------Copy end-------------------
