module sdram_wr_port #(
    parameter       DATA_DW             = 16        , 
    parameter       SDRAM_ADDRS_WIDE    = 21        ,
    parameter       SDRAM_DATA_WIDE     = 32            
) (
    input                                   i_rst_n                     ,
    //用户端口
    input                                   i_port_wr_clk               ,
    input                                   i_port_wr_start             ,
    input       [DATA_DW-1:0]               i_port_wr_data              ,
    input                                   i_port_wr_data_vld          ,
    input       [SDRAM_ADDRS_WIDE-1:0]      i_port_wr_addrs             ,
    input       [SDRAM_ADDRS_WIDE-1:0]      i_port_wr_length            ,

    input                                   i_sdram_clk                 ,
    input                                   i_sdram_rd_done             ,
    output      [SDRAM_DATA_WIDE-1:0]       o_sdram_data                ,
    input                                   i_sdram_data_req            , 
    output reg  [SDRAM_ADDRS_WIDE-1:0]      o_sdram_addrs               ,
    output reg  [7:0]                       o_sdram_wr_lengths          ,
    output reg                              o_wr_en                     ,
    output reg                              o_force_insert_signal                
);
function integer depth2width;
input [31:0] depth;
begin : fnDepth2Width
    if (depth > 1) begin
        for (depth2width=0; depth>0; depth2width = depth2width + 1)
            depth = depth>>1;
        end
    else
    depth2width = 0;
end
endfunction 

localparam  IDLE         = 2'b00;  
localparam  WR_DATA_WAIT = 2'b01; 
localparam  WR_WAIT      = 2'b10; 

reg                 [1:0]                   wr_start_dly                ;

reg                 [1:0]                   state_c                     ;
reg                                         fifo_rst                    ;
reg                 [DATA_DW-1:0]           fifo_wr_data                ;
reg                                         fifo_wr_en                  ;
wire                                        fifo_rd_en                  ;
wire                                        force_insert_signal         ;

reg                 [SDRAM_ADDRS_WIDE-1:0]  wr_length_buff              ;
reg                 [SDRAM_ADDRS_WIDE-1:0]  rd_length_buff              ;
wire                [9:0]                   fifo_rnum                   ;

always @(posedge i_sdram_clk ) begin
    wr_start_dly <= {wr_start_dly[0],i_port_wr_start};
end

