/*
 ******************************************************************************************
 * @file      i2c_apb.c
 * @author    Huangcheng
 * @device    Gowin_EMPU_M1
 * @brief     This file contains fake I2C serial functions which actually using apb tunnel 
 * translating data to logisc's i2c driver.
 ******************************************************************************************
 */

//include
#include "../../inc/system.h"
s32 I2C_SendByte_APB(unsigned char i2c_id,unsigned char slv_address,unsigned char data_start_address,unsigned char data)
{
    u32 i2c_bus;
    s32 s32Ret = NI_SUCCESS;
    //Busy sta check
    do{
        apb_read(APB_REG_ADDR_I2C_APB_BUS_C1  , &i2c_bus);
    }
    while(I2C_BUSY == (i2c_bus & 0x1));

    //write-data-ctrl
    i2c_bus = (I2C_Close<<6);
    apb_write(APB_REG_ADDR_I2C_APB_BUS_D1  , i2c_bus);
    i2c_bus = (slv_address & 0xff)<<24 | (data_start_address & 0xff)<<16 | (data & 0xff)<<8 | (I2C_W<<7) | (I2C_Open<<6) | (i2c_id & 0x7)<<3;
    apb_write(APB_REG_ADDR_I2C_APB_BUS_D1  , i2c_bus);

    do{
        apb_read(APB_REG_ADDR_I2C_APB_BUS_C1  , &i2c_bus);
    }
    while(I2C_BUSY == (i2c_bus & 0x1));
    if((i2c_bus >> 10) == 0x01)
    {
        s32Ret = NI_FAILURE;
        DEBUG_INFO("apb iic wr error nack !!\n\r");
    }
    return s32Ret;
}

s32 I2C_ReadByte_APB(unsigned char i2c_id,unsigned char slv_address,unsigned char data_start_address,unsigned char *data)
{
    u32 i2c_bus;
    s32 s32Ret = NI_SUCCESS;
    //Busy sta check
    do{
        apb_read(APB_REG_ADDR_I2C_APB_BUS_C1  , &i2c_bus);
    }
    while(I2C_BUSY == (i2c_bus & 0x1));
    //read-ctrl
    i2c_bus = (I2C_Close<<6)|0x4;   //清零有效位 ，保证 I2C_Open上升沿存在
    apb_write(APB_REG_ADDR_I2C_APB_BUS_D1  , i2c_bus);
    i2c_bus = (slv_address & 0xff)<<24 | (data_start_address & 0xff)<<16 | (I2C_R<<7) | (I2C_Open<<6) | (i2c_id & 0x7)<<3;
    apb_write(APB_REG_ADDR_I2C_APB_BUS_D1  , i2c_bus);
    //wait-busy
        do{
        apb_read(APB_REG_ADDR_I2C_APB_BUS_C1  , &i2c_bus);
    }
    while(I2C_BUSY == (i2c_bus & 0x1));

    //get data
    if(((i2c_bus>>9) & 0x1) == 0x01)
    {
        apb_read(APB_REG_ADDR_I2C_APB_BUS_C1  , &i2c_bus);
        *data = (i2c_bus>>1) & 0xff;
    }
    else 
    {
        s32Ret = NI_FAILURE;
        DEBUG_INFO("get iic data error!!\n\r");
    }
    if(((i2c_bus>>10) & 0x1) == 0x01)
    {
        s32Ret = NI_FAILURE;
        DEBUG_INFO(" iic NACK!!\n\r");
    }

    return s32Ret;
}
