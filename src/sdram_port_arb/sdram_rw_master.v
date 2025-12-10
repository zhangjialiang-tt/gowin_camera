module sdram_rw_master #(
    parameter SDRAM_ADDRS_WIDE  = 21    ,
    parameter SDRAM_DATA_WIDE   = 32      
) (
    input                                   i_clk               ,

    input                                   i_sdram_init_done   ,
    input                                   i_wr_en             ,
    input          [7:0]                    i_wr_lengths        ,
    input          [SDRAM_DATA_WIDE-1:0]    i_wr_data           ,
    output  reg                             o_wr_data_req       ,                             
    input          [SDRAM_ADDRS_WIDE-1:0]   i_wr_addrs          ,
    input          [3:0]                    i_wr_dqm            ,

    input                                   i_rd_en             ,
    input          [7:0]                    i_rd_lengths        ,
    input          [SDRAM_ADDRS_WIDE-1:0]   i_rd_addrs          ,
    input          [3:0]                    i_rd_dqm            ,

    output                                  o_rw_over           ,
    output  reg                             o_rd_wr_done        ,              
    output  reg                             o_rw_nack           ,
    output  reg                             o_sdram_wr_en_n     ,
    output  reg                             o_sdram_rd_en_n     ,    
    output         [SDRAM_DATA_WIDE-1:0]    o_sdram_wr_data     ,
    output  reg    [SDRAM_ADDRS_WIDE-1:0]   o_sdram_addrs       ,
    output  reg    [7:0]                    o_sdram_lengths     ,
    output  reg    [3:0]                    o_sdram_dqm         ,
    input                                   i_sdram_busy_n      ,
    input                                   i_sdram_rw_ack          
);
    

localparam IDLE         = 7'b000_0000;
localparam WR_START     = 7'b000_0001;
localparam WIAT_WR_ACK  = 7'b000_0010;
localparam WR_WIAT      = 7'b000_0100;
localparam RD_START     = 7'b000_1000;
localparam WIAT_RD_ACK  = 7'b001_0000;
localparam RD_WAIT      = 7'b010_0000;
localparam RD_WR_END    = 7'b100_0000;
localparam ACK_WAIT_NUM = 2'd3       ;


reg     [6:0]                               state_c             ;
reg     [1:0]                               wr_en_dly           ;
reg                                         wr_sync             ;
reg     [1:0]                               rd_en_dly           ;
reg                                         rd_sync             ;
reg     [7:0]                               rd_wr_cnt           ;
reg     [1:0]                               ack_wait_cnt        ;

always @(posedge i_clk ) begin
    wr_en_dly <= {wr_en_dly[0],i_wr_en};
end

always @(posedge i_clk ) begin
    rd_en_dly <= {rd_en_dly[0],i_rd_en};
end

