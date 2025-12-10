module sdram_wr_tunnel_mux
(
    //glb
    input                   i_clk               ,
    input                   i_rst_n             ,

    // 通道选择
    input                   i_tunnel_id         ,
    //USB升级传入数据
    input                   i_usb_clk           ,
    input                   i_usb_vld           ,
    input       [31:0]      i_usb_lens          ,
    input       [7:0]       i_usb_data          ,
    output                  o_mem_wr_end        ,
    // tunnel0
    input                   i_wr_master_0_wen   ,
    input       [15:0]      i_wr_master_0_data  ,
    input                   i_wr_master_0_start ,
    input       [20:0]      i_wr_master_0_addrs ,
    input       [31:0]      i_wr_master_0_lens  ,
    // tunnel1
    input                   i_wr_master_1_wen   ,
    input       [15:0]      i_wr_master_1_data  ,
    input                   i_wr_master_1_start ,
    input       [20:0]      i_wr_master_1_addrs ,
    input       [31:0]      i_wr_master_1_lens  ,

    //sdram
    output                  o_wr_master_2_clk   ,
    output                  o_wr_master_2_wen   ,
    output      [15:0]      o_wr_master_2_data  ,
    output                  o_wr_master_2_start ,
    output      [20:0]      o_wr_master_2_addrs ,
    output      [31:0]      o_wr_master_2_lens
);

//fifo
wire fifo_rd_en;
reg [31:0] usb_lens;
reg mem_vld; //FIFO出来的vld
wire [15:0] mem_data  ;
wire        fifo_empty; //fifo空
wire        fifo_full ; //fifo满
//machine
reg [6:0] reg_cnt; // mem操作计数
reg [21:0] data_i_cnt; // 有效数据数
reg [21:0] data_o_cnt; // 有效数据数
reg [21:0] data_o_cnt_dly1, data_o_cnt_dly2;
reg usb_start, usb_start_dly;
reg usb_start_dly1,usb_start_dly2;
reg mem_start; //通知mem
reg fifo_q_en; //可以开始往mem里写，读fifo了

assign fifo_rd_en = fifo_q_en & (!fifo_empty) ;
assign o_mem_wr_end = ~usb_start_dly2;

//sdram
    assign o_wr_master_2_clk = i_clk;
    assign o_wr_master_2_wen    = (i_tunnel_id)? i_wr_master_1_wen  : mem_vld;
    assign o_wr_master_2_data   = (i_tunnel_id)? i_wr_master_1_data : mem_data;
    assign o_wr_master_2_start  = (i_tunnel_id)? i_wr_master_1_start: mem_start;
    assign o_wr_master_2_addrs  = (i_tunnel_id)? i_wr_master_1_addrs: i_wr_master_0_addrs;
    assign o_wr_master_2_lens   = (i_tunnel_id)? i_wr_master_1_lens : i_wr_master_0_lens;
    
wire       [8:0]             Wnum_o;
wire       [7:0]             Rnum_o;
//fifo usb 8bit=>16bit
fifo_top fifo_top_inst(
    .WrClk  (i_usb_clk  ), //input WrClk
    .RdClk  (i_clk      ), //input RdClk
    .WrReset((~i_rst_n)    ), //input WrReset
    .RdReset((~i_rst_n)    ), //input RdReset
    .WrEn   (i_usb_vld  ), //input WrEn
    .Data   (i_usb_data ), //input [7:0] Data
    .RdEn   (fifo_rd_en ), //input RdEn
    // .Wnum   (Wnum_o), //output [8:0] Wnum
    // .Rnum   (Rnum_o), //output [7:0] Rnum
    .Q      (mem_data   ), //output [15:0] Q
    .Empty  (fifo_empty ), //output Empty
    .Full   (fifo_full  )  //output Full
);

