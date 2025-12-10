//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 (64-bit)
//Part Number: GW2ANR-LV18QN88C8/I7
//Device: GW2ANR-18
//Device Version: C
//Created Time: Thu Oct 23 09:43:56 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	yuv420_fifo_2 your_instance_name(
		.Data(Data), //input [7:0] Data
		.Clk(Clk), //input Clk
		.WrEn(WrEn), //input WrEn
		.RdEn(RdEn), //input RdEn
		.Reset(Reset), //input Reset
		.Wnum(Wnum), //output [10:0] Wnum
		.Q(Q), //output [7:0] Q
		.Empty(Empty), //output Empty
		.Full(Full) //output Full
	);

//--------Copy end-------------------
