

//REG MAP

    #define     APB_REG_NUM                             (0x0100)

    #define     APB_REG_ADDR_BASE1                      0xF1000000
    #define     APB_REG_ADDR_BASE2                      APB_M2
    #define     APB_REG_ADDR_MAX_RISV                   (APB_REG_NUM - 0x4)     //SIZE 1KB

    // 需要和RISCV部分对应
    #define     APB_REG_ADDR_VERSION0                   0x0000
    #define     APB_REG_ADDR_VERSION1                   0x0004
    #define     APB_REG_ADDR_TRF_DATALENS               0x0008          //搬运长度
    #define     APB_REG_IRQ_SEL                         0x000C

    #define     APB_REG_ADDR_AD_VALUE_AVERAGE_TOTAL     0x0010  //ad均值
    #define     APB_REG_ADDR_B_ADDRESS                  0x0014  //B地址
    #define     APB_REG_ADDR_K_ADDRESS                  0x0018  //K地址
    #define     APB_REG_ADDR_B_CAL                      0x001C  //计算B

    #define     APB_REG_TV_IIC_RW_REG                   0x0020  //
    #define     APB_REG_ADDR_FLASH_TRF_ADDR             0x0024  //搬运 flash基地址
    #define     APB_REG_ADDR_LENS_TEMP                  0x0028  //镜筒温
    #define     APB_REG_ADDR_SHUTTER_TEMP               0x002C  //快门温

    #define     APB_REG_ADDR_FPA_TEMP                   0x0030  //焦温
    #define     APB_REG_ADDR_SWITCH_RANGE               0x0034  //测温范围
    #define     APB_REG_ADDR_USB_ORDER                  0x0038  //解析usb指令
    #define     APB_REG_ADDR_EN_BUS0                    0x003C  //VISen等合集
    //I2C
    #define     APB_REG_ADDR_I2C_APB_BUS_D1             0x0040
    #define     APB_REG_ADDR_I2C_APB_BUS_C1             0x0044
    #define     APB_REG_ADDR_CALC_B_NUM                 0x0048
    #define     APB_REG_ADDR_DDR_TRF_ADDR               0x004C   //搬运DDR基地址

    #define     APB_REG_ADDR_RD_BUS0                    0x0050
    #define     APB_REG_ADDR_SENSOR_PARA0               0x0054

    #define     APB_REG_ADDR_SENSOR_PARA1               0x0058
    #define     APB_REG_ADDR_SENSOR_PARA2               0x005C
    #define     APB_REG_ADDR_SENSOR_PARA3               0x0060
    #define     APB_REG_ADDR_SENSOR_PARA4               0x0064
    #define     APB_REG_ADDR_SENSOR_PARA5               0x0068
    #define     APB_REG_ADDR_SENSOR_PARA6               0x006C
    #define     APB_REG_ADDR_SENSOR_PARA7               0x0070
    #define     APB_REG_ADDR_SENSOR_PARA8               0x0074
    #define     APB_REG_ADDR_SENSOR_PARA9               0x0078
    #define     APB_REG_ADDR_SENSOR_PARA10              0x007C

    #define     APB_REG_ADDR_SENSOR_PARA11              0x0080
    #define     APB_REG_ADDR_SENSOR_PARA12              0x0084
    #define     APB_REG_ADDR_SENSOR_PARA13              0x0088
    #define     APB_REG_ADDR_SENSOR_PARA14              0x008c
    #define     APB_REG_ADDR_SENSOR_PARA15              0x0090
    #define     APB_REG_ADDR_SENSOR_PARA16              0x0094
    #define     APB_REG_ADDR_SENSOR_PARA17              0x0098
    #define     APB_REG_ADDR_SENSOR_PARA18              0x009c
    #define     APB_REG_ADDR_SENSOR_PARA19              0x00a0
    #define     APB_REG_ADDR_SENSOR_PARA20              0x00a4

    #define     APB_REG_ADDR_SENSOR_PARA21              0x00a8
    #define     APB_REG_ADDR_SENSOR_PARA22              0x00ac
    #define     APB_REG_ADDR_SENSOR_PARA23              0x00b0
    #define     APB_REG_ADDR_SENSOR_PARA24              0x00b4
    #define     APB_REG_ADDR_SENSOR_PARA25              0x00b8
    #define     APB_REG_ADDR_SENSOR_PARA26              0x00bc
    #define     APB_REG_ADDR_SENSOR_PARA27              0x00c0
    #define     APB_REG_ADDR_SENSOR_PARA28              0x00c4

    #define     APB_REG_ADDR_CALC_LENS_TEMP             0x00d0      //计算后的镜筒温
    #define     APB_REG_ADDR_CALC_SHUTTER_TEMP          0x00d4      //计算后的快门温
    #define     APB_REG_ADDR_CALC_FPA_TEMP              0x00d8      //计算后的焦温