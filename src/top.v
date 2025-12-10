`include "sdram_port_arb/defin_sdram_port.v"
`include "apb/apb_reg_define.v"
//256 ir sensor 模组开窗信息 
//暂定 mc -->6M
//帧率 -->25HZ
//IR sensor 上电时序 DVDD --> AVDD -->VDET  硬件板子DVDD直接上电
// `define                                 ZC23A 
// `define                                 CH_Z 
// `define                                 UART_REUSE 
`define                                 NEORV32 
`ifndef ZC23A
    `define                                 TV_YUV420
`endif
module top
(
    input                                   i_clk               ,   //24M clk

    // IR sensor    
    input                                   i_sensor_pclk       ,
    input                                   i_vs                ,
    input                                   i_hs                ,
    input           [7:0]                   i_data              ,
    output                                  o_sensor_reset      ,
    output                                  o_sensor_avdd       ,
    output                                  o_sensor_vdet       ,
    inout                                   io_sensor_iic_scl   ,
    inout                                   io_sensor_iic_sda   ,
    output                                  o_addrx             ,
    output                                  o_sleep             ,
    output                                  o_sensor_mc         ,
    
    // USB
    input                                   i_usb_dxp           ,
    input                                   i_usb_dxn           ,
    output                                  o_usb_dxp           ,
    output                                  o_usb_dxn           ,
    input                                   i_usb_rxdp          ,
    input                                   i_usb_rxdn          ,
    output                                  o_usb_pullup_en     ,
    inout                                   io_usb_term_dp      ,
    inout                                   io_usb_term_dn      ,
    // MFI 芯片             
    inout                                   io_mfi_iic_scl      ,
    inout                                   io_mfi_iic_sda      ,
             
    //shutter
    output                                  o_shutter_gpioa     ,
    output                                  o_shutter_gpiob     ,

    inout                                  io_temp_iic_scl     , 
    inout                                  io_temp_iic_sda     , 
    // UART0--PRINT
    output wire                             print_uart_0_io_txd ,
    input  wire                             print_uart_0_io_rxd ,
    // spi-flash
    output                                  O_flash_cs_n        ,
    output                                  O_flash_ck          ,
    inout                                   IO_flash_do         ,
    output                                  IO_flash_di         ,
    //VIS-Light
        //ctrl
    output                                  o_cif_xclk          , // mclk
    output                                  o_cif_pwr_en        , // avdd
    output                                  o_cif_pwdn          , // pwrd
    output                                  o_cif_rst           , // rst
    //i2c
    inout                                   io_cif_iic_scl      ,
    inout                                   io_cif_iic_sda      ,
    //DVP
    input                                   i_tv_pclk           ,
    input           [7:0]                   i_tv_data           ,
    input                                   i_tv_hsync          ,
`ifdef UART_REUSE
    output                                  i_tv_vsync          ,
`else
    input                                   i_tv_vsync          ,
`endif

    //sdram
    output                                  O_sdram_clk         ,
    output                                  O_sdram_cke         ,
    output                                  O_sdram_cs_n        ,
    output                                  O_sdram_cas_n       ,
    output                                  O_sdram_ras_n       ,
    output                                  O_sdram_wen_n       , 
    output     [3:0]                        O_sdram_dqm         ,
    output     [10:0]                       O_sdram_addr        , 
    output     [1:0]                        O_sdram_ba          ,
    inout      [31 :0]                      IO_sdram_dq           
);
    
    localparam IR_IMAGE_WIDE_LENGTH = 256    ;
    localparam IR_IMAGE_HIGH_LENGTH = 192    ;
    localparam IR_IMAGE_TOTAL_LENGTH= IR_IMAGE_WIDE_LENGTH * IR_IMAGE_HIGH_LENGTH   ;

    localparam PSRAM_ADDRS_DW       = 21     ;
    localparam IR_DW                = 16     ; 

    localparam TV_IMAGE_WIDE_LENGTH = 800    ;
    localparam TV_IMAGE_HIGH_LENGTH = 600    ;
    localparam TV_IMAGE_LENGTH_420 = TV_IMAGE_WIDE_LENGTH*(TV_IMAGE_HIGH_LENGTH/2+TV_IMAGE_HIGH_LENGTH/4);
    localparam PARAM_LENGTH = 224+256+192;

    localparam IR_Y16_ADDRS0        = 'h66000;
    localparam IR_Y16_ADDRS1        = 'h6c000;
    localparam IR_Y16_ADDRS2        = 'h72000;

    localparam TV_ADDRS0            = 'h78000;
    localparam TV_ADDRS1            = 'hB2980;
    localparam TV_ADDRS2            = 'hED300;

//  clock
wire                                                    sensor_mc                           ;   //6M 
wire                                                    sensor_mc_oe                        ;

wire                                                    usb_fclk                            ;   //480M
wire                                                    usb_user_clk                        ;   //60M   
wire                                                    usb_pll_locked                      ;  

wire                                                    sdram_clk                           ;   //150M
wire                                                    sdrc_clk                            ;   //150M  phase 22.5
wire                                                    clk_1m                              ;   //1M
wire                                                    sdram_locked                        ;
wire                                                    clk_display                         ;   //30M
wire                                                    clk_pixe                            ;
//reset                         
wire                                                    rst_n                               ; //全局复位
wire                                                    apb_irq_arb_rst_n                   ;

wire                        [15:0]                      temp_sensor                         ;
wire                        [15:0]                      temp_shutter                        ;
wire                        [15:0]                      temp_lens                           ;

wire                        [15:0]                      calc_temp_sensor                    ;
wire                        [15:0]                      calc_temp_shutter                   ;
wire                        [15:0]                      calc_temp_lens                      ;

wire                                                    ir_freeze                           ;
wire                        [1:0]                       ir_fcnt                             ;

wire                        [3:0]                       temp_range                          ;
wire                                                    shutter_state                       ;  
wire                        [15:0]                      temp_shutter_start                  ;
wire                        [15:0]                      temp_lens_start                     ;
wire                        [15:0]                      temp_shutter_pre                    ;
wire                        [15:0]                      temp_sensor_pre                     ;
wire                        [15:0]                      temp_lens_pre                       ;

wire                        [15:0]                      usb_cmd                             ;
wire                        [15:0]                      usb_data                            ;
wire                                                    usb_cmd_en                          ;
wire                                                    usb_cmd_flag                        ;
//---sensor
wire                        [IR_DW-1:0]                 x16_data                            ;
wire                                                    x16_hs                              ;
wire                                                    x16_vs                              ;
wire                        [IR_DW-1:0]                 x16_data_mean                       ;
wire                        [IR_DW-1:0]                 center_x16_data                     ;
wire                        [IR_DW-1:0]                 center_y16_data                     ;
wire                        [IR_DW-1:0]                 calc_b_mean_data                     ;
wire                        [IR_DW-1:0]                 sub_aver_y16                        ;

wire                        [7:0]                       clac_b_mean_num                     ;
wire                                                    calc_b_en                           ;
wire                        [PSRAM_ADDRS_DW-1:0]        b_addrs                             ;
wire                                                    clac_b_done                         ;
wire                        [3:0]                       y16_data_sel                        ;
wire                        [PSRAM_ADDRS_DW-1:0]        k_addrs                             ;
wire                                                    init_k_load                         ; 
wire                                                    bp_type                             ;
wire                        [IR_DW-1:0]                 y16_data                            ;
wire                                                    y16_hs                              ;
wire                                                    y16_vs                              ;
// arm-core lock test
wire                core_lock_flag;
reg                 core_lock_flag_pre;
//---apb
wire                apbSlave_1_PCLK          ;
wire                apbSlave_1_PRESET        ;
wire    [32-1:0]    apbSlave_1_PADDR         ;
wire                apbSlave_1_PSEL          ;
wire                apbSlave_1_PENABLE       ;
wire                apbSlave_1_PWRITE        ;
wire    [32-1:0]    apbSlave_1_PWDATA        ;
wire                apbSlave_1_PREADY        ;
wire    [32-1:0]    apbSlave_1_PRDATA        ;
wire                apbSlave_1_PSLVERROR     ;
wire    [4-1:0]     apbSlave_1_PSTRB         ;
wire    [2:0]       apbSlave_1_PROT          ;
//---gpio
wire    [15:0]      gpiobus_io_en       ;
wire    [15:0]      gpiobus_io          ;
reg     [7:0]       gpiobus_i_regs      ;
reg     [7:0]       gpiobus_o_regs      ;

//---display
wire      [15:0]                usb_head_data                   ;
wire                            usb_head_data_vld               ;
wire                            usb_head_data_req               ;
wire      [15:0]                usb_ir_data                     ;
wire                            usb_ir_data_vld                 ;
wire                            usb_ir_data_ready               ;
wire                            usb_ir_data_req                 ;
wire      [15:0]                usb_tv_data                     ;
wire                            usb_tv_data_vld                 ;
wire                            usb_tv_data_req                 ;
wire                            usb_tv_data_ready               ;
wire      [15:0]                usb_param_data                  ;
wire                            usb_param_data_vld              ;
wire                            usb_param_req                   ;
wire                            usb_start                       ;

wire                            mem_ir_start                    ;   
wire       [20:0]               mem_ir_addrs                    ;     
wire       [31:0]               mem_ir_length                   ; 

wire                            mem_tv_start                    ;    
wire       [20:0]               mem_tv_addrs                    ;    
wire       [31:0]               mem_tv_length                   ; 


wire                            mem_wr0_start                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_wr0_addrs                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_wr0_lengths                 ; 
wire       [IR_DW-1:0]          mem_wr0_data                    ; 
wire                            mem_wr0_data_vld                ;

wire                            mem_wr1_start                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr1_addrs                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr1_lengths                 ;
wire       [IR_DW-1:0]          mem_wr1_data                    ;
wire                            mem_wr1_data_vld                ;
//K
wire                            mem_wr2_start                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr2_addrs                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr2_lengths                 ;
wire       [IR_DW-1:0]          mem_wr2_data                    ;
wire                            mem_wr2_data_vld                ;

wire                            mem_wr3_start                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr3_addrs                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr3_lengths                 ;
wire       [IR_DW-1:0]          mem_wr3_data                    ;
wire                            mem_wr3_data_vld                ;

wire                            mem_wr4_start                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr4_addrs                   ;
wire       [PSRAM_ADDRS_DW-1:0] mem_wr4_lengths                 ;
wire       [IR_DW-1:0]          mem_wr4_data                    ;
wire                            mem_wr4_data_vld                ;

wire                            mem_rd0_start                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_rd0_addrs                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_rd0_lengths                 ; 
wire       [IR_DW-1:0]          mem_rd0_data                    ; 
wire                            mem_rd0_data_req                ; 

wire                            mem_rd1_start                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_rd1_addrs                   ; 
wire       [PSRAM_ADDRS_DW-1:0] mem_rd1_lengths                 ; 
wire       [IR_DW-1:0]          mem_rd1_data                    ; 
wire                            mem_rd1_data_req                ; 
//sdram 3_rd 复用通道
wire                            mem_rd3_start                   ;
wire        [PSRAM_ADDRS_DW-1:0]mem_rd3_addrs                   ;
wire        [31:0]              mem_rd3_lens                    ;
wire                            mem_rd3_data_req                ;
wire                            mem_rd3_data_vld                ;
wire        [15:0]              mem_rd3_data                    ;
wire                            mem_rd3_data_ready              ;
//-------------------------------------------------------------------
//升级mem通道
wire                            rd_1_req                ; 
wire                            rd_1_data_vld           ;
wire       [IR_DW-1:0]          rd_1_data               ; 

wire                            flash_update_data_req           ; 
wire                            flash_update_data_vld           ;
wire       [IR_DW-1:0]          flash_update_data               ; 
wire        [PSRAM_ADDRS_DW-1:0]flash_update_addrs              ;

//apb
wire       [31:0]               i2c_apb_bus                     ; 
wire       [31:0]               apb_en_bus0                     ; 

//i2c-apb
wire       [31:0]               i2c_apb_bus_d1                  ;
wire       [31:0]               i2c_apb_bus_c1                  ;

wire       [31:0]               irq_ack                         ;
wire       [31:0]               irq_sel                         ;
wire                            ir_init_done                    ;  


wire        [31:0]              program_version0                ;
wire        [31:0]              program_version1                ;

reg                             tv_hsync_dly                    ;   
reg                             tv_vsync_dly                    ;
reg        [7:0]                tv_data_dly                     ;

wire       [15:0]               tv_yuv422_data                  ;
wire                            tv_yuv422_hsync                 ;
wire                            tv_yuv422_vsync                 ;
wire       [1:0]                tv_fcnt                         ;

wire        [31:0]              iic_reg_ctrl                    ;
wire        [31:0]              iic_reg_addrsdata               ;
wire                            iic_update                      ;

wire        [31:0]              mem_addrs                       ;
wire        [31:0]              flash_addrs                     ;
wire        [31:0]              flash_data_lens                 ;
wire        [31:0]              risv_rd_bus0                    ;
wire        [31:0]              risv_wr_bus0                    ;

wire                            param_load                      ;
wire                            flash2ddr_load                  ;
wire        [15:0]              flash_rd_data                   ;    
wire                            flash_rd_data_vld               ;
wire        [31:0]              param_rd_apb32bus0              ;
wire        [31:0]              param_wr_apb32bus0              ;
wire                            sensor_update_param             ;
wire        [15:0]              param_ddr_rd_data               ;    
wire                            param_ddr_rd_data_vld           ;
wire                            param_ddr_rd_data_ready         ;

wire                            mem_wr_flash_start              ;
wire        [31:0]              mem_wr_flash_addrs              ;
wire        [31:0]              mem_wr_flash_lens               ;
wire                            trigger_pos_15                  ;
//neorv32

wire [31:0] gpio_o_bus;
wire [31:0] gpio_i_bus;
wire twi_sda_i;
wire twi_scl_i;
wire twi_sda_o;
wire twi_scl_o;
// XBUS wires (internal connections)
wire [31:0] xbus_adr;
wire [31:0] xbus_dat_o_int;
wire [31:0] xbus_dat_i_int;
wire [ 2:0] xbus_cti;
wire [ 2:0] xbus_tag;
wire        xbus_we;
wire [ 3:0] xbus_sel;
wire        xbus_stb;
wire        xbus_cyc;
wire        xbus_ack_i;
wire        xbus_err_i;
// WB_MUX wires
wire [31:0] wbs0_adr;
wire [31:0] wbs0_dat_i;
wire [31:0] wbs0_dat_o;
wire        wbs0_we;
wire [ 3:0] wbs0_sel;
wire        wbs0_stb;
wire        wbs0_ack;
wire        wbs0_err;
wire        wbs0_rty;
wire        wbs0_cyc;

wire [31:0] wbs1_adr;
wire [31:0] wbs1_dat_i;
wire [31:0] wbs1_dat_o;
wire        wbs1_we;
wire [ 3:0] wbs1_sel;
wire        wbs1_stb;
wire        wbs1_ack;
wire        wbs1_err;
wire        wbs1_rty;
wire        wbs1_cyc;
//usb-cmd
wire hw_update_en; // 升级标志位
wire update_temp_range; // 升级测温包类型。影响保存地址。1:H 0:L
wire [31:0] update_lens; //参数包升级大小
wire [31:0] flash_update_addr; //参数包升级地址
wire [31:0] mem_update_addrs;  //升级地址

wire usb_update_vld;  // usb升级有效
wire [7:0] usb_update_data; // usb升级数据
wire [31:0] usb_update_lens; // usb升级参数包长度
wire [7:0]  update_type;
wire [7:0]  cmd_data;

wire flash_update_en; // 升级标志位- mem写完成，开始读
wire flash_up_start ; // 升级标志位= flash开始写
wire flash_st_idel; // flash空挡
wire ddr2flash_status;

wire                           flash_rd_en;
wire                           ddr_rd_start ;
wire                           ddr_rd_en    ;
wire                           mcu_en            ;// 
wire   [31:0]                  mcu_flash_addrs   ;
wire   [31:0]                  mcu_ddr_addrs     ;
wire                           mcu_option        ;// 0读flash 1写
wire   [31:0]                  mcu_lens          ;
wire   [3:0]                   mcu_ctrl_sel      ;// 
wire                           read_low_en;
wire                           read_high_en;
wire                           temp_rd_flash_ctrl_en;
wire                           send_done_pulse;

wire   [  15: 0]               int_set             ;
wire   [  15: 0]               gain                ;
wire   [  15: 0]               gsk_ref             ;
wire   [  15: 0]               gsk                 ;
wire   [  15: 0]               vbus                ;
wire   [  15: 0]               vbus_ref            ;
wire   [  15: 0]               rd_rc               ;
wire   [  15: 0]               gfid                ;
wire   [  15: 0]               csize               ;
wire   [  15: 0]               occ_value           ;
wire   [  15: 0]               occ_step            ;
wire   [  15: 0]               occ_thres_up        ;
wire   [  15: 0]               occ_thres_down      ;
wire   [  15: 0]               ra                  ;
wire   [  15: 0]               ra_thres_high       ;
wire   [  15: 0]               ra_thres_low        ;
wire   [  15: 0]               raadj               ;
wire   [  15: 0]               raadj_thres_high    ;
wire   [  15: 0]               raadj_thres_low     ;
wire   [  15: 0]               rasel               ;
wire   [  15: 0]               rasel_thres_high    ;
wire   [  15: 0]               rasel_thres_low     ;
wire   [  15: 0]               hssd                ;
wire   [  15: 0]               hssd_thres_high     ;
wire   [  15: 0]               hssd_thres_low      ;
wire   [  15: 0]               gsk_thres_high      ;
wire   [  15: 0]               gsk_thres_low       ;
wire   [  15: 0]               nuc_step            ;

wire   [  15: 0]               ShutterCorVal       ;
wire   [  15: 0]               shutterCorCoef      ;
wire   [  15: 0]               LensCorVal          ;
wire   [  15: 0]               LensCorCoef         ;
wire   [  15: 0]               Compensate_flag     ;
wire   [  15: 0]               Emiss_Humidy        ;//湿度 发射率
wire   [  15: 0]               EnTemp_Distance     ;//距离 环境温度
wire   [  15: 0]               Transs              ;//透过率
wire   [  15: 0]               near_kf             ;
wire   [  15: 0]               near_b              ;
wire   [  15: 0]               far_kf              ;
wire   [  15: 0]               far_b               ;
wire   [  15: 0]               pro_kf              ;
wire   [  15: 0]               pro_b               ;
wire   [  15: 0]               pro_kf_far          ;
wire   [  15: 0]               pro_b_far           ;
wire   [  15: 0]               reflectTemp         ; 
wire   [  15: 0]               x_fusion_offset     ;
wire   [  15: 0]               y_fusion_offset     ;
wire   [  15: 0]               fusion_amp_factor   ;

wire                           read_temp_en        ;
wire                           write_temp_en       ;
wire                           read_guogai_en      ;
wire                           flash_done          ;
wire    [  31: 0]              temp_param_out      ;
wire                           temp_param_valid    ;
wire                           temp_param_req      ;

parameter                      PARAM_L_LENGTH    = 748558;
parameter                      PARAM_H_LENGTH    = 885758;
parameter                      PARAM_L_TOTAL_LEN= ((PARAM_L_LENGTH >> 14) + 1) << 14;
parameter                      PARAM_H_TOTAL_LEN= ((PARAM_H_LENGTH >> 14) + 1) << 14;
parameter                      PARAM_L_ADDR     = 32'h127C80;
parameter                      PARAM_H_ADDR     = 32'h183290;//1EF490
parameter                      GUOGAI_ADDR      = 32'h1EF490;
//update----------------------
// assign update_lens = (cmd_data == 2)? 32'd633146 : 32'd535146;//316573   316672   267573    267776 
// assign update_lens = (cmd_data == 2)? 32'd633200 : 32'd535200;//267600
assign update_lens = read_guogai_en ? IR_IMAGE_TOTAL_LENGTH * 2 : (read_high_en)? 32'd885800 : 32'd748600;//267600
//sdram
// assign mem_update_addrs   = PARAM_L_ADDR;
assign mem_update_addrs   = read_guogai_en ? GUOGAI_ADDR : (read_high_en) ? PARAM_H_ADDR : PARAM_L_ADDR;
//flash635146-
// assign  update_temp_range = update_type == 8'h39 ? 1 : 0;
assign flash_update_addr =  (update_type == 8'h07 )?    32'h0000000 :
                            (update_type == 8'h56 )?    32'h0310000 :
                            (update_type == 8'h38 || (cmd_data == 1))?    'h100000 : 'h200000;
//L: 216 + 1400 + 5 * 2 + 2 * 5 * 2100 * 2 + 5 * 256 * 192 * 2 = 535146 527978
//H: 216 + 1400 + 5 * 2 + 2 * 5 * 7000 * 2 + 5 * 256 * 192 * 2 = 633146

//K
wire loadK_en;//加载K使能
wire [15:0] apb_K_lengths;//K长度（全部）
// assign mem_wr2_addrs    = k_addrs  ;
// assign mem_wr2_lengths  = apb_K_lengths;
//apb
// assign hw_update_en         = apb_en_bus0[1];
// assign update_temp_range    = apb_en_bus0[2];
// assign loadK_en             = apb_en_bus0[3];

//
clkdiv4 clkdiv4_ir_mc_inst(
        .clkout                                 (sensor_mc),  //output clkout   6M
        .hclkin                                 (i_clk    ),  //input hclkin    24M
        .resetn                                 (1'b1     )   //input resetn
    );

usb_pll usb_pll_inst(
        .clkout                                 (usb_fclk           ), //output clkout  480M
        .lock                                   (usb_pll_locked     ), //output lock
        .clkoutd                                (usb_user_clk       ), //output clkoutd 60M
        .clkin                                  (i_clk              ) //input clkin     24M
    );

sdram_pll sdram_pll_inst(
        .clkout                                 (sdram_clk          ), //output clkout      150M (demo-->166M)
        .lock                                   (sdram_locked       ), //output lock
        .clkoutp                                (sdrc_clk           ), //output clkoutp     150M  phase 22.5 (demo-->166M)
        // .clkoutd                                (clk_1m             ), //output clkoutd     1M
        .clkin                                  (i_clk              ) //input clkin         24M
    );

// clkdiv2 clkdiv2_ir_30m_inst(
//         .clkout                                 (clk_display        ),  //output clkout   30M
//         .hclkin                                 (usb_user_clk       ),  //input hclkin    60M
//         .resetn                                 (1'b1               )   //input resetn
//     );
    assign clk_display = usb_user_clk;
//APB 控制上电时序
//TV 
assign o_cif_xclk      = (apb_en_bus0[31] == 1'b0)? 1'b0 : i_clk    ;
assign o_cif_pwr_en    = (apb_en_bus0[30] == 1'b0)? 1'b0 : 1'b1     ; 
assign o_cif_pwdn      = (apb_en_bus0[29] == 1'b0)? 1'b1 : 1'b0     ;
assign o_cif_rst       = (apb_en_bus0[28] == 1'b0)? 1'b0 : 1'b1     ;
//IR
assign o_sensor_reset  = (apb_en_bus0[27] == 1'b0)? 1'b0 : 1'b1     ;
assign o_sensor_avdd   = (apb_en_bus0[26] == 1'b0)? 1'b0 : 1'b1     ;
assign o_sensor_vdet   = (apb_en_bus0[25] == 1'b0)? 1'b0 : 1'b1     ;
assign o_addrx         = (apb_en_bus0[24] == 1'b0)? 1'b0 : 1'b1     ;
assign o_sleep         = (apb_en_bus0[23] == 1'b0)? 1'b1 : 1'b0     ;
assign o_sensor_mc     = (apb_en_bus0[22] == 1'b0)? 1'b0 : sensor_mc;

// assign o_sensor_reset  = 1'b0;
// assign o_sensor_avdd   = 1'b0;
// assign o_sensor_vdet   = 1'b0;
// assign o_addrx         = 1'b0;
// assign o_sleep         = 1'b1;
// assign o_sensor_mc     = 1'b0;

assign clk_pixe        = i_sensor_pclk                              ;
assign ir_freeze       = apb_en_bus0[21]                            ;
assign init_k_load     = apb_en_bus0[19]                            ;
// assign init_k_load     = 1                            ;
//reset
gen_reset 
#(
    .RST_TIME                                   (63  )               ,           
    .DW                                         (2   )                           
)
gen_reset_inst
(
    .i_clk           (i_clk                             ),        //input                   
    .i_rst_n         (1'b1                              ),        //input                   
    .i_locked        ({usb_pll_locked,sdram_locked}     ),        //input       [DW-1:0]    
    .o_rst_n         (rst_n                             )         //output  reg                      

);
//TV
always @(posedge i_tv_pclk ) begin
    tv_hsync_dly <= i_tv_hsync;
`ifndef UART_REUSE
    tv_vsync_dly <= i_tv_vsync;
    tv_data_dly  <= i_tv_data ;
`endif
end
reg           [ 16  - 1 : 0 ]          dbg_tv_data               ;
reg           [  1  - 1 : 0 ]          dbg_tv_flag               ;
always @(posedge i_tv_pclk ) begin
    if(!rst_n)begin
        dbg_tv_flag <= 0;
        dbg_tv_data <= 0;
    end else if(tv_vsync_dly)begin
        if(tv_hsync_dly) begin
            dbg_tv_flag <= ~dbg_tv_flag;
            dbg_tv_data <= dbg_tv_data + 1;
        end else begin
            dbg_tv_flag <= dbg_tv_flag;
            dbg_tv_data <= dbg_tv_data;
        end
    end else begin
        dbg_tv_flag <= 0;
        dbg_tv_data <= 0;
    end
end

//yuv422 8bit to 16bit
//[Y][V][Y][U][Y][V][Y][U] --> [VY][UY][VY][UY]
`ifdef TV_YUV420
yuv422_to_nv12_converter # (
    .IMG_WIDTH(TV_IMAGE_WIDE_LENGTH),
    .IMG_HEIGHT(TV_IMAGE_HIGH_LENGTH)
  )
  yuv422_to_nv12_converter_inst (
    .i_clk                (i_tv_pclk         ),
    .i_rst_n              (rst_n             ),
    .i_data               (tv_data_dly       ),//dbg_tv_data       ),//tv_data_dly       ),
    .i_hsync              (tv_hsync_dly      ),
    .i_vsync              (tv_vsync_dly      ),
    .i_addrs0             (TV_ADDRS0         ),
    .i_addrs1             (TV_ADDRS1         ),
    .i_addrs2             (TV_ADDRS2         ),
    .o_fcnt               (tv_fcnt           ),
    .o_mem_y_wr_start     (mem_wr3_start     ),
    .o_mem_y_wr_addrs     (mem_wr3_addrs     ),
    .o_mem_y_wr_lengths   (mem_wr3_lengths   ),
    .o_mem_y_wr_data      (mem_wr3_data      ),
    .o_mem_y_wr_data_vld  (mem_wr3_data_vld  ),
    .o_mem_uv_wr_start    (mem_wr4_start     ),
    .o_mem_uv_wr_addrs    (mem_wr4_addrs     ),
    .o_mem_uv_wr_lengths  (mem_wr4_lengths   ),
    .o_mem_uv_wr_data     (mem_wr4_data      ),
    .o_mem_uv_wr_data_vld (mem_wr4_data_vld  ),
    .o_frame_done         (                  )
  );
