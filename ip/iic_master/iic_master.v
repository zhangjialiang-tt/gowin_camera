// ------------------------------------------------------------------------------------------------
// Company                      : Wuhan Guide Sensmart Tech Co., Ltd
// Create Date                  : 20241226
// Author Name                  : GD08766_HYK
// Module Name                  : iic_master
// Project Name                 : 
// Tarject Device               : 
// Tool Versions                : 
// Description                  : IIC 主机驱动，支持读写两种模式，读写字节数可自定义，可通过参数
//                                配置精确调整时序
//
// Revision                     : V1.0
// Modified by                  : 
// Modified Data                : 
// Additional Comments          : 
// ------------------------------------------------------------------------------------------------
//  IIC timing set:
//
//          | START         | DATA          | STOP_PRE      | STOP          |
//          ________________         _______                 ________________
//  SCL:                    \_______/       \_______________/
//          ________              _______________                    ________
//  SDA:            \____________X_______________X__________________/
//          |-T1----|       |-T3-|                          |-T2----|
module iic_master #(
    parameter CLK_IN_FREQ       = 100_000_000                               ,   //  模块工作时钟频率
    parameter IIC_SCL_RQEQ      = 400_000                                   ,   //  IIC 时钟频率
    parameter IIC_TIMING_T1_NS  = 1250                                      ,   //  T1
    parameter IIC_TIMING_T2_NS  = 1250                                      ,   //  T2
    parameter IIC_TIMING_T3_NS  = 500                                       ,   //  T3
    parameter WP_TO_RS          = 1                                         ,   //  是否需要先发 P 再发 S 以开启读操作
    parameter WAIT_SLAVE        = 1                                         ,   //  从机主动拉低 SCL 时是否需要主动等待从机
    parameter DATA_BYTE_NUM     = 2                                         ,   //  读写数据长度（以字节为单位）
    parameter CLK_CNT_WIDTH     = $clog2((CLK_IN_FREQ / IIC_SCL_RQEQ) - 1)  ,   //  （无需例化）IIC 时钟计数器位宽
    parameter BYTE_CNT_WIDTH    = $clog2(DATA_BYTE_NUM)                         //  （无需例化）读写字节长度位宽
) (
    input                                       i_clk           ,
    input                                       i_rst_n         ,

    output  reg                                 o_iic_scl_oe    ,
    input                                       i_iic_scl_in    ,
    output  reg                                 o_iic_scl_out   ,
    output  reg                                 o_iic_sda_oe    ,
    input                                       i_iic_sda_in    ,
    output  reg                                 o_iic_sda_out   ,

    input           [6:0]                       i_slave_addr    ,   //  从机地址
    input           [7:0]                       i_reg_addr      ,   //  寄存器地址
    input           [DATA_BYTE_NUM * 8 - 1:0]   i_write_data    ,   //  写入数据
    input                                       i_iic_en        ,   //  IIC 读写使能 脉冲
    input                                       i_wrrd          ,   //  IIC 读写模式标志 0-写 1-读

    output  reg                                 o_read_vld      ,   //  读数据有效 脉冲
    output  reg     [DATA_BYTE_NUM * 8 - 1:0]   o_read_data     ,   //  读到的数据
    output  reg                                 o_iic_ack       ,
    output  reg                                 o_busy              //  忙信号
);
//  状态机定义
    localparam ST_IDLE      = 4'd0  ;
    localparam WR_START     = 4'd1  ;
    localparam WR_ADDR      = 4'd2  ;
    localparam WR_CMD       = 4'd3  ;
    localparam WR_DATA      = 4'd4  ;
    localparam WR_STOP_PRE  = 4'd5  ;
    localparam WR_STOP      = 4'd6  ;
    localparam RD_START_PRE = 4'd7  ;
    localparam RD_START     = 4'd8  ;
    localparam RD_ADDR      = 4'd9  ;
    localparam RD_DATA      = 4'd10 ;
    localparam RD_STOP_PRE  = 4'd11 ;
    localparam RD_STOP      = 4'd12 ;
    localparam END_WAIT     = 4'd13 ;
    reg     [3:0]   state_c         ;
    reg     [3:0]   state_n         ;
    wire            idle_ws         ;
    wire            ws_wa           ;
    wire            wa_wc           ;
    wire            wc_wpp          ;
    wire            wc_wd           ;
    wire            wc_rsp          ;
    wire            wd_wpp          ;
    wire            wd_wd           ;
    wire            wpp_wp          ;
    wire            wp_idle         ;
    wire            wp_rs           ;
    wire            rsp_rs          ;
    wire            rs_ra           ;
    wire            ra_rd           ;
    wire            rd_rpp          ;
    wire            rd_rd           ;
    wire            rpp_rp          ;
    wire            rp_idle         ;

