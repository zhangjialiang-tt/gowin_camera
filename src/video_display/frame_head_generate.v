//延迟1拍

module frame_head_generate #(
  parameter  DW             = 16      ,
  parameter  HEAD_LENGTH    = 32                
)
(
    input                               i_rst_n     ,
    input                               i_clk       ,
    // input       [DW*HEAD_LENGTH-1:0]    i_head      ,
    input                               i_head_vld  ,
    output reg  [DW-1:0]                o_head      ,
    output reg                          o_head_vld      
);
// reg       [DW*HEAD_LENGTH-1:0]          head_reg    ;

always @(posedge i_clk ) begin
    o_head_vld <= i_head_vld;
end

// always @(posedge i_clk ) begin
//     if({i_head_vld,o_head_vld} == 2'b01)begin
//         head_reg <= i_head;
//     end
//     else if((i_head_vld == 1'b1) && (HEAD_LENGTH > 1))begin
//         head_reg <= {head_reg[0+:DW*(HEAD_LENGTH-1)],{DW{1'b0}}};
//     end
//     else begin
//         head_reg <= head_reg;
//     end
// end

always @(posedge i_clk ) begin
    if({o_head_vld,i_head_vld} == 2'b01)begin
        o_head <= 16'hBB66;
    end
    else if(i_head_vld == 1'b1)begin
        o_head <= 16'hffff;
        // o_head <= head_reg[DW*HEAD_LENGTH-1-:DW];
    end
    else begin
        o_head <= 16'd0;
    end
end


    
endmodule