`elsif TV_YUV422
//yuv422 8bit to 16bit
//[Y][V][Y][U][Y][V][Y][U] --> [VY][UY][VY][UY]
tv2yuv422 tv2yuv422_inst (
    .i_clk           (i_tv_pclk         ),    //input                   
    .i_rst_n         (rst_n             ),    //input                   
    .i_data          (tv_data_dly       ),    //input       [7:0]       
    .i_hsync         (tv_hsync_dly      ),    //input                   
    .i_vsync         (tv_vsync_dly      ),    //input                   
    .o_data          (tv_yuv422_data    ),    //output reg  [15:0]      
    .o_hsync         (tv_yuv422_hsync   ),    //output reg              
    .o_vsync         (tv_yuv422_vsync   )     //output reg               
);

data_mem_wr_ctrl #(
    .IMAGE_WIDE_LENGTH (TV_IMAGE_WIDE_LENGTH    )    ,
    .IMAGE_HIGH_LENGTH (TV_IMAGE_HIGH_LENGTH    )    ,
    .ADDRS_DW          (PSRAM_ADDRS_DW          )    ,
    .DW                (IR_DW                   )   
)data_mem_wr_ctrl_tv_inst (
    .i_rst_n             (rst_n                 ),        //input                           
    .i_clk               (i_tv_pclk             ),        //input                           
    .i_freeze_en         (1'b0                  ),        //input                           
    .i_addrs0            (TV_ADDRS0             ),        //input   [ADDRS_DW-1:0]          
    .i_addrs1            (TV_ADDRS1             ),        //input   [ADDRS_DW-1:0]          
    .i_addrs2            (TV_ADDRS2             ),        //input   [ADDRS_DW-1:0]          
    .i_data              (tv_yuv422_data        ),        //input   [DW-1:0]                
    .i_hs                (tv_yuv422_hsync       ),        //input                           
    .i_vs                (tv_yuv422_vsync       ),        //input                           
    .o_fcnt              (tv_fcnt               ),        //output  reg [1:0]               
    .o_mem_wr_start      (mem_wr3_start         ),        //output  reg                     
    .o_mem_wr_addrs      (mem_wr3_addrs         ),        //output  reg [ADDRS_DW - 1 : 0]  
    .o_mem_wr_lengths    (mem_wr3_lengths       ),        //output      [ADDRS_DW - 1 : 0]  
    .o_mem_wr_data       (mem_wr3_data          ),        //output  reg [DW - 1 : 0]        
    .o_mem_wr_data_vld   (mem_wr3_data_vld      )         //output  reg                     

);
`endif

