#ifndef _USB_PROCESS_H_
#define _USB_PROCESS_H_

#ifdef __cplusplus
extern "C"{
#endif /* __cplusplus */
#include "type.h"
/********************************************宏定义*****************************************************/
/* 升级包校验 */
#define UIMG_MAGIC          0x27051956
#define IH_NMLEN            32                      /* Image Name Length        */

/*********************************************USB通信协议指令集************************************************/
#define USB_CMD_OPEN_USB                        0x01                /* 打开USB通信接口 */
#define USB_CMD_CLOSE_USB                       0x02                /* 关闭USB通信接口 */
#define USB_CMD_GET_DEV_INFO                    0x03                /* 获取设备信息 */
#define USB_CMD_SEND_DEV_INFO                   0x04                /* 上传设备信息 */
#define USB_CMD_LOAD_UPDATE_PACK                0x07                /* 升级固件升级包 */       
#define USB_CMD_SEND_UPDATE_PACK_STATUS         0x08                /* 返回升级状态（成功或失败） */
#define USB_CMD_LOAD_PSEUDO_PACK                0x09		        /* 加载伪彩包 */
#define USB_CMD_SEND_PSEUDO_PACK_STATUS         0x0a                /* 返回伪彩包导入状态 */
#define USB_CMD_DELETE_PSEUDO_PACK        		0x0b                /* 删除伪彩包（通过上位机导入的才能删除）*/

#define USB_CMD_SET_PSEUDO                      0x11                /* 切换伪彩 */
#define USB_CMD_IMAGE_FREEZE                    0x12                /* 图像定格/解定格 */
#define USB_CMD_RST_SYSTEM                      0x13                /* 重启系统 */
#define USB_CMD_SHUTTER_COMPENSATE              0x14                /* 快门挡板运作 */
#define USB_CMD_SHUTTER_BASE_COMPENSATE         0x15                /* 快门补偿控制  0:无操作 1：场景补偿 2：本底补偿 3：NUC补偿 */
#define USB_CMD_HOT_TRACK_CFG                   0x16                /* 热点追踪开关控制  0：关闭  1：开启 */
#define USB_CMD_OPEN_HEARTBEAT_MODE             0x17                /* 开启心跳模式 */
#define USB_CMD_CLOSE_HEARTBEAT_MODE            0x18                /* 关闭心跳模式 */
#define USB_CMD_SEND_HEARTBEAT_PACK             0x19                /* 发送心跳包（喂狗）*/
#define USB_CMD_SET_DIGITIAL_DATA_MODE          0X1A                /* 设置数字口输出数据格式*/
#define USB_CMD_GET_DIGITIAL_DATA_MODE          0X1B                /* 获取数字口输出数据格式*/
#define USB_CMD_SED_DIGITIAL_DATA_MODE          0X1C                /* 返回数字口输出数据格式*/
#define USB_CMD_SET_IO_VOLTAGE                  0X1D                /* 设置观瞄测温电压切换*/

#define USB_CMD_SAVE_PARAME                     0x20                /* 保存参数 */
#define USB_CMD_SAVE_PARAME_STATUS              0x21                /* 保存参数状态 */

#define USB_CMD_RESTORE_FACTORY                 0x26                /* 恢复出厂设置 */
#define USB_CMD_RESTORE_FACTORY_STATUS          0x27                /* 恢复出厂设置状态 */
#define USB_CMD_TIMER_COMPENSATE_SWITCH         0x28                /* 定时补偿开关 */
#define USB_CMD_SET_TIMER_COMPENSATE_TIME       0x29                /* 设置定时补偿时间 */
#define USB_CMD_SET_SET_SN                      0x30                /* 设置SN号 */

#define USB_CMD_SET_FRAME						0x35                /* 设置帧频 */  

#define USB_CMD_UPDATE_PARAM_PACK			    0x36                /* 导入参数包--> 0：人体 1：工业低温 2：工业高温  3：观瞄 */
#define USB_CMD_UPDATE_PARAM_PACK_STATUS        0x37                /* 导入参数包执行状态 */
// #define USB_CMD_UPDATE_HUMAN_PACK				0x37                /* 导入人体参数包 */
#define USB_CMD_UPDATE_INDUSTRY_LOW_PACK        0x38                /* 导入工业低温参数包 */
#define USB_CMD_UPDATE_INDUSTRY_HIGH_PACK       0x39                /* 导入工业高温参数包 */
#define USB_CMD_SEND_PARAM_PACK_STATUS			0x3A                /* 发送导入参数包状态 */
#define USB_CMD_EXPORT_PARAM_PACK				0x3B                /* 导出参数包 */
// #define USB_CMD_EXPORT_HUMAN_PACK				0x3B                /* 导出人体参数包 */
#define USB_CMD_EXPORT_INDUSTRY_LOW_PACK        0x3C                /* 导出工业低温参数包 */
#define USB_CMD_EXPORT_INDUSTRY_HIGH_PACK       0x3D                /* 导出工业高温参数包 */
#define USB_CMD_EXPORT_HUMAN_PACK_STATUS	    0x3E                /* 导出人体参数包执行状态 */

#define USB_CMD_GET_BAD_X			            0x40                /* 获取坏点X坐标 */
#define USB_CMD_GET_BAD_Y			            0x41                /* 获取坏点Y坐标 */
#define USB_CMD_ADD_BAD_POINT                   0x42                /* 添加坏点 */
#define USB_CMD_ADD_BAD_POINT_STATUS            0x43                /* 添加坏点完成状态 */
#define USB_CMD_SAVE_BAD_POINT                  0x44                /* 保存坏点 */
#define USB_CMD_SAVE_BAD_POINT_STATUS           0x45                /* 保存坏点完成状态 */
#define USB_CMD_REMOVE_BAD_POINT                0x46                /* 移除坏点 */
#define USB_CMD_REMOVE_BAD_POINT_STATUS         0x47                /* 移除坏点完成状态 */
#define USB_CMD_TRY_BAD_POINT               	0x48                /* 标定坏点 */
#define USB_CMD_TRY_BAD_POINT_STATUS        	0x49                /* 标定坏点完成状态 */

#define USB_CMD_AUTO_BAD_POINT                  0x50                /* 一键校坏点 */
#define USB_CMD_AUTO_BAD_POINT_STATUS           0x51                /* 返回一键校坏点状态  0：成功  非0：失败*/

#define USB_CMD_ON_SFFC_MOULD                   0x52                /* 开启锅盖模板 */
#define USB_CMD_ON_SFFC_MOULD_STATUS            0x53                /* 返回开启锅盖模板状态 */
#define USB_CMD_GET_SFFC_MOULD                  0x54                /* 采集锅盖模板 */
#define USB_CMD_GET_SFFC_MOULD_STATUS           0x55                /* 返回采集锅盖模板状态 */
#define USB_CMD_SAVE_SFFC_MOULD                 0x56                /* 保存锅盖模板 */
#define USB_CMD_SAVE_SFFC_MOULD_STATUS          0x57                /* 返回保存锅盖模板状态 */
#define USB_CMD_OFF_SFFC_MOULD                  0x58                /* 关闭锅盖模板 */
#define USB_CMD_OFF_SFFC_MOULD_STATUS           0x59                /* 返回关闭锅盖模板状态 */

#define USB_CMD_AUTO_SWITCH_TEMP_GEAR           0x60                /* 自动切档开关控制 */

// #define USB_CMD_ON_SFFC_MOULD                   0x52                /* 开启锅盖模板 */
// #define USB_CMD_ON_SFFC_MOULD_STATUS            0x53                /* 返回开启锅盖模板状态 */
// #define USB_CMD_GET_SFFC_MOULD                  0x54                /* 采集锅盖模板 */
// // #define USB_CMD_GET_SFFC_MOULD_STATUS           //0x55                /* 返回采集锅盖模板状态 */
// #define USB_CMD_SAVE_SFFC_MOULD                 0x55//0x56                /* 保存锅盖模板 */
// // #define USB_CMD_SAVE_SFFC_MOULD_STATUS          //0x57                /* 返回保存锅盖模板状态 */
// #define USB_CMD_OFF_SFFC_MOULD                  0x56//0x58                /* 关闭锅盖模板 */
// // #define USB_CMD_OFF_SFFC_MOULD_STATUS           //0x59                /* 返回关闭锅盖模板状态 */

// #define USB_CMD_AUTO_SWITCH_TEMP_GEAR           0x57//0x60                /* 自动切档开关控制 */

/* AF相关参数包配置 */
#define USB_CMD_AF_PACK_DOWMLOAD				0x61     	        /* 导入AF参数包 */
#define USB_CMD_AF_PACK_DOWMLOAD_STATUS			0x62		        /* 返回AF导包状态 */
#define USB_CMD_AF_AUTO							0x63		        /* 自动对焦 */
#define USB_CMD_AF_SET_NEAR_FAR					0x64		        /* 粗调--> 0：近焦  1：远焦 */
#define USB_CMD_AF_SET_FINE_NEAR_FAR			0x65		        /* 细调--> 0：近焦  1：远焦 */
#define USB_CMD_AF_SET_STEP						0x66		        /* AF调焦步长设置  0：--   1：++ */
#define USB_CMD_AF_AUTO_SET_RUN_TIME			0x67		        /* AF单步步长时间设置 */
#define USB_CMD_AF_AUTO_SET_MAX_TIME_ADJ        0x68                /* AF全行程时间设置 */
#define USB_CMD_GET_AF_FULL_STROKE_PARAME       0x69                /* 获取AF全行程时间 */
#define USB_CMD_GET_AF_FULL_STROKE_STATUS       0x6A                /* 获取AF全行程时间状态 0：成功；1：失败 */

// #define USB_CMD_AF_PACK_DOWMLOAD				0x64     	        /* 导入AF参数包 */
// #define USB_CMD_AF_PACK_DOWMLOAD_STATUS			0x65		        /* 返回AF导包状态 */
// #define USB_CMD_AF_AUTO							0x66		        /* 自动对焦 */
// #define USB_CMD_AF_SET_NEAR_FAR					0x67		        /* 粗调--> 0：近焦  1：远焦 */
// #define USB_CMD_AF_SET_FINE_NEAR_FAR			0x68		        /* 细调--> 0：近焦  1：远焦 */
// #define USB_CMD_AF_SET_STEP						0x69		        /* AF调焦步长设置  0：--   1：++ */
// #define USB_CMD_AF_AUTO_SET_RUN_TIME			0x6B		        /* AF单步步长时间设置 */
// #define USB_CMD_AF_AUTO_SET_MAX_TIME_ADJ        0x6C                /* AF全行程时间设置 */

// #define USB_CMD_GET_AF_FULL_STROKE_PARAME       0x6A                /* 获取AF全行程时间 */

#define USB_CMD_GET_BL                          0x70                /* 采集BL */
#define USB_CMD_GET_BL_STATUS                   0x71                /* 返回采集BL状态 */
#define USB_CMD_GET_BH                          0x72                /* 采集BH */
#define USB_CMD_GET_BH_STATUS                   0x73                /* 返回采集BH状态  */
#define USB_CMD_CAL_K                           0x74                /* 计算K */
#define USB_CMD_CAL_K_STATUS                    0x75                /* 计算K返回状态 */
#define USB_CMD_SAVE_K                          0x76                /* 保存K */
#define USB_CMD_SAVE_K_STATUS                   0x77                /* 保存K返回状态 */
#define USB_CMD_LOAD_K                          0x78                /* 加载K */
#define USB_CMD_LOAD_K_STATUS                   0x79                /* 加载K返回状态 */
#define USB_CMD_INIT_K                          0x80                /* 初K */
#define USB_CMD_INIT_K_STATUS                   0x81                /* 初K返回状态 */
#define USB_CMD_UPLOAD_K                        0x82                /* 上传做K后的K矩阵 */
#define USB_CMD_UPLOAD_K_STATUS                 0x83                /* 返回上传做K后的K矩阵状态 */

#define USB_CMD_SET_ENV_CORR_SW					0x100               /* 环温修正开关 */
#define	USB_CMD_SET_LEN_CORR_SW					0x101               /* 镜筒温漂校正开关 */
#define USB_CMD_SET_SHUTTER_CORR_SW				0x102               /* 快门温漂校正开关 */
#define USB_CMD_SET_REFLECT_TEMP		        0x103               /* 设置反射温度 */
#define USB_CMD_SET_DISTANCE_CORR_SW			0x104               /* 距离补偿开关 */
#define USB_CMD_SET_LOW_LEN_COEFF				0x105               /* 常温档镜筒温漂修正系数 */
#define USB_CMD_SET_HIGH_LEN_COEFF				0x106               /* 高温档镜筒温漂修正系数 */
#define USB_CMD_SET_LOW_FAR_KF					0x107               /* 设置常温档远距离KF */
#define USB_CMD_SET_LOW_FAR_B					0x108               /* 设置常温档远距离B */
#define USB_CMD_SET_LOW_NEAR_KF					0x109               /* 设置常温档近距离KF */
#define USB_CMD_SET_LOW_NEAR_B					0x110               /* 设置常温档近距离B */
#define USB_CMD_SET_LOW_FAR_B2                  0x111               /* 设置二次校温低温档远距离B2 */
#define USB_CMD_SET_LOW_FAR_KF2                 0x112               /* 设置二次校温低温档远距离KF2 */
#define USB_CMD_SET_HIGH_FAR_KF					0x113               /* 设置高温档远距离KF */
#define USB_CMD_SET_HIGH_FAR_B					0x114               /* 设置高温档远距离B */
#define USB_CMD_SET_HIGH_NEAR_KF				0x115               /* 设置高温档近距离KF */
#define USB_CMD_SET_HIGH_NEAR_B					0x116               /* 设置高温档近距离B */
#define USB_CMD_SET_HIGH_FAR_B2                 0x117               /* 设置二次校温高温档远距离B2 */
#define USB_CMD_SET_HIGH_FAR_KF2                0x118               /* 设置二次校温高温档远距离KF2 */
#define USB_CMD_SET_TRANSMIT                    0x119               /* 设置透过率 */

#define USB_CMD_SET_TEMP_GEAR				    0x120               /* 设置测温范围 */

#define USB_CMD_SET_EMISS						0x121               /* 设置发射率 */
#define USB_CMD_SET_HUM							0x122               /* 设置湿度 */
#define USB_CMD_SET_DISTANCE					0x123               /* 设置距离 */
#define USB_CMD_SET_EMISS_CORR_SW				0x124               /* 发射率开关 */
#define USB_CMD_SET_TRANS_CORR_SW				0x125               /* 透过率开关 */
#define USB_CMD_SET_ENVIRON_TEMP				0x126	            /* 设置环境温度 */
#define USB_CMD_SET_AUTO_PARAM_TEMP1			0x127	            /* 设置自动校温温度1 */
#define USB_CMD_SET_AUTO_PARAM_TEMP2			0x128	            /* 设置自动校温温度2 */
#define USB_CMD_SET_AUTO_PARAM_TEMP3			0x129	            /* 设置自动校温温度3 */
#define USB_CMD_AUTO_PARAM_TEMP1_GET_Y16		0x130	            /* 自动校温温度1获取Y16 */
#define USB_CMD_AUTO_PARAM_TEMP2_GET_Y16		0x131	            /* 自动校温温度2获取Y16 */
#define USB_CMD_AUTO_PARAM_TEMP3_GET_Y16		0x132	            /* 自动校温温度3获取Y16 */
#define USB_CMD_AUTO_PARAM_PROC_START			0x133               /* 自动校温开始 */
#define USB_CMD_GET_AUTO_TEMP1_Y16_STATUS       0x134               /* 获取自动校温温度1Y16完成标志 */
#define USB_CMD_GET_AUTO_TEMP2_Y16_STATUS       0x135               /* 获取自动校温温度2Y16完成标志 */
#define USB_CMD_GET_AUTO_TEMP3_Y16_STATUS       0x136               /* 获取自动校温温度3Y16完成标志 */
#define USB_CMD_AUTO_TEMP_PARAM_STATUS		    0x137               /* 自动校温状态 */

#define USB_CMD_SET_HIGH_SHUTTER_CORRCOFF		0x138               /* 高温档快门温漂修正系数 */
#define USB_CMD_SET_LOW_SHUTTER_CORRCOFF		0x139               /* 低温档快门温漂修正系数 */

#define USB_CMD_SET_INT 						0x150               /* 设置探测器参数：Int */
#define USB_CMD_SET_GAIN 						0x151               /* 设置探测器参数：Gain */
#define USB_CMD_SET_RASEL 						0x152               /* 设置探测器参数：RASEL */
#define USB_CMD_SET_HSSD 						0x153               /* 设置探测器参数：HSSD */
#define USB_CMD_SET_NUC_STEP 					0x154               /* 设置探测器参数：NUC_STEP */
#define USB_CMD_SET_NUC_LOW 					0x155               /* 设置探测器参数：NUC_LOW */
#define USB_CMD_SET_NUC_HIGH 					0x156               /* 设置探测器参数：NUC_HIGH */
#define USB_CMD_SET_VSK_AD_LOW 					0x157               /* 设置探测器参数：VSK_AD_LOW */
#define USB_CMD_SET_VSK_AD_HIGH 			    0x158               /* 设置探测器参数：VSK_AD_HIGH */
#define USB_CMD_SET_VSK_THRESHOLD 				0x159               /* 设置探测器参数：VSK_THRESHOLD */
#define USB_CMD_SET_GPORNMOS 					0x160               /* 设置探测器参数：GPORNMOS */
#define USB_CMD_SET_GSTBEN 						0x161               /* 设置探测器参数：GSTBEN */
#define USB_CMD_SET_GSTBNUM 					0x162               /* 设置探测器参数：GSTBNUM */
#define USB_CMD_SET_REFPOLL 					0x163               /* 设置探测器参数：REFPOLL */
#define USB_CMD_SET_POLL 						0x164               /* 设置探测器参数：POLL */
#define USB_CMD_SET_GSK 						0x166               /* 设置探测器参数：GSK */
#define USB_CMD_SET_VCM 						0x167               /* 设置探测器参数：VCM */
#define USB_CMD_SET_VRD 						0x168               /* 设置探测器参数：VRD */
#define USB_CMD_SET_RDRC 						0x169               /* 设置探测器参数：RDRC */

#define USB_CMD_SET_AD_STEP 				    0x17A               /* 设置探测器参数：AD_STEP */

#define USB_CMD_GET_Y16_DATA 				    0x180               /* 获取一帧Y16数据 */
#define USB_CMD_GET_Y16_DATA_STATUS 		    0x181               /* 获取一帧Y16数据执行状态 */
#define USB_CMD_GET_PARAME_LINE_DATA 			0x182               /* 获取参数行数据 */
#define USB_CMD_GET_PARAME_LINE_DATA_STATUS     0x183               /* 获取参数行数据执行状态 */
#define USB_CMD_IMPORT_PSEUDO_INFO 	            0x184               /* 导入伪彩显示信息 */
#define USB_CMD_IMPORT_PSEUDO_INFO_STATUS       0x185               /* 导入伪彩显示信息执行状态 */
#define USB_CMD_EXPORT_PSEUDO_INFO 	            0x186               /* 导出伪彩显示信息 */
#define USB_CMD_EXPORT_PSEUDO_INFO_STATUS       0x187               /* 导出伪彩显示信息执行状态 */

#define USB_CMD_SET_FUSE_X_SHIFT                0x190               /* 设置融合：X偏移 */
#define USB_CMD_SET_FUSE_Y_SHIFT                0x191               /* 设置融合：Y偏移 */
#define USB_CMD_SET_FUSE_SCALING                0x192               /* 设置融合：放大倍数 */

#define USB_CMD_SET_BRIGHT 						0x200               /* 设置亮度 */
#define USB_CMD_SET_CONTRAST 					0x201               /* 设置对比度 */
#define USB_CMD_3DNR_RAW_SW					    0x202               /* 时域滤波开关 */
#define USB_CMD_SET_3DNR_RAW_PARAM			    0x203               /* 时域滤波参数配置 */
#define USB_CMD_FPNC_SW					        0x204               /* 去竖条纹开关 */
#define USB_CMD_SET_FPNC_PARAM			        0x205               /* 去竖条纹参数配置 */
#define USB_CMD_SET_DETAIL_ENHANCER_PARAM	    0x206               /* 细节增强参数配置 */
#define USB_CMD_SET_SHARPNESS_PARAM	            0x207               /* 锐度参数配置 */
#define USB_CMD_RFC_SW	                        0x208               /* 去横条纹开关 */
#define USB_CMD_2DNR_SW	                        0x209               /* 空域降噪开关 */
#define USB_CMD_SET_2DNR_PARAM	                0x210               /* 空域降噪参数配置 */

#define USB_CMD_SET_SCENE_MODE                  0x211               /* 设置场景模式 */


/*****************************************函数声明****************************************************/
#define  RINGBUFF_LEN          (4)  

typedef struct RingBuff
{
    u16 Head;           
    u16 Tail;
    u16 Lenght;
    u32  Ring_data[RINGBUFF_LEN];
}RingBuff_t;

extern RingBuff_t ringBuff;

s32 Write_RingBuff(u32 u32data);
void UsbLooping(void);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif
