module data_mem_wr_ctrl #(
    parameter IMAGE_WIDE_LENGTH = 256    ,
    parameter IMAGE_HIGH_LENGTH = 192    ,
    parameter ADDRS_DW          = 21     ,
    parameter DW                = 16    
) (
    input                           i_rst_n             ,
    input                           i_clk               ,

    input                           i_freeze_en         ,
    input   [ADDRS_DW-1:0]          i_addrs0            ,
    input   [ADDRS_DW-1:0]          i_addrs1            ,
    input   [ADDRS_DW-1:0]          i_addrs2            ,
    
    input   [DW-1:0]                i_data              ,
    input                           i_hs                ,
    input                           i_vs                ,

    output  reg [1:0]               o_fcnt              ,

    output  reg                     o_mem_wr_start      ,
    output  reg [ADDRS_DW - 1 : 0]  o_mem_wr_addrs      ,
    output      [ADDRS_DW - 1 : 0]  o_mem_wr_lengths    ,
    output  reg [DW - 1 : 0]        o_mem_wr_data       ,
    output  reg                     o_mem_wr_data_vld    

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
localparam WAIT_NUM = IMAGE_WIDE_LENGTH*4;
reg                                                 freeze_en           ;
reg         [depth2width(WAIT_NUM)-1:0]             fcnt_wait           ;

always @(posedge i_clk ) begin
    if(i_vs == 1'b1)begin
        fcnt_wait <= {depth2width(WAIT_NUM){1'b0}};
    end
    else if(fcnt_wait == WAIT_NUM-1)begin
        fcnt_wait <= fcnt_wait;
    end
    else begin
        fcnt_wait <= fcnt_wait + 1'b1;
    end
end

always @(posedge i_clk ) begin
    if((fcnt_wait > WAIT_NUM - 20) && (fcnt_wait < WAIT_NUM -10))begin
        o_mem_wr_start <= 1'b1;
    end
    else begin
        o_mem_wr_start <= 1'b0;
    end
end

always @(posedge i_clk or negedge i_rst_n ) begin
    if(!i_rst_n)begin
        o_fcnt <= 2'd0;
    end
    else if(freeze_en == 1'b1)begin
        o_fcnt <= o_fcnt;
    end
    else if((fcnt_wait == WAIT_NUM - 30) && (o_fcnt > 2'd1))begin
        o_fcnt <= 2'd0;
    end
    else if(fcnt_wait == WAIT_NUM - 30)begin
        o_fcnt <= o_fcnt + 1'b1;
    end
    else begin
        o_fcnt <= o_fcnt;
    end
end


always @(posedge i_clk ) begin
    case (o_fcnt)
       2'd0 : o_mem_wr_addrs <= i_addrs0    ;
       2'd1 : o_mem_wr_addrs <= i_addrs1    ;
       2'd2 : o_mem_wr_addrs <= i_addrs2    ;
        default: o_mem_wr_addrs <= i_addrs0 ;
    endcase
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        freeze_en <= 1'b0;
    end
    else if(fcnt_wait == WAIT_NUM - 40)begin
        freeze_en <= i_freeze_en;
    end
    else begin
        freeze_en <= freeze_en;
    end
end

always @(posedge i_clk ) begin
    if({i_vs,i_hs} == 2'b11)begin
        o_mem_wr_data <= i_data;
    end
    else begin
        o_mem_wr_data <= {DW{1'b0}};
    end
end

always @(posedge i_clk ) begin
    if({i_vs,i_hs} == 2'b11)begin
        o_mem_wr_data_vld <= 1'b1;
    end
    else begin
        o_mem_wr_data_vld <= 1'b0;
    end
end

assign o_mem_wr_lengths = IMAGE_WIDE_LENGTH * IMAGE_HIGH_LENGTH;
    
endmodule