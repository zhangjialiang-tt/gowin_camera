module image_test_data #(
    parameter DW                = 16  
) (
    input                   i_clk       ,
    input                   i_rst_n     ,
    input                   i_en        ,
    input       [DW-1:0]    i_data      ,
    input                   i_hs        ,
    input                   i_vs        ,

    output reg [DW-1:0]     o_data      ,
    output reg              o_hs        ,
    output reg              o_vs            
);  

reg                 [DW-1:0]            data        ;
reg                 [DW-1:0]            fcnt        ;    
reg                 [1:0]               vs_out_dly  ;

always @(posedge i_clk ) begin
    vs_out_dly <= {vs_out_dly[0],o_vs};
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        fcnt <= {DW{1'b0}};
    end
    else if(vs_out_dly == 2'b10)begin
        fcnt <= fcnt +1'b1;
    end
    else begin
        fcnt <= fcnt;
    end
end
always @(negedge i_clk ) begin
    if(i_vs == 1'b0)begin
        data <= 16'd0;
    end
    else if(i_hs == 1'b1)begin
        data <= data + 1'b1;
    end
    else begin
        data <= data;
    end
end

always @(posedge i_clk ) begin
    if(i_en == 1'b1)begin
        o_data <= data;
    end
    else begin
        o_data <= i_data;
    end
end

always @(posedge i_clk ) begin
    o_hs <= i_hs;
    o_vs <= i_vs;
end

endmodule