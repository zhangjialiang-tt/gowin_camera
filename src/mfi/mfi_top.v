module mfi_top (
    input                       i_usb_user_clk              ,
    input                       i_rst_n                     ,
    
    input           [3:0]       i_endpt                     ,

    input                       i_usb_rxact                 ,
    input                       i_usb_rxval                 ,
    input           [7:0]       i_usb_rxdat                 ,

    output  reg     [11:0]      o_txdat_len                 ,
    output  reg                 o_txcork                    ,   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    input                       i_txact                     ,
    input                       i_txpop                     ,
    output  wire    [7:0]       o_txdat                     ,

    output  reg                 o_os_type                   ,   //  0: 苹果；1: 安卓

    inout   wire                io_mfi_iic_scl              ,
    inout   wire                io_mfi_iic_sda               
);
//  参数定义
    localparam IAP2_ENDPT = 4'd2;

    localparam MS = 60_000;
    localparam PWR_DELAY_MS     = 1000;
    localparam IIC_DELAY_MS     = 15;
    localparam LOOP_TX_DELAY_MS = 200;

    localparam MFI_RAM_ADDR_DETECT         = 0;
    localparam MFI_RAM_LEN_DETECT          = 6;
    localparam MFI_RAM_ADDR_SYN            = MFI_RAM_ADDR_DETECT         + MFI_RAM_LEN_DETECT        ;
    localparam MFI_RAM_LEN_SYN             = 23;
    localparam MFI_RAM_ADDR_ACK            = MFI_RAM_ADDR_SYN            + MFI_RAM_LEN_SYN           ;
    localparam MFI_RAM_LEN_ACK             = 9;
    localparam MFI_RAM_ADDR_CERITICATE     = MFI_RAM_ADDR_ACK            + MFI_RAM_LEN_ACK           ;
    localparam MFI_RAM_LEN_CERITICATE      = 629;
    localparam MFI_RAM_ADDR_PARAM          = MFI_RAM_ADDR_CERITICATE     + MFI_RAM_LEN_CERITICATE    ;
    localparam MFI_RAM_LEN_PARAM           = 32;
    localparam MFI_RAM_ADDR_CHALLENGE      = MFI_RAM_ADDR_PARAM          + MFI_RAM_LEN_PARAM         ;
    localparam MFI_RAM_LEN_CHALLENGE       = 84;
    localparam MFI_RAM_ADDR_IDENTIFICATION = MFI_RAM_ADDR_CHALLENGE      + MFI_RAM_LEN_CHALLENGE     ;
    localparam MFI_RAM_LEN_IDENTIFICATION  = 456;
    localparam MFI_RAM_ADDR_APPLAUNCH      = MFI_RAM_ADDR_IDENTIFICATION + MFI_RAM_LEN_IDENTIFICATION;
    localparam MFI_RAM_LEN_APPLAUNCH       = 84;

