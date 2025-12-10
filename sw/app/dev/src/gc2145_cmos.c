
#include "../../inc/system.h"
#include "gc2145_cmos.h"
#include "type.h"
/****************************************************************************
 * static                                                            		*
 ****************************************************************************/

static void Gc2145CmosGetReg(u8 u8RegAddr, u8 *pu8Data);
static void Gc2145CmosSetReg(u8 u8RegAddr, u8 u8Data);

/****************************************************************************
 * FUNCTIONS                                                      			*
 ****************************************************************************/

static void Gc2145CmosGetReg(u8 u8RegAddr, u8 *pu8Data)
{
	u8 u8RdData;
	u8 u8loop;
	for (u8loop = 0; u8loop < 10; u8loop++)
	{
		if( NI_SUCCESS == I2C_ReadByte_APB(I2C_VIS,Gc2145CmosIICADDRS,u8RegAddr,&u8RdData))
		{
			u8loop = 10;
		}
		else 
		{
			DEBUG_INFO("IIC READ REG ADDRS 0x%X,READ ERROR DATA 0x%X \n\r",u8RegAddr,u8RdData);
			DEBUG_INFO("IIC READ ERROR! u8loop -->%d \n\r",u8loop);
		}
	}
	*pu8Data = u8RdData;
}


static void Gc2145CmosSetReg(u8 u8RegAddr, u8 u8Data)
{
	u8 u8loop;
	for (u8loop = 0; u8loop < 10; u8loop++)
	{
		if( NI_SUCCESS == I2C_SendByte_APB(I2C_VIS, Gc2145CmosIICADDRS,u8RegAddr, u8Data))
		{
			u8loop = 10;
		}
		else 
		{
			DEBUG_INFO("IIC WRITE REG ADDRS 0x%X,WRITE DATA 0x%X \n\r",u8RegAddr,u8Data);
			DEBUG_INFO("IIC WRITE ERROR! u8loop -->%d \n\r",u8loop);
		}
	}
}

// VIS POWER CTRL
    void gc2145_cmos_power_on(void)
    {
        u32   u32AdpWriteData;
        //开iovdd & dvdd
                        //set the gpio to low
                        //电源硬件默认拉高
        //上电时序使用apb控制 高云FPGA程序未起来时GPIO为高电平
            //其中PWDN 为反逻辑
            //logic 该APB初始化复位为0
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);
        apb_write(APB_REG_ADDR_EN_BUS0, (u32AdpWriteData&0x0FFFFFFF)); 
        hal_i2c_delay_us(100000);   //等待100MS
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);       //上电
        apb_write(APB_REG_ADDR_EN_BUS0, (u32AdpWriteData|0x40000000));    
        hal_i2c_delay_us(20000);   //等待20MS
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, (u32AdpWriteData|0x80000000));  //输出时钟
        hal_i2c_delay_us(20000);   //等待20MS 时钟稳定
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, (u32AdpWriteData|0x20000000));  //PWDN 拉低
        hal_i2c_delay_us(20000);   //等待20MS PWDN 拉低稳定
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, (u32AdpWriteData|0x10000000));  //复位拉高
        hal_i2c_delay_us(20000);   //等待20MS 复位拉高稳定
    }
    void gc2145_cmos_power_off(void)
    {
        u32   u32AdpWriteData; 
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, u32AdpWriteData&0xDFFFFFFF);   //PWDN 拉高
        hal_i2c_delay_us(20000);
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, u32AdpWriteData&0xEFFFFFFF);   //复位 拉低
        hal_i2c_delay_us(20000);
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, u32AdpWriteData&0x7FFFFFFF);   //关闭时钟
        hal_i2c_delay_us(20000);
        apb_read(APB_REG_ADDR_EN_BUS0, &u32AdpWriteData);   
        apb_write(APB_REG_ADDR_EN_BUS0, u32AdpWriteData&0xBFFFFFFF);   //关闭电源
    }

//白光DVP配置 访问logic 中的寄存器和地址 软核资源不够了将配置数据放在软核会爆
void gc2145_dvp_yuv_800X600_logic_inst(void)
{
    //logic 部分寄存器缓存区复位 高有效
    apb_write(APB_REG_TV_IIC_RW_REG, 0x80000000);
    apb_write(APB_REG_TV_IIC_RW_REG, 0x00000000);
    DEBUG_INFO("gc2145_dvp_yuv_800X600_logic_inst\n\r");
} 

void gc2145_dvp_yuv_800X600_init(u32 u32TimeNum,u8 *u8StateFlag)        //30M时钟计数 如1ms  u32TimeNum = (30000000/1000)-1 第29为数据是是否需要延时
{
    u32 u32ApbData;
    u8 u8Loop = 0x01;
    u8 u8Addrs,u8Data;
    apb_write(APB_REG_TV_IIC_RW_REG, 0x00000000); //清零保证logic的部分时序能检测到上升沿
    apb_write(APB_REG_TV_IIC_RW_REG, (u32TimeNum|0x40000000));
    if(((*u8StateFlag)&0x01) == 0x00)
    {
        while (u8Loop == 0x01)
        {
            apb_read(APB_REG_TV_IIC_RW_REG, &u32ApbData);
            // DEBUG_INFO("u32ApbData -- > %x\n\r",u32ApbData);
            if(((u32ApbData >> 16)&0x01)== 0x01)
            {
                if(((u32ApbData >> 16)&0x04)== 0x04)
                {
                    u8Data = (u32ApbData&0xff); 
                    u8Addrs = ((u32ApbData>>8)&0xff);
                    if(((u32ApbData >> 16)&0x08)== 0x08)
                    {
                        hal_i2c_delay_ms(u8Data);
                        DEBUG_INFO("hal_i2c_delay_ms-->%d \n\r",u8Data);
                    }
                    else if(((u32ApbData >> 16)&0x02)== 0x02)
                    {
                        Gc2145CmosGetReg(u8Addrs, &u8Data);
                        DEBUG_INFO("addrs-->%x data -->%x\n\r",u8Addrs,u8Data);
                    }
                    else if(((u32ApbData >> 16)&0x02)== 0x00)
                    {
                        Gc2145CmosSetReg(u8Addrs,u8Data);
                    }
                    else 
                    {
                        DEBUG_INFO("get iic reg and data error!!\n\r");
                    }
                } 
                else 
                {
                    u8Loop = 0;
                }
            }
            else 
            {
                DEBUG_INFO("init tv pass\n\r");
                *u8StateFlag = ((*u8StateFlag)|0x01);
                u8Loop = 0;
            }
        }
    }
}

