module image_data_get #(
    parameter   SDRAM_ADDRS_DW      = 21    ,
    parameter   IMAGE_WIDE_LENGTH   = 256   ,
    parameter   IMAGE_HIGH_LENGTH   = 192    
) (
    input                                       i_rst_n                 ,
    input                                       i_clk                   ,
    input                                       i_image_start           ,
    input           [1:0]                       i_mem_cnt               ,
    input           [SDRAM_ADDRS_DW-1:0]        i_mem_addrs0            , 
    input           [SDRAM_ADDRS_DW-1:0]        i_mem_addrs1            ,
    input           [SDRAM_ADDRS_DW-1:0]        i_mem_addrs2            ,

    output  reg                                 o_mem_start             ,   
    output  reg     [SDRAM_ADDRS_DW-1:0]        o_mem_addrs             ,
    output          [31:0]                      o_data_length           
);

reg                 [1:0]       mem_cnt                 ;

reg                 [1:0]       start_dly               ;

always @(posedge i_clk ) begin
    start_dly <= {start_dly[0],i_image_start};
end

always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        mem_cnt <= 2'd0;
    end
    else if(start_dly == 2'b01)begin
        mem_cnt <= i_mem_cnt;
    end
    else begin
        mem_cnt <= mem_cnt;
    end
end

always @(posedge i_clk ) begin
    case (mem_cnt)
       2'b00 :   o_mem_addrs <= i_mem_addrs2;
       2'b01 :   o_mem_addrs <= i_mem_addrs0;
       2'b10 :   o_mem_addrs <= i_mem_addrs1;
        default: o_mem_addrs <= i_mem_addrs0;
    endcase
end

always @(posedge i_clk ) begin
    if(start_dly == 2'b10)begin
        o_mem_start <= 1'b1;
    end
    else begin
        o_mem_start <= 1'b0;
    end
end

assign o_data_length = IMAGE_WIDE_LENGTH * IMAGE_HIGH_LENGTH;
    
endmodule