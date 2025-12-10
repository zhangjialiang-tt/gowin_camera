module tv2yuv422 #(
    parameter IMAGE_WIDE    = 800                           ,
    parameter IMAGE_HIGH    = 600                           ,
    parameter HNUM          = IMAGE_WIDE * 2 + 300          ,
    parameter VNUM          = IMAGE_HIGH + 100              ,
    parameter HNUM_START    = 0                             ,
    parameter HNUM_END      = (HNUM_START+IMAGE_WIDE)     ,               
    parameter VNUM_START    = 0                             ,
    parameter VNUM_END      = VNUM_START + IMAGE_HIGH                       

)(
    input                   i_clk           ,
    input                   i_rst_n         ,

    input       [7:0]       i_data          ,
    input                   i_hsync         ,
    input                   i_vsync         ,
    
    output reg  [15:0]      o_data          ,
    output reg              o_hsync         ,
    output reg              o_vsync           
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


reg                 [15:0]      data        ;
reg                 [1:0]       data_vld    ;
reg                             vsync_dly   ;

reg                 [depth2width(HNUM)-1:0]             hcnt        ;
reg                 [depth2width(VNUM)-1:0]             vcnt        ;
reg                 [1:0]                               hsync_dly   ;

always @(posedge i_clk ) begin
    hsync_dly <= {hsync_dly[0],i_hsync};
end


always @(posedge i_clk ) begin  //一拍
    data <= {i_data,data[15:8]};
end

always @(posedge i_clk ) begin
    if(i_hsync == 1'b0)begin
        data_vld[0] <= 1'b0;
    end
    else if({i_hsync,i_vsync} == 2'b11)begin
        data_vld[0] <= ~data_vld[0];
    end
    else begin
        data_vld[0] <= data_vld[0];
    end
end

always @(posedge i_clk ) begin
    vsync_dly <= i_vsync;
end

always @(posedge i_clk ) begin
   if(i_hsync == 1'b0)begin
        hcnt <= {depth2width(HNUM){1'b0}};
   end
   else if(hcnt == HNUM)begin
        hcnt <= hcnt;
   end
   else if(data_vld[0] == 1'b1)begin
        hcnt <= hcnt + 1'b1;
   end
   else begin
        hcnt <= hcnt;
   end 
end
//与data 同步
always @(posedge i_clk ) begin
    if((hcnt >= HNUM_START) && (hcnt < HNUM_END))begin
        data_vld[1] <= data_vld[0];
    end
    else begin
        data_vld[1] <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if(i_vsync == 1'b0)begin
        vcnt <= {depth2width(VNUM){1'b0}};
    end
    else if((hsync_dly == 2'b10) && (vcnt == VNUM))begin
        vcnt <= vcnt;
    end
    else if(hsync_dly == 2'b10)begin
        vcnt <= vcnt + 1'b1;
    end
    else begin
        vcnt <= vcnt;
    end
end

always @(posedge i_clk ) begin
    if(data_vld[1] == 1'b1 )begin
        o_data  <= data;
    end
    else begin
        o_data  <= o_data;
    end
end

always @(posedge i_clk ) begin
    if((vcnt >= VNUM_START) && (vcnt < VNUM_END))begin
        o_hsync <= data_vld[1];
    end
    else begin
        o_hsync <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if((vcnt >= VNUM_START) && (vcnt < VNUM_END) && (vsync_dly == 1'b1))begin
        o_vsync <= 1'b1;
    end
    else if((vcnt == VNUM_END) && (|hsync_dly == 1'b0) && (vsync_dly == 1'b1))begin
        o_vsync <= 1'b1;
    end
    else begin
        o_vsync <= 1'b0;
    end
end

endmodule