`timescale 1ns / 1ps
module nonuniform_top_v0 #(
    parameter IMAGE_WIDE_LENGTH = 256    ,
    parameter IMAGE_HIGH_LENGTH = 192    ,
    parameter ADDRS_DW          = 21     ,
    parameter DW                = 16       
) (
    input                               i_rst_n                 ,
    input                               i_clk                   ,

    input   [DW-1:0]                    i_data                  ,
    input                               i_hs                    ,
    input                               i_vs                    ,
    input   [3:0]                       i_clac_b_mean_num       ,
    input                               i_clac_b_en             ,
    input   [ADDRS_DW-1:0]              i_b_addrs               ,
    output                              o_clac_b_done           ,

    input   [3:0]                       i_data_sel              ,
    input   [ADDRS_DW-1:0]              i_k_addrs               ,
    input                               i_init_k_load           ,
    output                              o_bp_type               ,
    output  [DW-1:0]                    o_data                  ,
    output  [DW-1:0]                    o_calc_b_mean_data      ,
    output  [DW-1:0]                    o_center_y16_data       ,
    output  [DW-1:0]                    o_sub_aver_y16          ,
    output                              o_hs                    ,
    output                              o_vs                    ,

    output                              o_mem_wr_start          ,
    output   [ADDRS_DW-1:0]             o_mem_wr_addrs          ,
    output   [ADDRS_DW-1:0]             o_mem_wr_lengths        ,
    output   [DW-1:0]                   o_mem_wr_data           ,
    output                              o_mem_wr_data_vld       ,

    output                              o_mem_rd0_start         ,
    output   [ADDRS_DW-1:0]             o_mem_rd0_addrs         ,
    output   [ADDRS_DW-1:0]             o_mem_rd0_lengths       ,
    input    [DW-1:0]                   i_mem_rd0_data          ,
    output                              o_mem_rd0_data_req      ,

    output                              o_mem_rd1_start         ,
    output   [ADDRS_DW-1:0]             o_mem_rd1_addrs         ,
    output   [ADDRS_DW-1:0]             o_mem_rd1_lengths       ,
    input    [DW-1:0]                   i_mem_rd1_data          ,
    output                              o_mem_rd1_data_req       
);

wire                                    mem_rd_calc_b_start     ;
wire         [ADDRS_DW-1:0]             mem_rd_calc_b_addrs     ;
wire         [ADDRS_DW-1:0]             mem_rd_calc_b_lengths   ;
wire         [DW-1:0]                   mem_rd_calc_b_data      ;
wire                                    mem_rd_calc_b_data_req  ;

wire                                   mem_rd_revise_b_start    ;
wire         [ADDRS_DW-1:0]            mem_rd_revise_b_addrs    ;
wire         [ADDRS_DW-1:0]            mem_rd_revise_b_lengths  ;
wire                                   mem_rd_revise_b_data_req ;
wire         [DW-1:0]                  mem_rd_revise_b_data     ;

wire         [DW-1:0]                  calc_b_mean_data         ;
wire                                   calc_b_busy              ;

assign o_mem_rd0_start      = (calc_b_busy == 1'b1)? mem_rd_calc_b_start      : mem_rd_revise_b_start     ;
assign o_mem_rd0_addrs      = (calc_b_busy == 1'b1)? mem_rd_calc_b_addrs      : mem_rd_revise_b_addrs     ;
assign o_mem_rd0_lengths    = (calc_b_busy == 1'b1)? mem_rd_calc_b_lengths    : mem_rd_revise_b_lengths   ;
assign mem_rd_calc_b_data   = (calc_b_busy == 1'b1)? i_mem_rd0_data           : 16'd1                     ;
assign mem_rd_revise_b_data = (calc_b_busy == 1'b1)? 16'd1                    : i_mem_rd0_data            ;
assign o_mem_rd0_data_req   = (calc_b_busy == 1'b1)? mem_rd_calc_b_data_req   : mem_rd_revise_b_data_req  ;

//calc b
calc_b_v10 #(
    .IMAGE_WIDE_LENGTH  (IMAGE_WIDE_LENGTH             )  ,
    .IMAGE_HIGH_LENGTH  (IMAGE_HIGH_LENGTH             )  ,
    .ADDRS_DW           (ADDRS_DW                      )  ,
    .DW                 (DW                            )    
)calc_b_v10_inst(
    .i_rst_n             (i_rst_n                       ),    //input                           
    .i_clk               (i_clk                         ),    //input                           
    .i_calc_en           (i_clac_b_en                   ),    //input                           
    .i_base_mean_num     (i_clac_b_mean_num             ),    //input       [3:0]               
    .i_addrs             (i_b_addrs                     ),    //input       [ADDRS_DW - 1 : 0]  
    .i_data              (i_data                        ),    //input       [DW - 1 : 0]        
    .i_data_vld          (i_hs                          ),    //input                           
    .i_data_vs           (i_vs                          ),    //input                           
    .o_mem_rd_start      (mem_rd_calc_b_start           ),    //output  reg                      
    .o_mem_rd_addrs      (mem_rd_calc_b_addrs           ),    //output      [ADDRS_DW - 1 : 0]  
    .o_mem_rd_lengths    (mem_rd_calc_b_lengths         ),    //output      [ADDRS_DW - 1 : 0]  
    .i_mem_rd_data       (mem_rd_calc_b_data            ),    //input       [DW - 1 : 0]        
    .o_mem_rd_data_req   (mem_rd_calc_b_data_req        ),    //output                                
    .o_mem_wr_start      (o_mem_wr_start                ),    //output  reg                     
    .o_mem_wr_addrs      (o_mem_wr_addrs                ),    //output      [ADDRS_DW - 1 : 0]  
    .o_mem_wr_lengths    (o_mem_wr_lengths              ),    //output      [ADDRS_DW - 1 : 0]  
    .o_mem_wr_data       (o_mem_wr_data                 ),    //output  reg [DW - 1 : 0]        
    .o_mem_wr_data_vld   (o_mem_wr_data_vld             ),    //output  reg                     
    // .o_b_mean_data       (/*calc_b_mean_data */         ),    //output  reg [DW - 1 : 0] 
    .o_b_mean_data       (calc_b_mean_data          ),    //output  reg [DW - 1 : 0] 
    .o_calc_busy         (calc_b_busy                   ),    //output               
    .o_calc_done         (o_clac_b_done                 )     //output  reg                          
);

// assign calc_b_mean_data = 16'd0;
//nuc calc
assign  o_calc_b_mean_data  = calc_b_mean_data;
assign  o_sub_aver_y16      = o_center_y16_data - calc_b_mean_data;
// assign  o_sub_aver_y16      = o_center_y16_data > calc_b_mean_data ? o_center_y16_data - calc_b_mean_data : calc_b_mean_data - o_center_y16_data;
revise_v10 #(
    .SINED_SEL         ("YES"  ),    
    .MULT_DELAY        (5      ),
    .IMAGE_WIDE_LENGTH (IMAGE_WIDE_LENGTH           ),
    .IMAGE_HIGH_LENGTH (IMAGE_HIGH_LENGTH           ),
    .ADDRS_DW          (ADDRS_DW                    ),
    .DW                (DW                          )
)revise_v10_inst (
    .i_rst_n             (i_rst_n                   ),    //input                           
    .i_clk               (i_clk                     ),    //input                           
    .i_data              (i_data                    ),    //input           [DW-1:0]        
    .i_hs                (i_hs                      ),    //input                           
    .i_vs                (i_vs                      ),    //input                           
    .i_sel               (i_data_sel                ),    //input           [3:0]           
    .i_b_mean_data       (0                         ),    //input           [DW-1:0]        calc_b_mean_data
    .i_b_addrs           (i_b_addrs                 ),    //input           [ADDRS_DW-1:0]  
    .i_k_addrs           (i_k_addrs                 ),    //input           [ADDRS_DW-1:0]  
    .i_init_k_load       (i_init_k_load             ),    //input                           
    .o_rd_b_start        (mem_rd_revise_b_start     ),    //output reg                      
    .o_rd_b_addrs        (mem_rd_revise_b_addrs     ),    //output          [ADDRS_DW-1:0]  
    .o_rd_b_lengths      (mem_rd_revise_b_lengths   ),    //output          [ADDRS_DW-1:0]   
    .o_rd_b_req          (mem_rd_revise_b_data_req  ),    //output                          
    .i_rd_b_data         (mem_rd_revise_b_data      ),    //input           [DW-1:0]        
    .o_rd_k_start        (o_mem_rd1_start           ),    //output reg                      
    .o_rd_k_addrs        (o_mem_rd1_addrs           ),    //output          [ADDRS_DW-1:0]  
    .o_rd_k_lengths      (o_mem_rd1_lengths         ),    //output          [ADDRS_DW-1:0]   
    .o_rd_k_req          (o_mem_rd1_data_req        ),    //output                          
    .i_rd_k_data         (i_mem_rd1_data            ),    //input           [DW-1:0]        
    .o_bp_type           (o_bp_type                 ),    //output reg                      
    .o_data              (o_data                    ),    //output reg      [DW-1:0] 
    .o_center_y16_data   (o_center_y16_data         ),       
    .o_hs                (o_hs                      ),    //output reg                      
    .o_vs                (o_vs                      )     //output reg                         

);


reg             [15:0]          cnt11;

always @(posedge i_clk ) begin
    if(o_mem_rd1_start == 1'b1)begin
        cnt11 <= 16'd0;
    end
    else if(o_mem_rd1_data_req == 1'b1)begin
      cnt11 <= cnt11 +1'b1;
    end
    else begin
      cnt11 <= cnt11;
    end
end

    
endmodule