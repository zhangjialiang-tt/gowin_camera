module sdram_rd_port #(
    parameter       DATA_DW             = 16         , 
    parameter       OUTPUT_MODE         = "FWFT"    , //"STANDARD"
    parameter       SDRAM_ADDRS_WIDE    = 21        ,
    parameter       SDRAM_DATA_WIDE     = 32            
) (
    input                                   i_rst_n                     ,
    //用户端口
    input                                   i_port_rd_clk               ,
    input                                   i_port_rd_start             ,   
    output      [DATA_DW-1:0]               o_port_rd_data              ,
    output                                  o_port_rd_data_vld          ,
    input                                   i_port_rd_data_req          ,
    input       [SDRAM_ADDRS_WIDE-1:0]      i_port_rd_addrs             ,
    input       [SDRAM_ADDRS_WIDE-1:0]      i_port_rd_length            ,
    output                                  o_port_rd_data_ready        ,

    input                                   i_sdram_clk                 ,
    input                                   i_sdram_rd_done             ,
    input       [SDRAM_DATA_WIDE-1:0]       i_sdram_data                ,
    input                                   i_sdram_data_vld            , 
    output reg  [SDRAM_ADDRS_WIDE-1:0]      o_sdram_addrs               ,
    output      [7:0]                       o_sdram_rd_lengths          ,
    output reg                              o_rd_en                     ,
    output reg                              o_force_insert_signal                
);

localparam IDLE             = 2'b00;
localparam RD_DATA_WAIT     = 2'b01;
localparam RD_WAIT          = 2'b10;
reg                      [1:0]                          state_c                         ;
reg                      [1:0]                          start_dly                       ;
reg                                                     fifo_rst                        ;
wire                                                    fifo_wr_en                      ;
wire                    [DATA_DW-1:0]                   fifo_rd_data                    ;
wire                                                    fifo_empty                      ;
wire                                                    force_insert_signal             ;
wire                    [9:0]                           fifo_wnum                       ;
reg                     [SDRAM_ADDRS_WIDE-1:0]          fifo_wr_lengths                 ;
always @(posedge i_sdram_clk ) begin
    start_dly <= {start_dly[0],i_port_rd_start};
end
always @(posedge i_sdram_clk ) begin
    if(start_dly == 2'b01)begin
        fifo_rst <= 1'b1;        
    end
    else begin
        fifo_rst <= 1'b0;
    end
end

always @(posedge i_sdram_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        state_c <= IDLE;
    end
    else if(start_dly == 2'b01)begin
        state_c <= RD_DATA_WAIT;
    end
    else begin
        case (state_c)
RD_DATA_WAIT: if(((10'd512 - fifo_wnum) > 10'd128) && (start_dly[0] == 1'b0))begin
                    state_c <= RD_WAIT;
              end
              else begin
                    state_c <= state_c;
              end
RD_WAIT     : if((fifo_wr_lengths == {SDRAM_ADDRS_WIDE{1'b0}}) && (i_sdram_rd_done == 1'b1))begin
                    state_c <= IDLE;
              end
              else if(i_sdram_rd_done == 1'b1)begin
                    state_c <= RD_DATA_WAIT;
              end
              else begin
                    state_c <= state_c;
              end
            default: state_c <= IDLE;
        endcase
    end
end

always @(posedge i_sdram_clk ) begin
    if(start_dly == 2'b01)begin
        fifo_wr_lengths <= i_port_rd_length;
    end
    else if((state_c == RD_WAIT) && (fifo_wr_lengths <= {{(SDRAM_ADDRS_WIDE-1){1'b0}},1'b1}) && (i_sdram_data_vld == 1'b1))begin
        fifo_wr_lengths <= {SDRAM_ADDRS_WIDE{1'b0}};
    end
    else if((state_c == RD_WAIT) && (i_sdram_data_vld == 1'b1))begin
        fifo_wr_lengths <= fifo_wr_lengths - 2'd2;
    end
    else begin
        fifo_wr_lengths <= fifo_wr_lengths;
    end
end

always @(posedge i_sdram_clk ) begin
    if(start_dly == 2'b01)begin
        o_sdram_addrs <= i_port_rd_addrs;
    end
    else if((state_c == RD_WAIT) && (i_sdram_rd_done == 1'b1))begin
         o_sdram_addrs <=  o_sdram_addrs + 8'd128;
    end
    else begin
        o_sdram_addrs <= o_sdram_addrs;
    end
end

always @(posedge i_sdram_clk ) begin
    if((start_dly == 2'b01) || (state_c ==IDLE) || (i_sdram_rd_done == 1'b1))begin
        o_rd_en <= 1'b0;
    end
    else if(((10'd512 - fifo_wnum) > 10'd128) && (start_dly[0] == 1'b0) && (state_c == RD_DATA_WAIT))begin
         o_rd_en <= 1'b1;
    end
    else begin
        o_rd_en <= o_rd_en;
    end
end

always @(posedge i_sdram_clk ) begin
    if((start_dly == 2'b01) || (state_c ==IDLE) || (i_sdram_rd_done == 1'b1))begin
        o_force_insert_signal <= 1'b0;
    end
    else if({force_insert_signal,o_rd_en,i_sdram_rd_done} == 3'b110)begin
         o_force_insert_signal <= 1'b1;
    end
    else begin
        o_force_insert_signal <= o_force_insert_signal;
    end
end


assign o_port_rd_data_ready         = ~fifo_empty;
assign fifo_wr_en                   = (state_c == RD_WAIT) && (i_sdram_data_vld == 1'b1);
assign o_sdram_rd_lengths           = 8'd127;

generate
    if(OUTPUT_MODE == "FWFT")begin
        assign o_port_rd_data     = fifo_rd_data      ;
        assign o_port_rd_data_vld = i_port_rd_data_req;
    end
    else if(OUTPUT_MODE == "STANDARD")begin
        reg       [DATA_DW-1:0]     rd_data_pre     ;
        reg                         rd_data_vld_pre ;
        always @(posedge i_port_rd_clk ) begin
            rd_data_pre     <= fifo_rd_data      ;
            rd_data_vld_pre <= i_port_rd_data_req;
        end

        assign o_port_rd_data     = rd_data_pre      ;
        assign o_port_rd_data_vld = rd_data_vld_pre  ;

    end
    else begin
        assign o_port_rd_data     = fifo_rd_data      ;
        assign o_port_rd_data_vld = i_port_rd_data_req;
    end
endgenerate

sdram_rd_fifo sdram_rd_fifo_inst(
	.Data           ({i_sdram_data[15:0],i_sdram_data[31:16]}       ), //input [31:0] Data
	.Reset          (fifo_rst                                       ), //input Reset
	.WrClk          (i_sdram_clk                                    ), //input WrClk
	.RdClk          (i_port_rd_clk                                  ), //input RdClk
	.WrEn           (fifo_wr_en                                     ), //input WrEn
	.RdEn           (i_port_rd_data_req                             ), //input RdEn
	.Wnum           (fifo_wnum                                      ), //output [9:0] Wnum
	.Rnum           (                                               ), //output [10:0] Rnum
	.Almost_Empty   (force_insert_signal                            ), //output Almost_Empty
	.Q              (fifo_rd_data                                   ), //output [15:0] Q
	.Empty          (fifo_empty                                     ), //output Empty
	.Full           (                                               ) //output Full
);
    
endmodule