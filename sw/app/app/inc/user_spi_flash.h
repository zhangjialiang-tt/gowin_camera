#ifndef USER_SPI_FLASH_H
#define USER_SPI_FLASH_H
// FLASH 属性
/* flash: block 64K        */
/* flash: sector 4K        */
/* flash: page 256byte     */
/* flash: FREQ 120MHz      */
/* 页编程时间： 0.5ms       */
/* Sector 擦除时间：45ms    */
#include "type.h"
/*************************** MAP ********************************/
/****************************************************************/
#define FLASH_PAGE_SIZE                      0xFF           /* flash PAGE大小   0000FFH*/
#define FLASH_SECTOR_SIZE                    0xFFF          /* flash SECTOR大小 000FFFH*/
#define FLASH_BLOCK_SIZE                     0xFFFF         /* flash BLOCK大小  00FFFFH*/
/* flash空间分配 --> flash一次性擦除最小的空间为SECTOR 4K*/
#define USER_FLASHADDR_OFFSET                   0x0E0000        /* 用户数据起始地址 */
#define UPDATE_LOW_TEMP_PARAM_PACK_FLASHADDR    0x100000        /* 低温参数包升级flash内存地址 */
#define UPDATE_HIGH_TEMP_PARAM_PACK_FLASHADDR   0x200000        /* 高温参数包升级flash内存地址 */
// #define LOW_TEMP_K_ADDRS          				0x100000 + 216 + 1400 + 10 + 42000    	/*低温挡K数据基地址*/
// #define HIGH_TEMP_K_ADDRS         				0x200000 + 216 + 1400 + 10 + 140000 	/*高温挡K数据基地址*/

#define LOW_TEMP_K_ADDRS          				0x100000 + 216 + 1400 + 14 + 58800    	/*低温挡K数据基地址*/
#define HIGH_TEMP_K_ADDRS         				0x200000 + 216 + 1400 + 14 + 196000 	/*高温挡K数据基地址*/
/* 参数包宏定义 */
#define TEMP_PARAM_PACK_FOCUSNUMBER             7               /* 参数包焦温个数 -->目前默认7个，根据实际情况做调整 */

#define TEMP_PARAM_PACK_HEAD_ADDR               0               /* 参数包包头数据起始地址 */
#define TEMP_PARAM_PACK_SENSOR_ADDR             216             /* 参数包探测器参数起始地址 */
#define TEMP_PARAM_PACK_COKE_TEMP_ADDR          1616            /* 参数包焦温参数起始地址 */

#define TEMP_PARAM_PACK_TOTAL_SIZE              216 + 140          /* 分配内存大小:参数包总大小(以最大参数包为主) */
#define LOW_TEMP_PARAM_PACK_TOTAL_SIZE          216 + 140          /* 分配内存大小:工业低温参数包总大小(以最大参数包为主) */
#define HIGH_TEMP_PARAM_PACK_TOTAL_SIZE         216 + 140          /* 分配内存大小:工业高温参数包总大小(以最大参数包为主) */

#ifndef NULL
    #define NULL    0L
#endif

#define NI_NULL     0L
//------------------------------------------------------------------------------------------------------------------------
/* 参数包包头参数 */
#pragma pack(1)  //指定按1字节对齐
typedef struct tagTempDataHead
{
	u32        u32HeadLength;                              /* 文件头长度 */
	signed char         as8ModuleMtMark[60];                        /* 模组测温标识符 */
	u8       u8GearMark;                                 /* 测温档位标志 */
	u8       u8FocusNumber;                              /* 焦温个数 */
	s16        s16TMin;                                    /* 最小测量温度 */
	s16        s16TMax;                                    /* 最大测量温度 */
	u8       u8reserve1;
	u8       u8reserve2;
	u8       u8reserve3;
	u8       u8CurveNumber;                              /* 曲线条数 */
	u8       u8DistanceCompensateMode;                   /* 距离补偿模式 */
	u8       u8DistanceNumber;                           /* 距离点个数 */
	u16      u16Width;                                   /* 图像宽 */
	u16      u16Height;                                  /* 图像高 */
	u16      u16CurveTemperatureNumber;                  /* 曲线温度点个数 */
	u16      u16FocusArrayLength;                        /* 焦温数组长度 */
	u32        u32CurveDataLength;                         /* 曲线数据长度 */
	u32        u32KMatLength;                              /* k矩阵长度 */
	float               f32CompensateA1;                            /* 距离补偿参数 */
	float               f32CompensateA2;
	float               f32CompensateB1;
	float               f32CompensateB2;
	float               f32CompensateC1;
	float               f32CompensateC2;
	s16        as16DistanceArray[5];                       /* 标定距离点 */
	u8       au8Date[10];                                /* 日期与时间 */
	u8       au8Time[10];
	u8       au8ModuleCode[24];                          /* 模组编号 */
	u8       au8CollectionItem[12];                      /* 采集料号 */
	u8       u8SheBeiBianHao;					        /* 设备编号 */
	u8       u8ZhiJuHao;						            /* 治具号 */
	u8       u8KaChaoHao;					            /* 模组卡位号 */
	u8       u8DingBiaoHeiTiNumber;			            /* 定标黑体个数 */
	u8       u8FocusType; 					            /* 对焦类型  0  定焦；1 自动对焦 */
	u8       u8FieldType; 					            /* 视场角类型 0:56°-->3.2mm; 1:25°-->7mm; 2:120°-->1.7mm; 3:50°; 4:90°-->2.1mm; 5:33°; 13:90°; 14:17.5°-->10mm; 15:13°-->13mm; */
	u8       u8MtTpye;						            /* 测温类型 0  人体；1 工业低温； 2 工业高温 3 观瞄*/
 	u8       au8CorrectError[23];                        /* 校验误差，暂时未使用 */
	u16	    u16MTPointX;                                /* 标定测温点横坐标 */
	u16	    u16MTPointY;                                /* 标定测温点纵坐标 */
} TEMP_DATA_HEAD_S;
#pragma pack()   //取消指定对齐，恢复缺省对齐


//func

void FlashAndDdrDataTRFCtrl(u32 u32FlashAddrs,u32 u32DdrAddrs,u32 u32Lenss,u8 u8dir);
u8 ParameLoad(void);
#endif