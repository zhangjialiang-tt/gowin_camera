module usb_top #(
    parameter WB_DATA_WIDTH = 32,
    parameter WB_ADDR_WIDTH = 32,
    parameter               FIFO_INIT_WAIT_TIME = 150           ,
    parameter               FRAME_RATE          = 30            ,
    parameter               TIME_CNT            = 60000         ,
    parameter               HEAD_LENGTH         = 32            ,
    parameter               IR_LENGTH           = 256*192       ,
    parameter               TV_LENGTH           = 800*600       ,
    parameter               PARAM_LENGHT        = 256           ,
    parameter               VERSIONBCD          = 16'h0200      ,
    parameter               PRODUCTSTR          = "ZC23A"       ,
    parameter               PRODUCTSTR_LEN      = 5             ,
    parameter               SERIALSTR           = "ZC23A01"     ,
    parameter               SERIALSTR_LEN       = 7             ,
    parameter               SERIALSTR6          = "com.guidesensmart.ZC23A",
    parameter               SERIALSTR6_LEN      = 23            ,
    parameter               PARAM_L_LENGTH      = 535146        ,//字节 低温参数包长度
    parameter               PARAM_H_LENGTH      = 633146        ,//字节 高温参数包长度
    parameter               PARAM_L_TOTAL_LEN   = 540672        ,//字节 低温参数包长度
    parameter               PARAM_H_TOTAL_LEN   = 638976         //字节 
)(
    input                       i_usb_fclk      ,   //  480MHz
    input                       i_usb_user_clk  ,   //  60MHz
    input                       i_rpll_1_lock   ,
    input                       i_rst_n         ,

    input                       i_wb_clk,
    input                       i_wb_rst_n,
    input                       i_wb_cyc,
    input                       i_wb_stb,
    input                       i_wb_we,
    input   [WB_ADDR_WIDTH-1:0] i_wb_adr,
    input   [WB_DATA_WIDTH-1:0] i_wb_dat, // Data from CPU
    input   [3:0]               i_wb_sel,
    output  [WB_DATA_WIDTH-1:0] o_wb_dat, // Data to CPU
    output                      o_wb_ack,

    output  wire                o_debug_uart_tx ,

    input                       i_pclk          ,
    input                       i_ir_init_done  ,
    input           [15:0]      i_head_data     ,
    input                       i_head_data_vld ,
    output                      o_head_data_req ,
    input           [15:0]      i_ir_data       ,
    input                       i_ir_data_vld   ,
    input                       i_ir_data_ready , 
    output                      o_ir_data_req   ,
    input           [15:0]      i_tv_data       ,
    input                       i_tv_data_vld   ,
    output                      o_tv_data_req   ,
    input                       i_tv_data_ready ,
    input           [15:0]      i_param_data    ,
    input                       i_param_data_vld,
    output                      o_param_req     ,
    output                      o_start         ,

    output  wire                o_shutter_on_en ,
    output  wire                o_shutter_off_en,
    output  wire    [7:0]       o_temp_range    ,
    output  wire                o_cmd_occ_en    ,

    input                       i_usb_dxp       ,
    input                       i_usb_dxn       ,
    output  wire                o_usb_dxp       ,
    output  wire                o_usb_dxn       ,
    input                       i_usb_rxdp      ,
    input                       i_usb_rxdn      ,
    output  wire                o_usb_pullup_en ,
    inout                       io_usb_term_dp  ,
    inout                       io_usb_term_dn  ,

    input                       i_param_load    ,    
    input                       i_flash_rd_data_ready,
    input                       i_flash_rd_data_vld,
    input          [15:0]       i_flash_rd_data ,
    output wire    [7:0]        o_update_data   ,
    output wire    [7:0]        o_cmd_data,
    output wire                 o_update_vld    ,
    output wire    [31:0]       o_update_lens   , 
    output         [7:0]        o_update_type   ,
    output                      o_flash_rd_en     ,
    output                      o_ddr_rd_start  ,
    output                      o_ddr_rd_en     ,
    input                       i_ddr2flash_status,
    
    output  wire   [15:0]       o_usb_cmd       ,
    output  wire   [15:0]       o_usb_data      ,
    output  wire                o_usb_cmd_flag  ,
    output  wire                o_usb_cmd_en    ,
    inout   wire                io_mfi_iic_scl  ,
    inout   wire                io_mfi_iic_sda   
);
//  信号定义
    // USB UTMI
    wire    [7:0]       utmi_dataout            ;
    wire                utmi_txvalid            ;
    wire                utmi_txready            ;
    wire    [7:0]       utmi_datain             ;
    wire                utmi_rxactive           ;
    wire                utmi_rxvalid            ;
    wire                utmi_rxerror            ;
    wire    [1:0]       utmi_linestate          ;
    wire    [1:0]       utmi_opmode             ;
    wire    [1:0]       utmi_xcvrselect         ;
    wire                utmi_termselect         ;
    wire                utmi_reset              ;
    // Interface Setting
    wire    [7:0]       inf_alter_i             ;
    wire    [7:0]       inf_alter_o             ;
    wire    [7:0]       inf_sel_o               ;
    wire                inf_set_o               ;
    reg     [7:0]       interface0_alter        ;
    reg     [7:0]       interface1_alter        ;
    // USB Descriptor
    wire    [7:0]       descrom_rdata           ;
    wire    [15:0]      descrom_raddr           ;
    wire    [7:0]       desc_index              ;
    wire    [7:0]       desc_type               ;
    wire    [15:0]      desc_dev_addr           ;
    wire    [15:0]      desc_dev_len            ;
    wire    [15:0]      desc_qual_addr          ;
    wire    [15:0]      desc_qual_len           ;
    wire    [15:0]      desc_fscfg_addr         ;
    wire    [15:0]      desc_fscfg_len          ;
    wire    [15:0]      desc_hscfg_addr         ;
    wire    [15:0]      desc_hscfg_len          ;
    wire    [15:0]      desc_oscfg_addr         ;
    wire    [15:0]      desc_strlang_addr       ;
    wire    [15:0]      desc_strvendor_addr     ;
    wire    [15:0]      desc_strvendor_len      ;
    wire    [15:0]      desc_strproduct_addr    ;
    wire    [15:0]      desc_strproduct_len     ;
    wire    [15:0]      desc_strserial_addr     ;
    wire    [15:0]      desc_strserial_len      ;
    wire                desc_have_strings       ;
    // USB TX
    wire    [7:0]       usb_txdat               ;
    wire    [11:0]      usb_txdat_len           ;
    wire                usb_txcork              ;   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    wire                usb_txpop               ;
    wire                usb_txact               ;
    wire                user_usb_video_txcork   ;   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    wire    [11:0]      user_usb_video_txlen    ;
    wire    [7:0]       user_usb_video_txdat    ;
    wire                user_usb_iap2_txcork    ;   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    wire    [11:0]      user_usb_iap2_txlen     ;
    wire    [7:0]       user_usb_iap2_txdat     ;

    wire                user_usb_cmd_txcork    ;   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    wire    [11:0]      user_usb_cmd_txlen     ;
    wire    [7:0]       user_usb_cmd_txdat     ;
    // USB RX
    wire    [7:0]       usb_rxdat               ;
    wire                usb_rxval               ;
    wire                usb_rxact               ;
    wire                usb_rxrdy               ;
    wire                user_usb_rxrdy          ;
    // 配置数据活跃信号
    wire                setup_active            ;
    // 端点选择
    wire    [3:0]       endpt_sel               ;
    reg                 endpt_video             ;
    reg                 endpt_iap2              ;
    // USB 初始化
    wire                os_type                 ;   //  0: 苹果；1: 安卓