//IR
temp_rd_top #(
    .CLK_IN_FREQ (6_000_000)           //MAX 16M
)
temp_rd_top_inst
(
    .i_mc                    (sensor_mc         ),  //input                       
    .i_rst_n                 (rst_n             ),  //input                       
    .o_temp_sensor           (temp_sensor       ),  //output  wire    [15:0]      
    .o_temp_shutter          (temp_shutter      ),  //output  wire    [15:0]      
    .o_temp_lens             (temp_lens         ),  //output  wire    [15:0]      
    .io_temp_iic_scl         (io_temp_iic_scl   ),  //inout   wire                
    .io_temp_iic_sda         (io_temp_iic_sda   )   //inout   wire                
);

//参数温度解析
param_parse #(
    .SHUTTER_OPEN         (2'b01                                ) ,
    .SHUTTER_CLOS         (2'b10                                )  
)
param_parse_inst
(
    .i_rst_n              (rst_n                                ),   //input                   
    .i_clk                (clk_display                          ),   //input                   
    .i_calc_b_done        (clac_b_done                          ),   //input                   
    .i_shutter            ({o_shutter_gpiob,o_shutter_gpioa}    ),   //input       [1:0]       
    .i_temp_sensor        (calc_temp_sensor                     ),   //input       [15:0]      temp_sensor  
    .i_temp_lens          (calc_temp_lens                       ),   //input       [15:0]      temp_lens    
    .i_temp_shutter       (calc_temp_shutter                    ),   //input       [15:0]      temp_shutter     
    .o_shutter_state      (shutter_state                        ),   //output reg              
    .o_temp_shutter_pre   (temp_shutter_pre                     ),   //output reg  [15:0]      
    .o_temp_sensor_pre    (temp_sensor_pre                      ),   //output reg  [15:0]      
    .o_temp_lens_pre      (temp_lens_pre                        ),   //output reg  [15:0]      
    .o_temp_shutter_start (temp_shutter_start                   ),   //output reg  [15:0]      
    .o_temp_lens_start    (temp_lens_start                      )    //output reg  [15:0]       
);

sensor_data_parse #(
    .Y_BLANK_SIZE        ( 4                        )  ,
    .IMAGE_WIDE_LENGTH   ( IR_IMAGE_WIDE_LENGTH     )  ,
    .IMAGE_HIGH_LENGTH   ( IR_IMAGE_HIGH_LENGTH     )  ,
    .DW                  ( IR_DW/2                  )   
)sensor_data_parse_inst (
    .i_rst_n            (rst_n                      ),        //input                               
    .i_clk              (i_sensor_pclk              ),        //input                               
    .i_data             (i_data                     ),        //input           [DW-1:0]            
    .i_hs               (i_hs                       ),        //input                               
    .i_vs               (i_vs                       ),        //input                               
    .o_data_mean        (x16_data_mean              ),        //output          [DW*2-1:0]          
    .o_data             (x16_data                   ),        //output          [DW*2-1:0]    
    .o_center_x16_data  (center_x16_data            ),      
    .o_hs               (x16_hs                     ),        //output                              
    .o_vs               (x16_vs                     )         //output                              
);

assign y16_data_sel    = 4'b0001;
nonuniform_top_v0 #(
    .IMAGE_WIDE_LENGTH (IR_IMAGE_WIDE_LENGTH) ,
    .IMAGE_HIGH_LENGTH (IR_IMAGE_HIGH_LENGTH) ,
    .ADDRS_DW          (PSRAM_ADDRS_DW      ) ,
    .DW                (IR_DW               )   
)nonuniform_top_v0_inst (
    .i_rst_n                 (rst_n                     ),//input                               
    .i_clk                   (clk_pixe                  ),//input                               
    .i_data                  (x16_data                  ),//input   [DW-1:0]                    
    .i_hs                    (x16_hs                    ),//input                               
    .i_vs                    (x16_vs                    ),//input                               
    .i_clac_b_mean_num       (clac_b_mean_num[3:0]      ),//input   [3:0]                       
    .i_clac_b_en             (calc_b_en                 ),//input                               
    .i_b_addrs               (b_addrs                   ),//input   [ADDRS_DW-1:0]              
    .o_clac_b_done           (clac_b_done               ),//output                              
    .i_data_sel              (y16_data_sel              ),//input   [3:0]                       
    .i_k_addrs               (k_addrs                   ),//input   [ADDRS_DW-1:0]              
    .i_init_k_load           (init_k_load               ),//input                               
    .o_bp_type               (bp_type                   ),//output                              
    .o_data                  (y16_data                  ),//output  [DW-1:0]      
    .o_center_y16_data       (center_y16_data           ),     
    .o_calc_b_mean_data      (calc_b_mean_data              ),         
    .o_sub_aver_y16          (sub_aver_y16              ),
    .o_hs                    (y16_hs                    ),//output                              
    .o_vs                    (y16_vs                    ),//output                              
    .o_mem_wr_start          (mem_wr0_start             ),//output                              
    .o_mem_wr_addrs          (mem_wr0_addrs             ),//output   [ADDRS_DW-1:0]             
    .o_mem_wr_lengths        (mem_wr0_lengths           ),//output   [ADDRS_DW-1:0]             
    .o_mem_wr_data           (mem_wr0_data              ),//output   [DW-1:0]                   
    .o_mem_wr_data_vld       (mem_wr0_data_vld          ),//output                              
    .o_mem_rd0_start         (mem_rd0_start             ),//output                              
    .o_mem_rd0_addrs         (mem_rd0_addrs             ),//output   [ADDRS_DW-1:0]             
    .o_mem_rd0_lengths       (mem_rd0_lengths           ),//output   [ADDRS_DW-1:0]             
    .i_mem_rd0_data          (mem_rd0_data              ),//input    [DW-1:0]                   
    .o_mem_rd0_data_req      (mem_rd0_data_req          ),//output                              
    .o_mem_rd1_start         (mem_rd1_start             ),//output                              
    .o_mem_rd1_addrs         (mem_rd1_addrs             ),//output   [ADDRS_DW-1:0]             
    .o_mem_rd1_lengths       (mem_rd1_lengths           ),//output   [ADDRS_DW-1:0]             
    .i_mem_rd1_data          (mem_rd1_data              ),//input    [DW-1:0]                   
    .o_mem_rd1_data_req      (mem_rd1_data_req          ) //output                              
);

data_mem_wr_ctrl #(
    .IMAGE_WIDE_LENGTH (IR_IMAGE_WIDE_LENGTH    )    ,
    .IMAGE_HIGH_LENGTH (IR_IMAGE_HIGH_LENGTH    )    ,
    .ADDRS_DW          (PSRAM_ADDRS_DW          )    ,
    .DW                (IR_DW                   )   
)data_mem_wr_ctrl_ir_inst (
    .i_rst_n             (rst_n                 ),        //input                           
    .i_clk               (clk_pixe              ),        //input                           
    .i_freeze_en         (ir_freeze             ),        //input                           
    .i_addrs0            (IR_Y16_ADDRS0         ),        //input   [ADDRS_DW-1:0]          
    .i_addrs1            (IR_Y16_ADDRS1         ),        //input   [ADDRS_DW-1:0]          
    .i_addrs2            (IR_Y16_ADDRS2         ),        //input   [ADDRS_DW-1:0]          
    .i_data              (y16_data              ),        //input   [DW-1:0]                
    .i_hs                (y16_hs                ),        //input                           
    .i_vs                (y16_vs                ),        //input                           
    .o_fcnt              (ir_fcnt               ),        //output  reg [1:0]               
    .o_mem_wr_start      (mem_wr1_start         ),        //output  reg                     
    .o_mem_wr_addrs      (mem_wr1_addrs         ),        //output  reg [ADDRS_DW - 1 : 0]  
    .o_mem_wr_lengths    (mem_wr1_lengths       ),        //output      [ADDRS_DW - 1 : 0]  
    .o_mem_wr_data       (mem_wr1_data          ),        //output  reg [DW - 1 : 0]        
    .o_mem_wr_data_vld   (mem_wr1_data_vld      )         //output  reg                     

);


