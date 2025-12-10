// ------------------------------------------------------------------------------------------------
// Company                      : Wuhan Guide Sensmart Tech Co., Ltd
// Create Date                  : 20241124
// Author Name                  : zhangjl
// Module Name                  : gen_test
// Project Name                 : k7_base
// Tarject Device               : Titanium-ti180
// Tool Versions                : Efinix Efinity-2023.2.307.1.14
// Description                  : 该文件设计思路是
//                              
//                              
//                              
// Parameter Description        : IMAGE_WIDTH-->图像宽度
//                                IMAGE_HEIGHT-->图像高度
// Port Description             :
// Revision                     : 1.00.0
// Modified by                  :
// Modified Data                :
// Additional Comments          :
// Standard Syndoc              :
// ------------------------------------------------------------------------------------------------
module gen_test #(
    parameter USE_EXTER_RST = 0,  //是否使用外部复位信号
    parameter DW = 8,
    parameter CW = 10,
    parameter WR_PORT = 0,
    parameter STS_FREQ = 50_000_000,
    parameter FRAME_RATE = 50,
    parameter IMAGE_WIDTH = 'd640,
    parameter IMAGE_HEIGHT = 'd480
) (
    //global input interface
    input  wire [            1       - 1 : 0] i_Sys_clk,
    input  wire [            1       - 1 : 0] i_Rst_n,
    input  wire [            1       - 1 : 0] i_External_rst,
    input  wire [32                  - 1 : 0] i_Buffer_addr_0,
    input  wire [32                  - 1 : 0] i_Buffer_addr_1,
    output wire [1                   - 1 : 0] o_Field_rst,
    output reg  [32                  - 1 : 0] o_Base_addr,
    output wire [1                   - 1 : 0] o_Image_vs,
    output wire [1                   - 1 : 0] o_Image_de,
    output wire [DW                  - 1 : 0] o_Image_data
);  //gen_test
    //**********************************************************************************************
    //parameter and regs defination
    //**********************************************************************************************
    localparam FRAME_TIME = 1000 / FRAME_RATE;  //ms
    localparam FRAME_CNT = STS_FREQ * FRAME_TIME / 1000;
    localparam [31:0]TOTAL_PIXEL = IMAGE_WIDTH * IMAGE_HEIGHT;
    localparam POWERON_WAIT = 1024;  // 
    localparam TOTAL_PIXEL_W = $clog2(TOTAL_PIXEL);
    // 1000/STS_FREQ
    (*mark_debug = "false"*)reg  [ 1   - 1 : 0] dout_vld;
    (*mark_debug = "false"*)reg  [CW   - 1 : 0] hcnt;
    (*mark_debug = "false"*)reg  [CW   - 1 : 0] vcnt;
    (*mark_debug = "false"*)reg  [DW   - 1 : 0] dout;
    (*mark_debug = "false"*)reg  [ 32  - 1 : 0] cnt;
    (*mark_debug = "false"*)wire [ 1   - 1 : 0] external_rst;
    (*mark_debug = "false"*)reg  [16   - 1 : 0] poweron_wait;

    capture_edge #(
        .EDGE("rising")
    ) capture_edge_1_inst (
        .i_Sys_clk  (i_Sys_clk),
        .i_Rst_n    (i_Rst_n),
        .i_Din_valid(i_External_rst),
        .o_Dout_edge(external_rst)
    );
    //**********************************************************************************************
    // module1
    //**********************************************************************************************
    generate
        if (USE_EXTER_RST) begin
            always @(posedge i_Sys_clk) begin
                if (~i_Rst_n) cnt <= 'd0;
                else if (external_rst) cnt <= 'd0;
                // else if (cnt == FRAME_CNT - 1'b1) cnt <= 'd0;
                else
                    cnt <= cnt + 'd1;
            end
        end else begin
            always @(posedge i_Sys_clk) begin
                if (~i_Rst_n) cnt <= 'd0;
                else if (poweron_wait < POWERON_WAIT - 1) cnt <= 'd0;
                else if (cnt == FRAME_CNT - 1'b1) cnt <= 'd0;
                else cnt <= cnt + 'd1;
            end
        end
    endgenerate
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) poweron_wait <= 'd0;
        else if (poweron_wait == POWERON_WAIT - 1) poweron_wait <= poweron_wait;
        else poweron_wait <= poweron_wait + 1;
    end
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) dout_vld <= 'd0;
        else if (poweron_wait < POWERON_WAIT - 1) dout_vld <= 'd0;
        else if (cnt == TOTAL_PIXEL) dout_vld <= 'd0;
        else if (cnt == 0) dout_vld <= 'd1;
        else dout_vld <= dout_vld;
    end
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) begin
            hcnt <= 'd0;
            vcnt <= 'd0;
        end else if (dout_vld) begin
            if (hcnt == IMAGE_WIDTH - 1'b1) begin
                hcnt <= 'd0;
                vcnt <= vcnt + 'd1;
            end else begin
                hcnt <= hcnt + 'd1;
                vcnt <= vcnt;
            end
        end else begin
            hcnt <= 'd0;
            vcnt <= 'd0;
        end
    end
    reg [16  - 1 : 0] grad;
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) begin
            grad <= 'b0;
        end else if (vcnt[6] == 0) begin
            if (hcnt[6] == 0) grad <= 'd1;
            else grad <= 'd16383;
        end else if (vcnt[6] == 1) begin
            if (hcnt[6] == 0) grad <= 'd16383;
            else grad <= 'd1;
        end
    end
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) dout <= 'd0;
        else if (dout_vld) begin
            if (dout == 255) dout <= 0;
            else dout <= dout + 'd1;
        end else dout <= 0;
    end
    // assign o_Dout = {8'd0, grad[7:0]};
    reg [1  - 1 : 0] dout_vld_d1;
    reg [1  - 1 : 0] dout_vld_d2;
    reg [1  - 1 : 0] dout_vld_d3;
    reg [1  - 1 : 0] dout_vld_d4;
    reg [1  - 1 : 0] dout_vld_d5;
    reg [1  - 1 : 0] dout_vld_d6;
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) begin
            dout_vld_d1 <= 'd0;
            dout_vld_d2 <= 'd0;
            dout_vld_d3 <= 'd0;
            dout_vld_d4 <= 'd0;
            dout_vld_d5 <= 'd0;
            dout_vld_d6 <= 'd0;
        end else begin
            dout_vld_d1 <= dout_vld;
            dout_vld_d2 <= dout_vld_d1;
            dout_vld_d3 <= dout_vld_d2;
            dout_vld_d4 <= dout_vld_d3;
            dout_vld_d5 <= dout_vld_d4;
            dout_vld_d6 <= dout_vld_d5;
        end
    end
    reg [16  - 1 : 0] dbg_hcnt;
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) begin
            dbg_hcnt <= 0;
        end else if (dout_vld_d4) begin
            dbg_hcnt <= dbg_hcnt == IMAGE_WIDTH - 1 ? 0 : dbg_hcnt + 1;
        end
    end
    reg [1  - 1 : 0] addr_change_flag;
    generate
        if (WR_PORT == 1) begin
            // assign o_Field_rst = ~dout_vld_d4 && dout_vld_d3;//1 clcok
            // assign o_Field_rst = ~dout_vld_d3 && dout_vld_d2;//2 clcok
            // assign o_Field_rst = ~dout_vld_d2 && dout_vld_d1;//3 clcok
            assign o_Field_rst = ~dout_vld_d1 && dout_vld;//4 clcok
            // reg [1  - 1 : 0] addr_change_flag;
            always @(posedge i_Sys_clk) begin
                if (~i_Rst_n) begin
                    o_Base_addr <= i_Buffer_addr_0;
                    addr_change_flag <= 'd0;
                end else begin
                    addr_change_flag <= (~dout_vld_d2 && dout_vld_d1) ? ~addr_change_flag : addr_change_flag;
                    if (addr_change_flag) o_Base_addr <= i_Buffer_addr_0;
                    else o_Base_addr <= i_Buffer_addr_1;
                end
            end
    data_avl_delay#(
    .DW    ( 1) ,
    .DELAY_NUM    ( 20)
    )inst_signal_delay1(
    .i_clk(i_Sys_clk),
    .i_rst_n(i_Rst_n),
    .i_pixel_vld(1'b1),
    .i_data(dout_vld_d4),
    .o_data(o_Image_vs)
);
    data_avl_delay#(
    .DW    ( 1) ,
    .DELAY_NUM    ( 20)
    )inst_signal_delay2(
    .i_clk(i_Sys_clk),
    .i_rst_n(i_Rst_n),
    .i_pixel_vld(1'b1),
    .i_data(dout_vld_d4),
    .o_data(o_Image_de)
);
    data_avl_delay#(
    .DW    ( 16) ,
    .DELAY_NUM    ( 20)
    )inst_signal_delay3(
    .i_clk(i_Sys_clk),
    .i_rst_n(i_Rst_n),
    .i_pixel_vld(1'b1),
    // .i_data(dbg_hcnt),
    .i_data(grad),
    .o_data(o_Image_data)
);
        end else begin
            assign o_Field_rst = ~dout_vld_d5 && dout_vld_d6;
            // reg [1  - 1 : 0] addr_change_flag;
            always @(posedge i_Sys_clk) begin
                if (~i_Rst_n) begin
                    o_Base_addr <= i_Buffer_addr_0;
                    addr_change_flag <= 'd0;
                end else begin
                    addr_change_flag <= (~dout_vld_d2 && dout_vld_d3) ? ~addr_change_flag : addr_change_flag;
                    if (addr_change_flag) o_Base_addr <= i_Buffer_addr_0;
                    else o_Base_addr <= i_Buffer_addr_1;
                end
            end
    assign o_Image_vs   = dout_vld_d4;  //dout_vld;
    assign o_Image_de   = dout_vld_d4;  //dout_vld;
    assign o_Image_data = dbg_hcnt;
        end
    endgenerate
    //**********************************************************************************************
endmodule

