//Copyright (C)2014-2023 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.9 (64-bit)
//Part Number: GW2ANR-LV18QN88C8/I7
//Device: GW2ANR-18
//Device Version: C
//Created Time: Tue May 27 20:06:27 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    usb_pll your_instance_name(
        .clkout(clkout_o), //output clkout
        .lock(lock_o), //output lock
        .clkoutd(clkoutd_o), //output clkoutd
        .clkin(clkin_i) //input clkin
    );

//--------Copy end-------------------