always @(posedge i_clk ) begin
    if((i_sdram_init_done == 1'b0) || ({i_sdram_busy_n,wr_sync,state_c} == {2'b11,IDLE}))begin
        wr_sync <= 1'b0;
    end
    else if(wr_en_dly == 2'b01)begin
        wr_sync <= 1'b1;
    end
    else begin
        wr_sync <= wr_sync;
    end
end

always @(posedge i_clk ) begin
    if((i_sdram_init_done == 1'b0) || ({i_sdram_busy_n,rd_sync,state_c} == {2'b11,IDLE}))begin
        rd_sync <= 1'b0;
    end
    else if(rd_en_dly == 2'b01)begin
        rd_sync <= 1'b1;
    end
    else begin
        rd_sync <= rd_sync;
    end
end

always @(posedge i_clk ) begin
    if(i_sdram_init_done == 1'b0)begin
        state_c <= IDLE;
    end
    else begin
        case (state_c)
            IDLE: if({rd_sync,i_sdram_busy_n} == 2'b11)begin
                state_c <= RD_START;
            end
            else if({wr_sync,i_sdram_busy_n} == 2'b11)begin
                state_c <= WR_START;
            end
            else begin
                state_c <= IDLE;
            end
    WR_START    :state_c <= WIAT_WR_ACK;
    WIAT_WR_ACK :if(ack_wait_cnt == ACK_WAIT_NUM)begin
                    state_c <= WR_WIAT;
                end
                else begin
                    state_c <= state_c;
                end
    WR_WIAT     : if(o_sdram_lengths == rd_wr_cnt)begin
                    state_c <= RD_WR_END;
                  end
                  else begin
                    state_c <= state_c;
                  end
    RD_START    :state_c <= WIAT_RD_ACK;
    WIAT_RD_ACK :if(ack_wait_cnt == ACK_WAIT_NUM)begin
                  state_c <= RD_WAIT;
                end
                else begin
                  state_c <= state_c;
                end
    RD_WAIT     : if(o_sdram_lengths == rd_wr_cnt)begin
                    state_c <= RD_WR_END;
                  end
                  else begin
                    state_c <= state_c;
                  end
    RD_WR_END   : if(i_sdram_busy_n == 1'b1)begin
                    state_c <= IDLE;
                 end
                 else begin
                    state_c <= state_c;
                 end
            default: state_c <= IDLE;
        endcase
    end
end

always @(posedge i_clk ) begin
    if((state_c == IDLE) && (rd_sync == 1'b1))begin
        o_sdram_addrs <= i_rd_addrs;
    end
    else if((state_c == IDLE) && (wr_sync == 1'b1))begin
        o_sdram_addrs <= i_wr_addrs;
    end
    else begin
        o_sdram_addrs <= o_sdram_addrs;
    end
end

always @(posedge i_clk ) begin
    if((state_c == IDLE) && (rd_sync == 1'b1))begin
        o_sdram_lengths <= i_rd_lengths;
    end
    else if((state_c == IDLE) && (wr_sync == 1'b1))begin
        o_sdram_lengths <= i_wr_lengths;
    end
    else begin
        o_sdram_lengths <= o_sdram_lengths;
    end
end

always @(posedge i_clk ) begin
    if((state_c == IDLE) && (rd_sync == 1'b1))begin
        o_sdram_dqm <= i_rd_dqm;
    end
    else if((state_c == IDLE) && (wr_sync == 1'b1))begin
        o_sdram_dqm <= i_wr_dqm;
    end
    else begin
        o_sdram_dqm <= o_sdram_dqm;
    end
end


always @(posedge i_clk ) begin
    if((state_c == WR_START))begin
        o_sdram_wr_en_n <=1'b0; 
    end
    else begin
        o_sdram_wr_en_n <= 1'b1;
    end
end

always @(posedge i_clk ) begin
    if((state_c == WR_START) || (state_c == RD_START))begin
        rd_wr_cnt <= 8'd0;
    end
    else if(o_sdram_lengths == rd_wr_cnt)begin
        rd_wr_cnt <= rd_wr_cnt;
    end
    else begin
        rd_wr_cnt <= rd_wr_cnt +1'b1;
    end
end

always @(posedge i_clk ) begin
    if(state_c == IDLE)begin
        o_wr_data_req <= 1'b0;
    end
    else if(state_c == WR_START)begin
        o_wr_data_req <= 1'b1;
    end
    else if(o_sdram_lengths == rd_wr_cnt)begin
        o_wr_data_req <= 1'b0;
    end
    else begin
        o_wr_data_req <= o_wr_data_req;
    end
end

assign  o_sdram_wr_data = i_wr_data;

always @(posedge i_clk ) begin
    if((state_c == WIAT_WR_ACK) || (state_c == WIAT_RD_ACK))begin
       ack_wait_cnt<= ack_wait_cnt +2'd1;
    end
    else begin
        ack_wait_cnt<= 2'd0;
    end
end

always @(posedge i_clk ) begin
    if(state_c == RD_START)begin
      o_sdram_rd_en_n <= 1'b0;
    end
    else begin
      o_sdram_rd_en_n <= 1'b1;
    end
end

always @(posedge i_clk ) begin
    if(state_c == IDLE)begin
       o_rw_nack <= 1'b0;      
    end
    else if((ack_wait_cnt == ACK_WAIT_NUM) && (i_sdram_rw_ack == 1'b0))begin
       o_rw_nack <= 1'b1;
    end
    else begin
        o_rw_nack <= o_rw_nack;
    end
end

always @(posedge i_clk ) begin
    if((i_sdram_busy_n == 1'b1) && (state_c == RD_WR_END))begin
      o_rd_wr_done <= 1'b1;
    end
    else begin
      o_rd_wr_done <= 1'b0;
    end
end

assign o_rw_over = state_c ==IDLE;

endmodule