//
//配置白光寄存器
	void gc2145_mipi_yuv_800X600_init(void)
	{
		u8 u8RdData = 0;
		DEBUG_INFO("===gc2145 mipi_yuv_800*600 configuring===\n\r");
		Gc2145CmosGetReg(0xf0, &u8RdData);
        DEBUG_INFO("ID f0----->%x\n\r",u8RdData);
        Gc2145CmosGetReg(0xf1, &u8RdData);
        DEBUG_INFO("ID f1----->%x\n\r",u8RdData);
// 		Gc2145CmosSetReg( 0xfe, 0xf0); // rst
// 		Gc2145CmosSetReg( 0xf2, 0x00);
// 		Gc2145CmosSetReg( 0xf6, 0x00);
// 		Gc2145CmosSetReg( 0xf7, 0x1d);
// 		Gc2145CmosSetReg( 0xf8, 0x84);
// 		Gc2145CmosSetReg( 0xf9, 0x8e);
// 		Gc2145CmosSetReg( 0xfa, 0x00);
// 		Gc2145CmosSetReg( 0xfc, 0x06);
// 		//isp-regs
// 		Gc2145CmosSetReg( 0xfe, 0x00); // page-0
// 		Gc2145CmosSetReg( 0x03, 0x04);
// 		Gc2145CmosSetReg( 0x04, 0xe2);
// 		Gc2145CmosSetReg( 0x09, 0x00);
// 		Gc2145CmosSetReg( 0x0a, 0x00);
// 		Gc2145CmosSetReg( 0x0b, 0x00);
// 		Gc2145CmosSetReg( 0x0c, 0x00);
// 		Gc2145CmosSetReg( 0x0d, 0x04);
// 		Gc2145CmosSetReg( 0x0e, 0xc0);
// 		Gc2145CmosSetReg( 0x0f, 0x06);
// 		Gc2145CmosSetReg( 0x10, 0x52);
// 		Gc2145CmosSetReg( 0x12, 0x2e);
// 		Gc2145CmosSetReg( 0x17, 0x14); //mirror
// 		Gc2145CmosSetReg( 0x18, 0x22);
// 		Gc2145CmosSetReg( 0x19, 0x0e);
// 		Gc2145CmosSetReg( 0x1a, 0x01);
// 		Gc2145CmosSetReg( 0x1b, 0x4b);
// 		Gc2145CmosSetReg( 0x1c, 0x07);
// 		Gc2145CmosSetReg( 0x1d, 0x10);
// 		Gc2145CmosSetReg( 0x1e, 0x88);
// 		Gc2145CmosSetReg( 0x1f, 0x78);
// 		Gc2145CmosSetReg( 0x20, 0x03);
// 		Gc2145CmosSetReg( 0x21, 0x40);
// 		Gc2145CmosSetReg( 0x22, 0xa0); 
// 		Gc2145CmosSetReg( 0x24, 0x16);
// 		Gc2145CmosSetReg( 0x25, 0x01);
// 		Gc2145CmosSetReg( 0x26, 0x10);
// 		Gc2145CmosSetReg( 0x2d, 0x60);
// 		Gc2145CmosSetReg( 0x30, 0x01);
// 		Gc2145CmosSetReg( 0x31, 0x90);
// 		Gc2145CmosSetReg( 0x33, 0x06);
// 		Gc2145CmosSetReg( 0x34, 0x01);
// 		//isp-reg
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0x80, 0x7f);
// 		Gc2145CmosSetReg( 0x81, 0x26);
// 		Gc2145CmosSetReg( 0x82, 0xfa);
// 		Gc2145CmosSetReg( 0x83, 0x00);
// 		Gc2145CmosSetReg( 0x84, 0x02);//03 
// 		Gc2145CmosSetReg( 0x86, 0x02);
// 		Gc2145CmosSetReg( 0x88, 0x03);
// 		Gc2145CmosSetReg( 0x89, 0x03);
// 		Gc2145CmosSetReg( 0x85, 0x08); 
// 		Gc2145CmosSetReg( 0x8a, 0x00);
// 		Gc2145CmosSetReg( 0x8b, 0x00);
// 		Gc2145CmosSetReg( 0xb0, 0x55);
// 		Gc2145CmosSetReg( 0xc3, 0x00);
// 		Gc2145CmosSetReg( 0xc4, 0x80);
// 		Gc2145CmosSetReg( 0xc5, 0x90);
// 		Gc2145CmosSetReg( 0xc6, 0x3b);
// 		Gc2145CmosSetReg( 0xc7, 0x46);
// 		Gc2145CmosSetReg( 0xec, 0x06);
// 		Gc2145CmosSetReg( 0xed, 0x04);
// 		Gc2145CmosSetReg( 0xee, 0x60);
// 		Gc2145CmosSetReg( 0xef, 0x90);
// 		Gc2145CmosSetReg( 0xb6, 0x01);
// 		Gc2145CmosSetReg( 0x90, 0x01);
// 		Gc2145CmosSetReg( 0x91, 0x00);
// 		Gc2145CmosSetReg( 0x92, 0x00);
// 		Gc2145CmosSetReg( 0x93, 0x00);
// 		Gc2145CmosSetReg( 0x94, 0x00);
// 		Gc2145CmosSetReg( 0x95, 0x04);
// 		Gc2145CmosSetReg( 0x96, 0xb0);
// 		Gc2145CmosSetReg( 0x97, 0x06);
// 		Gc2145CmosSetReg( 0x98, 0x40);
// 		//blk
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0x40, 0x42);
// 		Gc2145CmosSetReg( 0x41, 0x00);
// 		Gc2145CmosSetReg( 0x43, 0x5b); 
// 		Gc2145CmosSetReg( 0x5e, 0x00); 
// 		Gc2145CmosSetReg( 0x5f, 0x00);
// 		Gc2145CmosSetReg( 0x60, 0x00); 
// 		Gc2145CmosSetReg( 0x61, 0x00); 
// 		Gc2145CmosSetReg( 0x62, 0x00);
// 		Gc2145CmosSetReg( 0x63, 0x00); 
// 		Gc2145CmosSetReg( 0x64, 0x00); 
// 		Gc2145CmosSetReg( 0x65, 0x00); 
// 		Gc2145CmosSetReg( 0x66, 0x20);
// 		Gc2145CmosSetReg( 0x67, 0x20); 
// 		Gc2145CmosSetReg( 0x68, 0x20); 
// 		Gc2145CmosSetReg( 0x69, 0x20); 
// 		Gc2145CmosSetReg( 0x76, 0x00);
// 		Gc2145CmosSetReg( 0x6a, 0x08); 
// 		Gc2145CmosSetReg( 0x6b, 0x08); 
// 		Gc2145CmosSetReg( 0x6c, 0x08); 
// 		Gc2145CmosSetReg( 0x6d, 0x08); 
// 		Gc2145CmosSetReg( 0x6e, 0x08); 
// 		Gc2145CmosSetReg( 0x6f, 0x08); 
// 		Gc2145CmosSetReg( 0x70, 0x08); 
// 		Gc2145CmosSetReg( 0x71, 0x08);
// 		Gc2145CmosSetReg( 0x76, 0x00);
// 		Gc2145CmosSetReg( 0x72, 0xf0);
// 		Gc2145CmosSetReg( 0x7e, 0x3c);
// 		Gc2145CmosSetReg( 0x7f, 0x00);
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x48, 0x15);
// 		Gc2145CmosSetReg( 0x49, 0x00);
// 		Gc2145CmosSetReg( 0x4b, 0x0b);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//aec
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x01, 0x04);
// 		Gc2145CmosSetReg( 0x02, 0xc0);
// 		Gc2145CmosSetReg( 0x03, 0x04);
// 		Gc2145CmosSetReg( 0x04, 0x90);
// 		Gc2145CmosSetReg( 0x05, 0x30);
// 		Gc2145CmosSetReg( 0x06, 0x90);
// 		Gc2145CmosSetReg( 0x07, 0x30);
// 		Gc2145CmosSetReg( 0x08, 0x80);
// 		Gc2145CmosSetReg( 0x09, 0x00);
// 		Gc2145CmosSetReg( 0x0a, 0x82);
// 		Gc2145CmosSetReg( 0x0b, 0x11);
// 		Gc2145CmosSetReg( 0x0c, 0x10);
// 		Gc2145CmosSetReg( 0x11, 0x10);
// 		Gc2145CmosSetReg( 0x13, 0x7b);
// 		Gc2145CmosSetReg( 0x17, 0x00);
// 		Gc2145CmosSetReg( 0x1c, 0x11);
// 		Gc2145CmosSetReg( 0x1e, 0x61);
// 		Gc2145CmosSetReg( 0x1f, 0x35);
// 		Gc2145CmosSetReg( 0x20, 0x40);
// 		Gc2145CmosSetReg( 0x22, 0x40);
// 		Gc2145CmosSetReg( 0x23, 0x20);
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x0f, 0x04);
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x12, 0x35);
// 		Gc2145CmosSetReg( 0x15, 0xb0);
// 		Gc2145CmosSetReg( 0x10, 0x31);
// 		Gc2145CmosSetReg( 0x3e, 0x28);
// 		Gc2145CmosSetReg( 0x3f, 0xb0);
// 		Gc2145CmosSetReg( 0x40, 0x90);
// 		Gc2145CmosSetReg( 0x41, 0x0f);
// 		//inpee
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x90, 0x6c);
// 		Gc2145CmosSetReg( 0x91, 0x03);
// 		Gc2145CmosSetReg( 0x92, 0xcb);
// 		Gc2145CmosSetReg( 0x94, 0x33);
// 		Gc2145CmosSetReg( 0x95, 0x84);
// 		Gc2145CmosSetReg( 0x97, 0x65);
// 		Gc2145CmosSetReg( 0xa2, 0x11);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//dndd
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x80, 0xc1);
// 		Gc2145CmosSetReg( 0x81, 0x08);
// 		Gc2145CmosSetReg( 0x82, 0x05);
// 		Gc2145CmosSetReg( 0x83, 0x08);
// 		Gc2145CmosSetReg( 0x84, 0x0a);
// 		Gc2145CmosSetReg( 0x86, 0xf0);
// 		Gc2145CmosSetReg( 0x87, 0x50);
// 		Gc2145CmosSetReg( 0x88, 0x15);
// 		Gc2145CmosSetReg( 0x89, 0xb0);
// 		Gc2145CmosSetReg( 0x8a, 0x30);
// 		Gc2145CmosSetReg( 0x8b, 0x10);
// 		//asde
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x21, 0x04);
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0xa3, 0x50);
// 		Gc2145CmosSetReg( 0xa4, 0x20);
// 		Gc2145CmosSetReg( 0xa5, 0x40);
// 		Gc2145CmosSetReg( 0xa6, 0x80);
// 		Gc2145CmosSetReg( 0xab, 0x40);
// 		Gc2145CmosSetReg( 0xae, 0x0c);
// 		Gc2145CmosSetReg( 0xb3, 0x46);
// 		Gc2145CmosSetReg( 0xb4, 0x64);
// 		Gc2145CmosSetReg( 0xb6, 0x38);
// 		Gc2145CmosSetReg( 0xb7, 0x01);
// 		Gc2145CmosSetReg( 0xb9, 0x2b);
// 		Gc2145CmosSetReg( 0x3c, 0x04);
// 		Gc2145CmosSetReg( 0x3d, 0x15);
// 		Gc2145CmosSetReg( 0x4b, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x20);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//gamma
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x10, 0x09);
// 		Gc2145CmosSetReg( 0x11, 0x0d);
// 		Gc2145CmosSetReg( 0x12, 0x13);
// 		Gc2145CmosSetReg( 0x13, 0x19);
// 		Gc2145CmosSetReg( 0x14, 0x27);
// 		Gc2145CmosSetReg( 0x15, 0x37);
// 		Gc2145CmosSetReg( 0x16, 0x45);
// 		Gc2145CmosSetReg( 0x17, 0x53);
// 		Gc2145CmosSetReg( 0x18, 0x69);
// 		Gc2145CmosSetReg( 0x19, 0x7d);
// 		Gc2145CmosSetReg( 0x1a, 0x8f);
// 		Gc2145CmosSetReg( 0x1b, 0x9d);
// 		Gc2145CmosSetReg( 0x1c, 0xa9);
// 		Gc2145CmosSetReg( 0x1d, 0xbd);
// 		Gc2145CmosSetReg( 0x1e, 0xcd);
// 		Gc2145CmosSetReg( 0x1f, 0xd9);
// 		Gc2145CmosSetReg( 0x20, 0xe3);
// 		Gc2145CmosSetReg( 0x21, 0xea);
// 		Gc2145CmosSetReg( 0x22, 0xef);
// 		Gc2145CmosSetReg( 0x23, 0xf5);
// 		Gc2145CmosSetReg( 0x24, 0xf9);
// 		Gc2145CmosSetReg( 0x25, 0xff);
// 		Gc2145CmosSetReg( 0xfe, 0x00);     
// 		Gc2145CmosSetReg( 0xc6, 0x20);
// 		Gc2145CmosSetReg( 0xc7, 0x2b);
// 		//gamma2
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x26, 0x0f);
// 		Gc2145CmosSetReg( 0x27, 0x14);
// 		Gc2145CmosSetReg( 0x28, 0x19);
// 		Gc2145CmosSetReg( 0x29, 0x1e);
// 		Gc2145CmosSetReg( 0x2a, 0x27);
// 		Gc2145CmosSetReg( 0x2b, 0x33);
// 		Gc2145CmosSetReg( 0x78, 0x3b);
// 		Gc2145CmosSetReg( 0x2d, 0x45);
// 		Gc2145CmosSetReg( 0x2e, 0x59);
// 		Gc2145CmosSetReg( 0x2f, 0x69);
// 		Gc2145CmosSetReg( 0x30, 0x7c);
// 		Gc2145CmosSetReg( 0x31, 0x89);
// 		Gc2145CmosSetReg( 0x32, 0x98);
// 		Gc2145CmosSetReg( 0x33, 0xae);
// 		Gc2145CmosSetReg( 0x34, 0xc0);
// 		Gc2145CmosSetReg( 0x35, 0xcf);
// 		Gc2145CmosSetReg( 0x36, 0xda);
// 		Gc2145CmosSetReg( 0x37, 0xe2);
// 		Gc2145CmosSetReg( 0x38, 0xe9);
// 		Gc2145CmosSetReg( 0x39, 0xf3);
// 		Gc2145CmosSetReg( 0x3a, 0xf9);
// 		Gc2145CmosSetReg( 0x3b, 0xff);
// 		//ycp
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0xd1, 0x32);
// 		Gc2145CmosSetReg( 0xd2, 0x32);
// 		Gc2145CmosSetReg( 0xd3, 0x40);
// 		Gc2145CmosSetReg( 0xd6, 0xf0);
// 		Gc2145CmosSetReg( 0xd7, 0x10);
// 		Gc2145CmosSetReg( 0xd8, 0xda);
// 		Gc2145CmosSetReg( 0xdd, 0x14);
// 		Gc2145CmosSetReg( 0xde, 0x86);
// 		Gc2145CmosSetReg( 0xed, 0x80);
// 		Gc2145CmosSetReg( 0xee, 0x00);
// 		Gc2145CmosSetReg( 0xef, 0x3f);
// 		Gc2145CmosSetReg( 0xd8, 0xd8);
// 		//abs
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x9f, 0x40);
// 		//lsc
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0xc2, 0x14);
// 		Gc2145CmosSetReg( 0xc3, 0x0d);
// 		Gc2145CmosSetReg( 0xc4, 0x0c);
// 		Gc2145CmosSetReg( 0xc8, 0x15);
// 		Gc2145CmosSetReg( 0xc9, 0x0d);
// 		Gc2145CmosSetReg( 0xca, 0x0a);
// 		Gc2145CmosSetReg( 0xbc, 0x24);
// 		Gc2145CmosSetReg( 0xbd, 0x10);
// 		Gc2145CmosSetReg( 0xbe, 0x0b);
// 		Gc2145CmosSetReg( 0xb6, 0x25);
// 		Gc2145CmosSetReg( 0xb7, 0x16);
// 		Gc2145CmosSetReg( 0xb8, 0x15);
// 		Gc2145CmosSetReg( 0xc5, 0x00);
// 		Gc2145CmosSetReg( 0xc6, 0x00);
// 		Gc2145CmosSetReg( 0xc7, 0x00);
// 		Gc2145CmosSetReg( 0xcb, 0x00);
// 		Gc2145CmosSetReg( 0xcc, 0x00);
// 		Gc2145CmosSetReg( 0xcd, 0x00);
// 		Gc2145CmosSetReg( 0xbf, 0x07);
// 		Gc2145CmosSetReg( 0xc0, 0x00);
// 		Gc2145CmosSetReg( 0xc1, 0x00);
// 		Gc2145CmosSetReg( 0xb9, 0x00);
// 		Gc2145CmosSetReg( 0xba, 0x00);
// 		Gc2145CmosSetReg( 0xbb, 0x00);
// 		Gc2145CmosSetReg( 0xaa, 0x01);
// 		Gc2145CmosSetReg( 0xab, 0x01);
// 		Gc2145CmosSetReg( 0xac, 0x00);
// 		Gc2145CmosSetReg( 0xad, 0x05);
// 		Gc2145CmosSetReg( 0xae, 0x06);
// 		Gc2145CmosSetReg( 0xaf, 0x0e);
// 		Gc2145CmosSetReg( 0xb0, 0x0b);
// 		Gc2145CmosSetReg( 0xb1, 0x07);
// 		Gc2145CmosSetReg( 0xb2, 0x06);
// 		Gc2145CmosSetReg( 0xb3, 0x17);
// 		Gc2145CmosSetReg( 0xb4, 0x0e);
// 		Gc2145CmosSetReg( 0xb5, 0x0e);
// 		Gc2145CmosSetReg( 0xd0, 0x09);
// 		Gc2145CmosSetReg( 0xd1, 0x00);
// 		Gc2145CmosSetReg( 0xd2, 0x00);
// 		Gc2145CmosSetReg( 0xd6, 0x08);
// 		Gc2145CmosSetReg( 0xd7, 0x00);
// 		Gc2145CmosSetReg( 0xd8, 0x00);
// 		Gc2145CmosSetReg( 0xd9, 0x00);
// 		Gc2145CmosSetReg( 0xda, 0x00);
// 		Gc2145CmosSetReg( 0xdb, 0x00);
// 		Gc2145CmosSetReg( 0xd3, 0x0a);
// 		Gc2145CmosSetReg( 0xd4, 0x00);
// 		Gc2145CmosSetReg( 0xd5, 0x00);
// 		Gc2145CmosSetReg( 0xa4, 0x00);
// 		Gc2145CmosSetReg( 0xa5, 0x00);
// 		Gc2145CmosSetReg( 0xa6, 0x77);
// 		Gc2145CmosSetReg( 0xa7, 0x77);
// 		Gc2145CmosSetReg( 0xa8, 0x77);
// 		Gc2145CmosSetReg( 0xa9, 0x77);
// 		Gc2145CmosSetReg( 0xa1, 0x80);
// 		Gc2145CmosSetReg( 0xa2, 0x80);

// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0xdf, 0x0d);
// 		Gc2145CmosSetReg( 0xdc, 0x25);
// 		Gc2145CmosSetReg( 0xdd, 0x30);
// 		Gc2145CmosSetReg( 0xe0, 0x77);
// 		Gc2145CmosSetReg( 0xe1, 0x80);
// 		Gc2145CmosSetReg( 0xe2, 0x77);
// 		Gc2145CmosSetReg( 0xe3, 0x90);
// 		Gc2145CmosSetReg( 0xe6, 0x90);
// 		Gc2145CmosSetReg( 0xe7, 0xa0);
// 		Gc2145CmosSetReg( 0xe8, 0x90);
// 		Gc2145CmosSetReg( 0xe9, 0xa0);                                      
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//awb
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x4f, 0x00);
// 		Gc2145CmosSetReg( 0x4f, 0x00);
// 		Gc2145CmosSetReg( 0x4b, 0x01);
// 		Gc2145CmosSetReg( 0x4f, 0x00);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01); // D75
// 		Gc2145CmosSetReg( 0x4d, 0x71);
// 		Gc2145CmosSetReg( 0x4e, 0x01);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x91);
// 		Gc2145CmosSetReg( 0x4e, 0x01);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x70);
// 		Gc2145CmosSetReg( 0x4e, 0x01);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01); // D65
// 		Gc2145CmosSetReg( 0x4d, 0x90);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xb0);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x8f);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x6f);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xaf);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xd0);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xf0);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xcf);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xef);
// 		Gc2145CmosSetReg( 0x4e, 0x02);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);//D50
// 		Gc2145CmosSetReg( 0x4d, 0x6e);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01); 
// 		Gc2145CmosSetReg( 0x4d, 0x8e);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xae);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xce);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x4d);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x6d);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x8d);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xad);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xcd);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x4c);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x6c);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x8c);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xac);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xcc);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xcb);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x4b);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x6b);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x8b);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xab);
// 		Gc2145CmosSetReg( 0x4e, 0x03);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01); //CWF
// 		Gc2145CmosSetReg( 0x4d, 0x8a);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xaa);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xca);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xca);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xc9);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x8a);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0x89);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xa9);
// 		Gc2145CmosSetReg( 0x4e, 0x04);
				
				
				
