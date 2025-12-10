
#ifndef __APB_H__
#define __APB_H__

#include <type.h>
#define EDITION_YEAR 2025 // 程序版本号：年
#define EDITION_MONTH 12 // 版本日期：月
#define EDITION_DATE 01 // 版本日期：日
#define EDITION_NUM1 1  // 大版本
#define EDITION_NUM2 0  // 中版本
#define EDITION_NUM3 6  // 小版本

//apb写接口，注意是否越界，地址增量为4
void apb_write(u16 addr, u32 data);

//apb读接口，注意是否越界，地址增量为4
void apb_read(u16 addr, u32 *data);

void ProgramVersion(u16 u16data);
#endif