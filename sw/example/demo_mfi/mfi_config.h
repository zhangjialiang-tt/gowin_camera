// ================================================================================
// MFi Configuration Header
// MFi产品身份参数配置（基于RTL硬件配置 - top.v/usb_top.v）
// ================================================================================

#ifndef MFI_CONFIG_H
#define MFI_CONFIG_H

#define ZC23A

// ================================================================================
// 应用Bundle ID和协议字符串
// ⚠️ 关键修复：必须与RTL RAM中实际存储的数据完全一致
// 通过分析dpb_mfi.v的INIT_RAM_27，发现App Launch使用的是缩短版本
// ================================================================================
#define MFI_EAP_APPBUNDLE_ID         "com.guide.ZX01A"          // ✅ 修正：与RTL RAM一致（15字节）
#define MFI_EAP_INTERFACE_STRING     "com.guidesensmart.ZX10A"  // Identification用（23字节）
#define MFI_PROTOCOL_STRING          "com.guidesensmart.ZX10A"  // USB描述符用（23字节）

// ================================================================================
// USB描述符配置（来自usb_top.v和top.v的参数定义）
// 注意：这些参数必须与USB描述符中的配置完全一致
// ================================================================================

#ifdef ZC23A
    // ZC23A产品配置
    #define MFI_USBD_PRODUCT_STRING      "ZX10A"//"EyeSearch 2"
    #define MFI_USBD_SERIALNUMBER_STRING "ZX01A19"//"EyeSearch 2"
    #define MFI_FIRMWARE_VERSION         "1.0.0"
#else
    // ZC23A+产品配置
    #define MFI_USBD_PRODUCT_STRING      "EyeSearch 2+"
    #define MFI_USBD_SERIALNUMBER_STRING "EyeSearch 2+"
    #define MFI_FIRMWARE_VERSION         "2.02"
#endif

// ================================================================================
// 厂商信息
// ================================================================================
#define MFI_USBD_MANUFACTURER_STRING "Wuhan Guide Infrared Co., Ltd."

// ================================================================================
// 版本和认证信息
// ================================================================================
#define MFI_HARDWARE_VERSION         "1.0"
#define MFI_TEAM_ID                  "NPB7U33WX7"
#define MFI_LANGUAGE                 "en"

// ================================================================================
// USB厂商/产品ID（来自usb_descriptor模块）
// ================================================================================
#define MFI_USB_VENDOR_ID            0x0525
#define MFI_USB_PRODUCT_ID           0xA4A0
#define MFI_USB_VERSION_BCD          0x0201

// ================================================================================
// 重要说明：
// 1. MFI_EAP_APPBUNDLE_ID 基于 SERIALSTR6 参数
// 2. MFI_PROTOCOL_STRING 必须与iOS应用Info.plist中的
//    UISupportedExternalAccessoryProtocols 数组项完全匹配
// 3. 产品字符串和序列号根据ZC23A宏定义自动选择
// 4. 固件版本号对应VERSIONBCD参数（0x0201 = "2.01"）
// ================================================================================

#endif // MFI_CONFIG_H