// 		Gc2145CmosSetReg( 0x4c, 0x02);//tl84
// 		Gc2145CmosSetReg( 0x4d, 0x0b);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x0a);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xeb);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
				
// 		Gc2145CmosSetReg( 0x4c, 0x01);
// 		Gc2145CmosSetReg( 0x4d, 0xea);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
						
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x09);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x29);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
							
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x2a);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
							
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x4a);
// 		Gc2145CmosSetReg( 0x4e, 0x05);
		
// 		//{0x4c , 0x02}, //A
// 		//{0x4d , 0x6a},
// 		//{0x4e , 0x06},
		
// 		Gc2145CmosSetReg( 0x4c, 0x02); 
// 		Gc2145CmosSetReg( 0x4d, 0x8a);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
						
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x49);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x69);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x89);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xa9);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
					
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x48);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x68);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0x69);
// 		Gc2145CmosSetReg( 0x4e, 0x06);
					
// 		Gc2145CmosSetReg( 0x4c, 0x02);//H
// 		Gc2145CmosSetReg( 0x4d, 0xca);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xc9);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xe9);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x03);
// 		Gc2145CmosSetReg( 0x4d, 0x09);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xc8);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xe8);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xa7);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xc7);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x02);
// 		Gc2145CmosSetReg( 0x4d, 0xe7);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
// 		Gc2145CmosSetReg( 0x4c, 0x03);
// 		Gc2145CmosSetReg( 0x4d, 0x07);
// 		Gc2145CmosSetReg( 0x4e, 0x07);
		
// 		Gc2145CmosSetReg( 0x4f, 0x01);
// 		Gc2145CmosSetReg( 0x50, 0x80);
// 		Gc2145CmosSetReg( 0x51, 0xa8);
// 		Gc2145CmosSetReg( 0x52, 0x47);
// 		Gc2145CmosSetReg( 0x53, 0x38);
// 		Gc2145CmosSetReg( 0x54, 0xc7);
// 		Gc2145CmosSetReg( 0x56, 0x0e);
// 		Gc2145CmosSetReg( 0x58, 0x08);
// 		Gc2145CmosSetReg( 0x5b, 0x00);
// 		Gc2145CmosSetReg( 0x5c, 0x74);
// 		Gc2145CmosSetReg( 0x5d, 0x8b);
// 		Gc2145CmosSetReg( 0x61, 0xdb);
// 		Gc2145CmosSetReg( 0x62, 0xb8);
// 		Gc2145CmosSetReg( 0x63, 0x86);
// 		Gc2145CmosSetReg( 0x64, 0xc0);
// 		Gc2145CmosSetReg( 0x65, 0x04);
		
// 		Gc2145CmosSetReg( 0x67, 0xa8);
// 		Gc2145CmosSetReg( 0x68, 0xb0);
// 		Gc2145CmosSetReg( 0x69, 0x00);
// 		Gc2145CmosSetReg( 0x6a, 0xa8);
// 		Gc2145CmosSetReg( 0x6b, 0xb0);
// 		Gc2145CmosSetReg( 0x6c, 0xaf);
// 		Gc2145CmosSetReg( 0x6d, 0x8b);
// 		Gc2145CmosSetReg( 0x6e, 0x50);
// 		Gc2145CmosSetReg( 0x6f, 0x18);
// 		Gc2145CmosSetReg( 0x73, 0xf0);
// 		Gc2145CmosSetReg( 0x70, 0x0d);
// 		Gc2145CmosSetReg( 0x71, 0x60);
// 		Gc2145CmosSetReg( 0x72, 0x80);
// 		Gc2145CmosSetReg( 0x74, 0x01);
// 		Gc2145CmosSetReg( 0x75, 0x01);
// 		Gc2145CmosSetReg( 0x7f, 0x0c);
// 		Gc2145CmosSetReg( 0x76, 0x70);
// 		Gc2145CmosSetReg( 0x77, 0x58);
// 		Gc2145CmosSetReg( 0x78, 0xa0);
// 		Gc2145CmosSetReg( 0x79, 0x5e);
// 		Gc2145CmosSetReg( 0x7a, 0x54);
// 		Gc2145CmosSetReg( 0x7b, 0x58);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//////////////////////////////////////////
// 		///////////CC////////////////////////
// 		//////////////////////////////////////////
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0xc0, 0x01);
// 		Gc2145CmosSetReg( 0xc1, 0x44);
// 		Gc2145CmosSetReg( 0xc2, 0xfd);
// 		Gc2145CmosSetReg( 0xc3, 0x04);
// 		Gc2145CmosSetReg( 0xc4, 0xf0);
// 		Gc2145CmosSetReg( 0xc5, 0x48);
// 		Gc2145CmosSetReg( 0xc6, 0xfd);
// 		Gc2145CmosSetReg( 0xc7, 0x46);
// 		Gc2145CmosSetReg( 0xc8, 0xfd);
// 		Gc2145CmosSetReg( 0xc9, 0x02);
// 		Gc2145CmosSetReg( 0xca, 0xe0);
// 		Gc2145CmosSetReg( 0xcb, 0x45);
// 		Gc2145CmosSetReg( 0xcc, 0xec);
// 		Gc2145CmosSetReg( 0xcd, 0x48);
// 		Gc2145CmosSetReg( 0xce, 0xf0);
// 		Gc2145CmosSetReg( 0xcf, 0xf0);
// 		Gc2145CmosSetReg( 0xe3, 0x0c);
// 		Gc2145CmosSetReg( 0xe4, 0x4b);
// 		Gc2145CmosSetReg( 0xe5, 0xe0);
// 		//////////////////////////////////////////
// 		///////////ABS ////////////////////
// 		//////////////////////////////////////////
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x9f, 0x40);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//////////////////////////////////////
// 		///////////  OUTPUT   ////////////////
// 		//////////////////////////////////////
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0xf2, 0x00);
		
