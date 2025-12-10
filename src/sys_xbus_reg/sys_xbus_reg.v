/*

Copyright (c) 2015-2016 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Wishbone RAM
 */
/*
 * Wishbone RAM
 */
module sys_xbus_reg #
(
    parameter NUM_REG               = 64,              // 增加寄存器数量到64（16读+16写+余量）
    parameter ADDR_WIDTH            = 32,              // width of address bus in bits
    parameter DATA_WIDTH            = 32,              // width of data bus in bits (8, 16, 32, or 64)
    parameter APB_REG_ADDR_BASE     = 32'h10000000,
    parameter SELECT_WIDTH          = (DATA_WIDTH/8)   // width of word select bus (1, 2, 4, or 8)
)
(
    input  wire                    clk,

    // 增加为16个写寄存器输出
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg1,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg2,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg3,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg4,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg5,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg6,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg7,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg8,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg9,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg10,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg11,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg12,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg13,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg14,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg15,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg16,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg17,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg18,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg19,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg20,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg21,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg22,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg23,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg24,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg25,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg26,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg27,
    output  reg  [DATA_WIDTH-1:0]    o_riscv_wb_wr_reg28,

    // 增加为16个读寄存器输入
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg1,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg2,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg3,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg4,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg5,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg6,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg7,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg8,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg9,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg10,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg11,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg12,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg13,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg14,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg15,
    input   wire [DATA_WIDTH-1:0]    i_riscv_wb_rd_reg16,

    input  wire [ADDR_WIDTH-1:0]   adr_i,   // ADR_I() address
    input  wire [DATA_WIDTH-1:0]   dat_i,   // DAT_I() data in
    input  wire                    we_i,    // WE_I write enable input
    input  wire [SELECT_WIDTH-1:0] sel_i,   // SEL_I() select input
    input  wire                    stb_i,   // STB_I strobe input
    input  wire                    cyc_i,    // CYC_I cycle input
    output wire [DATA_WIDTH-1:0]   dat_o,   // DAT_O() data out
    output wire                    ack_o   // ACK_O acknowledge output
);

parameter BASE_RD_REG = 16;  // 修改基地址偏移为16，因为前16个地址用于读寄存器

// for interfaces that are more than one word wide, disable address lines
parameter VALID_ADDR_WIDTH = $clog2(NUM_REG) - $clog2(SELECT_WIDTH);
// width of data port in words (1, 2, 4, or 8)
parameter WORD_WIDTH = SELECT_WIDTH;
// size of words (8, 16, 32, or 64 bits)
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

reg [DATA_WIDTH-1:0] dat_o_reg = {DATA_WIDTH{1'b0}};
reg ack_o_reg = 1'b0;

(*mark_debug = "true"*)wire [ADDR_WIDTH-1:0] adr_i_offset;
(*mark_debug = "true"*)wire [$clog2(NUM_REG)-1:0] adr_i_valid;
assign adr_i_offset = adr_i - APB_REG_ADDR_BASE;
assign adr_i_valid = adr_i_offset >> $clog2(SELECT_WIDTH);

assign dat_o = dat_o_reg;
assign ack_o = ack_o_reg;

integer i;

always @(posedge clk) begin
    ack_o_reg <= 1'b0;
    
    for (i = 0; i < WORD_WIDTH; i = i + 1) begin
        if (cyc_i & stb_i & ~ack_o) begin
            if (we_i & sel_i[i]) begin
                // 写寄存器逻辑 - 扩展到16个写寄存器
                case(adr_i_valid)
                    0+BASE_RD_REG : o_riscv_wb_wr_reg1[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    1+BASE_RD_REG : o_riscv_wb_wr_reg2[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    2+BASE_RD_REG : o_riscv_wb_wr_reg3[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    3+BASE_RD_REG : o_riscv_wb_wr_reg4[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    4+BASE_RD_REG : o_riscv_wb_wr_reg5[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    5+BASE_RD_REG : o_riscv_wb_wr_reg6[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    6+BASE_RD_REG : o_riscv_wb_wr_reg7[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    7+BASE_RD_REG : o_riscv_wb_wr_reg8[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    8+BASE_RD_REG : o_riscv_wb_wr_reg9[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    9+BASE_RD_REG : o_riscv_wb_wr_reg10[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    10+BASE_RD_REG: o_riscv_wb_wr_reg11[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    11+BASE_RD_REG: o_riscv_wb_wr_reg12[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    12+BASE_RD_REG: o_riscv_wb_wr_reg13[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    13+BASE_RD_REG: o_riscv_wb_wr_reg14[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    14+BASE_RD_REG: o_riscv_wb_wr_reg15[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    15+BASE_RD_REG: o_riscv_wb_wr_reg16[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    16+BASE_RD_REG: o_riscv_wb_wr_reg17[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    17+BASE_RD_REG: o_riscv_wb_wr_reg18[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    18+BASE_RD_REG: o_riscv_wb_wr_reg19[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    19+BASE_RD_REG: o_riscv_wb_wr_reg20[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    20+BASE_RD_REG: o_riscv_wb_wr_reg21[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    21+BASE_RD_REG: o_riscv_wb_wr_reg22[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    22+BASE_RD_REG: o_riscv_wb_wr_reg23[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    23+BASE_RD_REG: o_riscv_wb_wr_reg24[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    24+BASE_RD_REG: o_riscv_wb_wr_reg25[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    25+BASE_RD_REG: o_riscv_wb_wr_reg26[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    26+BASE_RD_REG: o_riscv_wb_wr_reg27[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    27+BASE_RD_REG: o_riscv_wb_wr_reg28[WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
                    default:;
                endcase
            end
            
            // 读寄存器逻辑 - 扩展到16个读寄存器
            case(adr_i_valid)
                0: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg1[WORD_SIZE*i +: WORD_SIZE];
                1: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg2[WORD_SIZE*i +: WORD_SIZE];
                2: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg3[WORD_SIZE*i +: WORD_SIZE];
                3: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg4[WORD_SIZE*i +: WORD_SIZE];
                4: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg5[WORD_SIZE*i +: WORD_SIZE];
                5: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg6[WORD_SIZE*i +: WORD_SIZE];
                6: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg7[WORD_SIZE*i +: WORD_SIZE];
                7: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg8[WORD_SIZE*i +: WORD_SIZE];
                8: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg9[WORD_SIZE*i +: WORD_SIZE];
                9: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg10[WORD_SIZE*i +: WORD_SIZE];
                10: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg11[WORD_SIZE*i +: WORD_SIZE];
                11: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg12[WORD_SIZE*i +: WORD_SIZE];
                12: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg13[WORD_SIZE*i +: WORD_SIZE];
                13: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg14[WORD_SIZE*i +: WORD_SIZE];
                14: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg15[WORD_SIZE*i +: WORD_SIZE];
                15: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= i_riscv_wb_rd_reg16[WORD_SIZE*i +: WORD_SIZE];
                default: dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= {WORD_SIZE{1'b0}};
            endcase
            
            ack_o_reg <= 1'b1;
        end
    end
end

endmodule