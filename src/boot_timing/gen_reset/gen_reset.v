`timescale 1ns / 1ps
module gen_reset 
#(
    parameter RST_TIME  = 255               ,           
    parameter DW        = 1                             
)
(
    input                   i_clk           ,
    input                   i_rst_n         ,
    input       [DW-1:0]    i_locked        ,

    output  reg             o_rst_n                   

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

reg     [depth2width(RST_TIME)-1:0]                   cnt         ;      

always @(posedge i_clk ) begin
    if(i_rst_n == 1'b0 || (&i_locked == 1'b0))begin
        cnt <= {depth2width(RST_TIME){1'b0}};
    end
    else if(cnt == RST_TIME)begin
        cnt <= cnt;
    end
    else begin
        cnt <= cnt +1'b1;
    end
end

always @(posedge i_clk ) begin
    if(cnt < RST_TIME)begin
        o_rst_n <= 1'b0;
    end
    else begin
        o_rst_n <= 1'b1;
    end
end

    
endmodule