// 		//////////////frame rate 50Hz/////////
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0x05, 0x01);
// 		Gc2145CmosSetReg( 0x06, 0x56);
// 		Gc2145CmosSetReg( 0x07, 0x00);
// 		Gc2145CmosSetReg( 0x08, 0x32);
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x25, 0x00);
// 		Gc2145CmosSetReg( 0x26, 0xfa); 
// 		Gc2145CmosSetReg( 0x27, 0x04); 
// 		Gc2145CmosSetReg( 0x28, 0xe2); //20fps 
// 		Gc2145CmosSetReg( 0x29, 0x06); 
// 		Gc2145CmosSetReg( 0x2a, 0xd6); //14fps 
// 		Gc2145CmosSetReg( 0x2b, 0x07); 
// 		Gc2145CmosSetReg( 0x78, 0xd0); //12fps
// 		Gc2145CmosSetReg( 0x2d, 0x0b); 
// 		Gc2145CmosSetReg( 0x2e, 0xb8); //8fps
// 		Gc2145CmosSetReg( 0xfe, 0x00);
		
// 		///////////////dark sun////////////////////
// 		Gc2145CmosSetReg( 0x18, 0x22); 
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x40, 0xbf);
// 		Gc2145CmosSetReg( 0x46, 0xcf);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		/////////////////////////////////////////////////////
// 		//////////////////////   MIPI   /////////////////////
// 		/////////////////////////////////////////////////////
// 		Gc2145CmosSetReg( 0xfe, 0x03);
// 		Gc2145CmosSetReg( 0x02, 0x22);
// 		Gc2145CmosSetReg( 0x03, 0x10); // 0x12 20140821
// 		Gc2145CmosSetReg( 0x04, 0x10); // 0x01 
// 		Gc2145CmosSetReg( 0x05, 0x00);
// 		Gc2145CmosSetReg( 0x06, 0x88);
// 		//GC2145_MIPI_2Lane
// 		Gc2145CmosSetReg( 0x01, 0x87);
// 		Gc2145CmosSetReg( 0x10, 0x85);