//  参数定义
    // 从该时钟开始到 T1 跳变位置之间的系统时钟数
    localparam SCL_T1_POSITION = (CLK_IN_FREQ / IIC_SCL_RQEQ) - (IIC_TIMING_T1_NS / (1_000_000_000 / CLK_IN_FREQ));
    // 从该时钟开始到 T2 跳变位置之间的系统时钟数
    localparam SCL_T2_POSITION = IIC_TIMING_T2_NS / (1_000_000_000 / CLK_IN_FREQ);
    // 从该时钟开始到 T3 跳变位置之间的系统时钟数
    localparam SCL_T3_POSITION = IIC_TIMING_T3_NS / (1_000_000_000 / CLK_IN_FREQ);

//  信号定义
    reg     [CLK_CNT_WIDTH - 1:0]       scl_cnt         ;
    wire                                scl_cnt_end     ;

    reg                                 iic_en_r1       ;
    wire                                iic_en_pos      ;
    reg                                 wrrd_mode       ;
    reg     [6:0]                       slave_addr      ;
    reg     [7:0]                       reg_addr        ;
    reg     [DATA_BYTE_NUM * 8 - 1:0]   write_data      ;

    reg     [7:0]                       bit_cnt         ;

    reg                                 sda_send_en     ;

    reg     [BYTE_CNT_WIDTH - 1:0]      byte_cnt        ;
    reg     [2:0]                       wait_cnt        ;   //APB 访问将BUSY延长几个周期

    reg                                 ack_vld         ;
    reg                                 ack_reg         ;