video_display #(
    .DW                     (16         ),
    .SDRAM_ADDRS_DW         (21         ),
    .HEAD_LENGTH            (32         ),
    .IR_IMAGE_WIDE_LENGTH   (IR_IMAGE_WIDE_LENGTH        ),
    .IR_IMAGE_HIGH_LENGTH   (IR_IMAGE_HIGH_LENGTH        ),
    .TV_IMAGE_WIDE_LENGTH   (800        ),
// `ifdef TV_YUV420
    .TV_IMAGE_HIGH_LENGTH   (300+150    ),//600        ),
    .PARAM_LENGHT           (PARAM_LENGTH        )  
// `else
//     .TV_IMAGE_HIGH_LENGTH   (600        ),
//     .PARAM_LENGHT           (224+256        )  
// `endif
)video_display_inst (
   .i_rst_n                      (rst_n                         ),        //input                               
    .i_clk                       (clk_display                   ),        //input    
    .i_program_version0          (program_version0              ),        //input       [31:0]
    .i_program_version1          (program_version1              ),        //input       [31:0]
    .i_x16_data_mean             (calc_b_mean_data                  ),        //input       [15:0]   x16_data_mean
    .i_center_x16_data           (center_x16_data               ),        //input       [15:0]  
    .i_center_y16_data           (center_y16_data               ),        //input       [15:0]  
    .i_sub_aver_y16              (sub_aver_y16                  ),        //input       [15:0]                              
    .i_shutter_state             ({15'd0,shutter_state}         ),        //input       [15:0]                     
    .i_temp_range                ({12'd0,temp_range}            ),        //input       [15:0]                     
    .i_tr_switch_flag            ({15'd0,ir_freeze}             ),        //input       [15:0]                     
    .i_temp_shutter              (calc_temp_shutter             ),        //input       [15:0]                     
    .i_temp_sensor               (calc_temp_sensor              ),        //input       [15:0]                     
    .i_temp_lens                 (calc_temp_lens                ),        //input       [15:0]                     
    .i_temp_shutter_pre          (temp_shutter_pre              ),        //input       [15:0]                     
    .i_temp_sensor_pre           (temp_sensor_pre               ),        //input       [15:0]                     
    .i_temp_lens_pre             (temp_lens_pre                 ),        //input       [15:0]                     
    .i_temp_shutter_start        (temp_shutter_start            ),        //input       [15:0]                     
    .i_temp_lens_start           (temp_lens_start               ),        //input       [15:0]  

    .i_int_set                   (int_set                       ),
    .i_gain                      (gain                          ),
    .i_gsk_ref                   (gsk_ref                       ),
    .i_gsk                       (gsk                           ),
    .i_vbus                      (vbus                          ),
    .i_vbus_ref                  (vbus_ref                      ),
    .i_rd_rc                     (rd_rc                         ),
    .i_gfid                      (gfid                          ),
    .i_csize                     (csize                         ),
    .i_occ_value                 (occ_value                     ),
    .i_occ_step                  (occ_step                      ),
    .i_occ_thres_up              (occ_thres_up                  ),
    .i_occ_thres_down            (occ_thres_down                ),
    .i_ra                        (ra                            ),
    .i_ra_thres_high             (ra_thres_high                 ),
    .i_ra_thres_low              (ra_thres_low                  ),
    .i_raadj                     (raadj                         ),
    .i_raadj_thres_high          (raadj_thres_high              ),
    .i_raadj_thres_low           (raadj_thres_low               ),
    .i_rasel                     (rasel                         ),
    .i_rasel_thres_high          (rasel_thres_high              ),
    .i_rasel_thres_low           (rasel_thres_low               ),
    .i_hssd                      (hssd                          ),
    .i_hssd_thres_high           (hssd_thres_high               ),
    .i_hssd_thres_low            (hssd_thres_low                ),
    .i_gsk_thres_high            (gsk_thres_high                ),
    .i_gsk_thres_low             (gsk_thres_low                 ),
    .i_nuc_step                  (nuc_step                      ),

    .i_shutterCorCoef            (shutterCorCoef                ),//i_shutterCorCoef        16'd0                     
    .i_LensCorCoef               (LensCorCoef                   ),//i_LensCorCoef           16'd0          
    .i_Compensate_flag           (Compensate_flag               ),//i_Compensate_flag       8'b0011_0110   
    .i_Emiss_Humidy              (Emiss_Humidy                  ),//i_Emiss_Humidy          {8'd95,8'd60}  
    .i_EnTemp_Distance           (EnTemp_Distance               ),//i_EnTemp_Distance       {8'd23,8'd15}  
    .i_Transs                    (Transs                        ),//i_Transs                16'd1          
    .i_near_kf                   (near_kf                       ),//i_near_kf               16'd10000      
    .i_near_b                    (near_b                        ),//i_near_b                16'd0          
    .i_far_kf                    (far_kf                        ),//i_far_kf                16'd10000      
    .i_far_b                     (far_b                         ),//i_far_b                 16'd0          
    .i_pro_kf                    (pro_kf                        ),//i_pro_kf                16'd10000      
    .i_pro_b                     (pro_b                         ),//i_pro_b                 16'd0          
    .i_pro_kf_far                (pro_kf_far                    ),//i_pro_kf_far            16'd10000      
    .i_pro_b_far                 (pro_b_far                     ),//i_pro_b_far             16'd0          
    .i_reflectTemp               (reflectTemp                   ),//i_reflectTemp           16'd23         
    .i_x_fusion_offset           (x_fusion_offset               ),//     
    .i_y_fusion_offset           (y_fusion_offset               ),//     
    .i_fusion_amp_factor         (fusion_amp_factor             ),//

    .i_start                     (usb_start                     ),        //input                               
    .i_head_vld                  (usb_head_data_req             ),        //input                               
    .i_param_vld                 (usb_param_req                 ),        //input                                                                    
    .i_ir_cnt                    (ir_fcnt                       ),        //input       [1:0]                   
    .i_tv_cnt                    (tv_fcnt                       ),        //input       [1:0]                   
    .i_mem_ir_addrs0             (IR_Y16_ADDRS0                 ),        //input       [SDRAM_ADDRS_DW - 1:0]  
    .i_mem_ir_addrs1             (IR_Y16_ADDRS1                 ),        //input       [SDRAM_ADDRS_DW - 1:0]  
    .i_mem_ir_addrs2             (IR_Y16_ADDRS2                 ),        //input       [SDRAM_ADDRS_DW - 1:0]  
    .o_mem_ir_start              (mem_ir_start                  ),        //output                                           
    .o_mem_ir_addrs              (mem_ir_addrs                  ),        //output      [SDRAM_ADDRS_DW - 1:0]                      
    .o_mem_ir_length             (mem_ir_length                 ),        //output      [31:0]                  
    .i_mem_tv_addrs0             (TV_ADDRS0                     ),        //input       [SDRAM_ADDRS_DW - 1:0]    
    .i_mem_tv_addrs1             (TV_ADDRS1                     ),        //input       [SDRAM_ADDRS_DW - 1:0]    
    .i_mem_tv_addrs2             (TV_ADDRS2                     ),        //input       [SDRAM_ADDRS_DW - 1:0]    
    .o_mem_tv_start              (mem_tv_start                  ),        //output                                           
    .o_mem_tv_addrs              (mem_tv_addrs                  ),        //output      [SDRAM_ADDRS_DW - 1:0]                              
    .o_mem_tv_length             (mem_tv_length                 ),        //output      [31:0]                  
    .o_head_data                 (usb_head_data                 ),        //output reg  [DW-1:0]                
    .o_head_data_vld             (usb_head_data_vld             ),        //output reg                          
    .o_param_data                (usb_param_data                ),        //output reg  [DW-1:0]                
    .o_param_data_vld            (usb_param_data_vld            )         //output reg                                          
);  
reg           [ 32  - 1 : 0 ]          dbg_cnt_1               ;
wire           [ 1  - 1 : 0 ]          dbg_rd_req               ;
    always @(posedge clk_display or negedge rst_n) begin
        if (!rst_n) begin
            dbg_cnt_1 <= 0;
        // end else if(tv_fcnt>0 && yuv422_to_nv12_converter_inst.hcnt == 1 && yuv422_to_nv12_converter_inst.vcnt == 100)begin
        end else if(mem_rd3_start)begin
            dbg_cnt_1 <= 0;
        end else if(dbg_cnt_1==800+800*(600/2 + 600/4)/1)begin
            dbg_cnt_1 <= dbg_cnt_1;
        end else begin
            dbg_cnt_1 <= dbg_cnt_1 + 1;
        end
    end
assign dbg_rd_req = dbg_cnt_1 >= 800 && dbg_cnt_1 < 800+800*(600/2 + 600/4)/1;
sdram_port_arb  #(
    `WR_SETTING(0,16),
    `WR_SETTING(1,16),
    `WR_SETTING(2,16),
    `WR_SETTING(3,16),
    `RD_SETTING(0,16,"STANDARD"),
    `RD_SETTING(1,16,"STANDARD"),
    `RD_SETTING(2,16,"STANDARD"),
    `RD_SETTING(3,16,"STANDARD"),
    
    .SDRAM_ADDRS_WIDE (32),
    .SDRAM_DATA_WIDE  (32)
)sdram_port_arb_inst (
    .i_rst_n                                (rst_n                  ),  //input                               
    .i_clk                                  (sdrc_clk               ),  //input                               
    .i_sdram_clk                            (sdram_clk              ),  //input                               
    .o_sdram_init_done                      (mem_init_done          ),  //output         
    .i_SDRAM_controller_sdram_selfrefresh   (1'b0                   ),  //input                               
    .i_SDRAM_controller_sdram_power_down    (1'b0                   ),  //input   
//用户读写端口
    .i_wr_master_0_clk                      (clk_pixe               ),     //input wire                                                     
    .i_wr_master_0_wen                      (mem_wr0_data_vld       ),     //input wire                                                     
    .i_wr_master_0_data                     (mem_wr0_data           ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    .i_wr_master_0_start                    (mem_wr0_start          ),     //input wire                                                   
    .i_wr_master_0_addrs                    (mem_wr0_addrs          ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    .i_wr_master_0_lengths                  (mem_wr0_lengths        ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                                

    .i_wr_master_1_clk                      (clk_pixe               ),     //input wire                                                     
    .i_wr_master_1_wen                      (mem_wr1_data_vld       ),     //input wire                                                     
    .i_wr_master_1_data                     (mem_wr1_data           ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    .i_wr_master_1_start                    (mem_wr1_start          ),     //input wire                                                   
    .i_wr_master_1_addrs                    (mem_wr1_addrs          ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    .i_wr_master_1_lengths                  (mem_wr1_lengths        ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]     

    // .i_wr_master_2_clk                      (clk_display            ),     //input wire                                                     
    // .i_wr_master_2_wen                      (flash_rd_data_vld      ),     //input wire                                                     
    // .i_wr_master_2_data                     (flash_rd_data          ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    // .i_wr_master_2_start                    (mem_wr_flash_start     ),     //input wire                                                   
    // .i_wr_master_2_addrs                    (mem_wr_flash_addrs     ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    // .i_wr_master_2_lengths                  (mem_wr_flash_lens      ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]     

    .i_wr_master_2_clk                      (mem_wr2_clk          ),     //input wire                                                     
    .i_wr_master_2_wen                      (mem_wr2_data_vld     ),     //input wire                                                     
    .i_wr_master_2_data                     (mem_wr2_data         ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    .i_wr_master_2_start                    (mem_wr2_start        ),     //input wire                                                   
    .i_wr_master_2_addrs                    (mem_wr2_addrs        ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    .i_wr_master_2_lengths                  (mem_wr2_lengths         ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]     
`ifndef ZC23A
    .i_wr_master_3_clk                      (i_tv_pclk                  ),     //input wire                                                     
    .i_wr_master_3_wen                      (mem_wr3_data_vld           ),     //input wire                                                     
    .i_wr_master_3_data                     (mem_wr3_data               ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    .i_wr_master_3_start                    (mem_wr3_start              ),     //input wire                                                   
    .i_wr_master_3_addrs                    (mem_wr3_addrs              ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    .i_wr_master_3_lengths                  (mem_wr3_lengths            ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]     

    .i_wr_master_4_clk                      (i_tv_pclk                  ),     //input wire                                                     
    .i_wr_master_4_wen                      (mem_wr4_data_vld           ),     //input wire                                                     
    .i_wr_master_4_data                     (mem_wr4_data               ),     //input wire  [USE_WRPORT``NUM``_DW-1:0]                        
    .i_wr_master_4_start                    (mem_wr4_start              ),     //input wire                                                   
    .i_wr_master_4_addrs                    (mem_wr4_addrs              ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]                           
    .i_wr_master_4_lengths                  (mem_wr4_lengths            ),     //input wire  [SDRAM_ADDRS_WIDE-1:0]     
`endif
    .i_rd_master_0_clk                      (clk_pixe                   ),     //input  wire                                                    
    .i_rd_master_0_req                      (mem_rd0_data_req           ),     //input  wire                                                    
    .o_rd_master_0_data                     (mem_rd0_data               ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_master_0_data_vld                 (                           ),     //output wire                                               
    .i_rd_master_0_start                    (mem_rd0_start              ),     //input  wire                                                  
    .i_rd_master_0_addrs                    (mem_rd0_addrs              ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    .i_rd_master_0_lengths                  (mem_rd0_lengths            ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .o_rd_master_0_data_ready               (                           ),     //output wire      

    .i_rd_master_1_clk                      (clk_pixe                   ),     //input  wire                                                    
    .i_rd_master_1_req                      (mem_rd1_data_req           ),     //input  wire                                                    
    .o_rd_master_1_data                     (mem_rd1_data               ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_master_1_data_vld                 (                           ),     //output wire                                               
    .i_rd_master_1_start                    (mem_rd1_start              ),     //input  wire                                                  
    .i_rd_master_1_addrs                    (mem_rd1_addrs              ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    .i_rd_master_1_lengths                  (mem_rd1_lengths            ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .o_rd_master_1_data_ready               (                           ),     //output wire                                                

    .i_rd_master_2_clk                      (clk_display                ),     //input  wire                                                    
    .i_rd_master_2_req                      (usb_ir_data_req            ),     //input  wire                                                    
    .o_rd_master_2_data                     (usb_ir_data                ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_master_2_data_vld                 (usb_ir_data_vld            ),     //output wire                                               
    .i_rd_master_2_start                    (mem_ir_start               ),     //input  wire                                                  
    .i_rd_master_2_addrs                    (mem_ir_addrs               ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    .i_rd_master_2_lengths                  (mem_ir_length              ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .o_rd_master_2_data_ready               (usb_ir_data_ready          ),     //output wire        

    .i_rd_master_3_clk                      (clk_display                ),     //input  wire                                                    
    .i_rd_master_3_start                    (mem_rd3_start              ),     //input  wire                                                  
    .i_rd_master_3_addrs                    (mem_rd3_addrs              ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    .i_rd_master_3_lengths                  (mem_rd3_lens               ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .i_rd_master_3_req                      (mem_rd3_data_req           ),     //input  wire                                                    
    .o_rd_master_3_data_vld                 (mem_rd3_data_vld           ),     //output wire                                               
    .o_rd_master_3_data                     (mem_rd3_data               ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_master_3_data_ready               (mem_rd3_data_ready ),

    // .i_rd_master_3_clk                      (clk_display                ),     //input  wire                                                    
    // .i_rd_master_3_start                    (mem_tv_start               ),     //input  wire                                                  
    // .i_rd_master_3_addrs                    (mem_tv_addrs               ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    // .i_rd_master_3_lengths                  (mem_tv_length              ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    // .i_rd_master_3_req                      (usb_tv_data_req            ),     //input  wire                                                    
    // .o_rd_master_3_data_vld                 (usb_tv_data_vld            ),     //output wire                                               
    // .o_rd_master_3_data                     (usb_tv_data                ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    // .o_rd_master_3_data_ready               (usb_tv_data_ready          ),     //output wire                                                     
//sdram interface
    .o_sdram_clk                            (O_sdram_clk                ),  //output                              
    .o_sdram_cke                            (O_sdram_cke                ),  //output                              
    .o_sdram_cs_n                           (O_sdram_cs_n               ),  //output                              
    .o_sdram_cas_n                          (O_sdram_cas_n              ),  //output                              
    .o_sdram_ras_n                          (O_sdram_ras_n              ),  //output                              
    .o_sdram_wen_n                          (O_sdram_wen_n              ),  //output                               
    .o_sdram_dqm                            (O_sdram_dqm                ),  //output     [3:0]                    
    .o_sdram_addrs                          (O_sdram_addr               ),  //output     [10:0]                    
    .o_sdram_ba                             (O_sdram_ba                 ),  //output     [1:0]                    
    .io_sdram_dq                            (IO_sdram_dq                )   //inout      [SDRAM_DATA_WIDE-1:0]    
);
 
reg [9:0] rd_wait_cnt;
wire update_mem_wr_end;
reg wr_mem_dly;
reg mem_cnt_st;
reg ddr2flash_status_ff0;
reg usb_tv_data_req_ff0;
assign      ddr2flash_status_ff0_ndge = ddr2flash_status_ff0 & (!ddr2flash_status);
always@(posedge clk_display or negedge rst_n)
begin
    if(!rst_n) begin
        wr_mem_dly <= 1'b1;
        mem_cnt_st <= 1'b0;
        ddr2flash_status_ff0 <= 0;
        usb_tv_data_req_ff0  <= 0;
    end
    else begin
        wr_mem_dly           <= update_mem_wr_end;
        ddr2flash_status_ff0 <= ddr2flash_status;
        if(update_mem_wr_end & (~wr_mem_dly)) begin
            mem_cnt_st <= 1'b1;
        // end else if(flash_update_en) begin
        end else if(ddr2flash_status_ff0_ndge) begin
            mem_cnt_st <= 1'b0;
        end else begin
            mem_cnt_st <= mem_cnt_st;
        end
        usb_tv_data_req_ff0 <= usb_tv_data_req;
    end
end
assign  flash_update_en = mem_cnt_st;
// always@(posedge clk_display or negedge rst_n)
// begin
//     if(!rst_n) begin
//         flash_update_en <= 1'b0;
//         rd_wait_cnt <= 1'b0;
//     end
//     else begin
//         if(mem_cnt_st) begin
//             if(rd_wait_cnt < 'd1000) begin
//                 rd_wait_cnt <= rd_wait_cnt + 1'b1;
//                 flash_update_en <= 1'b0;
//             end else begin
//                 rd_wait_cnt <= rd_wait_cnt;
//                 flash_update_en <= 1'b1;
//             end
//         end else begin
//             rd_wait_cnt <= 1'b0;
//             flash_update_en <= flash_update_en;
//         end
//     end
// end

sdram_wr_tunnel_mux sdram_wr_tunnel_mux_inst
(
    // glb
    .i_clk               ( clk_display              ),
    .i_rst_n             ( rst_n                    ),

    // 通道选择
    // .i_tunnel_id         ( flash2ddr_load),//apb_loadK_en
    .i_tunnel_id         ( !read_temp_en ? flash2ddr_load : 0),//apb_loadK_en
    // USB
    .i_usb_clk              ( usb_user_clk              ),
    .i_usb_vld              ( usb_update_vld            ),//test_update_vld
    .i_usb_data             ( usb_update_data           ),//test_cnt
    .i_usb_lens             ( usb_update_lens >> 1           ),
    .o_mem_wr_end           ( update_mem_wr_end         ),
    
    // 升级
    .i_wr_master_0_wen          ( ), 
    .i_wr_master_0_data         ( ), 
    .i_wr_master_0_start        ( ), 
    .i_wr_master_0_addrs        ( mem_update_addrs                ), //flash_update_addrs
    .i_wr_master_0_lens         ( usb_update_lens >> 1       ), 
    // 加载K
    .i_wr_master_1_wen          ( (!read_temp_en)? flash_rd_data_vld   :0     ), 
    .i_wr_master_1_data         ( (!read_temp_en)? flash_rd_data       :0     ), 
    .i_wr_master_1_start        ( (!read_temp_en)? mem_wr_flash_start  :0     ), 
    .i_wr_master_1_addrs        ( (!read_temp_en)? mem_wr_flash_addrs  :0     ), 
    .i_wr_master_1_lens         ( (!read_temp_en)? mem_wr_flash_lens   :0     ), 

    // mem2
    .o_wr_master_2_clk          ( mem_wr2_clk           ), 
    .o_wr_master_2_wen          ( mem_wr2_data_vld      ), 
    .o_wr_master_2_data         ( mem_wr2_data          ), 
    .o_wr_master_2_start        ( mem_wr2_start         ), 
    .o_wr_master_2_addrs        ( mem_wr2_addrs         ), 
    .o_wr_master_2_lens         ( mem_wr2_lengths       )
);

wire                            rd_0_start                   ; 
wire       [PSRAM_ADDRS_DW-1:0] rd_0_addrs                   ; 
wire       [PSRAM_ADDRS_DW-1:0] rd_0_lengths                 ; 
wire       [IR_DW-1:0]          rd_0_data                    ; 
wire                            rd_0_data_req                ; 
wire                            rd_0_data_val                ; 
wire                            rd_0_data_ready                ; 


assign                          rd_0_start              =  flash_rd_en ? ddr_rd_start           : mem_tv_start;
assign                          rd_0_addrs              =  flash_rd_en ? (update_type == 8'h5a) ? GUOGAI_ADDR : (cmd_data == 1) ? PARAM_L_ADDR : PARAM_H_ADDR  : mem_tv_addrs ;
assign                          rd_0_lengths            =  flash_rd_en ? (update_type == 8'h5a) ? IR_IMAGE_TOTAL_LENGTH     : (cmd_data == 1) ? 32'd748600>>1: 32'd885800>>1 : mem_tv_length;
// assign                          rd_0_addrs              =  flash_rd_en ? PARAM_L_ADDR  : mem_tv_addrs ;
// assign                          rd_0_lengths            =  flash_rd_en ? (update_lens >> 1)     : mem_tv_length;
assign                          rd_0_data_req           =  flash_rd_en ? ddr_rd_en              : usb_tv_data_req;

assign                          usb_tv_data             =  flash_rd_en ? 0 : rd_0_data ;
assign                          usb_tv_data_vld         =  flash_rd_en ? 0 : rd_0_data_val;
assign                          param_ddr_rd_data       =  flash_rd_en ? rd_0_data      : 0;
assign                          param_ddr_rd_data_vld   =  flash_rd_en ? rd_0_data_val  : 0;
assign                          param_ddr_rd_data_ready =  flash_rd_en ? rd_0_data_ready  : 0;

// assign                          rd_0_start              =  temp_rd_flash_ctrl_en ? ddr_rd_start           : mem_tv_start;
// assign                          rd_0_addrs              =  temp_rd_flash_ctrl_en ? mem_update_addrs        : mem_tv_addrs ;
// assign                          rd_0_lengths            =  temp_rd_flash_ctrl_en ? (update_lens >> 1)     : mem_tv_length;
// assign                          rd_0_data_req           =  temp_rd_flash_ctrl_en ? ddr_rd_en              : usb_tv_data_req;

// assign                          usb_tv_data             =  temp_rd_flash_ctrl_en ? 0 : rd_0_data ;
// assign                          usb_tv_data_vld         =  temp_rd_flash_ctrl_en ? 0 : rd_0_data_val;
// assign                          param_ddr_rd_data       =  temp_rd_flash_ctrl_en ? rd_0_data      : 0;
// assign                          param_ddr_rd_data_vld   =  temp_rd_flash_ctrl_en ? rd_0_data_val  : 0;
// assign                          param_ddr_rd_data_ready =  temp_rd_flash_ctrl_en ? rd_0_data_ready  : 0;
sdram_rd_tunnel_mux sdram_rd_tunnel_mux_inst
(
    //glb
    .i_clk               ( clk_display              ),
    .i_rst_n             ( rst_n                    ),

    //通道选择
    .i_tunnel_id         ( flash_update_en          ),
    .o_flash_start       ( flash_up_start           ),
    .i_flash_idle        (             ),

    //白光
    .i_rd_0_start        ( rd_0_start             ),     //input  wire                                                  
    .i_rd_0_addrs        ( rd_0_addrs             ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                          
    .i_rd_0_lengths      ( rd_0_lengths           ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .i_rd_0_req          ( rd_0_data_req          ),     //input  wire                                                    
    .o_rd_0_data_vld     ( rd_0_data_val          ),     //output wire                                               
    .o_rd_0_data         ( rd_0_data              ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_0_data_ready   ( rd_0_data_ready),     //output wire
    
    //升级                                                   
    .i_rd_1_start        ( flash_update_en          ),     //input  wire                                                  
    .i_rd_1_addrs        ( mem_update_addrs         ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]  flash_update_addrs                        
    .i_rd_1_lengths      ( usb_update_lens>> 1           ),     //input  wire  [SDRAM_ADDRS_WIDE-1:0]                        
    .i_rd_1_req          ( rd_1_req         ),     //input  wire                                                    
    .o_rd_1_data_vld     ( rd_1_data_vld    ),     //output wire                                               
    .o_rd_1_data         ( rd_1_data        ),     //output wire  [USE_RDPORT``NUM``_DW-1:0]                       
    .o_rd_1_data_ready   ( ),     //output wire

    //mem3
    .o_mem_rd3_start     ( mem_rd3_start            ),
    .o_mem_rd3_addrs     ( mem_rd3_addrs            ),
    .o_mem_rd3_lens      ( mem_rd3_lens             ),
    .o_mem_rd3_data_req  ( mem_rd3_data_req         ),
    .i_mem_rd3_data_vld  ( mem_rd3_data_vld         ),
    .i_mem_rd3_data      ( mem_rd3_data             ),
    .i_mem_rd3_data_ready(mem_rd3_data_ready        )      
);

usb_top #(
    .FIFO_INIT_WAIT_TIME  (300              )       ,
    .FRAME_RATE           (30               )       ,
    .TIME_CNT             (60_000_000/30    )       ,
    .HEAD_LENGTH          (32               )       ,
    .IR_LENGTH            (IR_IMAGE_TOTAL_LENGTH          )       ,
// `ifdef TV_YUV420
    .TV_LENGTH            (TV_IMAGE_LENGTH_420),//800*600          )       ,
    .PARAM_LENGHT         (PARAM_LENGTH              ) ,
// `else
//     .TV_LENGTH            (800*600          )       ,
//     .PARAM_LENGHT         (224+256              ) ,
// `endif
    .PARAM_L_LENGTH         (PARAM_L_LENGTH   ),
    .PARAM_H_LENGTH         (PARAM_H_LENGTH   ),
    .PARAM_L_TOTAL_LEN      (PARAM_L_TOTAL_LEN),
    .PARAM_H_TOTAL_LEN      (PARAM_H_TOTAL_LEN),
`ifdef ZC23A
    `ifdef CH_Z  
    // .PRODUCTSTR           ( "ZX10A"         ),
    // .SERIALSTR            ("ZX01A19"        )
        .VERSIONBCD           (16'h0201                  ),
        .PRODUCTSTR           ("ES2-Z"              ),
        .PRODUCTSTR_LEN       (5                        ),
        .SERIALSTR            ("ES2-Z"              ),
        .SERIALSTR_LEN        (5                        ),
    `else
        .VERSIONBCD           (16'h0201                  ),
        .PRODUCTSTR           ("ES2"              ),
        .PRODUCTSTR_LEN       (3                        ),
        .SERIALSTR            ("ES2"              ),
        .SERIALSTR_LEN        (3                        ),
    `endif
    // .SERIALSTR            ("com.guidesensmart.EyeSearch2"              ),
    // .SERIALSTR_LEN        (28                        )  
    .SERIALSTR6            ("com.guidesensmart.ZX10A"              ),
    .SERIALSTR6_LEN        (23                        )  
`else
    `ifdef CH_Z
        .VERSIONBCD           (16'h0202                  ),
        .PRODUCTSTR           ("ES2+Z"             ),
        .PRODUCTSTR_LEN       (5                        ),
        .SERIALSTR            ("ES2+Z"             ),
        .SERIALSTR_LEN        (5                        ),
    `else
        .VERSIONBCD           (16'h0202                  ),
        .PRODUCTSTR           ("ES2+"             ),
        .PRODUCTSTR_LEN       (4                        ),
        .SERIALSTR            ("ES2+"             ),
        .SERIALSTR_LEN        (4                        ),
    `endif 
    .SERIALSTR6            ("com.guidesensmart.ZX10A" ),
    .SERIALSTR6_LEN        (23                        )  
`endif 
)usb_top_inst (
    .i_usb_fclk         (usb_fclk           ),     //input                          //  480MHz
    .i_usb_user_clk     (usb_user_clk       ),     //input                          //  60MHz
    .i_rpll_1_lock      (usb_pll_locked     ),     //input                       
    .i_wb_clk           ( clk_display       ),//! usb_user_clk      ), 
    .i_wb_rst_n         ( rst_n             ),
    .i_wb_cyc           ( wbs1_cyc          ),
    .i_wb_stb           ( wbs1_stb          ),
    .i_wb_we            ( wbs1_we           ),
    .i_wb_adr           ( wbs1_adr          ),
    .i_wb_dat           ( wbs1_dat_o        ),
    .i_wb_sel           ( wbs1_sel          ),
    .o_wb_dat           ( wbs1_dat_i        ),
    .o_wb_ack           ( wbs1_ack          ),
    .i_rst_n            (rst_n              ),     //input                       
    .o_debug_uart_tx    (),     //output  wire                
    .i_pclk             (clk_display        ), //input       
    .i_ir_init_done     (ir_init_done       ),  //input         //红外初始化完成标志                   
    .i_head_data        (usb_head_data      ), //input           [15:0]      
    .i_head_data_vld    (usb_head_data_vld  ), //input                       
    .o_head_data_req    (usb_head_data_req  ), //output                      
    .i_ir_data          (usb_ir_data        ), //input           [15:0]      
    .i_ir_data_vld      (usb_ir_data_vld    ), //input                       
    .i_ir_data_ready    (1'b1  ), //input                        
    .o_ir_data_req      (usb_ir_data_req    ), //output                      

`ifdef ZC23A
    .i_tv_data          (16'd0        ), //input           [15:0]      
    .i_tv_data_vld      (usb_tv_data_req_ff0), //input          
`else 
    .i_tv_data          (usb_tv_data        ), //input           [15:0]      
    .i_tv_data_vld      (usb_tv_data_vld    ), //input          
`endif             

    .o_tv_data_req      (usb_tv_data_req    ), //output                      
    .i_tv_data_ready    (1'b1  ), //input                       
    .i_param_data       (usb_param_data     ), //input           [15:0]      
    .i_param_data_vld   (usb_param_data_vld ), //input    

    .o_param_req        (usb_param_req      ), //output                      
    .o_start            (usb_start          ), //output                      
    .o_shutter_on_en    (),     //output  wire                
    .o_shutter_off_en   (),     //output  wire                
    .o_temp_range       (),     //output  wire    [7:0]       
    .o_cmd_occ_en       (),     //output  wire                
    .i_usb_dxp          (i_usb_dxp          ),     //input                       
    .i_usb_dxn          (i_usb_dxn          ),     //input                       
    .o_usb_dxp          (o_usb_dxp          ),     //output  wire                
    .o_usb_dxn          (o_usb_dxn          ),     //output  wire                
    .i_usb_rxdp         (i_usb_rxdp         ),     //input                       
    .i_usb_rxdn         (i_usb_rxdn         ),     //input                       
    .o_usb_pullup_en    (o_usb_pullup_en    ),     //output  wire                
    .io_usb_term_dp     (io_usb_term_dp     ),     //inout                       
    .io_usb_term_dn     (io_usb_term_dn     ),     //inout
        
    
    .i_param_load       (send_done_pulse         ),//send_done_pulse flash2ddr_load
    .i_flash_rd_data_ready(param_ddr_rd_data_ready),
    .i_flash_rd_data_vld(param_ddr_rd_data_vld   ),
    .i_flash_rd_data    (param_ddr_rd_data       ),
    .o_update_data      (usb_update_data    ),//    程序升级
    .o_update_vld       (usb_update_vld     ),//    程序升级
    .o_update_lens      (usb_update_lens    ),//    程序升级
    .o_update_type      (update_type        ),//    程序升级
    .o_cmd_data         (cmd_data           ),
    .o_flash_rd_en      (flash_rd_en        ),
    .o_ddr_rd_start     (ddr_rd_start       ),
    .o_ddr_rd_en        (ddr_rd_en          ),
    .i_ddr2flash_status (ddr2flash_status   ),

    .o_usb_cmd          ({usb_cmd[7:0],usb_cmd[15:8]}            ),
    .o_usb_data         (usb_data           ),
    .o_usb_cmd_en       (usb_cmd_en         ),              
    .o_usb_cmd_flag     (usb_cmd_flag         ),                            
    .io_mfi_iic_scl     (/*io_mfi_iic_scl*/     ),     //inout   wire                
    .io_mfi_iic_sda     (/*io_mfi_iic_sda*/     )      //inout   wire                
);
`ifdef NEORV32
// ----------------  SDA  ----------------
assign twi_sda_i              = io_sensor_iic_sda;
assign io_sensor_iic_sda       = (twi_sda_o)?1'bz:1'b0;   // 0 = 拉低, 1 = 释放
// ----------------  SCL  ----------------
assign twi_scl_i              = io_sensor_iic_scl;
assign io_sensor_iic_scl       = (twi_scl_o)?1'bz:1'b0;
//**********************************************************************************************
`define DBG_FIELD_INTERUPT
`ifdef DBG_FIELD_INTERUPT
wire dbg_vsync;
    gen_test #(
                 .WR_PORT           (0           ),
                 .USE_EXTER_RST 	( 0          ),
                 .DW            	( 16         ),
                 .CW            	( 10         ),
                 .STS_FREQ      	( 60_000_000 ),
                 .FRAME_RATE    	( 50         ),
                 .IMAGE_WIDTH   	( 640        ),
                 .IMAGE_HEIGHT  	( 512        ))
             u_gen_test_2(
                 .i_Sys_clk       	( usb_user_clk    ),
                 .i_Rst_n         	( rst_n       ),
                 .o_Image_vs     	( dbg_vsync       )
             );
assign gpio_i_bus[0]    = dbg_vsync;
`else
assign gpio_i_bus[0]    = x16_vs;//场中断
`endif
//**********************************************************************************************
assign gpio_i_bus[1]    = trigger_pos_15;//apb中断

assign gpio_i_bus[8]    = io_mfi_iic_sda;
assign gpio_i_bus[9]    = io_mfi_iic_scl;
assign io_mfi_iic_sda = (gpio_o_bus[8] == 1'b0) ? 1'b0 : 1'bz;
assign io_mfi_iic_scl = (gpio_o_bus[9] == 1'b0) ? 1'b0 : 1'bz;
// 确保 gpio_i_bus 其他未使用的位有默认值，防止高阻
assign gpio_i_bus[31:10] = 22'd0;
assign gpio_i_bus[7:2]   = 6'd0; 

// assign print_uart_0_io_txd = sensor_mc;
`ifdef UART_REUSE
wire dbg_uart_rxd = i_tv_data[7];
wire dbg_uart_txd;//
assign i_tv_vsync = dbg_uart_txd;
`endif
neorv32_top #(
        .CLOCK_FREQUENCY(60_000_000),
`ifdef UART_REUSE
        .BOOT_MODE_SELECT(0),
`else
        .BOOT_MODE_SELECT(2),
`endif
        .RISCV_ISA_C(1'b1),
        .RISCV_ISA_M(1'b1),
        .RISCV_ISA_Zicntr(1'b1),
        .IMEM_EN(1'b1),
        .IMEM_SIZE(32 * 1024),
        .DMEM_EN(1'b1),
        .DMEM_SIZE(8 * 1024),
        .IO_GPIO_NUM(32),
        .IO_CLINT_EN(1'b1),
        .IO_SPI_EN(1'b1),
        .IO_UART0_EN(1'b1),
        .IO_UART1_EN(1'b0),
        .IO_TWI_EN(1'b1),
        .IO_TWI_FIFO(4),
        .XBUS_EN(1)
    ) neorv32_top_inst (
        .clk_i      (clk_display),//30M
        .rstn_i     (rst_n      ),
        .gpio_i     (gpio_i_bus),
        .gpio_o     (gpio_o_bus),
        .twi_sda_i  (twi_sda_i),
        .twi_sda_o  (twi_sda_o),
        .twi_scl_i  (twi_scl_i),
        .twi_scl_o  (twi_scl_o),

        .spi_clk_o  (),
        .spi_dat_o  (),//mosi
        .spi_dat_i  (),//miso
        .spi_csn_o  (),
`ifdef UART_REUSE
        .uart0_txd_o(dbg_uart_txd),
        .uart0_rxd_i(dbg_uart_rxd),
`endif
        // XBUS connections
        .xbus_adr_o (xbus_adr),
        .xbus_dat_o (xbus_dat_o_int),
        .xbus_cti_o (xbus_cti),
        .xbus_tag_o (xbus_tag),
        .xbus_we_o  (xbus_we),
        .xbus_sel_o (xbus_sel),
        .xbus_stb_o (xbus_stb),
        .xbus_cyc_o (xbus_cyc),
        .xbus_dat_i (xbus_dat_i_int),
        .xbus_ack_i (xbus_ack_i),
        .xbus_err_i (xbus_err_i)
    );      
    assign o_shutter_gpioa = gpio_o_bus[0];
    assign o_shutter_gpiob = gpio_o_bus[1]; 
    
    wb_mux_2 #(
        .DATA_WIDTH   (32),
        .ADDR_WIDTH   (32),
        .SELECT_WIDTH (4)
    ) u_wb_mux_2 (
        .clk          (clk_display),
        .rst          (~rst_n),
        
        // Wishbone主机接口 (来自NEORV32 XBUS)
        .wbm_adr_i    (xbus_adr),
        .wbm_dat_i    (xbus_dat_o_int),
        .wbm_we_i     (xbus_we),
        .wbm_sel_i    (xbus_sel),
        .wbm_stb_i    (xbus_stb),
        .wbm_cyc_i    (xbus_cyc),
        .wbm_dat_o    (xbus_dat_i_int),
        .wbm_ack_o    (xbus_ack_i),
        .wbm_err_o    (xbus_err_i),
        .wbm_rty_o    (),  // 未使用
        
        // Wishbone从机0接口 (APB 桥接)
        .wbs0_adr_o   (wbs0_adr),
        .wbs0_dat_i   (wbs0_dat_i),
        .wbs0_we_o    (wbs0_we),
        .wbs0_sel_o   (wbs0_sel),
        .wbs0_stb_o   (wbs0_stb),
        .wbs0_cyc_o   (wbs0_cyc),
        .wbs0_dat_o   (wbs0_dat_o),
        .wbs0_ack_i   (wbs0_ack),
        .wbs0_err_i   (wbs0_err),
        .wbs0_rty_i   (wbs0_rty),
        
        // Wishbone从机0地址配置 (0x0000_0000 - 0x7FFF_FFFF)
        .wbs0_addr    (32'hF100_0000),
        .wbs0_addr_msk(32'hFF00_0000),
        
        // Wishbone从机1接口 (USB桥接)
        .wbs1_adr_o   (wbs1_adr),
        .wbs1_dat_i   (wbs1_dat_i),
        .wbs1_we_o    (wbs1_we),
        .wbs1_sel_o   (wbs1_sel),
        .wbs1_stb_o   (wbs1_stb),
        .wbs1_cyc_o   (wbs1_cyc),
        .wbs1_dat_o   (wbs1_dat_o),
        .wbs1_ack_i   (wbs1_ack),
        .wbs1_err_i   (wbs1_err),
        .wbs1_rty_i   (1'b0),
        
        // Wishbone从机1地址配置 (0x8000_0000 - 0xFFFF_FFFF)
        .wbs1_addr    (32'hF200_0000),
        .wbs1_addr_msk(32'hFF00_0000)
    ); 
    // 实例化XBUS到APB转换桥接
    xbus_to_apb_bridge #(
        .ADDR_WIDTH   (`APB_AW),
        .DATA_WIDTH   (`APB_DW),
        .SELECT_WIDTH (4)//DATA_WIDTH/8
    ) u_xbus_to_apb_bridge (
        .clk          (clk_display ),
        .resetn       (rst_n       ),
        // XBUS接口
        .adr_i        (wbs0_adr),
        .dat_i        (wbs0_dat_o),
        .we_i         (wbs0_we ),
        .sel_i        (wbs0_sel),
        .stb_i        (wbs0_stb),
        .cyc_i        (wbs0_cyc),
        .dat_o        (wbs0_dat_i),
        .ack_o        (wbs0_ack),
        // APB接口
        .apb_PSEL     (apbSlave_1_PSEL     ),
        .apb_PADDR    (apbSlave_1_PADDR    ),
        .apb_PSTRB    (apbSlave_1_PSTRB    ),
        .apb_PPROT    (apbSlave_1_PROT     ),
        .apb_PENABLE  (apbSlave_1_PENABLE  ),
        .apb_PWRITE   (apbSlave_1_PWRITE   ),
        .apb_PWDATA   (apbSlave_1_PWDATA   ),
        .apb_PREADY   (apbSlave_1_PREADY   ),
        .apb_PRDATA   (apbSlave_1_PRDATA   ),
        .apb_PSLVERROR(apbSlave_1_PSLVERROR)
    );
`endif
`ifdef Gowin_EMPU_M1
Gowin_EMPU_M1_Top u_Gowin_EMPU_M1_Top(
    .LOCKUP     ( core_lock_flag        ), //output LOCKUP
    // .HALTED( ), //output HALTED
    //GPIO
    // .GPIO       ( gpiobus_io            ), //inout [15:0] GPIO
    .GPIOIN     ( {trigger_pos_15,15'b0}), //input [15:0] GPIOIN
    .GPIOOUT    ( gpiobus_io            ), //output [15:0] GPIOOUT
    .GPIOOUTEN  ( gpiobus_io_en         ), //output [15:0] GPIOOUTEN
    //Jtag-Wire
    // .JTAG_7     ( o_shutter_gpioa       ), //tms | swdio
    // .JTAG_9     ( o_shutter_gpiob       ), //tck | swclk
    //UART
    .UART0RXD   (    ), //input UART0RXD print_uart_0_io_rxd
    .UART0TXD   (    ), //output UART0TXD print_uart_0_io_txd
    //APB
    .APB1PCLK   (apbSlave_1_PCLK        ), //output APB1PCLK
    .APB1PRESET (apbSlave_1_PRESET      ), //output APB1PRESET
    .APB1PADDR  (apbSlave_1_PADDR       ), //output [31:0] APB1PADDR
    .APB1PSEL   (apbSlave_1_PSEL        ), //output APB1PSEL
    .APB1PSTRB  (apbSlave_1_PSTRB       ), //output [3:0] APB1PSTRB
    .APB1PPROT  (apbSlave_1_PROT        ), //output [2:0] APB1PPROT
    .APB1PENABLE(apbSlave_1_PENABLE     ), //output APB1PENABLE
    .APB1PWRITE (apbSlave_1_PWRITE      ), //output APB1PWRITE
    .APB1PWDATA (apbSlave_1_PWDATA      ), //output [31:0] APB1PWDATA
    .APB1PREADY (apbSlave_1_PREADY      ), //input APB1PREADY
    .APB1PRDATA (apbSlave_1_PRDATA      ), //input [31:0] APB1PRDATA
    .APB1PSLVERR(apbSlave_1_PSLVERROR   ), //input APB1PSLVERR
    //TIMER
    .TIMER0EXTIN( ), //input TIMER0EXTIN
    //IIC
    .SCL        ( io_sensor_iic_scl     ), //inout SCL
    .SDA        ( io_sensor_iic_sda     ), //inout SDA
    //spi-flash
    .FLASH_SPI_HOLDN    (), //inout FLASH_SPI_HOLDN
    // .FLASH_SPI_CSN      ( O_flash_cs_n  ), //inout FLASH_SPI_CSN
    // .FLASH_SPI_CLK      ( O_flash_ck    ), //inout FLASH_SPI_CLK
    // .FLASH_SPI_MISO     ( IO_flash_do   ), //inout FLASH_SPI_MISO
    // .FLASH_SPI_MOSI     ( IO_flash_di   ), //inout FLASH_SPI_MOSI
    .FLASH_SPI_WPN      (), //inout FLASH_SPI_WPN
    //GLOABLE
    .HCLK       (clk_display                ), //input HCLK
    .hwRstn     (rst_n                  ) //input hwRstn
);
// arm lock test
    always@(posedge clk_display)
    begin
        core_lock_flag_pre <= core_lock_flag;
    end
// gpio
    //in
    assign o_shutter_gpioa = gpiobus_io[0];
    assign o_shutter_gpiob = gpiobus_io[1];
`endif 

    //interupt
    // assign trigger_pos_15 = gpiobus_io[2];

gen_reset 
#(
    .RST_TIME                                   (63  )               ,           
    .DW                                         (1   )                           
)
gen_reset_apb_irq_arb_inst
(
    .i_clk           (usb_user_clk                      ),        //input                   
    .i_rst_n         (rst_n                             ),        //input                   
    .i_locked        (~irq_ack[31]                      ),        //input       [DW-1:0]    
    .o_rst_n         (apb_irq_arb_rst_n                 )         //output  reg                      

);

apb_irq_arb  #(
    .CLK_REQ         (60_000_000)
)apb_irq_arb_inst
(
    .i_rst_n         (apb_irq_arb_rst_n     ), //input                   
    .i_clk           (usb_user_clk          ), //input                   
    .i_usb_cmd_en    (usb_cmd_en            ), //input                   
    .i_vs            (x16_vs                ), //input                   
    .i_irq_ack       (irq_ack               ), //input        [31:0]    
    .o_irq_sel       (irq_sel               ), //output  reg  [31:0]     
    .o_irq_en        (trigger_pos_15        )  //output  reg             
);


    apb_top #
    (
        .ADDR_WIDTH     ( `APB_AW               ),
        .DATA_WIDTH     ( `APB_DW               ),
        .NUM_REG        ( `APB_REG_NUM          ),
        .ADDR_BASE1     ( `APB_REG_ADDR_BASE1   )
    )
    u_apb_top
    (
        .clk                    ( clk_display           ) ,
        .resetn                 ( rst_n                 ) ,
        .o_program_version0     (program_version0       ) ,
        .o_program_version1     (program_version1       ) ,
        .risv_i2c_apb_bus_d1    ( i2c_apb_bus_d1        ) ,
        .risv_i2c_apb_bus_c1    ( i2c_apb_bus_c1        ) ,
        .risv_wr_en_bus0        ( apb_en_bus0           ) ,
        .i_ir_x16_mean          (x16_data_mean          ),     //input     [15:0]              
        .i_temp_sensor          (temp_sensor            ),     //input     [15:0]              
        .i_temp_shutter         (temp_shutter           ),     //input     [15:0]              
        .i_temp_lens            (temp_lens              ),     //input     [15:0]              
        .i_temp_range           (temp_range             ),     //input     [3:0]               
        .i_usb_cmd              ({usb_cmd,usb_data }    ),//input     [31:0]  {usb_cmd[7:0],usb_cmd[15:8]}
        .i_irq_sel              (irq_sel                ),     //input     [31:0]              
        .o_calc_b_en            (calc_b_en              ) ,    //output                        
        .o_b_addrs              (b_addrs                ) ,    //output    [20:0]              
        .o_k_addrs              (k_addrs                ) ,    //output    [20:0]  
        .o_mem_addrs            (mem_addrs              ),     //output    [31:0]              
        .o_flash_addrs          (flash_addrs            ),     //output    [31:0]              
        .o_flash_data_lens      (flash_data_lens        ),     //output    [31:0]              
        .i_risv_rd_bus0         (risv_rd_bus0           ),     //input     [31:0]              
        .o_risv_wr_bus0         (risv_wr_bus0           ),     //output    [31:0]                                           
        .i_param_apb32bus0      (param_wr_apb32bus0     ),
        .o_param_apb32bus0      (param_rd_apb32bus0     ),
        .o_sensor_update_param  (sensor_update_param    ),
        // .o_ir_freeze            (              ) ,    //output    
        .o_temp_range           (temp_range             ) ,    //output    [3:0] 
        .o_irq_ack              (irq_ack                ) ,
        .o_calc_b_num           (clac_b_mean_num        ) ,
        .o_ir_init_done         (ir_init_done           ),
        .i_iic_reg_addrsdata    (iic_reg_addrsdata      ),
        .o_iic_reg_ctrl         (iic_reg_ctrl           ),
        .o_iic_update           (iic_update             ), 

        .o_int_set              (int_set                ),
        .o_gain                 (gain                   ),
        .o_gsk_ref              (gsk_ref                ),
        .o_gsk                  (gsk                    ),
        .o_vbus                 (vbus                   ),
        .o_vbus_ref             (vbus_ref               ),
        .o_rd_rc                (rd_rc                  ),
        .o_gfid                 (gfid                   ),
        .o_csize                (csize                  ),
        .o_occ_value            (occ_value              ),
        .o_occ_step             (occ_step               ),
        .o_occ_thres_up         (occ_thres_up           ),
        .o_occ_thres_down       (occ_thres_down         ),
        .o_ra                   (ra                     ),
        .o_ra_thres_high        (ra_thres_high          ),
        .o_ra_thres_low         (ra_thres_low           ),
        .o_raadj                (raadj                  ),
        .o_raadj_thres_high     (raadj_thres_high       ),
        .o_raadj_thres_low      (raadj_thres_low        ),
        .o_rasel                (rasel                  ),
        .o_rasel_thres_high     (rasel_thres_high       ),
        .o_rasel_thres_low      (rasel_thres_low        ),
        .o_hssd                 (hssd                   ),
        .o_hssd_thres_high      (hssd_thres_high        ),
        .o_hssd_thres_low       (hssd_thres_low         ),
        .o_gsk_thres_high       (gsk_thres_high         ),
        .o_gsk_thres_low        (gsk_thres_low          ),
        .o_nuc_step             (nuc_step               ),
        
        .o_calc_temp_sensor     (calc_temp_sensor       ),
        .o_calc_temp_shutter    (calc_temp_shutter      ),
        .o_calc_temp_lens       (calc_temp_lens         ),

        .apb_PSEL               ( apbSlave_1_PSEL       ) ,
        .apb_PADDR              ( apbSlave_1_PADDR      ) ,
        .apb_PSTRB              ( apbSlave_1_PSTRB      ) , //unused 4
        .apb_PPROT              ( apbSlave_1_PROT       ) , //unused 1
        .apb_PENABLE            ( apbSlave_1_PENABLE    ) ,
        .apb_PWRITE             ( apbSlave_1_PWRITE     ) ,
        .apb_PWDATA             ( apbSlave_1_PWDATA     ) ,
        .apb_PREADY             ( apbSlave_1_PREADY     ) ,
        .apb_PRDATA             ( apbSlave_1_PRDATA     ) ,
        .apb_PSLVERROR          ( apbSlave_1_PSLVERROR  )   //unused 0
    );

//
i2c_reg_buff i2c_reg_buff_inst(
    .i_clk           (clk_display           ),    //input                   
    .i_rst_n         ( rst_n                 ),        
    .i_apb_data      (iic_reg_ctrl          ),    //input           [31:0]  
    .i_update        (iic_update            ),    //input                   
    .o_apb_data      (iic_reg_addrsdata     )     //output reg      [31:0]  

);
//i2c-apb

    i2c_apb_top #(
        .CLK_IN_FREQ        (30_000_000),
        .DWIDTH_BYTE        (1)
    )
    u_i2c_apb_top_1(
        .i_mc               ( clk_display           ),
        .i_rst_n            ( rst_n                 ),
        .i_rd_clear         ( i2c_apb_bus_d1[2]     ),
        .i_i2c_addr         ( i2c_apb_bus_d1[31:24] ),
        .i_i2c_reg          ( i2c_apb_bus_d1[23:16] ),
        .o_i2c_busy         ( i2c_apb_bus_c1[0]     ),
        .i_iic_en           ( i2c_apb_bus_d1[6]     ),
        .i_wrrd             ( i2c_apb_bus_d1[7]     ),
        .i_data             ( i2c_apb_bus_d1[15:8]  ),
        .o_rd_vld           ( i2c_apb_bus_c1[9]     ),
        .o_data             ( i2c_apb_bus_c1[8:1]   ),
        .o_iic_ack          ( i2c_apb_bus_c1[10]    ),
        .io_apb_iic_scl     ( io_cif_iic_scl        ),
        .io_apb_iic_sda     ( io_cif_iic_sda        )
    );
//

assign                         temp_rd_flash_ctrl_en = read_low_en | read_high_en | read_temp_en | read_guogai_en;
temperature_ddr_ctrl  temperature_ddr_ctrl_inst (
    .clk                                (clk_display               ),
    .rst_n                              (rst_n                     ),
    .temp_range                         (temp_range                ),
    .ddr_init_done                      (mem_init_done             ),

    .flash_load_en                      (flash2ddr_load            ),
    .flash_wr_en                        (flash_done                ),

    .send_low_cmd                       ((cmd_data == 1) ? flash_rd_en : 0),
    .send_high_cmd                      ((cmd_data == 2) ? flash_rd_en : 0),
    .send_guogai_cmd                    ((update_type == 8'h5a) ? flash_rd_en : 0),

    .update_temp_param                  (usb_cmd_flag   ),
    // .write_temp_en                      (usb_cmd_flag   ),
    .temp_cmd                           (usb_cmd        ),
    .temp_param_in                      (usb_data       ),

    .temp_rd_data_valid                 (flash_rd_data_vld         ),
    .temp_rd_data                       (flash_rd_data             ),
    .temp_param_req                     (temp_param_req            ),
    
    .o_shutterCorCoef                   (shutterCorCoef             ),//                 
    .o_LensCorCoef                      (LensCorCoef                ),//      
    .o_Compensate_flag                  (Compensate_flag            ),//      
    .o_Emiss_Humidy                     (Emiss_Humidy               ),//      
    .o_EnTemp_Distance                  (EnTemp_Distance            ),//      
    .o_Transs                           (Transs                     ),//      
    .o_near_kf                          (near_kf                    ),//      
    .o_near_b                           (near_b                     ),//      
    .o_far_kf                           (far_kf                     ),//      
    .o_far_b                            (far_b                      ),//      
    .o_pro_kf                           (pro_kf                     ),//      
    .o_pro_b                            (pro_b                      ),//      
    .o_pro_kf_far                       (pro_kf_far                 ),//      
    .o_pro_b_far                        (pro_b_far                  ),//      
    .o_reflectTemp                      (reflectTemp                ),//
    .o_x_fusion_offset                  (x_fusion_offset            ),
    .o_y_fusion_offset                  (y_fusion_offset            ),
    .o_fusion_amp_factor                (fusion_amp_factor          ),

    .read_low_en                        (read_low_en                ),
    .read_high_en                       (read_high_en               ),
    .read_guogai_en                     (read_guogai_en             ),
    .send_done_pulse                    (send_done_pulse            ),
    .read_temp_en                       (read_temp_en               ),
    .write_temp_en_out                  (write_temp_en              ),
    .temp_param_out                     (temp_param_out             ),
    .temp_param_valid                   (temp_param_valid           )
);

// assign  mcu_en          = write_temp_en ? 1                 : flash_update_en ? flash_up_start      : temp_rd_flash_ctrl_en ? 1 :  apb_en_bus0[3];
assign  mcu_en          = write_temp_en | temp_rd_flash_ctrl_en ? 1                 : flash_update_en ? flash_up_start: apb_en_bus0[3];
assign  mcu_flash_addrs = write_temp_en ? 'h300000          : flash_update_en ? flash_update_addr   : temp_rd_flash_ctrl_en ? read_low_en ? 'h100000: read_high_en ? 'h200000 : read_guogai_en ? 'h310000 : 'h300000 :flash_addrs;
// assign  mcu_ddr_addrs   = write_temp_en ? mem_update_addrs  : flash_update_en | temp_rd_flash_ctrl_en ? mem_update_addrs : mem_addrs;
assign  mcu_ddr_addrs   = write_temp_en | flash_update_en | temp_rd_flash_ctrl_en ? mem_update_addrs  :  mem_addrs;
// assign  mcu_option      = write_temp_en ? 1                 : flash_update_en ? 1 : temp_rd_flash_ctrl_en ? 0 : apb_en_bus0[0];
assign  mcu_option      = write_temp_en | flash_update_en? 1 : temp_rd_flash_ctrl_en ? 0 : apb_en_bus0[0];
assign  mcu_lens        = write_temp_en ? ('h400)           : flash_update_en ? (usb_update_lens >> 1) : temp_rd_flash_ctrl_en ? read_temp_en ? ('h400) : (update_lens >> 1):  flash_data_lens;////4D4a0 4D49D 316573 41540 267573
// assign  mcu_ctrl_sel    = write_temp_en ? 1                 : flash_update_en ? 1 : temp_rd_flash_ctrl_en ? 1 : risv_wr_bus0[3:0];
assign  mcu_ctrl_sel    = write_temp_en | flash_update_en | temp_rd_flash_ctrl_en ? 1 : risv_wr_bus0[3:0];


// assign  mcu_en          = write_temp_en ? 1 : flash_update_en ? flash_up_start      : temp_rd_flash_ctrl_en ? 1 :  apb_en_bus0[3];
// assign  mcu_flash_addrs = write_temp_en ? 'h300000  : flash_update_en ? flash_update_addr   : temp_rd_flash_ctrl_en ? read_low_en ? 'h100000: read_high_en ? 'h200000 : 'h300000 :flash_addrs;
// assign  mcu_ddr_addrs   = write_temp_en ? mem_update_addrs  : flash_update_en | temp_rd_flash_ctrl_en ? mem_update_addrs : mem_addrs;
// assign  mcu_option      = write_temp_en ? 1      : flash_update_en ? 1 : temp_rd_flash_ctrl_en ? 0 : apb_en_bus0[0];
// assign  mcu_lens        = write_temp_en ? ('h400) : flash_update_en ? (usb_update_lens >> 1) : temp_rd_flash_ctrl_en ? read_temp_en ? ('h400) : (update_lens >> 1): flash_data_lens;////4D4a0 4D49D 316573 41540 267573
// assign  mcu_ctrl_sel    = write_temp_en ? 1  : flash_update_en ? 1 : temp_rd_flash_ctrl_en ? 1 : risv_wr_bus0[3:0];

assign  rd_1_req                = flash_update_en   ? flash_update_data_req : 0;
assign  temp_param_req          = write_temp_en     ? flash_update_data_req : 0;
assign  flash_update_data_vld   = write_temp_en     ? temp_param_valid      : rd_1_data_vld;
assign  flash_update_data       = write_temp_en     ? temp_param_out        : rd_1_data;
//
//FLASH
flash_top flash_top_inst (
    //glb
    .i_clk                              (clk_display               ),//input                           
    .i_rst_n                            (rst_n                     ),//input                             
    .i_mem_busyn                        (mem_init_done             ),//input                                  
    .i_mcu_en                           (mcu_en                    ),//input   
    .i_mcu_option                       (mcu_option                ),//input   0读flash 1写         APB_REG_ADDR_EN_BUS0      
    .i_mcu_ctrl_sel                     (mcu_ctrl_sel              ),//input   [3:0]    APB_REG_ADDR_RD_BUS0  

    .i_mcu_flash_addrs                  (mcu_flash_addrs           ),//input   [31:0]                  
    .i_mcu_ddr_addrs                    (mcu_ddr_addrs             ),//input   [31:0]                  
    .i_mcu_lens                         (mcu_lens                  ),//input   [31:0]                

    .o_flash2ddr                        (flash2ddr_load            ),//output  reg                     
    .o_ddr2flash                        (ddr2flash_status          ),//output  reg                 

    .o_param_load                       (param_load                ),//output  reg                     
    .o_flash_rd_data                    (flash_rd_data             ),//output        [15:0]            
    .o_flash_rd_data_vld                (flash_rd_data_vld         ),//output                                 
    .o_mem_wr_start                     (mem_wr_flash_start        ),//output  reg                     
    .o_mem_wr_addrs                     (mem_wr_flash_addrs        ),//output  reg   [31:0]            
    .o_mem_wr_lens                      (mem_wr_flash_lens         ),//output  reg   [31:0]

    .i_mem_rd_data                      (flash_update_data         ),//input         [15:0]            
    .i_mem_rd_data_vld                  (flash_update_data_vld     ),//input                           
    .o_mem_rd_start                     (                          ),//output  reg                     
    .o_mem_rd_addrs                     (                          ),//output  reg   [31:0]            
    .o_mem_rd_lens                      (                          ),//output  reg   [31:0]     
    .o_data_req                         (flash_update_data_req     ),//output  
    
    .i_param_data                       (                          ),//input         [15:0]            
    .i_param_data_vld                   (                          ),//input                    

    .o_flash_done                       (flash_done),
    .o_busy                             (risv_rd_bus0[0]           ),//output  reg                     
    .O_flash_ck                         (O_flash_ck                ),//output                          
    .O_flash_cs_n                       (O_flash_cs_n              ),//output                          
    .IO_flash_do                        (IO_flash_do               ),//inout                           
    .IO_flash_di                        (IO_flash_di               ),//output                          
    .flash_id                           (                          ) //output                                             
    
);

para_load para_load_inst (
    .i_clk                   (clk_display           ),
    .i_rst_n                 (rst_n                 ),
    .i_param_load            (param_load            ),
    .i_update                (sensor_update_param   ),
    .i_option                (apb_en_bus0[0]        ),
    .i_data                  (flash_rd_data         ),
    .i_data_vld              (flash_rd_data_vld     ),
    .i_data_req              (),
    .o_data                  (),
    .o_data_vld              (),                      
    .i_apb32bus0             (param_rd_apb32bus0    ),
    .o_apb32bus0             (param_wr_apb32bus0    )  
);

endmodule