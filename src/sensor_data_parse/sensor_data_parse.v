module sensor_data_parse #(
    parameter   Y_BLANK_SIZE        = 4     ,
    parameter   IMAGE_WIDE_LENGTH   = 256   ,
    parameter   IMAGE_HIGH_LENGTH   = 192   ,
    parameter   DW                  = 8      
) (
    input                               i_rst_n         ,
    input                               i_clk           ,
    input           [DW-1:0]            i_data          ,
    input                               i_hs            ,
    input                               i_vs            ,

    output reg      [DW*2-1:0]          o_data_mean     ,
    output reg      [DW*2-1:0]          o_data          ,
    output reg      [DW*2-1:0]          o_center_x16_data ,
    output reg                          o_hs            ,
    output reg                          o_vs             
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

localparam          VNUM       = IMAGE_HIGH_LENGTH + Y_BLANK_SIZE + 4       ;
localparam          HNUM       = IMAGE_WIDE_LENGTH * 2                      ;
localparam          SUM_NUM    = IMAGE_WIDE_LENGTH * IMAGE_HIGH_LENGTH      ; 
localparam          SUM_NUM_DW = depth2width(SUM_NUM) + (DW*2)              ;
reg             [DW-1:0]                                        data_dly0,data_dly1,data_dly2           ;
reg                                                             hs_dly0  ,hs_dly1  ,hs_dly2             ;
reg                                                             vs_dly0  ,vs_dly1  ,vs_dly2             ;
reg             [SUM_NUM_DW-1:0]                                data_sum                                ;

reg             [DW*2-1:0]                                      x16_data                                ;
reg                                                             x16_hs                                  ;
reg                                                             x16_vs                                  ;

reg             [depth2width(HNUM)-1:0]                         hcnt                                    ;
reg             [depth2width(VNUM)-1:0]                         vcnt                                    ;

reg             [1:0]                                           calc_en                                 ;
wire            [SUM_NUM_DW-1:0]                                data_div                                ;
wire                                                            data_div_vld                            ;

always @(negedge i_clk ) begin
    data_dly0 <= i_data;
    hs_dly0   <= i_hs  ;
    vs_dly0   <= i_vs  ;
end

always @(posedge i_clk ) begin
    data_dly1 <= data_dly0;
    hs_dly1   <= hs_dly0  ;
    vs_dly1   <= vs_dly0  ;

    data_dly2 <= data_dly1;
    hs_dly2   <= hs_dly1  ;
    vs_dly2   <= vs_dly1  ;
end

always @(posedge i_clk ) begin
    if(vs_dly2 == 1'b0)begin
        hcnt <= {depth2width(HNUM){1'b0}};
    end
    else if((hs_dly2 == 1'b1) && (hcnt == HNUM-1))begin
        hcnt <= {depth2width(HNUM){1'b0}};
    end
    else if(hs_dly2 == 1'b1)begin
        hcnt <= hcnt + 1'b1;
    end
    else begin
        hcnt <= hcnt;
    end
end

always @(posedge i_clk ) begin
    if(vs_dly2 == 1'b0)begin
        vcnt <= {depth2width(VNUM){1'b0}};
    end
    else if((hs_dly2 == 1'b1) && (hcnt == HNUM-1) && (vcnt == VNUM-1))begin
        vcnt <= vcnt;
    end
    else if((hs_dly2 == 1'b1) && (hcnt == HNUM-1))begin
        vcnt <= vcnt + 1'b1;
    end
    else begin
        vcnt <= vcnt;
    end
end

always @(posedge i_clk ) begin
    if({hs_dly2,vs_dly2} ==  2'b11 )begin
        x16_data <= {x16_data[7:0],data_dly2};
    end
    else begin
        x16_data <= x16_data;
    end
end

always @(posedge i_clk ) begin
    x16_vs <= vs_dly2;
end

always @(posedge i_clk ) begin
    if(({hs_dly2,vs_dly2} ==  2'b11) && (hcnt[0] == 1'b1) 
   && (vcnt >=Y_BLANK_SIZE ) && (vcnt <= IMAGE_HIGH_LENGTH + Y_BLANK_SIZE -1 ))begin
        x16_hs <= 1'b1;
    end
    else begin
        x16_hs <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if(x16_vs == 1'b0)begin
        data_sum <= { SUM_NUM_DW {1'b0}} ;
    end
    else if(x16_hs == 1'b1)begin
        data_sum <= data_sum + x16_data;
    end
    else begin
        data_sum <= data_sum;
    end
end

always @(posedge i_clk ) begin
    if((vcnt == IMAGE_HIGH_LENGTH + Y_BLANK_SIZE-1) && hcnt == HNUM-1)begin
        calc_en[0] <= 1'b1;
    end
    else begin
        calc_en[0] <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    calc_en[1] <= calc_en[0];
end

unsigned_divider #(
    .NUMER_DW   (SUM_NUM_DW                             )     ,
    .DENOM_DW   (depth2width(SUM_NUM       )            )                                     
)unsigned_divider_inst (
    .i_clk               (i_clk         ),        //input                                       
    .i_rst_n             (i_rst_n       ),        //input                                       
    .i_div_en            (calc_en[1]    ),        //input                                       
    .i_numer             (data_sum      ),        //input           [NUMER_DW-1:0]              
    .i_denom             (SUM_NUM       ),        //input           [DENOM_DW-1:0]              
    .o_quotient          (data_div      ),        //output reg      [NUMER_DW-1:0]              
    .o_quotient_vld      (data_div_vld  )         //output reg                                      
); 

always @(posedge i_clk ) begin
    if(data_div_vld == 1'b1)begin
        o_data_mean <= data_div[2*DW-1:0];
    end
    else begin
        o_data_mean <= o_data_mean;        
    end
end

always @(posedge i_clk ) begin
    if(({hs_dly2,vs_dly2} ==  2'b11) && (hcnt == (HNUM >> 1) -1) && (vcnt == (VNUM >> 1)-1))begin
        o_center_x16_data <= {x16_data[7:0],data_dly2};
    end
    else begin
        o_center_x16_data <= o_center_x16_data;        
    end
end


always @(posedge i_clk ) begin
    o_data <= x16_data ;
    o_hs   <= x16_hs   ;
    o_vs   <= x16_vs   ;
end


endmodule