
module apb_irq_arb #(
    parameter CLK_REQ = 60_000_000
)
(
    input                   i_rst_n         ,
    input                   i_clk           ,
    input                   i_usb_cmd_en    ,
    input                   i_vs            ,
    input        [31:0]     i_irq_ack       ,
    output  reg  [31:0]     o_irq_sel       ,  
    output  reg             o_irq_en        
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


localparam TIME_100MS = CLK_REQ/100_000_000;

reg      [1:0]       usb_cmd_en_dly                         ;
reg      [1:0]       vs_dly                                 ;
reg      [7:0]       irq_sync                               ;
reg      [7:0]       irq_sel                                ;
reg      [31:0]      irq_ack_dly1,irq_ack_dly2              ;   
reg      [depth2width(TIME_100MS)-1:0]        cnt_100ms     ;
reg      [7:0]                                irq_en        ;  




always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        irq_en <= 8'd0;
    end
    else if({i_irq_ack[31:17],i_irq_ack[8:0]} == 2'd0)begin
        irq_en <= i_irq_ack[9+:8];
    end
    else begin
        irq_en <=irq_en;
    end
end

always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        cnt_100ms <= {depth2width(TIME_100MS){1'b0}};
    end
    else if(cnt_100ms == TIME_100MS -1)begin
        cnt_100ms <= {depth2width(TIME_100MS){1'b0}};
    end
    else begin
        cnt_100ms <= cnt_100ms + 1'b1;
    end
end



always @(posedge i_clk ) begin
    irq_sync[7:3] <= 'd0;
end

always @(posedge i_clk ) begin
    vs_dly <= {vs_dly[0],i_vs};
end

always @(posedge i_clk ) begin
    usb_cmd_en_dly <= {usb_cmd_en_dly[0],i_usb_cmd_en};
end

always @(posedge i_clk ) begin
    irq_ack_dly1 <= i_irq_ack   ;
    irq_ack_dly2 <= irq_ack_dly1;
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        irq_sync[0] <= 1'b0;
    end
    else if(({irq_ack_dly1[8],irq_ack_dly2[8]} == 2'b10) && (irq_ack_dly1[7:0] == 8'b0000_0001))begin
        irq_sync[0] <= 1'b0;
    end
    else if((usb_cmd_en_dly == 2'b01) && (irq_en[0] == 1'b1)) begin
        irq_sync[0] <= 1'b1;
    end
    else begin
        irq_sync[0] <= irq_sync[0];
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        irq_sync[1] <= 1'b0;
    end
    else if(({irq_ack_dly1[8],irq_ack_dly2[8]} == 2'b10) && (irq_ack_dly1[7:0] == 8'b0000_0010))begin
        irq_sync[1] <= 1'b0;
    end
    else if((vs_dly == 2'b01) && (irq_en[1] == 1'b1)) begin
        irq_sync[1] <= 1'b1;
    end
    else begin
        irq_sync[1] <= irq_sync[1];
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        irq_sync[2] <= 1'b0;
    end
    else if(({irq_ack_dly1[8],irq_ack_dly2[8]} == 2'b10) && (irq_ack_dly1[7:0] == 8'b0000_0100))begin
        irq_sync[2] <= 1'b0;
    end
    else if((cnt_100ms == TIME_100MS -1)&& (irq_en[2] == 1'b1)) begin
        irq_sync[2] <= 1'b1;
    end
    else begin
        irq_sync[2] <= irq_sync[2];
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        o_irq_sel[7:0] <= 8'h01;
    end
    else if(((o_irq_en == 1'b0) && ((o_irq_sel[7:0] & irq_sync) == 8'b0)) || 
    ({irq_ack_dly1[8],irq_ack_dly2[8],o_irq_en} == 3'b101) )begin
        case (o_irq_sel[7:0])
            8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80: 
            o_irq_sel[7:0] <= {o_irq_sel[6:0],o_irq_sel[7]};
            default: o_irq_sel[7:0] <= 8'h01;
        endcase
    end
    else begin
        o_irq_sel[7:0]  <= o_irq_sel[7:0]; 
    end
end


always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        o_irq_en <= 1'b0;
    end
    else if({irq_ack_dly1[8],irq_ack_dly2[8],o_irq_en} == 3'b101)begin
        o_irq_en <= 1'b0;
    end
    else if(((o_irq_sel[7:0] & irq_sync) != 8'd0) && (o_irq_en == 1'b0) )begin
        o_irq_en <= 1'b1;
    end
    else begin
        o_irq_en <= o_irq_en;
    end
end


endmodule