//
reg usb_vld_dly;
always@(posedge i_usb_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_vld_dly <= 1'd0;
    end
    else begin
        usb_vld_dly <= i_usb_vld;
    end
end
// 升级一次触发
always@(posedge i_usb_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_start_dly <= 1'd0;
    end
    else begin
        usb_start_dly <= usb_start;
    end
end

// MEM写入：流程启动
always@(posedge i_usb_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_lens <= 1'b0;
    end
    else if(usb_start & (~usb_start_dly)) begin
        usb_lens <= i_usb_lens;
    end else begin
        usb_lens <= usb_lens;
    end
end

//clk transform
reg                 usb_data_trans_end;
reg                 usb_data_trans_end_ff0;
reg                 usb_data_trans_end_ff1;
always@(posedge i_usb_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        data_o_cnt_dly2 <= 1'b0;
        data_o_cnt_dly1 <= 1'b0;
        usb_data_trans_end_ff0 <= 0;
    end else begin
        data_o_cnt_dly1 <= data_o_cnt;
        data_o_cnt_dly2 <= data_o_cnt_dly1;

        usb_data_trans_end_ff0 <= usb_data_trans_end;
        usb_data_trans_end_ff1 <= usb_data_trans_end_ff0;
    end
end

always@(posedge i_usb_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_start <= 1'd0;
    end else begin
        if((~usb_vld_dly) & i_usb_vld) begin
            usb_start <= 1'd1;
        // end else if(data_o_cnt_dly2 >= i_usb_lens) begin //end of upgrade
        end else if(usb_data_trans_end_ff1 ^ usb_data_trans_end_ff0) begin //end of upgrade
            usb_start <= 1'b0;
        end else begin
            usb_start <= usb_start;
        end
    end
end

// MEM写入：流程计数
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_start_dly1 <= 1'b0;
        usb_start_dly2 <= 1'b0;
    end else begin
        usb_start_dly1 <= usb_start;
        usb_start_dly2 <= usb_start_dly1;
    end
end

always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        reg_cnt <= 1'd0;
    end else if(usb_start_dly1 & (~usb_start_dly2))begin
        reg_cnt <= 1'd1;
    end else if(usb_start_dly1 & (reg_cnt < 'd64))begin
        reg_cnt <= reg_cnt + 1'd1;
    end else if(1'b0 == usb_start_dly1) begin
        reg_cnt <= 1'd0;
    end else begin
        reg_cnt <= reg_cnt;
    end
end

// MEM写入：流程
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        mem_start <= 1'b0;
        fifo_q_en <= 1'b0;
    end else if(reg_cnt < 'd3) begin
        mem_start <= 1'b0;
        fifo_q_en <= 1'b0;
    end else if(reg_cnt == 'd3) begin
        mem_start <= 1'b1;
    end else if(reg_cnt == 'd8)begin
        mem_start <= 1'b0;
    end else if(reg_cnt > 'd58) begin
        fifo_q_en <= 1'b1;
    end
end

//读FIFO使能
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        // fifo_rd_en <= 1'b0;
        mem_vld <= 1'b0;
    end
    else begin
        // fifo_rd_en <= fifo_q_en & (!fifo_empty);
        mem_vld <= fifo_rd_en;
    end
end

// //开始升级 vld计数
// always@(posedge i_usb_clk or negedge i_rst_n)
// begin
//     if(!i_rst_n) begin
//         data_i_cnt <= 1'd0;
//     end
//     else if(i_usb_vld) begin
//         if(~usb_vld_dly) begin
//             data_i_cnt <= 1'b1;
//         end else begin
//             data_i_cnt <= data_i_cnt + 1'd1;
//         end
//     end else begin
//         data_i_cnt <= data_i_cnt;
//     end
// end

// 出FIFO计数
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        data_o_cnt <= 1'd0;
    end else if(fifo_rd_en) begin
        data_o_cnt <= data_o_cnt + 1'b1;
    end else if(data_o_cnt >= ((usb_lens) - 1)) begin
        data_o_cnt <= 1'b0;
    end else begin
        data_o_cnt <= data_o_cnt;
    end
end

always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        usb_data_trans_end <= 1'd0;
    end else if(data_o_cnt == ((usb_lens) - 1)) begin
        usb_data_trans_end <= ~usb_data_trans_end;
    end else begin
        usb_data_trans_end <= usb_data_trans_end;
    end
end

endmodule