//  DEBUG
    reg                 debug_fifo_wr_en        ;
    reg     [7:0]       debug_fifo_wr_data      ;
    wire                debug_fifo_empty        ;
    reg                 debug_fifo_rd_en        ;
    wire    [7:0]       debug_fifo_rd_data      ;
    wire                uart_busy               ;
    reg                 usb_txact_r1            ;
    reg                 usb_rxact_r1            ;

    debug_fifo u_debug_fifo (
        .Reset  ( ~i_rst_n              ),

        .WrClk  ( i_usb_user_clk        ),
        .Full   (                       ),
        .WrEn   ( debug_fifo_wr_en      ),
        .Data   ( debug_fifo_wr_data    ),

        .RdClk  ( i_usb_user_clk        ),
        .Empty  ( debug_fifo_empty      ),
        .RdEn   ( debug_fifo_rd_en      ),
        .Q      ( debug_fifo_rd_data    ) 
    );

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            usb_txact_r1 <= 1'd0;
            usb_rxact_r1 <= 1'd0;
        end
        else begin
            usb_txact_r1 <= usb_txact;
            usb_rxact_r1 <= usb_rxact;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            debug_fifo_wr_en <= 1'd0;
            debug_fifo_wr_data <= 8'd0;
        end
        // else if (~usb_txact_r1 && usb_txact) begin
        //     debug_fifo_wr_en <= 1'd1;
        //     debug_fifo_wr_data <= 8'hAA;
        // end
        // else if (~usb_rxact_r1 && usb_rxact) begin
        //     debug_fifo_wr_en <= 1'd1;
        //     debug_fifo_wr_data <= 8'hBB;
        // end
        else if (usb_rxval) begin
            debug_fifo_wr_en <= 1'd1;
            debug_fifo_wr_data <= usb_rxdat;
        end
        // else if (usb_txpop) begin
        //     debug_fifo_wr_en <= 1'd1;
        //     debug_fifo_wr_data <= usb_txdat;
        // end
        else begin
            debug_fifo_wr_en <= 1'd0;
            debug_fifo_wr_data <= debug_fifo_wr_data;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            debug_fifo_rd_en <= 1'd0;
        end
        else if (~uart_busy && ~debug_fifo_rd_en && ~debug_fifo_empty) begin
            debug_fifo_rd_en <= 1'd1;
        end
        else begin
            debug_fifo_rd_en <= 1'd0;
        end
    end

    uart_transfer #(
        .CLK_FREQUENCY      ( 60_000_000            ),  //          模块工作时钟
        .BAUD_RATE          ( 115_200               ),  //          波特率
        .CHECK_MODE         ( "NO"                  )   //          奇偶校验，NO / ODD / EVEN
    ) u_uart_transfer_to_arm (
        .i_clk              ( i_usb_user_clk        ),
        .i_rst_n            ( i_rst_n               ),
        .o_busy             ( uart_busy             ),
        .i_tx_en            ( debug_fifo_rd_en      ),
        .i_tx_data          ( debug_fifo_rd_data    ),
        .o_txd              ( o_debug_uart_tx       ) 
    );