// 		Gc2145CmosSetReg( 0x11, 0x1e);
// 		Gc2145CmosSetReg( 0x12, 0x80);
// 		Gc2145CmosSetReg( 0x13, 0x0c);
// 		Gc2145CmosSetReg( 0x15, 0x10);
// 		Gc2145CmosSetReg( 0x17, 0xf0);
		
// 		Gc2145CmosSetReg( 0x21, 0x10);
// 		Gc2145CmosSetReg( 0x22, 0x04);
// 		Gc2145CmosSetReg( 0x23, 0x10);
// 		Gc2145CmosSetReg( 0x24, 0x10);
// 		Gc2145CmosSetReg( 0x25, 0x10);
// 		Gc2145CmosSetReg( 0x26, 0x05);
// 		Gc2145CmosSetReg( 0x29, 0x03);
// 		Gc2145CmosSetReg( 0x2a, 0x0a);
// 		Gc2145CmosSetReg( 0x2b, 0x06);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		//////////////////////////////////////////////////////////////////
// 		//////////////////////   GC2145_MIPI_YUV_800x600   ///////////////
// 		//////////////////////////////////////////////////////////////////
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0xfd, 0x01);
// 		Gc2145CmosSetReg( 0xfa, 0x00);
// 		//// crop window             
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0x99, 0x11);  
// 		Gc2145CmosSetReg( 0x9a, 0x06);
// 		Gc2145CmosSetReg( 0x9b, 0x00);
// 		Gc2145CmosSetReg( 0x9c, 0x00);
// 		Gc2145CmosSetReg( 0x9d, 0x00);
// 		Gc2145CmosSetReg( 0x9e, 0x00);
// 		Gc2145CmosSetReg( 0x9f, 0x00);
// 		Gc2145CmosSetReg( 0xa0, 0x00);  
// 		Gc2145CmosSetReg( 0xa1, 0x00);
// 		Gc2145CmosSetReg( 0xa2 ,0x00);
// 		Gc2145CmosSetReg( 0x90, 0x01); 
// 		Gc2145CmosSetReg( 0x91, 0x00);
// 		Gc2145CmosSetReg( 0x92, 0x00);
// 		Gc2145CmosSetReg( 0x93, 0x00);
// 		Gc2145CmosSetReg( 0x94, 0x00);
// 		Gc2145CmosSetReg( 0x95, 0x02);
// 		Gc2145CmosSetReg( 0x96, 0x58);
// 		Gc2145CmosSetReg( 0x97, 0x03);
// 		Gc2145CmosSetReg( 0x98, 0x20);