always @(posedge i_sdram_clk ) begin
    if(wr_start_dly == 2'b01)begin
        fifo_rst <= 1'b1;
    end
    else begin
        fifo_rst <= 1'b0;
    end
end


always @(posedge i_sdram_clk or negedge i_rst_n) begin
    if((i_rst_n == 1'b0) )begin
        state_c <= IDLE;
    end 
    else if(wr_start_dly == 2'b01)begin
        state_c <= WR_DATA_WAIT;
    end
    else begin
        case (state_c)
           WR_DATA_WAIT : if((fifo_rnum >= 10'd128)  && (wr_start_dly[0] == 1'b0))begin
                            state_c <= WR_WAIT ;
                        end
                        else begin
                            state_c <= state_c ;
                        end
            WR_WAIT    : if((i_sdram_rd_done == 1'b1) && (rd_length_buff == {SDRAM_ADDRS_WIDE{1'b0}}))begin
                            state_c <= IDLE;
                        end
                        else if(i_sdram_rd_done == 1'b1)begin
                            state_c <= WR_DATA_WAIT;
                        end
                        else begin
                            state_c <= state_c ;
                        end
            default: state_c <= IDLE;
        endcase
    end
end



always @(posedge i_sdram_clk ) begin
    if((state_c == IDLE) || (i_sdram_rd_done == 1'b1) || (wr_start_dly == 2'b01))begin
        o_wr_en <= 1'b0;
    end
    else if((fifo_rnum >= 10'd128)  && (wr_start_dly[0] == 1'b0) && (state_c == WR_DATA_WAIT))begin
        o_wr_en <= 1'b1;
    end
    else begin
        o_wr_en <= o_wr_en;
    end
end

always @(posedge i_sdram_clk ) begin
    if(wr_start_dly == 2'b01)begin
        rd_length_buff <= i_port_wr_length;
    end
    else if((fifo_rd_en == 1'b1) && (rd_length_buff <= {{(SDRAM_ADDRS_WIDE-1){1'b0}},1'b1}))begin
        rd_length_buff <= {SDRAM_ADDRS_WIDE{1'b0}};
    end 
    else if(fifo_rd_en == 1'b1)begin
        rd_length_buff <= rd_length_buff - 2'd2;
    end
    else begin
        rd_length_buff <= rd_length_buff;
    end
end

always @(posedge i_sdram_clk ) begin
    if((state_c == IDLE) || (i_sdram_rd_done == 1'b1) || (wr_start_dly == 2'b01))begin
        o_force_insert_signal <= 1'b0;
    end
    else if({force_insert_signal,o_wr_en,i_sdram_rd_done} == 3'b110)begin
        o_force_insert_signal <= 1'b1;
    end
    else begin
        o_force_insert_signal <= o_force_insert_signal;
    end
end

always @(posedge i_sdram_clk ) begin
    if((state_c == WR_DATA_WAIT ) && (|rd_length_buff[SDRAM_ADDRS_WIDE-1:8]) == 1'b1)begin
       o_sdram_wr_lengths <= 8'd127;
    end 
    else if((state_c == WR_DATA_WAIT) && (rd_length_buff[0] == 1'b1))begin
        o_sdram_wr_lengths <= rd_length_buff[7:1] ;
    end
    else if(state_c == WR_DATA_WAIT)begin
        o_sdram_wr_lengths <= rd_length_buff[7:1] - 1'b1;
    end
    else begin
        o_sdram_wr_lengths <= o_sdram_wr_lengths;
    end
end

always @(posedge i_sdram_clk ) begin
    if(wr_start_dly == 2'b01)begin
        o_sdram_addrs <= i_port_wr_addrs;
    end
    else if((i_sdram_rd_done == 1'b1) && (state_c == WR_WAIT))begin
        o_sdram_addrs <= o_sdram_addrs + 8'd128;
    end
    else begin
        o_sdram_addrs <= o_sdram_addrs;
    end
end

always @(posedge i_port_wr_clk ) begin
    if(i_port_wr_start == 1'b1)begin
        wr_length_buff <= i_port_wr_length;
    end
    else if((fifo_wr_en == 1'b1) && (wr_length_buff != {(SDRAM_ADDRS_WIDE+1){1'b0}}))begin
        wr_length_buff <= wr_length_buff - 1'b1;
    end
    else begin
        wr_length_buff <= wr_length_buff;
    end
end

always @(posedge i_port_wr_clk ) begin
    if((i_port_wr_data_vld == 1'b1) && (state_c != IDLE))begin
        fifo_wr_en <= 1'b1;
    end
    else if(({i_port_wr_start,wr_length_buff} == {(SDRAM_ADDRS_WIDE+1){1'b0}}) && (state_c != IDLE) )begin
        fifo_wr_en <= 1'b1;
    end
    else begin
        fifo_wr_en <= 1'b0;
    end
end

always @(posedge i_port_wr_clk ) begin
    if(({i_port_wr_start,wr_length_buff} == {(SDRAM_ADDRS_WIDE+1){1'b0}}) && (state_c != IDLE) )begin
        fifo_wr_data <= {DATA_DW{1'b1}};
    end
    else if((i_port_wr_data_vld == 1'b1) && (state_c != IDLE))begin
        fifo_wr_data <= i_port_wr_data;
    end 
    else begin
        fifo_wr_data <= fifo_wr_data;
    end
end

assign fifo_rd_en = i_sdram_data_req    ;

sdram_wr_fifo sdram_wr_fifo_inst(
	.Data           (fifo_wr_data               ), //input [15:0] Data
	.Reset          (fifo_rst                   ), //input Reset
	.WrClk          (i_port_wr_clk              ), //input WrClk
	.RdClk          (i_sdram_clk                ), //input RdClk
	.WrEn           (fifo_wr_en                 ), //input WrEn
	.RdEn           (fifo_rd_en                 ), //input RdEn
	.Wnum           (                           ), //output [10:0] Wnum
	.Rnum           (fifo_rnum                  ), //output [9:0] Rnum
	.Almost_Full    (force_insert_signal        ), //output Almost_Full 快满了dsram优先写
	.Q              (o_sdram_data               ), //output [31:0] Q
	.Empty          (                           ), //output Empty
	.Full           (                           ) //output Full
);
    
endmodule