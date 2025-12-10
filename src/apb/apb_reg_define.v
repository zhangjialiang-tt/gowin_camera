`define     APB_AW                                  (16)
`define     APB_DW                                  (32)
`define     APB_REG_NUM                             ('h100 >> 2)

`define     APB_REG_ADDR_BASE1                      'hF100_0000
`define     APB_REG_ADDR_MAX_LOGIC                  ((`APB_REG_NUM-1) << 2)     //SIZE 64KB

`define     APB_REG_ADDR_VERSION0                   'h0000
`define     APB_REG_ADDR_VERSION1                   'h0004
`define     APB_REG_ADDR_TRF_DATALENS               'h0008
`define     APB_REG_IRQ_SEL                         'h000C

`define     APB_REG_ADDR_AD_VALUE_AVERAGE_TOTAL     'h0010      //AD均值
`define     APB_REG_ADDR_B_ADDRESS                  'h0014      //B地址
`define     APB_REG_ADDR_K_ADDRESS                  'h0018      //K地址
`define     APB_REG_ADDR_B_CAL                      'h001C      //计算B

`define     APB_REG_TV_IIC_RW_REG                   'h0020      //可见光配置数据和地址
`define     APB_REG_ADDR_FLASH_TRF_ADDR             'h0024      //
`define     APB_REG_ADDR_LENS_TEMP                  'h0028      //镜筒温
`define     APB_REG_ADDR_SHUTTER_TEMP               'h002C      //快门温

`define     APB_REG_ADDR_FPA_TEMP                   'h0030      //焦温
`define     APB_REG_ADDR_SWITCH_RANGE               'h0034      //测温范围
`define     APB_REG_ADDR_USB_ORDER                  'h0038      //解析USB指令  
//EN BUS
`define     APB_REG_ADDR_EN_BUS0                    'h003C
//I2C
`define     APB_REG_ADDR_I2C_APB_BUS_D1             'h0040
`define     APB_REG_ADDR_I2C_APB_BUS_C1             'h0044
`define     APB_REG_ADDR_CALC_B_NUM                 'h0048
`define     APB_REG_ADDR_DDR_TRF_ADDR               'h004C

`define     APB_REG_ADDR_RD_BUS0                    'h0050
`define     APB_REG_ADDR_SENSOR_PARA0               'h0054
`define     APB_REG_ADDR_SENSOR_PARA1               'h0058
`define     APB_REG_ADDR_SENSOR_PARA2               'h005C

`define     APB_REG_ADDR_SENSOR_PARA3               'h0060
`define     APB_REG_ADDR_SENSOR_PARA4               'h0064
`define     APB_REG_ADDR_SENSOR_PARA5               'h0068
`define     APB_REG_ADDR_SENSOR_PARA6               'h006C

`define     APB_REG_ADDR_SENSOR_PARA7               'h0070
`define     APB_REG_ADDR_SENSOR_PARA8               'h0074
`define     APB_REG_ADDR_SENSOR_PARA9               'h0078
`define     APB_REG_ADDR_SENSOR_PARA10              'h007C

`define     APB_REG_ADDR_SENSOR_PARA11              'h0080
`define     APB_REG_ADDR_SENSOR_PARA12              'h0084
`define     APB_REG_ADDR_SENSOR_PARA13              'h0088

`define     APB_REG_ADDR_SENSOR_PARA14              'h008c
`define     APB_REG_ADDR_SENSOR_PARA15              'h0090
`define     APB_REG_ADDR_SENSOR_PARA16              'h0094
`define     APB_REG_ADDR_SENSOR_PARA17              'h0098
`define     APB_REG_ADDR_SENSOR_PARA18              'h009c
`define     APB_REG_ADDR_SENSOR_PARA19              'h00a0
`define     APB_REG_ADDR_SENSOR_PARA20              'h00a4

`define     APB_REG_ADDR_SENSOR_PARA21              'h00a8
`define     APB_REG_ADDR_SENSOR_PARA22              'h00ac
`define     APB_REG_ADDR_SENSOR_PARA23              'h00b0
`define     APB_REG_ADDR_SENSOR_PARA24              'h00b4
`define     APB_REG_ADDR_SENSOR_PARA25              'h00b8
`define     APB_REG_ADDR_SENSOR_PARA26              'h00bc
`define     APB_REG_ADDR_SENSOR_PARA27              'h00c0
`define     APB_REG_ADDR_SENSOR_PARA28              'h00c4

`define     APB_REG_ADDR_CALC_LENS_TEMP             'h00d0      //计算后的镜筒温
`define     APB_REG_ADDR_CALC_SHUTTER_TEMP          'h00d4      //计算后的快门温
`define     APB_REG_ADDR_CALC_FPA_TEMP              'h00d8      //计算后的焦温