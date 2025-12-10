
#include "user_spi_flash.h"
#include "../../inc/system.h"
//define
static void FlashParameCtrl(u32 u32FlashAddrs,u32 u32Lens,u8 u8Dir);
static void SensorFlashParameload(u32 *u32Data);


static void SensorFlashParameload(u32 *u32Data)
{
    u32 u32ApbData;
    apb_read(APB_REG_ADDR_SENSOR_PARA0  , &u32ApbData);
    // DEBUG_INFO("SensorFlashParameload u32ApbData-->   %x \n\r",u32ApbData   ); 
    *u32Data = u32ApbData;
}

u8 ParameLoad(void)
{
    u8 u8Loop = 0x01;
    u8 u8Loop_i = 0x00;
    u8 u8StateFlag = 0x00;
    u32 u32ApbData;
    for (u8Loop = 1; u8Loop < 3; u8Loop++)
    {
        apb_write(APB_REG_ADDR_SENSOR_PARA0, 0xffffffff);   //fifo rst
        apb_write(APB_REG_ADDR_SENSOR_PARA0, 0x00000000);
        if(u8Loop == 0x01)
        {
            FlashParameCtrl(UPDATE_LOW_TEMP_PARAM_PACK_FLASHADDR,LOW_TEMP_PARAM_PACK_TOTAL_SIZE,0);
        }
        else 
        {
            FlashParameCtrl(UPDATE_HIGH_TEMP_PARAM_PACK_FLASHADDR,HIGH_TEMP_PARAM_PACK_TOTAL_SIZE,0);
        }

        do{
            apb_read(APB_REG_ADDR_RD_BUS0  , &u32ApbData);
        }
        while(0x01 == (u32ApbData & 0x1));
        
        if(u8Loop == 0x01)
        {   
            SensorFlashParameload(&u32ApbData);     
            if((u32ApbData&0x0000ffff) != 0x00d8)
            {
                u8Loop = 3;     //参数异常直接停止加载 快速结束
                u8StateFlag =0x01;
            }
            else 
            {
            for (u8Loop_i = 0; u8Loop_i < 108; u8Loop_i++)
            {
                SensorFlashParameload(&u32ApbData); 
            }
            DEBUG_INFO("go to load low param\n\r");
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_int_set           = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gain              = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gsk_ref           = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gsk               = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_vbus              = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_vbus_ref          = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_rd_rc             = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gfid              = (u32ApbData &0xffff);           
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_csize             = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_occ_value         = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_occ_step          = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_occ_thres_up      = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_occ_thres_down    = (u32ApbData &0xffff);           
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_ra                = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_ra_thres_high     = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_ra_thres_low      = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_raadj             = (u32ApbData &0xffff);           
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_raadj_thres_high  = (u32ApbData &0xffff);           
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_raadj_thres_low   = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_rasel             = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_rasel_thres_high  = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_rasel_thres_low   = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_hssd              = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_hssd_thres_high   = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_hssd_thres_low    = (u32ApbData &0xffff);            
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gsk_thres_high    = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_low_gsk_thres_low     = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16nuc_low_step              = (u32ApbData &0xffff);     

            apb_write(APB_REG_ADDR_SENSOR_PARA1 , stSensorParam.u16_low_int_set);
            apb_write(APB_REG_ADDR_SENSOR_PARA2 , stSensorParam.u16_low_gain);
            apb_write(APB_REG_ADDR_SENSOR_PARA3 , stSensorParam.u16_low_gsk_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA4 , stSensorParam.u16_low_gsk);
            apb_write(APB_REG_ADDR_SENSOR_PARA5 , stSensorParam.u16_low_vbus);
            apb_write(APB_REG_ADDR_SENSOR_PARA6 , stSensorParam.u16_low_vbus_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA7 , stSensorParam.u16_low_rd_rc);
            apb_write(APB_REG_ADDR_SENSOR_PARA8 , stSensorParam.u16_low_gfid);
            apb_write(APB_REG_ADDR_SENSOR_PARA9 , stSensorParam.u16_low_csize);
            apb_write(APB_REG_ADDR_SENSOR_PARA10, stSensorParam.u16_low_occ_value);
            apb_write(APB_REG_ADDR_SENSOR_PARA11, stSensorParam.u16_low_occ_step);
            apb_write(APB_REG_ADDR_SENSOR_PARA12, stSensorParam.u16_low_occ_thres_up);
            apb_write(APB_REG_ADDR_SENSOR_PARA13, stSensorParam.u16_low_occ_thres_down);
            apb_write(APB_REG_ADDR_SENSOR_PARA14, stSensorParam.u16_low_ra);
            apb_write(APB_REG_ADDR_SENSOR_PARA15, stSensorParam.u16_low_ra_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA16, stSensorParam.u16_low_ra_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA17, stSensorParam.u16_low_raadj);
            apb_write(APB_REG_ADDR_SENSOR_PARA18, stSensorParam.u16_low_raadj_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA19, stSensorParam.u16_low_raadj_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA20, stSensorParam.u16_low_rasel);
            apb_write(APB_REG_ADDR_SENSOR_PARA21, stSensorParam.u16_low_rasel_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA22, stSensorParam.u16_low_rasel_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA23, stSensorParam.u16_low_hssd);
            apb_write(APB_REG_ADDR_SENSOR_PARA24, stSensorParam.u16_low_hssd_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA25, stSensorParam.u16_low_hssd_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA26, stSensorParam.u16_low_gsk_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA27, stSensorParam.u16_low_gsk_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA28, stSensorParam.u16nuc_low_step); 
            }
        }
        else 
        {
            SensorFlashParameload(&u32ApbData);  
            if((u32ApbData&0x0000ffff) != 0x00d8)
            {
                u8StateFlag =0x01;
            }
            else 
            {
            for (u8Loop_i = 0; u8Loop_i < 108; u8Loop_i++)
            {
                SensorFlashParameload(&u32ApbData); 
            }
            DEBUG_INFO("go to load high param  \n\r"   );
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_int_set           = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gain              = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gsk_ref           = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gsk               = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_vbus              = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_vbus_ref          = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_rd_rc             = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gfid              = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_csize             = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_occ_value         = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_occ_step          = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_occ_thres_up      = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_occ_thres_down    = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_ra                = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_ra_thres_high     = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_ra_thres_low      = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_raadj             = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_raadj_thres_high  = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_raadj_thres_low   = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_rasel             = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_rasel_thres_high  = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_rasel_thres_low   = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_hssd              = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_hssd_thres_high   = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_hssd_thres_low    = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gsk_thres_high    = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16_high_gsk_thres_low     = (u32ApbData &0xffff);
            SensorFlashParameload(&u32ApbData);
            stSensorParam.u16nuc_high_step              = (u32ApbData &0xffff);  
            
            apb_write(APB_REG_ADDR_SENSOR_PARA1 , stSensorParam.u16_high_int_set);
            apb_write(APB_REG_ADDR_SENSOR_PARA2 , stSensorParam.u16_high_gain);
            apb_write(APB_REG_ADDR_SENSOR_PARA3 , stSensorParam.u16_high_gsk_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA4 , stSensorParam.u16_high_gsk);
            apb_write(APB_REG_ADDR_SENSOR_PARA5 , stSensorParam.u16_high_vbus);
            apb_write(APB_REG_ADDR_SENSOR_PARA6 , stSensorParam.u16_high_vbus_ref);
            apb_write(APB_REG_ADDR_SENSOR_PARA7 , stSensorParam.u16_high_rd_rc);
            apb_write(APB_REG_ADDR_SENSOR_PARA8 , stSensorParam.u16_high_gfid);
            apb_write(APB_REG_ADDR_SENSOR_PARA9 , stSensorParam.u16_high_csize);
            apb_write(APB_REG_ADDR_SENSOR_PARA10, stSensorParam.u16_high_occ_value);
            apb_write(APB_REG_ADDR_SENSOR_PARA11, stSensorParam.u16_high_occ_step);
            apb_write(APB_REG_ADDR_SENSOR_PARA12, stSensorParam.u16_high_occ_thres_up);
            apb_write(APB_REG_ADDR_SENSOR_PARA13, stSensorParam.u16_high_occ_thres_down);
            apb_write(APB_REG_ADDR_SENSOR_PARA14, stSensorParam.u16_high_ra);
            apb_write(APB_REG_ADDR_SENSOR_PARA15, stSensorParam.u16_high_ra_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA16, stSensorParam.u16_high_ra_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA17, stSensorParam.u16_high_raadj);
            apb_write(APB_REG_ADDR_SENSOR_PARA18, stSensorParam.u16_high_raadj_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA19, stSensorParam.u16_high_raadj_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA20, stSensorParam.u16_high_rasel);
            apb_write(APB_REG_ADDR_SENSOR_PARA21, stSensorParam.u16_high_rasel_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA22, stSensorParam.u16_high_rasel_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA23, stSensorParam.u16_high_hssd);
            apb_write(APB_REG_ADDR_SENSOR_PARA24, stSensorParam.u16_high_hssd_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA25, stSensorParam.u16_high_hssd_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA26, stSensorParam.u16_high_gsk_thres_high);
            apb_write(APB_REG_ADDR_SENSOR_PARA27, stSensorParam.u16_high_gsk_thres_low);
            apb_write(APB_REG_ADDR_SENSOR_PARA28, stSensorParam.u16nuc_high_step);  
            }
        }
    }
    return u8StateFlag;
    
}

 void FlashParameCtrl(u32 u32FlashAddrs,u32 u32Lens,u8 u8Dir)
 {
    u32 u32ApbData;
    do{
        apb_read(APB_REG_ADDR_RD_BUS0  , &u32ApbData);
    }
    while(0x01 == (u32ApbData & 0x1));
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    apb_write(APB_REG_ADDR_RD_BUS0, 0x02); 
    if(u8Dir == 0x00)
    {
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffffe)); //flash to ddr
    }
    else 
    {
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData|0x00000001)); //ddr to flash
    }
    apb_write( APB_REG_ADDR_FLASH_TRF_ADDR,u32FlashAddrs);
    apb_write( APB_REG_ADDR_TRF_DATALENS,u32Lens);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffff7)); //en-->0  
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData|0x00000008)); //en-->1  
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffff7)); //en-->0  
    apb_write(APB_REG_ADDR_RD_BUS0, 0x00); 
 }

