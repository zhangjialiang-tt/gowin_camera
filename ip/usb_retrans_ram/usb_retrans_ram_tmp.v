//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 (64-bit)
//Part Number: GW2ANR-LV18QN88C8/I7
//Device: GW2ANR-18
//Device Version: C
//Created Time: Fri Nov  7 17:27:44 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    usb_retrans_ram your_instance_name(
        .dout(dout), //output [7:0] dout
        .wre(wre), //input wre
        .wad(wad), //input [8:0] wad
        .di(di), //input [7:0] di
        .rad(rad), //input [8:0] rad
        .clk(clk) //input clk
    );

//--------Copy end-------------------
