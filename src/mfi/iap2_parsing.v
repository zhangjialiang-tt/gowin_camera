module iap2_parsing (
    input                       i_usb_user_clk              ,
    input                       i_rst_n                     ,

    input           [3:0]       i_endpt_sel                 ,
    input                       i_usb_rxact                 ,
    input                       i_usb_rxval                 ,
    input           [7:0]       i_usb_rxdat                 ,

    output  reg     [7:0]       o_iap2_rx_packet_seq        ,   //  接收到的包序号
    output  reg     [15:0]      o_iap2_rx_param_lenth       ,   //  Request Challenge Response 中的 param_lenth
    output  reg                 o_iap2_rx_param_data_vld    ,
    output  reg     [7:0]       o_iap2_rx_param_data        ,   //  Request Challenge Response 中的 param_data

    output  reg                 o_iap2_rx_android           ,
    output  reg                 o_iap2_rx_detect            ,   //  成功收到 FF 55 02 00 EE 10
    output  reg                 o_iap2_rx_syn_ack           ,   //  成功收到 SYN + ACK
    output  reg                 o_iap2_rx_ack               ,   //  成功收到 ACK
    output  reg                 o_iap2_rx_rst               ,   //  成功收到 RST
    output  reg                 o_iap2_rx_slp               ,   //  成功收到 SLP
    output  reg                 o_iap2_rx_rac               ,   //  成功收到 Request Authentication Certificate
    output  reg                 o_iap2_rx_rcr               ,   //  成功收到 Request Challenge Response
    output  reg                 o_iap2_rx_ar                ,   //  成功收到 Authentication Result[PASS]
    output  reg                 o_iap2_rx_si                ,   //  成功收到 Start Identification
    output  reg                 o_iap2_rx_ia                ,   //  成功收到 Identification Accept
    output  reg                 o_iap2_rx_pwrupdate             //  成功收到 Power Update
);
//  参数定义
    localparam IDLE        = 5'd0 ;
    localparam SOP_FF      = 5'd1 ; //  Start of Packet MSB (FF)
    localparam SOP_5A      = 5'd2 ; //  Start of Packet LSB (5A)
    localparam SYN_ACK     = 5'd3 ; //  SYN + ACK
    localparam ACK_CONTROL = 5'd4 ;
    localparam ACK_SESSION = 5'd5 ; //  ACK
    localparam RST         = 5'd6 ; //  RST
    localparam SLP         = 5'd7 ; //  SLP
    localparam CMDTOKEN1   = 5'd8 ; //  CMD TOKEN (40)
    localparam CMDTOKEN2   = 5'd9 ; //  CMD TOKEN (40)
    localparam CMDID1_AA   = 5'd10;
    localparam RAC         = 5'd11; //  Request Authentication Certificate
    localparam RCR         = 5'd12; //  Request Challenge Response
    localparam AR          = 5'd13; //  Authentication Result[PASS]
    localparam CMDID1_1D   = 5'd14; //  CMD ID (1D)
    localparam SI          = 5'd15; //  Start Identification
    localparam IA          = 5'd16; //  Identification Accept
    localparam CMDID1_AE   = 5'd17; //  CMD ID (AE)
    localparam PWRUPDATE   = 5'd18; //  Power Update
    localparam DETECT_55   = 5'd19;
    localparam DETECT_02   = 5'd20;
    localparam DETECT_00   = 5'd21;
    localparam DETECT_EE   = 5'd22;
    localparam DETECT      = 5'd23;
    localparam ANDROID     = 5'd24;

//  信号定义
    reg     [3:0]       endpt_sel_temp  ;
    reg                 usb_rxact_temp  ;
    reg                 usb_rxval_temp  ;
    reg     [7:0]       usb_rxdat_temp  ;
    reg     [3:0]       endpt_sel       ;
    reg                 usb_rxact       ;
    reg                 usb_rxval       ;
    reg     [7:0]       usb_rxdat       ;

    reg     [7:0]       rx_cnt          ;
    reg                 iap2_rx_endpt   ;
    reg                 rx_done         ;   //  脉冲

    reg     [4:0]       rx_state        ;   //  非 DETECT 指令的其他指令解析状态
    reg     [7:0]       packet_len      ;   //  只取低 8 位

//  寄存数据
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            endpt_sel_temp <= 4'd0;
            usb_rxact_temp <= 1'd0;
            usb_rxval_temp <= 1'd0;
            usb_rxdat_temp <= 8'd0;
            endpt_sel <= 4'd0;
            usb_rxact <= 1'd0;
            usb_rxval <= 1'd0;
            usb_rxdat <= 8'd0;
        end
        else begin
            endpt_sel_temp <= i_endpt_sel;
            usb_rxact_temp <= i_usb_rxact;
            usb_rxval_temp <= i_usb_rxval;
            usb_rxdat_temp <= i_usb_rxdat;
            endpt_sel <= endpt_sel_temp;
            usb_rxact <= usb_rxact_temp;
            usb_rxval <= usb_rxval_temp;
            usb_rxdat <= usb_rxdat_temp;
        end
    end

