module calc_b_v10 #(
    parameter IMAGE_WIDE_LENGTH = 256    ,
    parameter IMAGE_HIGH_LENGTH = 192    ,
    parameter ADDRS_DW          = 21     ,
    parameter DW                = 14       
) (
    input                           i_rst_n             ,
    input                           i_clk               ,
    input                           i_calc_en           ,
    input       [3:0]               i_base_mean_num     ,
    input       [ADDRS_DW - 1 : 0]  i_addrs             ,
    input       [DW - 1 : 0]        i_data              ,
    input                           i_data_vld          ,
    input                           i_data_vs           ,

    output  reg                     o_mem_rd_start      , 
    output      [ADDRS_DW - 1 : 0]  o_mem_rd_addrs      ,
    output      [ADDRS_DW - 1 : 0]  o_mem_rd_lengths    ,
    input       [DW - 1 : 0]        i_mem_rd_data       ,
    output                          o_mem_rd_data_req   ,      

    output  reg                     o_mem_wr_start      ,
    output      [ADDRS_DW - 1 : 0]  o_mem_wr_addrs      ,
    output      [ADDRS_DW - 1 : 0]  o_mem_wr_lengths    ,
    output  reg [DW - 1 : 0]        o_mem_wr_data       ,
    output  reg                     o_mem_wr_data_vld   ,
    output  reg [DW - 1 : 0]        o_b_mean_data       ,
    output                          o_calc_busy         ,
    output  reg                     o_calc_done               
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


localparam IMAGE_LENGTH      = IMAGE_WIDE_LENGTH*IMAGE_HIGH_LENGTH          ;
localparam SUM_DW            =  depth2width(IMAGE_LENGTH)                   ;

reg                 [1:0]           calc_en_dly                             ;
reg                                 calc_sync                               ;
reg                 [1:0]           vs_dly                                  ;
reg                 [1:0]           hs_dly                                  ;
reg                                 calc_en                                 ;

reg                 [5:0]           fcnt                                    ;
reg                 [7:0]           start_cnt                               ;

reg                 [DW : 0]        data_add                                ;
reg                                 mean_en                                 ;

reg                 [SUM_DW + DW -1:0]                      data_sum        ;

wire                [SUM_DW + DW -1:0]                      data_div        ;
wire                                                        data_div_vld    ;


assign o_mem_rd_addrs   = i_addrs       ;
assign o_mem_rd_lengths = IMAGE_LENGTH  ;
assign o_mem_wr_addrs   = i_addrs       ;
assign o_mem_wr_lengths = IMAGE_LENGTH  ;
assign o_calc_busy      = calc_en       ;

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        calc_en_dly <= 2'b00;
    end
    else begin
        calc_en_dly <= {calc_en_dly[0],i_calc_en};
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        calc_sync <= 1'b0;
    end
    else if((vs_dly ==2'b10) && (calc_sync == 1'b1))begin
        calc_sync <= 1'b0;
    end
    else if((calc_en_dly == 2'b01) && (calc_sync == 1'b0))begin
        calc_sync <= 1'b1;
    end
    else begin
        calc_sync <= calc_sync;
    end
end

always @(posedge i_clk ) begin
    vs_dly <= {vs_dly[0],i_data_vs};
    hs_dly <= {hs_dly[0],i_data_vld};
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        calc_en <= 1'b0;
    end
    else if((calc_en == 1'b1) && (o_calc_done == 1'b1))begin
        calc_en <= 1'b0;
    end
    else if((vs_dly ==2'b10) && (calc_sync == 1'b1))begin
        calc_en <= 1'b1;
    end
    else begin
        calc_en <= calc_en;
    end
end

always @(posedge i_clk ) begin
    if({calc_en,i_data_vs,i_data_vld} == 3'b111)begin
        case (i_base_mean_num)
        4'b0001: data_add <= i_data + 2'd2 ;
        4'b0010: data_add <= i_data + 3'd4 ;
        4'b0100: data_add <= i_data + 4'd8 ;
        4'b1000: data_add <= i_data + 5'd16;
            default: data_add <= i_data + 4'd8 ;
        endcase
    end
    else begin
        data_add <= {(DW+1){1'b0}};
    end
end

always @(posedge i_clk ) begin
    case (i_base_mean_num)
    4'b0001: if(fcnt == 6'd0)begin
                o_mem_wr_data <= {1'd0,data_add[DW:2]};
            end
            else begin
                o_mem_wr_data <= {1'd0,data_add[DW:2]} + i_mem_rd_data;
            end
    4'b0010: if(fcnt == 6'd0)begin
                o_mem_wr_data <= {2'd0,data_add[DW:3]};
            end
            else begin
                o_mem_wr_data <= {2'd0,data_add[DW:3]} + i_mem_rd_data;
            end
    4'b0100: if(fcnt == 6'd0)begin
                o_mem_wr_data <= {3'd0,data_add[DW:4]};
            end
            else begin
                o_mem_wr_data <= {3'd0,data_add[DW:4]} + i_mem_rd_data;
            end
    4'b1000:if(fcnt == 6'd0)begin
                o_mem_wr_data <= {4'd0,data_add[DW:5]};
            end
            else begin
                o_mem_wr_data <= {4'd0,data_add[DW:5]} + i_mem_rd_data;
            end 
        default: if(fcnt == 6'd0)begin
                o_mem_wr_data <= {3'd0,data_add[DW:4]};
            end
            else begin
                o_mem_wr_data <= {3'd0,data_add[DW:4]} + i_mem_rd_data;
            end
    endcase
end

always @(posedge i_clk ) begin
    if(calc_en == 1'b0)begin
        start_cnt <= 8'h0f;
    end
    else if(i_data_vs == 1'b1)begin
        start_cnt <= 8'h00;
    end
    else if(start_cnt == 8'hFF)begin
        start_cnt <= start_cnt;
    end
    else begin
        start_cnt <= start_cnt + 8'h01;
    end
end

always @(posedge i_clk ) begin
    if(start_cnt == 8'hF0)begin
        o_mem_rd_start <= 1'b1;
        o_mem_wr_start <= 1'b1;
    end
    else begin
        o_mem_rd_start <= 1'b0;
        o_mem_wr_start <= 1'b0;
    end
end
always @(posedge i_clk ) begin
    if(calc_en == 1'b0)begin
        fcnt <= 6'd0;
    end
    else if(start_cnt  == 8'h0A)begin
        fcnt <= fcnt + 8'd1;
    end
    else begin
        fcnt <= fcnt;
    end
end

always @(posedge i_clk ) begin
    case (i_base_mean_num)
    4'b0001: if((start_cnt == 8'h0A) && (fcnt > 6'd2 ))begin
        o_calc_done <= 1'b1;
    end
    else begin
        o_calc_done <= 1'b0;
    end
    4'b0010: if((start_cnt == 8'h0A) && (fcnt > 6'd6 ))begin
        o_calc_done <= 1'b1;
    end
    else begin
        o_calc_done <= 1'b0;
    end
    4'b0100: if((start_cnt == 8'h0A) && (fcnt > 6'd14))begin
        o_calc_done <= 1'b1;
    end
    else begin
        o_calc_done <= 1'b0;
    end
    4'b1000: if((start_cnt == 8'h0A) && (fcnt > 6'd30))begin
        o_calc_done <= 1'b1;
    end
    else begin
        o_calc_done <= 1'b0;
    end
        default: if((start_cnt == 8'h0A) && (fcnt > 6'd14))begin
            o_calc_done <= 1'b1;            
        end
        else begin
            o_calc_done <= 1'b0;
        end
    endcase
end

assign o_mem_rd_data_req = ({calc_en,i_data_vs,i_data_vld} == 3'b111)? 1'b1 : 1'b0;



always @(posedge i_clk ) begin
    if(fcnt == 6'd0)begin
        mean_en <= 1'b0;
    end
    else begin
        case (i_base_mean_num)
        4'b0001: if((fcnt == 6'd3) && (o_mem_rd_start == 1'b1))begin
            mean_en <= 1'b1 ;
        end
        else begin
            mean_en <= mean_en;
        end
        4'b0010: if((fcnt == 6'd7) && (o_mem_rd_start == 1'b1))begin
            mean_en <= 1'b1 ;
        end
        else begin
            mean_en <= mean_en;
        end
        4'b0100: if((fcnt == 6'd15) && (o_mem_rd_start == 1'b1))begin
            mean_en <= 1'b1 ;
        end
        else begin
            mean_en <= mean_en;
        end
        4'b1000:if((fcnt == 6'd3) && (o_mem_rd_start == 1'b1))begin
            mean_en <= 1'b1 ;
        end
        else begin
            mean_en <= mean_en;
        end
            default:if((fcnt == 6'd15) && (o_mem_rd_start == 1'b1))begin
                mean_en <= 1'b1 ;
            end
            else begin
                mean_en <= mean_en;
            end
        endcase 
    end
end

always @(posedge i_clk ) begin
    if({vs_dly,calc_en} ==3'b011 )begin
        data_sum <= {(SUM_DW + DW ){1'b0}}; 
    end
    else if({mean_en,o_mem_wr_data_vld} == 2'b11)begin
        data_sum <= data_sum + o_mem_wr_data;
    end
    else begin
        data_sum <= data_sum;
    end
end

always @(posedge i_clk ) begin
    if({hs_dly[0],vs_dly[0]} == 2'b11)begin
        o_mem_wr_data_vld <= 1'b1;
    end
    else begin
        o_mem_wr_data_vld <= 1'b0;        
    end
end


unsigned_divider #(
    .NUMER_DW   (SUM_DW + DW                            )     ,
    .DENOM_DW   (depth2width(IMAGE_LENGTH       )       )                                     
)unsigned_divider_inst (
    .i_clk               (i_clk         ),        //input                                       
    .i_rst_n             (i_rst_n       ),        //input                                       
    .i_div_en            (o_calc_done   ),        //input                                       
    .i_numer             (data_sum      ),        //input           [NUMER_DW-1:0]              
    .i_denom             (IMAGE_LENGTH  ),        //input           [DENOM_DW-1:0]              
    .o_quotient          (data_div      ),        //output reg      [NUMER_DW-1:0]              
    .o_quotient_vld      (data_div_vld  )         //output reg                                      
);  

always @(posedge i_clk ) begin
    if(data_div_vld == 1'b1)begin
        o_b_mean_data <= data_div[0 +:DW];
    end
    else begin
        // o_b_mean_data <= 'd8192;
        o_b_mean_data <= o_b_mean_data;
    end
end


endmodule