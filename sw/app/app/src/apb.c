#include "../../inc/system.h"

#define XBUS_WRITE(addr, value) \
    neorv32_cpu_store_unsigned_word((u32)(addr), (u32)(value))

#define XBUS_READ(addr) \
    neorv32_cpu_load_unsigned_word((u32)(addr))
// static inline u32 read_u32(u32 address){
// 	return *((volatile u32*) address);
// }
// static inline void write_u32(u32 data, u32 address){
// 	*((volatile u32*) address) = data;
// }

//apb写接口，注意是否越界，地址增量为4
void apb_write(u16 addr, u32 data)
{
    u32 waddr = 0;
    if (addr > APB_REG_ADDR_MAX_RISV)
    {
        addr = APB_REG_ADDR_MAX_RISV;
    }
    waddr = APB_REG_ADDR_BASE1 + addr;
    // write_u32(data, (addr & 0xFFFC) + APB_REG_ADDR_BASE1);
    XBUS_WRITE(waddr, data);
}
//apb读接口，注意是否越界，地址增量为4
void apb_read(u16 addr , u32 *data)
{
    u32 waddr = 0;
    if (addr > APB_REG_ADDR_MAX_RISV)
    {
        addr = APB_REG_ADDR_MAX_RISV;
    }
    waddr = APB_REG_ADDR_BASE1 + addr;
    // *data = read_u32((addr & 0xFFFC) + APB_REG_ADDR_BASE1);
    *data = XBUS_READ(waddr);
}

void ProgramVersion(u16 u16data)
{
    u32 WrApbData;
    WrApbData = (((EDITION_NUM1 <<12)|(EDITION_NUM2 <<6)|EDITION_NUM3))|(u16data<<16);
    apb_write(APB_REG_ADDR_VERSION0,WrApbData);
    WrApbData = ((EDITION_YEAR <<16)| (EDITION_MONTH<<8) | EDITION_DATE);//年月日
    apb_write(APB_REG_ADDR_VERSION1,WrApbData);
    DEBUG_INFO("version -->V%d.%d.%d.%d/%d/%d\n\r",
	EDITION_NUM1,EDITION_NUM2,EDITION_NUM3,EDITION_YEAR,EDITION_MONTH,EDITION_DATE);
}