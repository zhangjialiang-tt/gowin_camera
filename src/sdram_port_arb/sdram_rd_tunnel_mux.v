module sdram_rd_tunnel_mux
(
    input                   i_clk               ,
    input                   i_rst_n             ,

    input                   i_tunnel_id         ,
    output                  o_flash_start       ,
    input                   i_flash_idle        ,

    input                   i_rd_0_start        ,
    input        [20:0]     i_rd_0_addrs        ,
    input        [31:0]     i_rd_0_lengths      ,
    input                   i_rd_0_req          ,
    output                  o_rd_0_data_vld     ,
    output       [15:0]     o_rd_0_data         ,
    output                  o_rd_0_data_ready   ,

    input                   i_rd_1_start        ,
    input        [20:0]     i_rd_1_addrs        ,
    input        [31:0]     i_rd_1_lengths      ,
    input                   i_rd_1_req          ,
    output                  o_rd_1_data_vld     ,
    output       [15:0]     o_rd_1_data         ,
    output                  o_rd_1_data_ready   ,

    output                  o_mem_rd3_start     ,
    output       [20:0]     o_mem_rd3_addrs     ,
    output       [31:0]     o_mem_rd3_lens      ,
    output                  o_mem_rd3_data_req  ,
    input                   i_mem_rd3_data_vld  ,
    input        [15:0]     i_mem_rd3_data      ,
    input                   i_mem_rd3_data_ready   
);

reg rd1_start;
reg [7:0] reg_cnt;
reg mem_start;
reg flash_start;
assign o_flash_start = flash_start;
//
reg rd_1_start_dly;
reg flash_idle_dly;
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        rd_1_start_dly <= 1'd0;
        flash_idle_dly <= 1'd0;
    end
    else begin
        rd_1_start_dly <= i_rd_1_start;
        flash_idle_dly <= i_flash_idle;
    end
end
//start 1
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        rd1_start <= 1'd0;
    end
    else begin
        if((~rd_1_start_dly) & i_rd_1_start) begin
            rd1_start <= 1'd1;
        // end else if((!flash_idle_dly) & i_flash_idle) begin
        end else if((!i_rd_1_start) & rd_1_start_dly) begin
            rd1_start <= 1'd0;
        end else begin
            rd1_start<= rd1_start;
        end
    end
end

always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        reg_cnt <= 7'd0;
    end else if((!i_rd_1_start) & rd_1_start_dly)begin
        reg_cnt <= 7'd0;
    end else if(rd1_start & (reg_cnt < 7'd80))begin
        reg_cnt <= reg_cnt + 1'd1;
    end else begin
        reg_cnt <= reg_cnt;
    end
end

always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        mem_start <= 1'b0;
        flash_start <= 1'b0;
    end else if((!i_rd_1_start) & rd_1_start_dly) begin
        mem_start   <= 1'b0;
        flash_start <= 1'b0;
    end else if(reg_cnt == 'd3) begin
        mem_start   <= 1'b1;
    end else if(reg_cnt == 'd8)begin
        mem_start   <= 1'b0;
    end else if(reg_cnt > 'd68) begin
        flash_start <= 1'b1;
    end
end

reg tmp_start;
always@(posedge i_clk or negedge i_rst_n)
begin
    if(!i_rst_n) begin
        tmp_start <= 1'b0;
    end else if(1 == i_tunnel_id) begin
        tmp_start <= mem_start;
    end else begin
        tmp_start <= i_rd_0_start;
    end
end

assign o_mem_rd3_start = tmp_start;

    // assign o_mem_rd3_start      = (1'b1 == i_tunnel_id)? mem_start             : i_rd_0_start;
    assign o_mem_rd3_addrs      = (1'b1 == i_tunnel_id)? i_rd_1_addrs          : i_rd_0_addrs;
    assign o_mem_rd3_lens       = (1'b1 == i_tunnel_id)? i_rd_1_lengths        : i_rd_0_lengths;
    assign o_mem_rd3_data_req   = (1'b1 == i_tunnel_id)? i_rd_1_req            : i_rd_0_req;

    assign  o_rd_0_data_ready   = (1'b0 == i_tunnel_id)? i_mem_rd3_data_ready            : 0;
    assign  o_rd_1_data_ready   = (1'b1 == i_tunnel_id)? i_mem_rd3_data_ready            : 0;

    assign o_rd_0_data_vld      = (1'b0 == i_tunnel_id)? i_mem_rd3_data_vld    : 'd0;
    assign o_rd_0_data          = (1'b0 == i_tunnel_id)? i_mem_rd3_data        : 'd0;
    assign o_rd_1_data_vld      = (1'b1 == i_tunnel_id)? i_mem_rd3_data_vld    : 'd0;
    assign o_rd_1_data          = (1'b1 == i_tunnel_id)? i_mem_rd3_data        : 'd0;
endmodule