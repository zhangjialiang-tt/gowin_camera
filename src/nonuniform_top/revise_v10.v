`timescale 1ns / 1ps
module revise_v10 #(
    parameter SINED_SEL         = "YES"  ,    
    parameter MULT_DELAY        = 1      ,
    parameter IMAGE_WIDE_LENGTH = 256    ,
    parameter IMAGE_HIGH_LENGTH = 192    ,
    parameter ADDRS_DW          = 21     ,
    parameter DW                = 16    
) (
    input                           i_rst_n             ,
    input                           i_clk               ,
    input           [DW-1:0]        i_data              ,
    input                           i_hs                ,
    input                           i_vs                ,

    input           [3:0]           i_sel               ,
    input           [DW-1:0]        i_b_mean_data       ,
    input           [ADDRS_DW-1:0]  i_b_addrs           ,
    input           [ADDRS_DW-1:0]  i_k_addrs           ,
    input                           i_init_k_load       ,
    output reg                      o_rd_b_start        ,
    output          [ADDRS_DW-1:0]  o_rd_b_addrs        ,
    output          [ADDRS_DW-1:0]  o_rd_b_lengths      , 
    output                          o_rd_b_req          ,
    input           [DW-1:0]        i_rd_b_data         ,

    output reg                      o_rd_k_start        ,
    output          [ADDRS_DW-1:0]  o_rd_k_addrs        ,
    output          [ADDRS_DW-1:0]  o_rd_k_lengths      , 
    output                          o_rd_k_req          ,
    input           [DW-1:0]        i_rd_k_data         ,

    output reg                      o_bp_type           ,
    output reg      [DW-1:0]        o_data              ,
    output reg      [DW-1:0]        o_center_y16_data   ,
    output reg                      o_hs               ,
    output reg                      o_vs                    

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

reg             [DW-1 : 0]                              data_dly                ;

reg             [DW-1 : 0]                              sub_b_data              ;

reg             [1:0]                                   vs_out_dly              ;
reg                                                     init_k_load             ;
reg             [DW-1:0]                                data_k                  ;


wire            [31:0]                                  multi_y16               ;
reg             [18:0]                                  multi_y16_div           ;
reg             [18:0]                                  y16_pipe                ;
reg                                                     bp_type                 ;
reg             [(MULT_DELAY+4)*DW-1:0]                 data_b_dly              ;
reg             [(MULT_DELAY+3)*DW-1:0]                 data_k_dly              ;
reg             [(MULT_DELAY+5)*DW-1:0]                 data_x16_dly            ;
reg             [MULT_DELAY+4 : 0]                      vs_dly                  ;   
reg             [MULT_DELAY+4 : 0]                      hs_dly                  ;   
reg             [DW-1:0]                                data_y16                ;   
reg             [3:0]                                   sel                     ;          

always @(posedge i_clk ) begin
    if(vs_out_dly == 2'b10)begin
        o_rd_b_start <= 1'b1;
    end
    else begin
        o_rd_b_start <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if(vs_out_dly == 2'b10)begin
        o_rd_k_start <= 1'b1;
    end
    else begin
        o_rd_k_start <= 1'b0;
    end
end
assign o_rd_k_req       = ({i_hs,i_vs} == 2'b11)? 1'b1 : 1'b0  ;
assign o_rd_b_req       = ({i_hs,i_vs} == 2'b11)? 1'b1 : 1'b0  ;
assign o_rd_b_lengths   = IMAGE_WIDE_LENGTH * IMAGE_HIGH_LENGTH;
assign o_rd_k_lengths   = IMAGE_WIDE_LENGTH * IMAGE_HIGH_LENGTH;
assign o_rd_b_addrs     = i_b_addrs ;
assign o_rd_k_addrs     = i_k_addrs ;
    

always @(posedge i_clk ) begin
    vs_out_dly <= {vs_out_dly[0],o_vs};
end

always @(posedge i_clk ) begin
    if(vs_out_dly == 2'b10)begin
        init_k_load <= i_init_k_load;
    end
    else begin
        init_k_load <= init_k_load;
    end
end

always @(posedge i_clk ) begin
    if({i_hs,i_vs} == 2'b11)begin
        data_dly <= i_data;
    end
    else begin
        data_dly <= {DW{1'b0}};
    end
end

always @(posedge i_clk ) begin
    if({hs_dly[0],vs_dly[0]} == 2'b11)begin
        sub_b_data <= data_dly - i_rd_b_data;
    end
    else begin
        sub_b_data <= {DW{1'b0}};
    end
end

always @(posedge i_clk ) begin
    if(({hs_dly[0],vs_dly[0]} == 2'b11) && (init_k_load == 1'b0))begin
        data_k <= {1'b0,i_rd_k_data[DW-2:0]};
    end
    else begin
        data_k <= 'd8192;
    end
end

always @(posedge i_clk ) begin
    if({hs_dly[0],vs_dly[0]} == 2'b11)begin
        bp_type <= i_rd_k_data[DW-1]; 
    end
    else begin
        bp_type <= 1'b0;
    end
end

// always @(posedge i_clk ) begin  //MULT_DELAY
//     multi_y16 <= data_k*sub_b_data; 
// end

mult_signed_nuc mult_signed_nuc_inst(
	.clk        (i_clk          ), //input clk
	.rstn       (i_rst_n        ), //input rstn
	.mul_a      (data_k         ), //input [15:0] mul_a
	.mul_b      (sub_b_data     ), //input [15:0] mul_b
	.product    (multi_y16      ) //output [31:0] product	
);

always @(posedge i_clk ) begin  //1
    if({hs_dly[1+MULT_DELAY],vs_dly[1+MULT_DELAY]} == 2'b11)begin
        multi_y16_div <= multi_y16[31:13]; 
    end
    else begin
        multi_y16_div <= 19'd0; 
    end
end

always @(posedge i_clk ) begin  //1
    y16_pipe <= multi_y16_div + i_b_mean_data;
end

generate
    if(SINED_SEL == "YES")begin
        always @(posedge i_clk ) begin //1
            if((y16_pipe[18] == 1'b0) && (|y16_pipe[18:15] == 1'b1))begin
                data_y16 <= 16'h7FFF;
            end
            else if((y16_pipe[18] == 1'b1) && (y16_pipe[18:0] < 19'h78000) )begin
                data_y16 <= 16'h8000;
            end
            else begin
                data_y16 <= y16_pipe[15:0];
            end
        end 
    end
    else begin
        always @(posedge i_clk ) begin //1
            if(y16_pipe[18] == 1'b1)begin
                data_y16 <= {DW{1'b0}};
            end
            else if(|y16_pipe[18:14] == 1'b1)begin
                data_y16 <= {{(DW-14){1'b0}},{14{1'b1}}};
            end
            else begin
                data_y16 <= {{(DW-14){1'b0}},y16_pipe[13:0]};
            end
        end       
    end
endgenerate

always @(posedge i_clk ) begin
    if(vs_out_dly == 2'b10 )begin
        sel <= i_sel;
    end
    else begin
        sel <= sel;
    end
end

always @(posedge i_clk ) begin
    data_x16_dly <= {data_x16_dly[(MULT_DELAY+4)*DW-1:0],i_data};
end

always @(posedge i_clk ) begin
    data_b_dly <= {data_b_dly[(MULT_DELAY+3)*DW-1:0],i_rd_b_data};
end

always @(posedge i_clk ) begin
    data_k_dly <= {data_k_dly[(MULT_DELAY+2)*DW-1:0],{bp_type,data_k[DW-2:0]}};
end

always @(posedge i_clk ) begin
    case (sel)
    4'b0001:o_data <= data_y16;                                             //Y16
    4'b0010:o_data <= data_x16_dly[(MULT_DELAY+5)*DW-1 -: DW];              //X16
    4'b0100:o_data <= data_b_dly[(MULT_DELAY+4)*DW-1 -: DW];                //B
    4'b1000:o_data <= {1'b0,{data_k_dly[(MULT_DELAY+3)*DW-2 -: DW-1]}};     //K
        default: o_data <= data_y16;
    endcase
end

always @(posedge i_clk ) begin
    o_bp_type <= data_k_dly[(MULT_DELAY+3)*DW-1];
end
always @(posedge i_clk ) begin
    vs_dly[MULT_DELAY+4 : 0] <= {vs_dly[MULT_DELAY+3:0],i_vs};
    hs_dly[MULT_DELAY+4 : 0] <= {hs_dly[MULT_DELAY+3:0],i_hs};
end


always @(posedge i_clk ) begin
    o_vs <= vs_dly[MULT_DELAY+4];
    o_hs <= hs_dly[MULT_DELAY+4];
end


reg             [depth2width(IMAGE_WIDE_LENGTH)-1:0]                         hcnt                                    ;
reg             [depth2width(IMAGE_HIGH_LENGTH)-1:0]                         vcnt                                    ;

always @(posedge i_clk ) begin
    if(vs_dly[MULT_DELAY+4] == 1'b0)begin
        hcnt <= {depth2width(IMAGE_WIDE_LENGTH){1'b0}};
    end
    else if((hs_dly[MULT_DELAY+4] == 1'b1) && (hcnt == IMAGE_WIDE_LENGTH-1))begin
        hcnt <= {depth2width(IMAGE_WIDE_LENGTH){1'b0}};
    end
    else if(hs_dly[MULT_DELAY+4] == 1'b1)begin
        hcnt <= hcnt + 1'b1;
    end
    else begin
        hcnt <= hcnt;
    end
end

always @(posedge i_clk ) begin
    if(vs_dly[MULT_DELAY+4] == 1'b0)begin
        vcnt <= {depth2width(IMAGE_HIGH_LENGTH){1'b0}};
    end
    else if((hs_dly[MULT_DELAY+4] == 1'b1) && (hcnt == IMAGE_WIDE_LENGTH-1) && (vcnt == IMAGE_HIGH_LENGTH-1))begin
        vcnt <= vcnt;
    end
    else if((hs_dly[MULT_DELAY+4] == 1'b1) && (hcnt == IMAGE_WIDE_LENGTH-1))begin
        vcnt <= vcnt + 1'b1;
    end
    else begin
        vcnt <= vcnt;
    end
end

always @(posedge i_clk ) begin
    if((vs_dly[MULT_DELAY+4])&& (hs_dly[MULT_DELAY+4]) && (hcnt == (IMAGE_WIDE_LENGTH >> 1) -1) && (vcnt == (IMAGE_HIGH_LENGTH >> 1)-1))begin
        o_center_y16_data <= data_y16;
    end
    else begin
        o_center_y16_data <= o_center_y16_data;        
    end
end
endmodule