wire                send_end;
wire                state_rst;
wire                txpktfin_o;
//  USB 收发控制
usb_tx_ctrl_v10 #(
    .FIFO_INIT_WAIT_TIME  (FIFO_INIT_WAIT_TIME),
    .TIME_CNT             (TIME_CNT           ),
    .FRAME_RATE           (FRAME_RATE         ),
    .HEAD_LENGTH          (HEAD_LENGTH        ),
    .IR_LENGTH            (IR_LENGTH          ),
    .TV_LENGTH            (TV_LENGTH          ),
    .PARAM_LENGHT         (PARAM_LENGHT       ),
    .PARAM_L_LENGTH       (PARAM_L_LENGTH     ),
    .PARAM_H_LENGTH       (PARAM_H_LENGTH     ),
    .PARAM_L_TOTAL_LEN    (PARAM_L_TOTAL_LEN  ),
    .PARAM_H_TOTAL_LEN    (PARAM_H_TOTAL_LEN  ) 
)usb_tx_ctrl_v10_inst (
    .i_clk                       (i_usb_user_clk            ),        //input                           
    .i_rst_n                     (i_rst_n                   ),        //input                           
    .i_pclk                      (i_pclk                    ),        //input         
    .i_ir_init_done              (i_ir_init_done            ),        //input                 
    .i_head_data                 (i_head_data               ),        //input           [15:0]          
    .i_head_data_vld             (i_head_data_vld           ),        //input                           
    .o_head_data_req             (o_head_data_req           ),        //output     reg                  
    .i_ir_data                   (i_ir_data                 ),        //input           [15:0]          
    .i_ir_data_vld               (i_ir_data_vld             ),        //input                           
    .i_ir_data_ready             (i_ir_data_ready           ),        //input                            
    .o_ir_data_req               (o_ir_data_req             ),        //output     reg                  
    .i_tv_data                   (i_tv_data                 ),        //input           [15:0]          
    .i_tv_data_vld               (i_tv_data_vld             ),        //input                           
    .o_tv_data_req               (o_tv_data_req             ),        //output     reg                  
    .i_tv_data_ready             (i_tv_data_ready           ),        //input                           
    .i_param_data                (i_param_data              ),        //input           [15:0]          
    .i_param_data_vld            (i_param_data_vld          ),        //input                           
    .o_param_req                 (o_param_req               ),        //output     reg                  
    .o_start                     (o_start                   ),        //output     reg    

    .i_param_load                (i_param_load              ),
    .i_flash_rd_data_ready       (i_flash_rd_data_ready     ),
    .i_flash_rd_data_vld         (i_flash_rd_data_vld       ),
    .i_flash_rd_data             (i_flash_rd_data           ),
    .i_update_type               (o_update_type             ),
    .i_cmd_data                  (o_cmd_data                ),
    .o_flash_rd_en               (o_flash_rd_en             ),
    .o_ddr_rd_start              (o_ddr_rd_start            ),
    .o_ddr_rd_en                 (o_ddr_rd_en               ),
    .o_send_end                  (send_end                  ),
    .i_state_rst                 (state_rst                 ),

    .i_os_type                   (os_type                   ),        //input                           
    .i_endpt                     (endpt_sel                 ),        //input           [3:0]           
    .o_txdat                     (user_usb_video_txdat      ),        //output  wire    [7:0]           
    .o_txdat_len                 (user_usb_video_txlen      ),        //output  wire    [11:0]          
    .o_txcork                    (user_usb_video_txcork     ),        //output  reg                        //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    .i_txpop                     (usb_txpop                 ),        //input                           
    .i_txact                     (usb_txact                 ),         //input   
    .i_txpktfin_o                (txpktfin_o                )                        
);