//  判断是否是 iAP2 Interface 的接收端口
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iap2_rx_endpt <= 1'd0;
        end
        else if (endpt_sel == 4'd2) begin
            iap2_rx_endpt <= 1'd1;
        end
        else begin
            iap2_rx_endpt <= 1'd0;
        end
    end

//  字节计数器
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            rx_cnt <= 8'd0;
        end
        else if (~usb_rxact) begin
            rx_cnt <= 8'd0;
        end
        else if (usb_rxval && iap2_rx_endpt) begin
            rx_cnt <= rx_cnt + 8'd1;
        end
        else begin
            rx_cnt <= rx_cnt;
        end
    end

//  接收结束标志
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            rx_done <= 1'd0;
        end
        else if (iap2_rx_endpt && usb_rxact && ~usb_rxact_temp) begin
            rx_done <= 1'd1;
        end
        else begin
            rx_done <= 1'd0;
        end
    end

//  非 DETECT 指令的其他指令解析状态
    always @(posedge i_usb_user_clk) begin
        if (~usb_rxact) begin
            rx_state <= IDLE;
        end
        else if (iap2_rx_endpt && usb_rxact && usb_rxval) begin
            case (rx_state)
                IDLE: rx_state <= (rx_cnt == 8'd0 && usb_rxdat == 8'hFF) ? SOP_FF : rx_state;
                SOP_FF: begin
                    if (rx_cnt == 8'd1) begin
                        if (usb_rxdat == 8'h5A) begin
                            rx_state <= SOP_5A;
                        end
                        else if (usb_rxdat == 8'h55) begin
                            rx_state <= DETECT_55;
                        end
                        else begin
                            rx_state <= rx_state;
                        end
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                DETECT_55: rx_state <= (rx_cnt == 8'd2 && usb_rxdat == 8'h02) ? DETECT_02 : rx_state;
                DETECT_02: rx_state <= (rx_cnt == 8'd3 && usb_rxdat == 8'h00) ? DETECT_00 : rx_state;
                DETECT_00: rx_state <= (rx_cnt == 8'd4 && usb_rxdat == 8'hEE) ? DETECT_EE : rx_state;
                DETECT_EE: begin
                    if (rx_cnt == 8'd5) begin
                        if (usb_rxdat == 8'h10) begin
                            rx_state <= DETECT;
                        end
                        else if (usb_rxdat == 8'h20) begin
                            rx_state <= ANDROID;
                        end
                    end
                end
                SOP_5A: begin
                    if (rx_cnt == 8'd4) begin
                        if (usb_rxdat[7:6] == 2'b11) begin
                            rx_state <= SYN_ACK;
                        end
                        else if (usb_rxdat[6]) begin
                            rx_state <= ACK_CONTROL;
                        end
                        else if (usb_rxdat[4]) begin
                            rx_state <= RST;
                        end
                        else if (usb_rxdat[3]) begin
                            rx_state <= SLP;
                        end
                        else begin
                            rx_state <= rx_state;
                        end
                    end
                    else if (rx_cnt == 8'd9 && usb_rxdat == 8'h40) begin
                        rx_state <= CMDTOKEN1;
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                // ACK_CONTROL: rx_state <= (rx_cnt == 8'd7 && usb_rxdat == 8'h00) ? ACK_SESSION : rx_state;
                ACK_CONTROL: begin
                    if (rx_cnt == 8'd7 && usb_rxdat == 8'h00) begin
                        rx_state <= ACK_SESSION;
                    end
                    else if (rx_cnt == 8'd9 && usb_rxdat == 8'h40) begin
                        rx_state <= CMDTOKEN1;
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                CMDTOKEN1: rx_state <= (rx_cnt == 8'd10 && usb_rxdat == 8'h40) ? CMDTOKEN2 : rx_state;
                CMDTOKEN2: begin
                    if (rx_cnt == 8'd13) begin
                        if (usb_rxdat == 8'hAA) begin
                            rx_state <= CMDID1_AA;
                        end
                        else if (usb_rxdat == 8'h1D) begin
                            rx_state <= CMDID1_1D;
                        end
                        else if (usb_rxdat == 8'hAE) begin
                            rx_state <= CMDID1_AE;
                        end
                        else begin
                            rx_state <= rx_state;
                        end
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                CMDID1_AA: begin
                    if (rx_cnt == 8'd14) begin
                        if (usb_rxdat == 8'h00) begin
                            rx_state <= RAC;
                        end
                        else if (usb_rxdat == 8'h02) begin
                            rx_state <= RCR;
                        end
                        else if (usb_rxdat == 8'h05) begin
                            rx_state <= AR;
                        end
                        else begin
                            rx_state <= rx_state;
                        end
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                CMDID1_1D: begin
                    if (rx_cnt == 8'd14 && usb_rxdat == 8'h00) begin
                        rx_state <= SI;
                    end
                    else if (rx_cnt == 8'd14 && usb_rxdat == 8'h02) begin
                        rx_state <= IA;
                    end
                    else begin
                        rx_state <= rx_state;
                    end
                end
                CMDID1_AE: rx_state <= (rx_cnt == 8'd14 && usb_rxdat == 8'h01) ? PWRUPDATE : rx_state;
                default: rx_state <= rx_state;
            endcase
        end
        else begin
            rx_state <= rx_state;
        end
    end

//  获取非 DETECT 指令时的指令长度
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            packet_len <= 8'd0;
        end
        else if (rx_cnt == 8'd3 && usb_rxval) begin
            packet_len <= usb_rxdat;
        end
        else begin
            packet_len <= packet_len;
        end
    end

//  输出解析结果
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iap2_rx_android   <= 1'd0;
            o_iap2_rx_detect    <= 1'd0;
            o_iap2_rx_syn_ack   <= 1'd0;
            o_iap2_rx_ack       <= 1'd0;
            o_iap2_rx_rst       <= 1'd0;
            o_iap2_rx_slp       <= 1'd0;
            o_iap2_rx_rac       <= 1'd0;
            o_iap2_rx_rcr       <= 1'd0;
            o_iap2_rx_ar        <= 1'd0;
            o_iap2_rx_si        <= 1'd0;
            o_iap2_rx_ia        <= 1'd0;
            o_iap2_rx_pwrupdate <= 1'd0;
        end
        else if (rx_done && rx_state == ANDROID) begin
            o_iap2_rx_android <= 1'd1;
        end
        else if (rx_done && rx_state == DETECT) begin
            o_iap2_rx_detect <= 1'd1;
        end
        else if (rx_done && rx_cnt == packet_len) begin
            case (rx_state)
                SYN_ACK    : o_iap2_rx_syn_ack   <= 1'd1;
                ACK_SESSION: o_iap2_rx_ack       <= 1'd1;
                RST        : o_iap2_rx_rst       <= 1'd1;
                SLP        : o_iap2_rx_slp       <= 1'd1;
                RAC        : o_iap2_rx_rac       <= 1'd1;
                RCR        : o_iap2_rx_rcr       <= 1'd1;
                AR         : o_iap2_rx_ar        <= 1'd1;
                SI         : o_iap2_rx_si        <= 1'd1;
                IA         : o_iap2_rx_ia        <= 1'd1;
                PWRUPDATE  : o_iap2_rx_pwrupdate <= 1'd1;
                default    : ;
            endcase
        end
        else begin
            o_iap2_rx_android   <= 1'd0;
            o_iap2_rx_detect    <= 1'd0;
            o_iap2_rx_syn_ack   <= 1'd0;
            o_iap2_rx_ack       <= 1'd0;
            o_iap2_rx_rst       <= 1'd0;
            o_iap2_rx_slp       <= 1'd0;
            o_iap2_rx_rac       <= 1'd0;
            o_iap2_rx_rcr       <= 1'd0;
            o_iap2_rx_ar        <= 1'd0;
            o_iap2_rx_si        <= 1'd0;
            o_iap2_rx_ia        <= 1'd0;
            o_iap2_rx_pwrupdate <= 1'd0;
        end
    end

//  接收到的包序号
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iap2_rx_packet_seq <= 8'd0;
        end
        else if (rx_cnt == 8'd5 && usb_rxval) begin
            o_iap2_rx_packet_seq <= usb_rxdat;
        end
        else begin
            o_iap2_rx_packet_seq <= o_iap2_rx_packet_seq;
        end
    end

//  param_lenth / param_data
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iap2_rx_param_lenth <= 16'd0;
        end
        else if (rx_state == RCR && rx_cnt == 8'd15 && usb_rxval) begin
            o_iap2_rx_param_lenth[15:8] <= usb_rxdat;
        end
        else if (rx_state == RCR && rx_cnt == 8'd16 && usb_rxval) begin
            o_iap2_rx_param_lenth <= {o_iap2_rx_param_lenth[15:8], usb_rxdat} - 16'd4;
        end
        else begin
            o_iap2_rx_param_lenth <= o_iap2_rx_param_lenth;
        end
    end

    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iap2_rx_param_data_vld <= 1'd0;
            o_iap2_rx_param_data <= 8'd0;
        end
        else if (rx_state == RCR && rx_cnt >= 8'd19 && rx_cnt <= (o_iap2_rx_param_lenth[7:0] + 8'd18) && usb_rxval) begin
            o_iap2_rx_param_data_vld <= 1'd1;
            o_iap2_rx_param_data <= usb_rxdat;
        end
        else begin
            o_iap2_rx_param_data_vld <= 1'd0;
            o_iap2_rx_param_data <= o_iap2_rx_param_data;
        end
    end

endmodule