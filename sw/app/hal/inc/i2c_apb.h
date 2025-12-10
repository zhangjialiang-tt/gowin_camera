/*
 ******************************************************************************************
 * @file      i2c_apb.h
 * @author    Huangcheng
 * @device    Gowin_EMPU_M1
 * @brief     This file contains fake I2C serial functions which actually using apb tunnel 
 * translating data to logisc's i2c driver.
 ******************************************************************************************
 */
#ifndef I2C_APB_H
#define I2C_APB_H

#ifdef __cplusplus
 extern "C" {
#endif

//include
#include "apb_reg_define.h"
#include "type.h"
//local defines & vars
#define APB_REG_ADDR_I2C_APB 1

//max 8 apb-i2c tunnels
#define I2C_VIS     1
#define I2C_xx2     2
#define I2C_xx3     3

#define I2C_BUSY    0x1
#define I2C_WAIT    0x0

#define I2C_Open     0x1
#define I2C_Close    0x0

#define I2C_W     0x0
#define I2C_R     0x1

#define I2C_RDVALID     0x1
#define I2C_INVALID     0x0
//External Funcs
/**
 * @brief Send the data to the I2C in logic through apb tunnel.
 */
extern s32 I2C_SendByte_APB(unsigned char i2c_id,unsigned char slv_address,unsigned char data_start_address,unsigned char data);
extern s32 I2C_ReadByte_APB(unsigned char i2c_id,unsigned char slv_address,unsigned char data_start_address,unsigned char *data);

#ifdef __cplusplus
}
#endif

#endif /* I2C_APB_H */