wire        cmd_send_en ;
usb_cmd_feedback  usb_cmd_feedback (
    .clk                                (i_usb_user_clk            ),
    .rst_n                              (i_rst_n                   ),
    .i_txact                            (usb_txact                 ),
    .i_txpop                            (usb_txpop                 ),
    .i_txpktfin_o                       (txpktfin_o                ),
    .i_update_type                      (o_update_type             ),
    .upgrade_status                     (i_ddr2flash_status        ),
    .o_cmd_en                           (cmd_send_en                  ),

    .o_txdat                            (user_usb_cmd_txdat        ),
    .o_txdat_len                        (user_usb_cmd_txlen        ),
    .o_txcork                           (user_usb_cmd_txcork       ),
    .tx_busy                            (                   ) 
  );

    // usb_tx_ctrl u_usb_tx_ctrl (
    //     .i_clk                      ( i_usb_user_clk        ),
    //     .i_rst_n                    ( i_rst_n               ),

    //     .i_pclk                     ( i_pclk                ),
    //     .i_vs                       ( i_vs                  ),
    //     .i_hs                       ( i_hs                  ),
    //     .i_data                     ( i_data                ),

    //     .i_os_type                  ( os_type               ),

    //     .i_endpt                    ( endpt_sel             ),
    //     .o_txdat                    ( user_usb_video_txdat  ),
    //     .o_txdat_len                ( user_usb_video_txlen  ),
    //     .o_txcork                   ( user_usb_video_txcork ),
    //     .i_txpop                    ( usb_txpop             ),
    //     .i_txact                    ( usb_txact             ) 
    // );

    wb_usb_bridge #(
        .DATA_WIDTH(WB_DATA_WIDTH),
        .ADDR_WIDTH(WB_ADDR_WIDTH)
    ) u_wb_usb_bridge (
        .i_usb_clk          ( i_usb_user_clk        ), // 使用 USB 用户时钟
        .i_usb_rst_n        ( i_rst_n               ),

        // Wishbone Interface
        .i_wb_clk       ( i_wb_clk        ), // 使用 USB 用户时钟
        .i_wb_rst_n     ( i_wb_rst_n               ),
        .i_wb_cyc       ( i_wb_cyc              ),
        .i_wb_stb       ( i_wb_stb              ),
        .i_wb_we        ( i_wb_we               ),
        .i_wb_adr       ( i_wb_adr              ),
        .i_wb_dat       ( i_wb_dat              ),
        .i_wb_sel       ( i_wb_sel              ),
        .o_wb_dat       ( o_wb_dat              ),
        .o_wb_ack       ( o_wb_ack              ),

        // USB Interface
        .i_usb_rxact        ( usb_rxact             ),
        .i_usb_rxval        ( usb_rxval             ),
        .i_usb_rxdat        ( usb_rxdat             ),
        .i_endpt_sel    ( endpt_sel             ),

        .i_txact        ( usb_txact             ),
        .i_txpop        ( usb_txpop             ),
        .o_txdat_len    ( user_usb_iap2_txlen   ),
        .o_txcork       ( user_usb_iap2_txcork  ),
        .o_txdat        ( user_usb_iap2_txdat   ),
        .o_txval        (    ),
        .o_rxrdy        (    )

        ,.o_os_type      (os_type               ) // 控制 OS 类型
    );
    // assign os_type = 1'b1;
    // mfi_top u_mfi_top (
    //     .i_usb_user_clk             ( i_usb_user_clk        ),
    //     .i_rst_n                    ( i_rst_n               ),

    //     .i_endpt                    ( endpt_sel             ),

    //     .i_usb_rxact                ( usb_rxact             ),
    //     .i_usb_rxval                ( usb_rxval             ),
    //     .i_usb_rxdat                ( usb_rxdat             ),

    //     .o_txdat_len                ( user_usb_iap2_txlen   ),
    //     .o_txcork                   ( user_usb_iap2_txcork  ),
    //     .i_txact                    ( usb_txact             ),
    //     .i_txpop                    ( usb_txpop             ),
    //     .o_txdat                    ( user_usb_iap2_txdat   ),

    //     .o_os_type                  ( os_type               ),

    //     .io_mfi_iic_scl             ( io_mfi_iic_scl        ),
    //     .io_mfi_iic_sda             ( io_mfi_iic_sda        ) 
    // );
    
    assign usb_txcork     = ((~os_type && endpt_sel == 4'd1) || (os_type && endpt_sel == 4'd2)) ? cmd_send_en ? user_usb_cmd_txcork: user_usb_video_txcork : ((~os_type && endpt_sel == 4'd2) ? user_usb_iap2_txcork : 1'd0 );
    assign usb_txdat      = ((~os_type && endpt_sel == 4'd1) || (os_type && endpt_sel == 4'd2)) ? cmd_send_en ? user_usb_cmd_txdat : user_usb_video_txdat  : ((~os_type && endpt_sel == 4'd2) ? user_usb_iap2_txdat  : 8'd0 );
    assign usb_txdat_len  = ((~os_type && endpt_sel == 4'd1) || (os_type && endpt_sel == 4'd2)) ? cmd_send_en ? user_usb_cmd_txlen : user_usb_video_txlen  : ((~os_type && endpt_sel == 4'd2) ? user_usb_iap2_txlen  : 12'd0);
    assign user_usb_rxrdy = 1'd1;
    assign usb_rxrdy      = user_usb_rxrdy;

//  指令解析
    // usb_cmd_parsing u_usb_cmd_parsing (
    //     .i_usb_user_clk             ( i_usb_user_clk        ),
    //     .i_rst_n                    ( i_rst_n               ),

    //     .i_endpt_sel                ( endpt_sel             ),
    //     .i_usb_rxact                ( usb_rxact             ),
    //     .i_usb_rxval                ( usb_rxval             ),
    //     .i_usb_rxdat                ( usb_rxdat             ),

    //     .i_os_type                  ( os_type               ),

    //     .o_cmd_shutter_on_en        ( o_shutter_on_en       ),
    //     .o_cmd_shutter_off_en       ( o_shutter_off_en      ),
    //     .o_cmd_temp_range           ( o_temp_range          ),
    //     .o_cmd_occ_en               ( o_cmd_occ_en          ) 
    // );
usb_cmd_parsing usb_cmd_parsing_inst (           
    .i_usb_user_clk          (i_usb_user_clk    ),        //input                       
    .i_rst_n                 (i_rst_n           ),        //input                       
    .i_endpt_sel             (endpt_sel         ),        //input           [3:0]       
    .i_usb_rxact             (usb_rxact         ),        //input                       
    .i_usb_rxval             (usb_rxval         ),        //input                       
    .i_usb_rxdat             (usb_rxdat         ),        //input           [7:0]       
    .i_os_type               (os_type           ),        //input 

    .o_data_update           (o_update_data     ),  
    .o_data_update_vld       (o_update_vld      ),
    .o_update_lens           (o_update_lens     ),
    .o_update_type           (o_update_type     ),  
    .o_cmd_data              (o_cmd_data        ),
    .i_update_end            (send_end          ),
    .o_state_rst             (state_rst         ),

    .o_usb_cmd_flag          (o_usb_cmd_flag    ),
    .o_cmd                   (o_usb_cmd         ),        //output  reg     [15:0]      
    .o_data                  (o_usb_data        ),        //output  reg     [15:0]      
    .o_usb_cmd_en            (o_usb_cmd_en      )         //output  reg                     
);

//  usb_device_controller
USB_Device_Controller_Top u_usb_device_controller (
        .clk_i                      ( i_usb_user_clk        ),
        .reset_i                    ( ~i_rst_n              ),

        .usbrst_o                   (                       ),
        .highspeed_o                (                       ),
        .suspend_o                  (                       ),
        .online_o                   (                       ),

        .txdat_i                    ( usb_txdat             ),
        .txval_i                    ( 1'b0                  ),  //  发送数据有效信号（仅在控制端点时启用其他时候为 0）
        .txdat_len_i                ( usb_txdat_len         ),
        .txcork_i                   ( usb_txcork            ),
        .txiso_pid_i                ( 4'b0011               ),
        .txpop_o                    ( usb_txpop             ),
        .txact_o                    ( usb_txact             ),  // 1 表示进入发数据状态
        .txpktfin_o                 ( txpktfin_o            ),

        .rxdat_o                    ( usb_rxdat             ),
        .rxval_o                    ( usb_rxval             ),
        .rxact_o                    ( usb_rxact             ),
        .rxrdy_i                    ( 1'd1                  ),  //  ( usb_rxrdy             ),
        .rxpktval_o                 (                       ),

        .setup_o                    ( setup_active          ),  //  数据活跃指示信号，高电平时表示 USB 配置数据处于活跃状态。
        .endpt_o                    ( endpt_sel             ),  //  端点选择指示信号，表示 USB 当前通信端点。

        .sof_o                      (                       ),
        .inf_alter_i                ( inf_alter_i           ),
        .inf_alter_o                ( inf_alter_o           ),
        .inf_sel_o                  ( inf_sel_o             ),
        .inf_set_o                  ( inf_set_o             ),

        .descrom_rdata_i            ( descrom_rdata         ),
        .descrom_raddr_o            ( descrom_raddr         ),
        .desc_index_o               ( desc_index            ),
        .desc_type_o                ( desc_type             ),
        .desc_dev_addr_i            ( desc_dev_addr         ),
        .desc_dev_len_i             ( desc_dev_len          ),
        .desc_qual_addr_i           ( desc_qual_addr        ),
        .desc_qual_len_i            ( desc_qual_len         ),
        .desc_fscfg_addr_i          ( desc_fscfg_addr       ),
        .desc_fscfg_len_i           ( desc_fscfg_len        ),
        .desc_hscfg_addr_i          ( desc_hscfg_addr       ),
        .desc_hscfg_len_i           ( desc_hscfg_len        ),
        .desc_oscfg_addr_i          ( desc_oscfg_addr       ),
        .desc_hidrpt_addr_i         ( 16'd0                 ),
        .desc_hidrpt_len_i          ( 16'd0                 ),
        .desc_bos_addr_i            ( 16'd0                 ),
        .desc_bos_len_i             ( 16'd0                 ),
        .desc_strlang_addr_i        ( desc_strlang_addr     ),
        .desc_strvendor_addr_i      ( desc_strvendor_addr   ),
        .desc_strvendor_len_i       ( desc_strvendor_len    ),
        .desc_strproduct_addr_i     ( desc_strproduct_addr  ),
        .desc_strproduct_len_i      ( desc_strproduct_len   ),
        .desc_strserial_addr_i      ( desc_strserial_addr   ),
        .desc_strserial_len_i       ( desc_strserial_len    ),
        .desc_have_strings_i        ( desc_have_strings     ),

        .utmi_dataout_o             ( utmi_dataout          ),
        .utmi_txvalid_o             ( utmi_txvalid          ),
        .utmi_txready_i             ( utmi_txready          ),
        .utmi_datain_i              ( utmi_datain           ),
        .utmi_rxactive_i            ( utmi_rxactive         ),
        .utmi_rxvalid_i             ( utmi_rxvalid          ),
        .utmi_rxerror_i             ( utmi_rxerror          ),
        .utmi_linestate_i           ( utmi_linestate        ),
        .utmi_opmode_o              ( utmi_opmode           ),
        .utmi_xcvrselect_o          ( utmi_xcvrselect       ),
        .utmi_termselect_o          ( utmi_termselect       ),
        .utmi_reset_o               ( utmi_reset            ) 
    );

//  Interface Setting
    assign inf_alter_i = (inf_sel_o == 0) ? interface0_alter : (inf_sel_o == 1) ? interface1_alter : 8'd0;

    always@(posedge i_usb_user_clk, negedge i_rst_n) begin
        if (~i_rst_n) begin
            interface0_alter <= 'd0;
            interface1_alter <= 'd0;
        end
        else begin
            if (inf_set_o) begin
                if (inf_sel_o == 0) begin
                    interface0_alter <= inf_alter_o;
                end
                else if (inf_sel_o == 1) begin
                    interface1_alter <= inf_alter_o;
                end
            end
        end
    end

//  USB Device descriptor
    usb_descriptor #(
        .VENDORID                   ( 16'h0525              ),
        .PRODUCTID                  ( 16'hA4A0              ),
        .VERSIONBCD                 ( 16'h0200              ),
        .HSSUPPORT                  ( 1                     ),
        .SELFPOWERED                ( 1                     ),
        .PRODUCTSTR                 ( PRODUCTSTR            ),
        .PRODUCTSTR_LEN             ( PRODUCTSTR_LEN        ),
        .SERIALSTR                  ( SERIALSTR             ),
        .SERIALSTR_LEN              ( SERIALSTR_LEN         ),
        .SERIALSTR6                 ( SERIALSTR6            ),
        .SERIALSTR6_LEN             ( SERIALSTR6_LEN        )
    ) u_usb_descriptor (
        .i_clk                      ( i_usb_user_clk        ),
        .i_rst_n                    ( i_rst_n               ),

        .i_pid                      ( 16'd0                 ),
        .i_vid                      ( 16'd0                 ),

        .i_endpt_sel                ( endpt_sel             ),
        .i_usb_rxval                ( usb_rxval             ),
        .i_usb_rxdat                ( usb_rxdat             ),

        .i_descrom_raddr            ( descrom_raddr         ),
        .o_descrom_rdat             ( descrom_rdata         ),
        .o_desc_dev_addr            ( desc_dev_addr         ),
        .o_desc_dev_len             ( desc_dev_len          ),
        .o_desc_qual_addr           ( desc_qual_addr        ),
        .o_desc_qual_len            ( desc_qual_len         ),
        .o_desc_fscfg_addr          ( desc_fscfg_addr       ),
        .o_desc_fscfg_len           ( desc_fscfg_len        ),
        .o_desc_hscfg_addr          ( desc_hscfg_addr       ),
        .o_desc_hscfg_len           ( desc_hscfg_len        ),
        .o_desc_oscfg_addr          ( desc_oscfg_addr       ),
        .o_desc_strlang_addr        ( desc_strlang_addr     ),
        .o_desc_strvendor_addr      ( desc_strvendor_addr   ),
        .o_desc_strvendor_len       ( desc_strvendor_len    ),
        .o_desc_strproduct_addr     ( desc_strproduct_addr  ),
        .o_desc_strproduct_len      ( desc_strproduct_len   ),
        .o_desc_strserial_addr      ( desc_strserial_addr   ),
        .o_desc_strserial_len       ( desc_strserial_len    ),
        .o_descrom_have_strings     ( desc_have_strings     ) 
    );

//  USB SoftPHY
    USB2_0_SoftPHY_Top usb2_0_softphy_inst (
        .clk_i                      ( i_usb_user_clk    ),
        .rst_i                      ( ~i_rst_n         ),//utmi_reset
        .fclk_i                     ( i_usb_fclk        ),
        .pll_locked_i               ( i_rpll_1_lock     ),

        .utmi_data_out_i            ( utmi_dataout      ),
        .utmi_txvalid_i             ( utmi_txvalid      ),
        .utmi_op_mode_i             ( utmi_opmode       ),
        .utmi_xcvrselect_i          ( utmi_xcvrselect   ),
        .utmi_termselect_i          ( utmi_termselect   ),
        .utmi_data_in_o             ( utmi_datain       ),
        .utmi_txready_o             ( utmi_txready      ),
        .utmi_rxvalid_o             ( utmi_rxvalid      ),
        .utmi_rxactive_o            ( utmi_rxactive     ),
        .utmi_rxerror_o             ( utmi_rxerror      ),
        .utmi_linestate_o           ( utmi_linestate    ),

        .usb_dxp_i                  ( i_usb_dxp         ),
        .usb_dxn_i                  ( i_usb_dxn         ),
        .usb_dxp_o                  ( o_usb_dxp         ),
        .usb_dxn_o                  ( o_usb_dxn         ),
        .usb_rxdp_i                 ( i_usb_rxdp        ),
        .usb_rxdn_i                 ( i_usb_rxdn        ),
        .usb_pullup_en_o            ( o_usb_pullup_en   ),
        .usb_term_dp_io             ( io_usb_term_dp    ),
        .usb_term_dn_io             ( io_usb_term_dn    ) 
    );
endmodule