// 		//// AWB                      
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0xec, 0x02);
// 		Gc2145CmosSetReg( 0xed, 0x02);
// 		Gc2145CmosSetReg( 0xee, 0x30);
// 		Gc2145CmosSetReg( 0xef, 0x48);
// 		Gc2145CmosSetReg( 0xfe, 0x02);
// 		Gc2145CmosSetReg( 0x9d, 0x0b);
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x74, 0x00);
// 		//// AEC                      
// 		Gc2145CmosSetReg( 0xfe, 0x01);
// 		Gc2145CmosSetReg( 0x01, 0x04);
// 		Gc2145CmosSetReg( 0x02, 0x60);
// 		Gc2145CmosSetReg( 0x03, 0x02);
// 		Gc2145CmosSetReg( 0x04, 0x48);
// 		Gc2145CmosSetReg( 0x05, 0x18);
// 		Gc2145CmosSetReg( 0x06, 0x50);
// 		Gc2145CmosSetReg( 0x07, 0x10);
// 		Gc2145CmosSetReg( 0x08, 0x38);
// 		Gc2145CmosSetReg( 0x0a, 0x80);
// 		Gc2145CmosSetReg( 0x21, 0x04);
// 		Gc2145CmosSetReg( 0xfe, 0x00);
// 		Gc2145CmosSetReg( 0x20, 0x03);

// 		//// mipi
// 		Gc2145CmosSetReg( 0xfe, 0x03);
// 		Gc2145CmosSetReg( 0x12, 0x40);
// 		Gc2145CmosSetReg( 0x13, 0x06);
// 		//GC2145_MIPI_2Lane
// 		Gc2145CmosSetReg( 0x04, 0x90);
// 		Gc2145CmosSetReg( 0x05, 0x01);
// 		Gc2145CmosSetReg( 0xfe, 0x00);

        
        Gc2145CmosSetReg(0xfe, 0x00);
        Gc2145CmosSetReg(0xfd, 0x01);
        Gc2145CmosSetReg(0xfa, 0x00);
        //// crop window             
        Gc2145CmosSetReg(0xfe, 0x00);
        Gc2145CmosSetReg(0x90, 0x01);
        Gc2145CmosSetReg(0x91, 0x00);
        Gc2145CmosSetReg(0x92, 0x00);
        Gc2145CmosSetReg(0x93, 0x00);
        Gc2145CmosSetReg(0x94, 0x00);
        Gc2145CmosSetReg(0x95, 0x02);
        Gc2145CmosSetReg(0x96, 0x58);
        Gc2145CmosSetReg(0x97, 0x03);
        Gc2145CmosSetReg(0x98, 0x20);
        Gc2145CmosSetReg(0x99, 0x11);
        Gc2145CmosSetReg(0x9a, 0x06);
        //// AWB                     
        Gc2145CmosSetReg(0xfe, 0x00);
        Gc2145CmosSetReg(0xec, 0x02);
        Gc2145CmosSetReg(0xed, 0x02);
        Gc2145CmosSetReg(0xee, 0x30);
        Gc2145CmosSetReg(0xef, 0x48);
        Gc2145CmosSetReg(0xfe, 0x02);
        Gc2145CmosSetReg(0x9d, 0x08);
        Gc2145CmosSetReg(0xfe, 0x01);
        Gc2145CmosSetReg(0x74, 0x00);
        //// AEC                     
        Gc2145CmosSetReg(0xfe, 0x01);
        Gc2145CmosSetReg(0x01, 0x04);
        Gc2145CmosSetReg(0x02, 0x60);
        Gc2145CmosSetReg(0x03, 0x02);
        Gc2145CmosSetReg(0x04, 0x48);
        Gc2145CmosSetReg(0x05, 0x18);
        Gc2145CmosSetReg(0x06, 0x50);
        Gc2145CmosSetReg(0x07, 0x10);
        Gc2145CmosSetReg(0x08, 0x38);
        Gc2145CmosSetReg(0x0a, 0x80);
        Gc2145CmosSetReg(0x21, 0x04);
        Gc2145CmosSetReg(0xfe, 0x00);
        Gc2145CmosSetReg(0x20, 0x03);
        //// mipi
        Gc2145CmosSetReg(0xfe, 0x03);
        Gc2145CmosSetReg(0x12, 0x40);
        Gc2145CmosSetReg(0x13, 0x06);
#if defined(GC2145MIPI_2Lane)
        Gc2145CmosSetReg(0x04, 0x90);
        Gc2145CmosSetReg(0x05, 0x01);
        DEBUG_INFO("-------------------------->\n\r");
#else
        Gc2145CmosSetReg(0x04, 0x01);
        Gc2145CmosSetReg(0x05, 0x00);
#endif
        Gc2145CmosSetReg(0xfe, 0x00);
		
		DEBUG_INFO("===gc2145 mipi_yuv_800*600 configured===\n\r");
};
//
// TURN VIS STREAM ON
	void gc2145_stream_on(void)
	{
		DEBUG_INFO("===gc2145 stream on===\n");
		
		Gc2145CmosSetReg(0xfe, 0x03);
		Gc2145CmosSetReg(0x10, 0x91);
		Gc2145CmosSetReg(0xfe, 0x00);
	}
//