//  状态机定义
    //                                  {state, delay, tx_pre, tx  }
    //                                   [7:3]  [2]    [1]     [0]
    localparam PWR_DELAY              = {5'd0 , 1'd1 , 1'd0  , 1'd0};
    localparam CERITICATE_LEN_RD      = {5'd1 , 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY1             = {5'd2 , 1'd1 , 1'd0  , 1'd0};
    localparam CERITICATE_DATA_RD     = {5'd3 , 1'd0 , 1'd0  , 1'd0};
    localparam IDLE                   = {5'd4 , 1'd0 , 1'd0  , 1'd0};
    localparam DETECT_TX_PRE          = {5'd5 , 1'd0 , 1'd1  , 1'd0};
    localparam DETECT_TX              = {5'd6 , 1'd0 , 1'd0  , 1'd1};
    localparam SYN_TX_PRE             = {5'd7 , 1'd0 , 1'd1  , 1'd0};
    localparam SYN_TX                 = {5'd8 , 1'd0 , 1'd0  , 1'd1};
    localparam ACK_TX_PRE             = {5'd9 , 1'd0 , 1'd1  , 1'd0};
    localparam ACK_TX                 = {5'd10, 1'd0 , 1'd0  , 1'd1};
    localparam CERITICATE_TX_PRE      = {5'd11, 1'd0 , 1'd1  , 1'd0};
    localparam CERITICATE_TX          = {5'd12, 1'd0 , 1'd0  , 1'd1};
    localparam PARAM_LEN_WR           = {5'd13, 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY2             = {5'd14, 1'd1 , 1'd0  , 1'd0};
    localparam PARAM_DATA_WR          = {5'd15, 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY3             = {5'd16, 1'd1 , 1'd0  , 1'd0};
    localparam STATUS_WR              = {5'd17, 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY4             = {5'd18, 1'd1 , 1'd0  , 1'd0};
    localparam STATUS_RD              = {5'd19, 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY5             = {5'd20, 1'd1 , 1'd0  , 1'd0};
    localparam CHALLENGE_LEN_RD       = {5'd21, 1'd0 , 1'd0  , 1'd0};
    localparam IIC_DELAY6             = {5'd22, 1'd1 , 1'd0  , 1'd0};
    localparam CHALLENGE_DATA_RD      = {5'd23, 1'd0 , 1'd0  , 1'd0};
    localparam CHALLENGE_TX_PRE       = {5'd24, 1'd0 , 1'd1  , 1'd0};
    localparam CHALLENGE_TX           = {5'd25, 1'd0 , 1'd0  , 1'd1};
    localparam INDENTIFICATION_TX_PRE = {5'd26, 1'd0 , 1'd1  , 1'd0};
    localparam INDENTIFICATION_TX     = {5'd27, 1'd0 , 1'd0  , 1'd1};
    localparam APPLAUNCH_TX_PRE       = {5'd28, 1'd0 , 1'd1  , 1'd0};
    localparam APPLAUNCH_TX           = {5'd29, 1'd0 , 1'd0  , 1'd1};

//  信号定义
    // 判断是否是 iAP2 端点
    reg                 iap2_endpt                  ;
    // 状态机
    reg     [7:0]       state_n                     ;   // [7:3] state; [2] delay; [1] tx_pre; [0] tx
    reg     [7:0]       state_c                     ;   // [7:3] state; [2] delay; [1] tx_pre; [0] tx
    wire                state_change                ;
    reg                 pwr_delay_done              ;
    reg                 iic_delay_done              ;
    reg                 loop_tx_delay_done          ;
    reg                 detect_tx_pre_done          ;
    reg                 syn_tx_pre_done             ;
    reg                 ack_tx_pre_done             ;
    reg                 ceriticate_tx_pre_done      ;
    reg                 challenge_tx_pre_done       ;
    reg                 indentification_tx_done     ;
    reg                 applaunch_tx_pre_done       ;
    // 延迟计数器
    reg     [15:0]      ms_delay_cnt                ;
    reg                 ms_delay_cnt_end            ;
    reg     [15:0]      delay_cnt                   ;
    // IIC
    wire                iic_scl_oe                  ;
    wire                iic_scl_in                  ;
    wire                iic_scl_out                 ;
    wire                iic_sda_oe                  ;
    wire                iic_sda_in                  ;
    wire                iic_sda_out                 ;
    reg     [15:0]      iic_data_num                ;
    reg     [7:0]       iic_reg_addr                ;
    wire                iic_wr_data_req             ;
    reg     [7:0]       iic_write_data              ;
    reg                 iic_en                      ;
    reg                 iic_wrrd                    ;
    wire                iic_read_vld                ;
    wire    [7:0]       iic_read_data               ;
    wire                iic_busy                    ;
    reg                 iic_busy_r1                 ;
    reg                 iic_busy_neg                ;
    // 状态逻辑
    reg     [15:0]      ceriticate_len              ;
    reg                 detect_tx_loop_en           ;
    reg                 syn_tx_loop_en              ;
    reg     [10:0]      pre_cnt                     ;
    reg     [10:0]      pre_cnt_r1                  ;
    reg     [10:0]      pre_cnt_r2                  ;
    reg                 pre_temp                    ;
    reg     [15:0]      checksum_temp               ;
    wire    [15:0]      checksum                    ;
    reg     [7:0]       tx_packet_seq               ;
    reg     [10:0]      ceriticate_data_wr_ram_cnt  ;
    reg     [7:0]       param_data_wr_ram_cnt       ;
    reg     [7:0]       param_data_rd_ram_cnt       ;
    reg                 challenge_gen_state         ;
    reg     [15:0]      challenge_len               ;
    reg     [7:0]       challenge_data_wr_ram_cnt   ;
    // MFI RAM BUFFER
    reg     [10:0]      mfi_ram_addr                ;
    reg                 mfi_ram_wr_en               ;
    reg     [7:0]       mfi_ram_wr_data             ;
    wire    [7:0]       mfi_ram_rd_data_temp        ;
    wire    [7:0]       mfi_ram_rd_data             ;
    // iAP2 指令解析结果
    wire                iap2_rx_android             ;
    wire    [7:0]       iap2_rx_packet_seq          ;
    wire    [15:0]      iap2_rx_param_lenth         ;
    wire                iap2_rx_param_data_vld      ;
    wire    [7:0]       iap2_rx_param_data          ;
    wire                iap2_rx_detect              ;
    wire                iap2_rx_syn_ack             ;
    wire                iap2_rx_ack                 ;
    wire                iap2_rx_rst                 ;
    wire                iap2_rx_slp                 ;
    wire                iap2_rx_rac                 ;
    wire                iap2_rx_rcr                 ;
    wire                iap2_rx_ar                  ;
    wire                iap2_rx_si                  ;
    wire                iap2_rx_ia                  ;
    wire                iap2_rx_pwrupdate           ;
    // TX FIFO
    reg                 fifo_wr_en                  ;
    reg     [7:0]       fifo_wr_data                ;
    wire    [11:0]      fifo_rd_num                 ;
    wire                fifo_empty                  ;
    wire                fifo_tx_rden                ;
    reg     [11:0]      tx_cnt                      ;

//  判断是否是 iAP2 端点
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iap2_endpt <= 1'd0;
        end
        else if (i_endpt == IAP2_ENDPT && ~o_os_type) begin
            iap2_endpt <= 1'd1;
        end
        else begin
            iap2_endpt <= 1'd0;
        end
    end

//  判断是否是安卓系统
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_os_type <= 1'd0;
        end
        else if (iap2_rx_android) begin
            o_os_type <= 1'd1;
        end
        else begin
            o_os_type <= o_os_type;
        end
    end

///////////////////////////////////////////////////// MFI 状态机

//  state_c
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            state_c <= PWR_DELAY;
        end
        else begin
            state_c <= state_n;
        end
    end
    // assign state_change = state_c[9:5] != state_n[9:5];
    assign state_change = state_c != state_n;

//  状态跳转条件
    always @(posedge i_usb_user_clk) begin
        if (delay_cnt == PWR_DELAY_MS - 'd2) begin
            pwr_delay_done <= 1'd1;
        end
        else begin
            pwr_delay_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (delay_cnt == IIC_DELAY_MS - 'd2) begin
            iic_delay_done <= 1'd1;
        end
        else begin
            iic_delay_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (delay_cnt == LOOP_TX_DELAY_MS - 'd2) begin
            loop_tx_delay_done <= 1'd1;
        end
        else begin
            loop_tx_delay_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_DETECT) begin
            detect_tx_pre_done <= 1'd1;
        end
        else begin
            detect_tx_pre_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_SYN) begin
            syn_tx_pre_done <= 1'd1;
        end
        else begin
            syn_tx_pre_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_ACK) begin
            ack_tx_pre_done <= 1'd1;
        end
        else begin
            ack_tx_pre_done <= 1'd0;
        end
    end
    
    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == ceriticate_len + 12'd20) begin
            ceriticate_tx_pre_done <= 1'd1;
        end
        else begin
            ceriticate_tx_pre_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_CHALLENGE) begin
            challenge_tx_pre_done <= 1'd1;
        end
        else begin
            challenge_tx_pre_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_IDENTIFICATION) begin
            indentification_tx_done <= 1'd1;
        end
        else begin
            indentification_tx_done <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        if (fifo_rd_num == MFI_RAM_LEN_APPLAUNCH) begin
            applaunch_tx_pre_done <= 1'd1;
        end
        else begin
            applaunch_tx_pre_done <= 1'd0;
        end
    end

//  state_n
    always @(*) begin
        if (~i_rst_n) begin
            state_n = PWR_DELAY;
        end
        else begin
            case (state_c)
                PWR_DELAY:          state_n = pwr_delay_done                                  ? CERITICATE_LEN_RD  : state_c;
                CERITICATE_LEN_RD:  state_n = iic_busy_neg                                    ? IIC_DELAY1         : state_c;
                IIC_DELAY1:         state_n = iic_delay_done                                  ? CERITICATE_DATA_RD : state_c;
                CERITICATE_DATA_RD: state_n = iic_busy_neg                                    ? IDLE               : state_c;
                IDLE: begin
                    if (detect_tx_loop_en && loop_tx_delay_done) begin
                        state_n = DETECT_TX_PRE;
                    end
                    else if (syn_tx_loop_en && loop_tx_delay_done) begin
                        state_n = SYN_TX_PRE;
                    end
                    else if (iap2_rx_syn_ack || iap2_rx_ar || iap2_rx_pwrupdate) begin
                        state_n = ACK_TX_PRE;
                    end
                    else if (iap2_rx_rac) begin
                        state_n = CERITICATE_TX_PRE;
                    end
                    else if (iap2_rx_rcr) begin
                        state_n = PARAM_LEN_WR;
                    end
                    else if (iap2_rx_si) begin
                        state_n = INDENTIFICATION_TX_PRE;
                    end
                    else if (iap2_rx_ia) begin
                        state_n = APPLAUNCH_TX_PRE;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
                DETECT_TX_PRE:          state_n = detect_tx_pre_done                          ? DETECT_TX          : state_c;
                DETECT_TX:              state_n = fifo_empty                                  ? IDLE               : state_c;
                SYN_TX_PRE:             state_n = syn_tx_pre_done                             ? SYN_TX             : state_c;
                SYN_TX:                 state_n = fifo_empty                                  ? IDLE               : state_c;
                ACK_TX_PRE:             state_n = ack_tx_pre_done                             ? ACK_TX             : state_c;
                ACK_TX:                 state_n = fifo_empty                                  ? IDLE               : state_c;
                CERITICATE_TX_PRE:      state_n = ceriticate_tx_pre_done                      ? CERITICATE_TX      : state_c;
                CERITICATE_TX:          state_n = fifo_empty                                  ? IDLE               : state_c;
                PARAM_LEN_WR:           state_n = iic_busy_neg                                ? IIC_DELAY2         : state_c;
                IIC_DELAY2:             state_n = iic_delay_done                              ? PARAM_DATA_WR      : state_c;
                PARAM_DATA_WR:          state_n = iic_busy_neg                                ? IIC_DELAY3         : state_c;
                IIC_DELAY3:             state_n = iic_delay_done                              ? STATUS_WR          : state_c;
                STATUS_WR:              state_n = iic_busy_neg                                ? IIC_DELAY4         : state_c;
                IIC_DELAY4:             state_n = iic_delay_done                              ? STATUS_RD          : state_c;
                STATUS_RD: begin
                    if (iic_busy_neg && challenge_gen_state) begin
                        state_n = IIC_DELAY5;
                    end
                    else if (iic_busy_neg && ~challenge_gen_state) begin
                        state_n = IIC_DELAY4;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
                IIC_DELAY5:             state_n = iic_delay_done                              ? CHALLENGE_LEN_RD   : state_c;
                CHALLENGE_LEN_RD:       state_n = iic_busy_neg                                ? IIC_DELAY6         : state_c;
                IIC_DELAY6:             state_n = iic_delay_done                              ? CHALLENGE_DATA_RD  : state_c;
                CHALLENGE_DATA_RD:      state_n = iic_busy_neg                                ? CHALLENGE_TX_PRE   : state_c;
                CHALLENGE_TX_PRE:       state_n = challenge_tx_pre_done                       ? CHALLENGE_TX       : state_c;
                CHALLENGE_TX:           state_n = fifo_empty                                  ? IDLE               : state_c;
                INDENTIFICATION_TX_PRE: state_n = indentification_tx_done                     ? INDENTIFICATION_TX : state_c;
                INDENTIFICATION_TX:     state_n = fifo_empty                                  ? IDLE               : state_c;
                APPLAUNCH_TX_PRE:       state_n = applaunch_tx_pre_done                       ? APPLAUNCH_TX       : state_c;
                APPLAUNCH_TX:           state_n = fifo_empty                                  ? IDLE               : state_c;
                default:                state_n =                                                                    state_c;
            endcase
        end
    end


    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            ms_delay_cnt <= 'd0;
        end
        else if (ms_delay_cnt_end) begin
            ms_delay_cnt <= 'd0;
        end
        else if (state_c[2] || (state_c == IDLE && (detect_tx_loop_en || syn_tx_loop_en))) begin
            ms_delay_cnt <= ms_delay_cnt + 'd1;
        end
        else begin
            ms_delay_cnt <= 'd0;
        end
    end
    // assign ms_delay_cnt_end = ms_delay_cnt == (MS - 'd1);

    always @(posedge i_usb_user_clk) begin
        if (ms_delay_cnt == MS - 'd2) begin
            ms_delay_cnt_end <= 1'd1;
        end
        else begin
            ms_delay_cnt_end <= 1'd0;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            delay_cnt <= 'd0;
        end
        else if (state_c[2] || (state_c == IDLE && (detect_tx_loop_en || syn_tx_loop_en))) begin
            if (ms_delay_cnt_end) begin
                delay_cnt <= delay_cnt + 'd1;
            end
            else begin
                delay_cnt <= delay_cnt;
            end
        end
        else begin
            delay_cnt <= 'd0;
        end
    end

///////////////////////////////////////////////////// 状态逻辑

//  获取 ceriticate_len
    always @(posedge i_usb_user_clk) begin
        if (state_c == CERITICATE_LEN_RD && iic_read_vld) begin
            ceriticate_len <= {ceriticate_len[7:0], iic_read_data};
        end
        else begin
            ceriticate_len <= ceriticate_len;
        end
    end

//  detect_tx_loop_en / syn_tx_loop_en
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            detect_tx_loop_en <= 1'd1;
        end
        else if (iap2_rx_detect) begin
            detect_tx_loop_en <= 1'd0;
        end
        else begin
            detect_tx_loop_en <= detect_tx_loop_en;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            syn_tx_loop_en <= 1'd0;
        end
        else if (iap2_rx_detect) begin
            syn_tx_loop_en <= 1'd1;
        end
        else if (iap2_rx_syn_ack) begin
            syn_tx_loop_en <= 1'd0;
        end
        else begin
            syn_tx_loop_en <= syn_tx_loop_en;
        end
    end

//  向 MFI RAM 中写入 ceriticate_data 时的字节计数
    always @(posedge i_usb_user_clk) begin
        if (state_c == CERITICATE_DATA_RD && iic_read_vld) begin
            ceriticate_data_wr_ram_cnt <= ceriticate_data_wr_ram_cnt + 11'd1;
        end
        else begin
            ceriticate_data_wr_ram_cnt <= ceriticate_data_wr_ram_cnt;
        end
    end

//  向 MFI RAM 中写入 param_data 时的字节计数
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            param_data_wr_ram_cnt <= 8'd0;
        end
        else if (state_c != IDLE && state_n == IDLE) begin
            param_data_wr_ram_cnt <= 8'd0;
        end
        else if (iap2_rx_param_data_vld) begin
            param_data_wr_ram_cnt <= param_data_wr_ram_cnt + 8'd1;
        end
        else begin
            param_data_wr_ram_cnt <= param_data_wr_ram_cnt;
        end
    end

//  从 MFI RAM 中读出 param_data 时的字节计数
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            param_data_rd_ram_cnt <= 8'd0;
        end
        else if (iic_en) begin
            param_data_rd_ram_cnt <= 8'd0;
        end
        else if (iic_wr_data_req) begin
            param_data_rd_ram_cnt <= param_data_rd_ram_cnt + 8'd1;
        end
        else begin
            param_data_rd_ram_cnt <= param_data_rd_ram_cnt;
        end
    end

//  根据 STATUS_RD 是读取的结果判断 challenge 是否成功生成
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            challenge_gen_state <= 1'd0;
        end
        else if (iap2_rx_rcr) begin
            challenge_gen_state <= 1'd0;
        end
        else if (state_c == STATUS_RD && iic_read_vld && iic_read_data[6:4] == 3'd1) begin
            challenge_gen_state <= 1'd1;
        end
        else begin
            challenge_gen_state <= challenge_gen_state;
        end
    end

//  寄存 CHALLENGE_LEN_RD 状态中读到的 challenge_len
    always @(posedge i_usb_user_clk) begin
        if (state_c == CHALLENGE_LEN_RD && iic_read_vld) begin
            challenge_len <= {challenge_len[7:0], iic_read_data};
        end
        else begin
            challenge_len <= challenge_len;
        end
    end

//  向 MFI RAM 中写入 challenge_data 时的字节计数
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            challenge_data_wr_ram_cnt <= 8'd0;
        end
        else if (iap2_rx_rcr) begin
            challenge_data_wr_ram_cnt <= 8'd0;
        end
        else if (state_c == CHALLENGE_DATA_RD && iic_read_vld) begin
            challenge_data_wr_ram_cnt <= challenge_data_wr_ram_cnt + 8'd1;
        end
        else begin
            challenge_data_wr_ram_cnt <= challenge_data_wr_ram_cnt;
        end
    end

///////////////////////////////////////////////////// TX_FIFO

//  校验计算
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            checksum_temp <= 16'd256;
        end
        else if (pre_cnt_r2 == 'd0 || pre_cnt_r2 == 'd9) begin
            checksum_temp <= 16'd256;
        end
        else if (fifo_wr_en) begin
            checksum_temp <= $signed(checksum_temp) - $signed({8'd0, fifo_wr_data});
        end
        else begin
            checksum_temp <= 16'd256;
        end
    end
    assign checksum = $signed(checksum_temp) - $signed({8'd0, fifo_wr_data}); 

//  tx_packet_seq
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            tx_packet_seq <= 8'd7;
        end
        else if (iap2_rx_rac || iap2_rx_rcr || iap2_rx_si || iap2_rx_ia) begin
            tx_packet_seq <= tx_packet_seq + 8'd1;
        end
        else begin
            tx_packet_seq <= tx_packet_seq;
        end
    end

//  pre_cnt
    always @(posedge i_usb_user_clk) begin
        if (state_c[1]) begin
            pre_cnt <= pre_cnt + 11'd1;
        end
        else begin
            pre_cnt <= 11'd0;
        end
    end

    always @(posedge i_usb_user_clk) begin
        begin
            pre_cnt_r1 <= pre_cnt;
            pre_cnt_r2 <= pre_cnt_r1;
        end
    end

//  pre_temp
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            pre_temp <= 1'd0;
        end
        else if (pre_cnt == 11'd1) begin
            pre_temp <= 1'd1;
        end
        else begin
            case (state_c)
                DETECT_TX_PRE:          pre_temp <= (pre_cnt == MFI_RAM_LEN_DETECT + 11'd1)         ? 1'd0 : pre_temp;
                SYN_TX_PRE:             pre_temp <= (pre_cnt == MFI_RAM_LEN_SYN + 11'd1)            ? 1'd0 : pre_temp;
                ACK_TX_PRE:             pre_temp <= (pre_cnt == MFI_RAM_LEN_ACK + 11'd1)            ? 1'd0 : pre_temp;
                CERITICATE_TX_PRE:      pre_temp <= (pre_cnt == ceriticate_len + 11'd21)            ? 1'd0 : pre_temp;
                CHALLENGE_TX_PRE:       pre_temp <= (pre_cnt == MFI_RAM_LEN_CHALLENGE + 11'd1)      ? 1'd0 : pre_temp;
                INDENTIFICATION_TX_PRE: pre_temp <= (pre_cnt == MFI_RAM_LEN_IDENTIFICATION + 11'd1) ? 1'd0 : pre_temp;
                APPLAUNCH_TX_PRE:       pre_temp <= (pre_cnt == MFI_RAM_LEN_APPLAUNCH + 11'd1)      ? 1'd0 : pre_temp;
                default:                pre_temp <=                                                          pre_temp;
            endcase
        end
    end

//  fifo_wr_en
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            fifo_wr_en <= 1'd0;
        end
        else begin
            fifo_wr_en <= pre_temp;
        end
    end

//  fifo_wr_data
    always @(posedge i_usb_user_clk) begin
        if (state_c == SYN_TX_PRE) begin
            case (pre_cnt_r2)
                11'd5:                   fifo_wr_data <= tx_packet_seq;
                11'd8:                   fifo_wr_data <= checksum[7:0];
                MFI_RAM_LEN_SYN - 11'd1: fifo_wr_data <= checksum[7:0];
                default:                 fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else if (state_c == ACK_TX_PRE) begin
            case (pre_cnt_r2)
                11'd5:   fifo_wr_data <= tx_packet_seq;
                11'd6:   fifo_wr_data <= iap2_rx_packet_seq;
                11'd8:   fifo_wr_data <= checksum[7:0];
                default: fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else if (state_c == CERITICATE_TX_PRE) begin
            case (pre_cnt_r2)
                11'd2:                   fifo_wr_data <= (ceriticate_len + 16'd20) >> 8;
                11'd3:                   fifo_wr_data <= (ceriticate_len + 16'd20) & 8'hFF;
                11'd5:                   fifo_wr_data <= tx_packet_seq;
                11'd6:                   fifo_wr_data <= iap2_rx_packet_seq;
                11'd8:                   fifo_wr_data <= checksum[7:0];
                11'd11:                  fifo_wr_data <= (ceriticate_len + 16'd10) >> 8;
                11'd12:                  fifo_wr_data <= (ceriticate_len + 16'd10) & 8'hFF;
                11'd15:                  fifo_wr_data <= (ceriticate_len + 16'd4) >> 8;
                11'd16:                  fifo_wr_data <= (ceriticate_len + 16'd4) & 8'hFF;
                ceriticate_len + 11'd19: fifo_wr_data <= checksum[7:0];
                default:                 fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else if (state_c == CHALLENGE_TX_PRE) begin
            case (pre_cnt_r2)
                11'd2:                         fifo_wr_data <= (challenge_len + 16'd20) >> 8;
                11'd3:                         fifo_wr_data <= (challenge_len + 16'd20) & 8'hFF;
                11'd5:                         fifo_wr_data <= tx_packet_seq;
                11'd6:                         fifo_wr_data <= iap2_rx_packet_seq;
                11'd8:                         fifo_wr_data <= checksum[7:0];
                11'd11:                        fifo_wr_data <= (challenge_len + 16'd10) >> 8;
                11'd12:                        fifo_wr_data <= (challenge_len + 16'd10) & 8'hFF;
                11'd15:                        fifo_wr_data <= (challenge_len + 16'd4) >> 8;
                11'd16:                        fifo_wr_data <= (challenge_len + 16'd4) & 8'hFF;
                MFI_RAM_LEN_CHALLENGE - 11'd1: fifo_wr_data <= checksum[7:0];
                default:                       fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else if (state_c == INDENTIFICATION_TX_PRE) begin
            case (pre_cnt_r2)
                11'd5:                              fifo_wr_data <= tx_packet_seq;
                11'd6:                              fifo_wr_data <= iap2_rx_packet_seq;
                11'd8:                              fifo_wr_data <= checksum[7:0];
                MFI_RAM_LEN_IDENTIFICATION - 11'd1: fifo_wr_data <= checksum[7:0];
                default:                            fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else if (state_c == APPLAUNCH_TX_PRE) begin
            case (pre_cnt_r2)
                11'd5:                         fifo_wr_data <= tx_packet_seq;
                11'd6:                         fifo_wr_data <= iap2_rx_packet_seq;
                11'd8:                         fifo_wr_data <= checksum[7:0];
                MFI_RAM_LEN_APPLAUNCH - 11'd1: fifo_wr_data <= checksum[7:0];
                default:                       fifo_wr_data <= mfi_ram_rd_data;
            endcase
        end
        else begin
            fifo_wr_data <= mfi_ram_rd_data;
        end
    end

//  TX FIFO
    fifo_iap2_tx u_fifo_iap2_tx (
        .Reset      ( ~i_rst_n                          ),

        .WrClk      ( i_usb_user_clk                    ),
        .Full       (                                   ),
        .WrEn       ( fifo_wr_en                        ),
        .Data       ( fifo_wr_data                      ),

        .RdClk      ( i_usb_user_clk                    ),
        .Rnum       ( fifo_rd_num                       ), //  [11:0]
        .Empty      ( fifo_empty                        ),
        .RdEn       ( fifo_tx_rden                      ),
        .Q          ( o_txdat                           ) 
    );
    assign fifo_tx_rden = (iap2_endpt && i_txpop);

//  o_txdat_len
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_txdat_len <= 12'd0;
        end
        else if (~i_txact) begin
            if (fifo_rd_num >= 12'd512) begin
                o_txdat_len <= 12'd512;
            end
            else begin
                o_txdat_len <= fifo_rd_num;
            end
        end
        else begin
            o_txdat_len <= o_txdat_len;
        end
    end

//  o_txcork
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            tx_cnt <= 12'd0;
        end
        else if (o_txcork) begin
            tx_cnt <= 12'd0;
        end
        else if (iap2_endpt && i_txpop) begin
            tx_cnt <= tx_cnt + 12'd1;
        end
        else begin
            tx_cnt <= tx_cnt;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_txcork <= 1'd1;
        end
        else if (state_c[0]) begin
            if (~i_txact && fifo_rd_num >= o_txdat_len && ~fifo_empty) begin
                o_txcork <= 1'd0;
            end
            else if (i_txpop && tx_cnt == o_txdat_len - 12'd1) begin
                o_txcork <= 1'd1;
            end
            else begin
                o_txcork <= o_txcork;
            end
        end
        else begin
            o_txcork <= o_txcork;
        end
    end

///////////////////////////////////////////////////// MFI RAM BUFFER

//  RAM 控制
    // mfi_ram_addr / mfi_ram_wr_en / mfi_ram_wr_data
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            mfi_ram_addr    <= mfi_ram_addr;
            mfi_ram_wr_en   <= 1'd0;
            mfi_ram_wr_data <= 8'd0;
        end
        else begin
            case (state_c)
                // CERITICATE_DATA_RD 写 RAM
                CERITICATE_DATA_RD: begin
                    if (iic_read_vld) begin
                        mfi_ram_addr    <= MFI_RAM_ADDR_CERITICATE + 11'd19 + ceriticate_data_wr_ram_cnt;
                        mfi_ram_wr_en   <= 1'd1;
                        mfi_ram_wr_data <= iic_read_data;
                    end
                    else begin
                        mfi_ram_addr    <= mfi_ram_addr;
                        mfi_ram_wr_en   <= 1'd0;
                        mfi_ram_wr_data <= 8'd0;
                    end
                end
                // DETECT_TX_PRE 状态的地址控制
                DETECT_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_DETECT + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // SYN_TX_PRE 状态的地址控制
                SYN_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_SYN + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // ACK_TX_PRE 状态的地址控制
                ACK_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_ACK + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // CERITICATE_TX_PRE 状态的地址控制
                CERITICATE_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_CERITICATE + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // IDLE 状态将 iap2_rx_param_data 写入 RAM
                IDLE: begin
                    if (iap2_rx_param_data_vld) begin
                        mfi_ram_addr    <= MFI_RAM_ADDR_PARAM + {3'd0, param_data_wr_ram_cnt};
                        mfi_ram_wr_en   <= 1'd1;
                        mfi_ram_wr_data <= iap2_rx_param_data;    
                    end
                    else begin
                        mfi_ram_addr    <= mfi_ram_addr;
                        mfi_ram_wr_en   <= 1'd0;
                        mfi_ram_wr_data <= 8'd0;
                    end
                end
                // PARAM_DATA_WR 状态将 param_data 读出 RAM
                PARAM_DATA_WR: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_PARAM + {3'd0, param_data_rd_ram_cnt};
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // CHALLENGE_DATA_RD 状态将 challenge_data 写入 RAM
                CHALLENGE_DATA_RD: begin
                    if (iic_read_vld) begin
                        mfi_ram_addr    <= MFI_RAM_ADDR_CHALLENGE + 11'd19 + {3'd0, challenge_data_wr_ram_cnt};
                        mfi_ram_wr_en   <= 1'd1;
                        mfi_ram_wr_data <= iic_read_data;
                    end
                    else begin
                        mfi_ram_addr    <= mfi_ram_addr;
                        mfi_ram_wr_en   <= 1'd0;
                        mfi_ram_wr_data <= 8'd0;
                    end
                end
                // CHALLENGE_TX_PRE 状态的地址控制
                CHALLENGE_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_CHALLENGE + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // INDENTIFICATION_TX_PRE 状态的地址控制
                INDENTIFICATION_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_IDENTIFICATION + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                // APPLAUNCH_TX_PRE 状态的地址控制
                APPLAUNCH_TX_PRE: begin
                    mfi_ram_addr    <= MFI_RAM_ADDR_APPLAUNCH + pre_cnt;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
                default: begin
                    mfi_ram_addr    <= mfi_ram_addr;
                    mfi_ram_wr_en   <= 1'd0;
                    mfi_ram_wr_data <= 8'd0;
                end
            endcase
        end
    end

//  RAM IP
    dpb_mfi u_dpb_mfi (
        .clka   ( i_usb_user_clk        ),
        .reseta ( ~i_rst_n              ),
        .cea    ( 1'd1                  ),
        .ocea   ( 1'd1                  ),
        .wrea   ( mfi_ram_wr_en         ),
        .ada    ( mfi_ram_addr          ),  //  [10:0]
        .dina   ( mfi_ram_wr_data       ),
        .douta  (                       ),

        .clkb   ( i_usb_user_clk        ),
        .resetb ( ~i_rst_n              ),
        .ceb    ( 1'd1                  ),
        .oceb   ( 1'd1                  ),
        .wreb   ( 1'd0                  ),
        .adb    ( mfi_ram_addr          ),  //  [10:0]
        .dinb   (                       ),
        .doutb  ( mfi_ram_rd_data       ) 
    );

///////////////////////////////////////////////////// IIC

//  IIC 控制
    // iic_data_num / iic_en / iic_wrrd / iic_reg_addr
    always @(posedge i_usb_user_clk) begin
        // PARAM_LEN_WR 状态写入 param_lenth
        if (iap2_rx_rcr) begin
            iic_data_num <= 16'd1;
            iic_en       <= 1'd1;
            iic_wrrd     <= 1'd0;
            iic_reg_addr <= 8'h20;
        end
        else if (state_change) begin
            case (state_c)
                // CERITICATE_LEN_RD 状态读取 ceriticate_len
                PWR_DELAY: begin
                    iic_data_num <= 16'd2;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd1;
                    iic_reg_addr <= 8'h30;
                end
                // CERITICATE_DARA_RD 状态读取 ceriticate_data
                IIC_DELAY1: begin
                    iic_data_num <= ceriticate_len;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd1;
                    iic_reg_addr <= 8'h31;
                end
                // PARAM_DATA_WR 状态写入 param_data
                IIC_DELAY2: begin
                    iic_data_num <= iap2_rx_param_lenth;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd0;
                    iic_reg_addr <= 8'h21;
                end
                // STATUS_WR 状态开始生成 challenge
                IIC_DELAY3: begin
                    iic_data_num <= 16'd1;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd0;
                    iic_reg_addr <= 8'h10;
                end
                // STATUS_RD 状态读取 challeng 生成状态
                IIC_DELAY4: begin
                    iic_data_num <= 16'd1;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd1;
                    iic_reg_addr <= 8'h10;
                end
                // CHALLENGE_LEN_RD 状态读取 challenge_len
                IIC_DELAY5: begin
                    iic_data_num <= 16'd2;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd1;
                    iic_reg_addr <= 8'h11;
                end
                // CHALLENGE_DATA_RD 状态读取 challenge_data
                IIC_DELAY6: begin
                    iic_data_num <= challenge_len;
                    iic_en       <= 1'd1;
                    iic_wrrd     <= 1'd1;
                    iic_reg_addr <= 8'h12;
                end
                default: begin
                    iic_data_num <= 16'd0;
                    iic_en       <= 1'd0;
                    iic_wrrd     <= 1'd0;
                    iic_reg_addr <= 8'd0;
                end
            endcase
        end
        else begin
            iic_data_num <= 16'd0;
            iic_en       <= 1'd0;
            iic_wrrd     <= 1'd0;
            iic_reg_addr <= 8'd0;
        end
    end

    // iic_write_data
    always @(posedge i_usb_user_clk) begin
        // PARAM_LEN_WR 状态写入 param_lenth
        if (state_c == PARAM_LEN_WR && iic_wr_data_req) begin
            iic_write_data <= iap2_rx_param_lenth[7:0];
        end
        // PARAM_DATA_WR 状态写入 param_data
        else if (state_c == PARAM_DATA_WR && iic_wr_data_req) begin
            iic_write_data <= mfi_ram_rd_data;
        end
        // STATUS_WR 状态开始生成 challenge
        else if (state_c == STATUS_WR && iic_wr_data_req) begin
            iic_write_data <= 8'h01;
        end
        else begin
            iic_write_data <= iic_write_data;
        end
    end

//  IIC 驱动
    iic_master_mfi #(        
        .CLK_IN_FREQ        ( 60_000_000        ),
        .IIC_SCL_RQEQ       ( 100_000           ),
        .IIC_TIMING_T1_NS   ( 5000              ),
        .IIC_TIMING_T2_NS   ( 5000              ),
        .IIC_TIMING_T3_NS   ( 2500              ),
        .WP_TO_RS           ( 1                 ),
        .WAIT_SLAVE         ( 0                 ) 
    ) u_iic_master_mfi (             
        .i_clk              ( i_usb_user_clk    ),
        .i_rst_n            ( i_rst_n           ),

        .o_iic_scl_oe       ( iic_scl_oe        ),
        .i_iic_scl_in       ( iic_scl_in        ),
        .o_iic_scl_out      ( iic_scl_out       ),
        .o_iic_sda_oe       ( iic_sda_oe        ),
        .i_iic_sda_in       ( iic_sda_in        ),
        .o_iic_sda_out      ( iic_sda_out       ),

        .i_data_num         ( iic_data_num      ),
        .i_slave_addr       ( 7'b0010000        ),
        .i_reg_addr         ( iic_reg_addr      ),
        .o_wr_data_req      ( iic_wr_data_req   ),
        .o_byte_cnt         (                   ),
        .i_write_data       ( iic_write_data    ),
        .i_iic_en           ( iic_en            ),
        .i_wrrd             ( iic_wrrd          ),

        .o_read_vld         ( iic_read_vld      ),
        .o_read_data        ( iic_read_data     ),

        .o_busy             ( iic_busy          ) 
    );
    assign io_mfi_iic_scl = iic_scl_oe ? iic_scl_out : 1'bz;
    assign io_mfi_iic_sda = iic_sda_oe ? iic_sda_out : 1'bz;
    assign iic_scl_in = io_mfi_iic_scl;
    assign iic_sda_in = io_mfi_iic_sda;

//  获取 busy 下降沿
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_busy_r1 <= 1'd0;
        end
        else begin
            iic_busy_r1 <= iic_busy;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_busy_neg <= 1'd0;
        end
        else if (iic_busy_r1 && ~iic_busy) begin
            iic_busy_neg <= 1'd1;
        end
        else begin
            iic_busy_neg <= 1'd0;
        end
    end

///////////////////////////////////////////////////// 指令解析

//  iAP2 指令解析
    iap2_parsing u_iap2_parsing (
        .i_usb_user_clk             ( i_usb_user_clk            ),
        .i_rst_n                    ( i_rst_n                   ),

        .i_endpt_sel                ( i_endpt                   ),
        .i_usb_rxact                ( i_usb_rxact               ),
        .i_usb_rxval                ( i_usb_rxval               ),
        .i_usb_rxdat                ( i_usb_rxdat               ),

        .o_iap2_rx_packet_seq       ( iap2_rx_packet_seq        ),  //  接收到的包序号
        .o_iap2_rx_param_lenth      ( iap2_rx_param_lenth       ),  //  Request Challenge Response 中的 param_lenth
        .o_iap2_rx_param_data_vld   ( iap2_rx_param_data_vld    ),
        .o_iap2_rx_param_data       ( iap2_rx_param_data        ),  //  Request Challenge Response 中的 param_data

        .o_iap2_rx_android          ( iap2_rx_android           ),  //  成功收到安卓系统指令
        .o_iap2_rx_detect           ( iap2_rx_detect            ),  //  成功收到 FF 55 02 00 EE 10
        .o_iap2_rx_syn_ack          ( iap2_rx_syn_ack           ),  //  成功收到 SYN + ACK
        .o_iap2_rx_ack              ( iap2_rx_ack               ),  //  成功收到 ACK
        .o_iap2_rx_rst              ( iap2_rx_rst               ),  //  成功收到 RST
        .o_iap2_rx_slp              ( iap2_rx_slp               ),  //  成功收到 SLP
        .o_iap2_rx_rac              ( iap2_rx_rac               ),  //  成功收到 Request Authentication Certificate
        .o_iap2_rx_rcr              ( iap2_rx_rcr               ),  //  成功收到 Request Challenge Response
        .o_iap2_rx_ar               ( iap2_rx_ar                ),  //  成功收到 Authentication Result[PASS]
        .o_iap2_rx_si               ( iap2_rx_si                ),  //  成功收到 Start Identification
        .o_iap2_rx_ia               ( iap2_rx_ia                ),  //  成功收到 Identification Accept
        .o_iap2_rx_pwrupdate        ( iap2_rx_pwrupdate         )   //  成功收到 Power Update
    );
endmodule