void FlashAndDdrDataTRFCtrl(u32 u32FlashAddrs,u32 u32DdrAddrs,u32 u32Lenss,u8 u8Dir)
{
    u32 u32ApbData;
    do{
        apb_read(APB_REG_ADDR_RD_BUS0  , &u32ApbData);
    }
    while(0x01 == (u32ApbData & 0x1));
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    apb_write(APB_REG_ADDR_RD_BUS0, 0x01); 
    if(u8Dir == 0x00)
    {
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffffe)); //flash to ddr
    }
    else 
    {
        apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData|0x00000001)); //ddr to flash
    }
    apb_write(APB_REG_ADDR_FLASH_TRF_ADDR,u32FlashAddrs);
    apb_write(APB_REG_ADDR_DDR_TRF_ADDR,u32DdrAddrs);
    apb_write(APB_REG_ADDR_TRF_DATALENS,u32Lenss);
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData); 
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffff7)); //en-->0  
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData|0x00000008)); //en-->1  
    apb_read(APB_REG_ADDR_EN_BUS0, &u32ApbData);
    apb_write(APB_REG_ADDR_EN_BUS0, (u32ApbData&0xfffffff7)); //en-->0  
    apb_write(APB_REG_ADDR_RD_BUS0, 0x00); 
}