//  状态机
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            state_c <= ST_IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end
    assign idle_ws = (state_c == ST_IDLE     ) && (iic_en_pos);
    assign ws_wa   = (state_c == WR_START    ) && (scl_cnt_end);
    assign wa_wc   = (state_c == WR_ADDR     ) && (bit_cnt == 8'd8 && scl_cnt_end);
    assign wc_wpp  = (state_c == WR_CMD      ) && (bit_cnt == 8'd8 && scl_cnt_end && wrrd_mode == 1'd1 && WP_TO_RS == 1'd1);
    assign wc_wd   = (state_c == WR_CMD      ) && (bit_cnt == 8'd8 && scl_cnt_end && wrrd_mode == 1'd0);
    assign wc_rsp  = (state_c == WR_CMD      ) && (bit_cnt == 8'd8 && scl_cnt_end && wrrd_mode == 1'd1 && WP_TO_RS == 1'd0);
    assign wd_wpp  = (state_c == WR_DATA     ) && (bit_cnt == 8'd8 && scl_cnt_end && byte_cnt == (DATA_BYTE_NUM - 1));
    assign wd_wd   = (state_c == WR_DATA     ) && (bit_cnt == 8'd8 && scl_cnt_end && byte_cnt < (DATA_BYTE_NUM - 1));
    assign wpp_wp  = (state_c == WR_STOP_PRE ) && (scl_cnt_end);
    assign wp_idle = (state_c == WR_STOP     ) && (scl_cnt_end && wrrd_mode == 1'd0);
    assign wp_rs   = (state_c == WR_STOP     ) && (scl_cnt_end && wrrd_mode == 1'd1);
    assign rsp_rs  = (state_c == RD_START_PRE) && (scl_cnt_end);
    assign rs_ra   = (state_c == RD_START    ) && (scl_cnt_end);
    assign ra_rd   = (state_c == RD_ADDR     ) && (bit_cnt == 8'd8 && scl_cnt_end);
    assign rd_rpp  = (state_c == RD_DATA     ) && (bit_cnt == 8'd8 && scl_cnt_end && byte_cnt == (DATA_BYTE_NUM - 1));
    assign rd_rd   = (state_c == RD_DATA     ) && (bit_cnt == 8'd8 && scl_cnt_end && byte_cnt < (DATA_BYTE_NUM - 1));
    assign rpp_rp  = (state_c == RD_STOP_PRE ) && (scl_cnt_end);
    assign rp_idle = (state_c == RD_STOP     ) && (scl_cnt_end);
    always @(*) begin
        if (~i_rst_n) begin
            state_n = ST_IDLE;
        end
        else begin
            case (state_c)
                ST_IDLE: begin
                    if (idle_ws) begin
                        state_n = WR_START;
                    end
                    else begin
                        state_n = ST_IDLE;
                    end
                end
                WR_START: begin
                    if (ws_wa) begin
                        state_n = WR_ADDR;
                    end
                    else begin
                        state_n = WR_START;
                    end
                end
                WR_ADDR: begin
                    if (wa_wc) begin
                        state_n = WR_CMD;
                    end
                    else begin
                        state_n = WR_ADDR;
                    end
                end
                WR_CMD: begin
                    if (wc_wpp) begin
                        state_n = WR_STOP_PRE;
                    end
                    else if (wc_wd) begin
                        state_n = WR_DATA;
                    end
                    else if (wc_rsp) begin
                        state_n = RD_START_PRE;
                    end
                    else begin
                        state_n = WR_CMD;
                    end
                end
                WR_DATA: begin
                    if (wd_wpp) begin
                        state_n = WR_STOP_PRE;
                    end
                    else if (wd_wd) begin
                        state_n = WR_DATA;
                    end
                    else begin
                        state_n = WR_DATA;
                    end
                end
                WR_STOP_PRE: begin
                    if (wpp_wp) begin
                        state_n = WR_STOP;
                    end
                    else begin
                        state_n = WR_STOP_PRE;
                    end
                end
                WR_STOP: begin
                    if (wp_idle) begin
                        state_n = END_WAIT;
                    end
                    else if (wp_rs) begin
                        state_n = RD_START;
                    end
                    else begin
                        state_n = WR_STOP;
                    end
                end
                RD_START_PRE: begin
                    if (rsp_rs) begin
                        state_n = RD_START;
                    end
                    else begin
                        state_n = RD_START_PRE;
                    end
                end
                RD_START: begin
                    if (rs_ra) begin
                        state_n = RD_ADDR;
                    end
                    else begin
                        state_n = RD_START;
                    end
                end
                RD_ADDR: begin
                    if (ra_rd) begin
                        state_n = RD_DATA;
                    end
                    else begin
                        state_n = RD_ADDR;
                    end
                end
                RD_DATA: begin
                    if (rd_rpp) begin
                        state_n = RD_STOP_PRE;
                    end
                    else if (rd_rd) begin
                        state_n = RD_DATA;
                    end
                    else begin
                        state_n = RD_DATA;
                    end
                end
                RD_STOP_PRE: begin
                    if (rpp_rp) begin
                        state_n = RD_STOP;
                    end
                    else begin
                        state_n = RD_STOP_PRE;
                    end
                end
                RD_STOP: begin
                    if (rp_idle) begin
                        state_n = END_WAIT;
                    end
                    else begin
                        state_n = RD_STOP;
                    end
                end
                END_WAIT: if(wait_cnt == 3'd7)begin
                    state_n = ST_IDLE;
                end
                else begin
                    state_n = END_WAIT;
                end
                default: state_n = ST_IDLE;
            endcase
        end
    end

always @(posedge i_clk ) begin
    if(state_c == END_WAIT)begin
        wait_cnt <= wait_cnt + 1'b1;
    end
    else begin
        wait_cnt <= 3'd0;
    end
end

//  寄存输入
    // 读写使能上升沿
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_en_r1  <= 1'd0;
        end
        else begin
            iic_en_r1  <= i_iic_en    ;
        end
    end
    assign iic_en_pos = (~iic_en_r1 && i_iic_en);
    // 当读写使能上升沿到来时寄存输入数据
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            wrrd_mode  <= 1'd0;
            slave_addr <= 1'd0;
            reg_addr   <= 1'd0;
            write_data <= 1'd0;
        end
        else if (iic_en_pos) begin
            wrrd_mode  <= i_wrrd      ;
            slave_addr <= i_slave_addr;
            reg_addr   <= i_reg_addr  ;
            write_data <= i_write_data;
        end
        else if (state_c == WR_DATA && sda_send_en && bit_cnt < 8'd8) begin
            write_data <= {write_data[DATA_BYTE_NUM * 8 - 2:0], 1'd1};
        end
        else begin
            wrrd_mode  <= wrrd_mode ;
            slave_addr <= slave_addr;
            reg_addr   <= reg_addr  ;
            write_data <= write_data;
        end
    end
    
//  产生 IIC 时钟
    // 时钟计数器
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            scl_cnt <= 1'd0;
        end
        else if (state_c == ST_IDLE) begin
            scl_cnt <= 1'd0;
        end
        else if (WAIT_SLAVE == 1'd1 && state_c != ST_IDLE && o_iic_scl_out && ~i_iic_scl_in) begin    // 从机若强行拉低 SCL 则等待
            scl_cnt <= scl_cnt;
        end
        else if (scl_cnt_end) begin
            scl_cnt <= 1'd0;
        end
        else begin
            scl_cnt <= scl_cnt + 1'd1;
        end
    end
    assign scl_cnt_end = (scl_cnt == CLK_IN_FREQ / IIC_SCL_RQEQ - 1);
    // 时钟输出使能
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iic_scl_oe <= 1'd1;
        end
        else begin
            o_iic_scl_oe <= 1'd1;
        end
    end
    // 生成时钟
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iic_scl_out <= 1'd1;
        end
        else if ((state_c == WR_START || 
                  state_c == WR_ADDR || 
                  state_c == WR_CMD || 
                  state_c == WR_DATA || 
                  state_c == RD_START || 
                  state_c == RD_ADDR || 
                  state_c == RD_DATA) && scl_cnt_end) begin
            o_iic_scl_out <= 1'd0;
        end
        else if ((state_c == WR_STOP_PRE || state_c == RD_START_PRE || state_c == RD_STOP_PRE) && scl_cnt_end) begin
            o_iic_scl_out <= 1'd1;
        end
        else if ((state_c == WR_ADDR || 
                  state_c == WR_CMD || 
                  state_c == WR_DATA || 
                  state_c == RD_ADDR || 
                  state_c == RD_DATA) && scl_cnt == CLK_IN_FREQ / IIC_SCL_RQEQ / 2 - 1) begin
            o_iic_scl_out <= 1'd1;
        end
        else begin
            o_iic_scl_out <= o_iic_scl_out;
        end
    end

//  bit 计数器
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            bit_cnt <= 1'd0;
        end
        else if (state_c != state_n || wd_wd || rd_rd) begin
            bit_cnt <= 1'd0;
        end
        else if (scl_cnt_end) begin
            bit_cnt <= bit_cnt + 1'd1;
        end
        else begin
            bit_cnt <= bit_cnt;
        end
    end

//  byte 计数器
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            byte_cnt <= 'd0;
        end
        else if (state_c == ST_IDLE) begin
            byte_cnt <= 'd0;
        end
        else if (state_c == WR_DATA && bit_cnt == 8'd8 && scl_cnt_end) begin
            byte_cnt <= byte_cnt + 2'd1;
        end
        else if (state_c == RD_DATA && bit_cnt == 8'd8 && scl_cnt_end) begin
            byte_cnt <= byte_cnt + 2'd1;
        end
        else begin
            byte_cnt <= byte_cnt;
        end
    end

//  sda_send_en 数据发送标志
    always @(*) begin
        if (~i_rst_n) begin
            sda_send_en = 1'd0;
        end
        else if ((state_c == WR_START || state_c == RD_START) && scl_cnt == SCL_T1_POSITION - 1) begin
            sda_send_en = 1'd1;
        end
        else if ((state_c == WR_STOP || state_c == RD_STOP) && scl_cnt == SCL_T2_POSITION - 1) begin
            sda_send_en = 1'd1;
        end
        else if (state_c != WR_START && state_c != RD_START && state_c != WR_STOP && state_c != RD_STOP && 
                 scl_cnt == SCL_T3_POSITION - 1) begin
            sda_send_en = 1'd1;
        end
        else begin
            sda_send_en = 1'd0;
        end
    end

//  SDA_OE
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iic_sda_oe <= 1'd1;
        end
        else if (state_c != RD_DATA && bit_cnt == 8'd8 && sda_send_en) begin
            o_iic_sda_oe <= 1'd0;
        end
        else if (state_c != RD_DATA && bit_cnt == 8'd0 && sda_send_en) begin
            o_iic_sda_oe <= 1'd1;
        end
        else if (state_c == RD_DATA && bit_cnt == 8'd0 && sda_send_en) begin
            o_iic_sda_oe <= 1'd0;
        end
        else if (state_c == RD_DATA && bit_cnt == 8'd8 && sda_send_en) begin
            o_iic_sda_oe <= 1'd1;
        end
        else begin
            o_iic_sda_oe <= o_iic_sda_oe;
        end
    end

//  SDA_OUT
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_iic_sda_out <= 1'd1;
        end
        else if ((state_c == WR_START || state_c == RD_START) && sda_send_en) begin
            o_iic_sda_out <= 1'd0;
        end
        else if ((state_c == WR_STOP || state_c == RD_STOP) && sda_send_en) begin
            o_iic_sda_out <= 1'd1;
        end
        else if ((state_c == WR_STOP_PRE || state_c == RD_STOP_PRE) && sda_send_en) begin
            o_iic_sda_out <= 1'd0;
        end
        else if (state_c == RD_START_PRE && sda_send_en) begin
            o_iic_sda_out <= 1'd1;
        end
        else if ((state_c == WR_ADDR || state_c == RD_ADDR) && sda_send_en) begin
            case (bit_cnt)
                8'd0   : o_iic_sda_out <= slave_addr[6];
                8'd1   : o_iic_sda_out <= slave_addr[5];
                8'd2   : o_iic_sda_out <= slave_addr[4];
                8'd3   : o_iic_sda_out <= slave_addr[3];
                8'd4   : o_iic_sda_out <= slave_addr[2];
                8'd5   : o_iic_sda_out <= slave_addr[1];
                8'd6   : o_iic_sda_out <= slave_addr[0];
                8'd7   : o_iic_sda_out <= (state_c == WR_ADDR) ? 1'd0 : 1'd1;
                default: o_iic_sda_out <= 1'd1;
            endcase
        end
        else if (state_c == WR_CMD && sda_send_en) begin
            case (bit_cnt)
                8'd0   : o_iic_sda_out <= reg_addr[7];
                8'd1   : o_iic_sda_out <= reg_addr[6];
                8'd2   : o_iic_sda_out <= reg_addr[5];
                8'd3   : o_iic_sda_out <= reg_addr[4];
                8'd4   : o_iic_sda_out <= reg_addr[3];
                8'd5   : o_iic_sda_out <= reg_addr[2];
                8'd6   : o_iic_sda_out <= reg_addr[1];
                8'd7   : o_iic_sda_out <= reg_addr[0];
                default: o_iic_sda_out <= 1'd1;
            endcase
        end
        // else if (state_c == WR_DATA && sda_send_en) begin
        //     case (bit_cnt)
        //         8'd0   : o_iic_sda_out <= write_data[7];
        //         8'd1   : o_iic_sda_out <= write_data[6];
        //         8'd2   : o_iic_sda_out <= write_data[5];
        //         8'd3   : o_iic_sda_out <= write_data[4];
        //         8'd4   : o_iic_sda_out <= write_data[3];
        //         8'd5   : o_iic_sda_out <= write_data[2];
        //         8'd6   : o_iic_sda_out <= write_data[1];
        //         8'd7   : o_iic_sda_out <= write_data[0];
        //         default: o_iic_sda_out <= 1'd1;
        //     endcase
        // end
        else if (state_c == WR_DATA && sda_send_en && bit_cnt < 8'd8) begin
            o_iic_sda_out <= write_data[DATA_BYTE_NUM * 8 - 1];
        end
        else if (state_c == RD_DATA && bit_cnt == 8'd8 && sda_send_en) begin
            o_iic_sda_out <= 1'd0;
        end
        else if (state_c == RD_DATA && bit_cnt == 8'd0 && sda_send_en) begin
            o_iic_sda_out <= 1'd1;
        end
        else begin
            o_iic_sda_out <= o_iic_sda_out;
        end
    end

//  读数据
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_read_data <= 1'd0;
        end
        else if (state_c == RD_DATA && bit_cnt < 8'd8 && scl_cnt == ((CLK_IN_FREQ / IIC_SCL_RQEQ) / 4) * 3 - 1) begin
            o_read_data <= {o_read_data[DATA_BYTE_NUM * 8 - 2:0], i_iic_sda_in};
        end
        else begin
            o_read_data <= o_read_data;
        end
    end

always @(posedge i_clk ) begin
    if(state_c == ST_IDLE)begin
        ack_vld <= 1'b0;
    end
    else if((scl_cnt == ((CLK_IN_FREQ / IIC_SCL_RQEQ) / 4) * 3 - 1) && (bit_cnt == 8'd8))begin
        ack_vld <= 1'b1;
    end
    else begin
        ack_vld <= 1'b0;
    end
end
always @(posedge i_clk ) begin
    if((o_iic_sda_oe == 1'b1) && (scl_cnt == ((CLK_IN_FREQ / IIC_SCL_RQEQ) / 4) * 3 - 1)  && (bit_cnt == 8'd8))begin
        ack_reg <= o_iic_sda_out;
    end
    else if((scl_cnt == ((CLK_IN_FREQ / IIC_SCL_RQEQ) / 4) * 3 - 1)  && (bit_cnt == 8'd8))begin
        ack_reg <= i_iic_sda_in;
    end
    else begin
        ack_reg <= ack_reg;
    end
end

always @(posedge i_clk ) begin
    if(state_n == WR_START)begin
        o_iic_ack <= 1'b0;
    end
    else if((ack_reg == 1'b1) && (ack_vld == 1'b1))begin
        o_iic_ack <= 1'b1;
    end
    else begin
        o_iic_ack <= o_iic_ack;
    end
end

//  读数据有效
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_read_vld <= 1'd0;
        end
        else if (rp_idle) begin
            o_read_vld <= 1'd1;
        end
        else begin
            o_read_vld <= 1'd0;
        end
    end

//  忙信号
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_busy <= 1'd0;
        end
        else if (idle_ws) begin
            o_busy <= 1'd1;
        end
        else if ((state_c == END_WAIT) && (wait_cnt == 3'b111)) begin
            o_busy <= 1'd0;
        end
        else begin
            o_busy <= o_busy;
        end
    end
endmodule