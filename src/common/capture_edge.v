// ------------------------------------------------------------------------------------------------
// Company                      : Wuhan Guide Sensmart Tech Co., Ltd
// Create Date                  : 20240815
// Author Name                  : zhangjl
// Module Name                  : capture_edge
// Project Name                 : zp44b
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
module capture_edge #(
    parameter EDGE = "rising"  //rising/falling
) (
    //global input interface
    input  wire [1       - 1 : 0] i_Sys_clk,
    input  wire [1       - 1 : 0] i_Rst_n,
    input  wire [1       - 1 : 0] i_Din_valid,
    output wire [1       - 1 : 0] o_Dout_edge
);  //capture_edge
    //**********************************************************************************************
    //parameter and regs defination
    //**********************************************************************************************
    reg  [1   - 1 : 0] i_Din_valid_d1;
    reg  [1   - 1 : 0] i_Din_valid_d2;
    wire [ 1  - 1 : 0] vld_pos;
    wire [ 1  - 1 : 0] vld_neg;
    always @(posedge i_Sys_clk) begin
        if (~i_Rst_n) begin
            i_Din_valid_d1 <= 'd0;
            i_Din_valid_d2 <= 'd0;
        end else begin
            i_Din_valid_d1 <= i_Din_valid;
            i_Din_valid_d2 <= i_Din_valid_d1;
        end
    end
    // assign vld_pos = i_Din_valid & ~i_Din_valid_d1;
    // assign vld_neg = i_Din_valid_d1 & ~i_Din_valid;
    assign vld_pos = i_Din_valid_d1 & ~i_Din_valid_d2;
    assign vld_neg = i_Din_valid_d2 & ~i_Din_valid_d1;

    generate
        if (EDGE == "rising") assign o_Dout_edge = vld_pos;
        else assign o_Dout_edge = vld_neg;
    endgenerate

endmodule
