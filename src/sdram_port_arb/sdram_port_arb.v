module sdram_port_arb #(
    parameter       SDRAM_ADDRS_WIDE            = 21        ,
    parameter       SDRAM_DATA_WIDE             = 32        ,  
    parameter       USE_WRPORT0_DW              = 16         ,
    parameter       USE_WRPORT1_DW              = 16         ,
    parameter       USE_WRPORT2_DW              = 16         ,
    parameter       USE_WRPORT3_DW              = 16         ,
    parameter       USE_WRPORT4_DW              = 16         ,
    parameter       USE_RDPORT0_DW              = 16         ,
    parameter       USE_RDPORT0_FIFO_MODE       = 0         ,
    parameter       USE_RDPORT1_DW              = 16         ,
    parameter       USE_RDPORT1_FIFO_MODE       = 0         ,
    parameter       USE_RDPORT2_DW              = 16         ,
    parameter       USE_RDPORT2_FIFO_MODE       = 0         ,
    parameter       USE_RDPORT3_DW              = 16         ,
    parameter       USE_RDPORT3_FIFO_MODE       = 0            
) (
    input                               i_rst_n                                             ,
    input                               i_clk                                               ,
    input                               i_sdram_clk                                         ,
    output                              o_sdram_init_done                                   ,
    input                               i_SDRAM_controller_sdram_selfrefresh                , 
    input                               i_SDRAM_controller_sdram_power_down                 , 

    // WR_MASTER_LIST(0)
    input wire                                  i_wr_master_0_clk,
    input wire                                  i_wr_master_0_wen,
    input wire  [USE_WRPORT0_DW-1:0]            i_wr_master_0_data,
    input wire                                  i_wr_master_0_start,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_0_addrs,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_0_lengths,
    
    // WR_MASTER_LIST(1)
    input wire                                  i_wr_master_1_clk,
    input wire                                  i_wr_master_1_wen,
    input wire  [USE_WRPORT1_DW-1:0]            i_wr_master_1_data,
    input wire                                  i_wr_master_1_start,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_1_addrs,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_1_lengths,
    
    // WR_MASTER_LIST(2)
    input wire                                  i_wr_master_2_clk,
    input wire                                  i_wr_master_2_wen,
    input wire  [USE_WRPORT2_DW-1:0]            i_wr_master_2_data,
    input wire                                  i_wr_master_2_start,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_2_addrs,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_2_lengths,
    
    // WR_MASTER_LIST(3)
    input wire                                  i_wr_master_3_clk,
    input wire                                  i_wr_master_3_wen,
    input wire  [USE_WRPORT3_DW-1:0]            i_wr_master_3_data,
    input wire                                  i_wr_master_3_start,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_3_addrs,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_3_lengths,
    
    // WR_MASTER_LIST(4)
    input wire                                  i_wr_master_4_clk,
    input wire                                  i_wr_master_4_wen,
    input wire  [USE_WRPORT4_DW-1:0]            i_wr_master_4_data,
    input wire                                  i_wr_master_4_start,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_4_addrs,
    input wire  [SDRAM_ADDRS_WIDE-1:0]          i_wr_master_4_lengths,
    
    // RD_MASTER_LIST(0)
    input  wire                                 i_rd_master_0_clk,
    input  wire                                 i_rd_master_0_req,
    output wire  [USE_RDPORT0_DW-1:0]           o_rd_master_0_data,
    output wire                                 o_rd_master_0_data_vld,
    input  wire                                 i_rd_master_0_start,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_0_addrs,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_0_lengths,
    output wire                                 o_rd_master_0_data_ready,
    
    // RD_MASTER_LIST(1)
    input  wire                                 i_rd_master_1_clk,
    input  wire                                 i_rd_master_1_req,
    output wire  [USE_RDPORT1_DW-1:0]           o_rd_master_1_data,
    output wire                                 o_rd_master_1_data_vld,
    input  wire                                 i_rd_master_1_start,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_1_addrs,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_1_lengths,
    output wire                                 o_rd_master_1_data_ready,
    
    // RD_MASTER_LIST(2)
    input  wire                                 i_rd_master_2_clk,
    input  wire                                 i_rd_master_2_req,
    output wire  [USE_RDPORT2_DW-1:0]           o_rd_master_2_data,
    output wire                                 o_rd_master_2_data_vld,
    input  wire                                 i_rd_master_2_start,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_2_addrs,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_2_lengths,
    output wire                                 o_rd_master_2_data_ready,
    
    // RD_MASTER_LIST(3)
    input  wire                                 i_rd_master_3_clk,
    input  wire                                 i_rd_master_3_req,
    output wire  [USE_RDPORT3_DW-1:0]           o_rd_master_3_data,
    output wire                                 o_rd_master_3_data_vld,
    input  wire                                 i_rd_master_3_start,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_3_addrs,
    input  wire  [SDRAM_ADDRS_WIDE-1:0]         i_rd_master_3_lengths,
    output wire                                 o_rd_master_3_data_ready,
    
//sdram interface
    output                              o_sdram_clk                                         ,
    output                              o_sdram_cke                                         ,
    output                              o_sdram_cs_n                                        ,
    output                              o_sdram_cas_n                                       ,
    output                              o_sdram_ras_n                                       ,
    output                              o_sdram_wen_n                                       , 
    output     [3:0]                    o_sdram_dqm                                         ,
    output     [10:0]                   o_sdram_addrs                                       , 
    output     [1:0]                    o_sdram_ba                                          ,
    inout      [SDRAM_DATA_WIDE-1:0]    io_sdram_dq                                          

);

wire                                                    SDRAM_controller_sdram_wr_en_n                  ;
wire                                                    SDRAM_controller_sdram_rd_en_n                  ;
wire     [SDRAM_DATA_WIDE-1:0]                          SDRAM_controller_sdram_wr_data                  ;
wire     [SDRAM_ADDRS_WIDE-1:0]                         SDRAM_controller_sdram_addrs                    ;
wire     [7:0]                                          SDRAM_controller_sdram_lengths                  ;
wire     [3:0]                                          SDRAM_controller_sdram_dqm                      ;
wire                                                    SDRAM_controller_sdram_busy_n                   ;
wire                                                    SDRAM_controller_sdram_rw_ack                   ;
wire     [SDRAM_DATA_WIDE-1:0]                          SDRAM_controller_sdram_rd_data                  ;
wire                                                    SDRAM_controller_sdram_rd_data_vld              ;

reg      [4:0]                                          wr_shift                                        ;
reg      [3:0]                                          rd_shift                                        ;
wire     [4:0]                                          wr_en                                           ;
wire     [3:0]                                          rd_en                                           ;
wire     [4:0]                                          wr_force_insert                                 ;
wire     [3:0]                                          rd_force_insert                                 ;
reg      [SDRAM_ADDRS_WIDE-1:0]                         master_sdram_addrs                              ;
wire     [SDRAM_ADDRS_WIDE-1:0]                         wr_port0_addrs,wr_port1_addrs                   ,
                                                        wr_port2_addrs,wr_port3_addrs                   ,
                                                        wr_port4_addrs                                  ;
wire     [SDRAM_ADDRS_WIDE-1:0]                         rd_port0_addrs,rd_port1_addrs                   ,
                                                        rd_port2_addrs,rd_port3_addrs                   ;    
reg      [7:0]                                          master_sdram_rw_lengths                         ;
wire     [7:0]                                          wr_port0_lengths,wr_port1_lengths                 ,
                                                        wr_port2_lengths,wr_port3_lengths                 ,
                                                        wr_port4_lengths                                  ;
wire     [7:0]                                          rd_port0_lengths,rd_port1_lengths                 ,
                                                        rd_port2_lengths,rd_port3_lengths                 ;
reg      [SDRAM_DATA_WIDE-1:0]                          master_sdram_wr_data                            ;
wire     [SDRAM_DATA_WIDE-1:0]                          wr_port0_wr_data,wr_port1_wr_data               ,
                                                        wr_port2_wr_data,wr_port3_wr_data               ,
                                                        wr_port4_wr_data                                 ; 
wire                                                    master_sdram_wr_data_req                        ;                                                         

reg                                                     locked                                          ;  

wire                                                    master_rd_wr_done                               ;  
wire                                                    master_rd_en                                    ;
wire                                                    master_wr_en                                    ;
reg                                                     sdram_init_done                                 ;
reg                                                     locked_down                                     ;

//SDRAM 写端口
// WR_MASTER_INST(0)
generate
    if(USE_WRPORT0_DW == 16)begin
sdram_wr_port #(
    .DATA_DW             (USE_WRPORT0_DW                              ),
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )
)sdram_wr_port_0_inst (
    .i_rst_n                     (sdram_init_done                           ),
    .i_port_wr_clk               (i_wr_master_0_clk                   ),
    .i_port_wr_start             (i_wr_master_0_start                 ),
    .i_port_wr_data              (i_wr_master_0_data                  ),
    .i_port_wr_data_vld          (i_wr_master_0_wen                   ),
    .i_port_wr_addrs             (i_wr_master_0_addrs                 ),
    .i_port_wr_length            (i_wr_master_0_lengths               ),
    .i_sdram_clk                 (i_clk                                     ),
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[0]           ),
    .o_sdram_data                (wr_port0_wr_data                    ),
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[0]    ),
    .o_sdram_addrs               (wr_port0_addrs                      ),
    .o_sdram_wr_lengths          (wr_port0_lengths                    ),
    .o_wr_en                     (wr_en[0]                                ),
    .o_force_insert_signal       (wr_force_insert[0]                      )
);
    end
    else begin
        assign wr_en[0]                = 1'b0                         ;
        assign wwr_port0_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;
        assign wr_port0_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;
        assign wr_force_insert[0]      = 1'b0                         ;
    end
endgenerate

// WR_MASTER_INST(1)
generate
    if(USE_WRPORT1_DW == 16)begin
sdram_wr_port #(
    .DATA_DW             (USE_WRPORT1_DW                              ),
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )
)sdram_wr_port_1_inst (
    .i_rst_n                     (sdram_init_done                           ),
    .i_port_wr_clk               (i_wr_master_1_clk                   ),
    .i_port_wr_start             (i_wr_master_1_start                 ),
    .i_port_wr_data              (i_wr_master_1_data                  ),
    .i_port_wr_data_vld          (i_wr_master_1_wen                   ),
    .i_port_wr_addrs             (i_wr_master_1_addrs                 ),
    .i_port_wr_length            (i_wr_master_1_lengths               ),
    .i_sdram_clk                 (i_clk                                     ),
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[1]           ),
    .o_sdram_data                (wr_port1_wr_data                    ),
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[1]    ),
    .o_sdram_addrs               (wr_port1_addrs                      ),
    .o_sdram_wr_lengths          (wr_port1_lengths                    ),
    .o_wr_en                     (wr_en[1]                                ),
    .o_force_insert_signal       (wr_force_insert[1]                      )
);
    end
    else begin
        assign wr_en[1]                = 1'b0                         ;
        assign wwr_port1_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;
        assign wr_port1_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;
        assign wr_force_insert[1]      = 1'b0                         ;
    end
endgenerate

// WR_MASTER_INST(2)
generate
    if(USE_WRPORT2_DW == 16)begin
sdram_wr_port #(
    .DATA_DW             (USE_WRPORT2_DW                              ),
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )
)sdram_wr_port_2_inst (
    .i_rst_n                     (sdram_init_done                           ),
    .i_port_wr_clk               (i_wr_master_2_clk                   ),
    .i_port_wr_start             (i_wr_master_2_start                 ),
    .i_port_wr_data              (i_wr_master_2_data                  ),
    .i_port_wr_data_vld          (i_wr_master_2_wen                   ),
    .i_port_wr_addrs             (i_wr_master_2_addrs                 ),
    .i_port_wr_length            (i_wr_master_2_lengths               ),
    .i_sdram_clk                 (i_clk                                     ),
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[2]           ),
    .o_sdram_data                (wr_port2_wr_data                    ),
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[2]    ),
    .o_sdram_addrs               (wr_port2_addrs                      ),
    .o_sdram_wr_lengths          (wr_port2_lengths                    ),
    .o_wr_en                     (wr_en[2]                                ),
    .o_force_insert_signal       (wr_force_insert[2]                      )
);
    end
    else begin
        assign wr_en[2]                = 1'b0                         ;
        assign wwr_port2_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;
        assign wr_port2_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;
        assign wr_force_insert[2]      = 1'b0                         ;
    end
endgenerate

// WR_MASTER_INST(3)
generate
    if(USE_WRPORT3_DW == 16)begin
sdram_wr_port #(
    .DATA_DW             (USE_WRPORT3_DW                              ),
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )
)sdram_wr_port_3_inst (
    .i_rst_n                     (sdram_init_done                           ),
    .i_port_wr_clk               (i_wr_master_3_clk                   ),
    .i_port_wr_start             (i_wr_master_3_start                 ),
    .i_port_wr_data              (i_wr_master_3_data                  ),
    .i_port_wr_data_vld          (i_wr_master_3_wen                   ),
    .i_port_wr_addrs             (i_wr_master_3_addrs                 ),
    .i_port_wr_length            (i_wr_master_3_lengths               ),
    .i_sdram_clk                 (i_clk                                     ),
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[3]           ),
    .o_sdram_data                (wr_port3_wr_data                    ),
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[3]    ),
    .o_sdram_addrs               (wr_port3_addrs                      ),
    .o_sdram_wr_lengths          (wr_port3_lengths                    ),
    .o_wr_en                     (wr_en[3]                                ),
    .o_force_insert_signal       (wr_force_insert[3]                      )
);
    end
    else begin
        assign wr_en[3]                = 1'b0                         ;
        assign wwr_port3_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;
        assign wr_port3_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;
        assign wr_force_insert[3]      = 1'b0                         ;
    end
endgenerate

// WR_MASTER_INST(4)
generate
    if(USE_WRPORT4_DW == 16)begin
sdram_wr_port #(
    .DATA_DW             (USE_WRPORT4_DW                              ),
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )
)sdram_wr_port_4_inst (
    .i_rst_n                     (sdram_init_done                           ),
    .i_port_wr_clk               (i_wr_master_4_clk                   ),
    .i_port_wr_start             (i_wr_master_4_start                 ),
    .i_port_wr_data              (i_wr_master_4_data                  ),
    .i_port_wr_data_vld          (i_wr_master_4_wen                   ),
    .i_port_wr_addrs             (i_wr_master_4_addrs                 ),
    .i_port_wr_length            (i_wr_master_4_lengths               ),
    .i_sdram_clk                 (i_clk                                     ),
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[4]           ),
    .o_sdram_data                (wr_port4_wr_data                    ),
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[4]    ),
    .o_sdram_addrs               (wr_port4_addrs                      ),
    .o_sdram_wr_lengths          (wr_port4_lengths                    ),
    .o_wr_en                     (wr_en[4]                                ),
    .o_force_insert_signal       (wr_force_insert[4]                      )
);
    end
    else begin
        assign wr_en[4]                = 1'b0                         ;
        assign wwr_port4_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;
        assign wr_port4_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;
        assign wr_force_insert[4]      = 1'b0                         ;
    end
endgenerate

//SDRAM 读端口
// RD_MASTER_INST(0)
generate
    if(USE_RDPORT0_DW == 16)begin
    sdram_rd_port #(
    .DATA_DW            (USE_RDPORT0_DW       ),
    .OUTPUT_MODE        (USE_RDPORT0_FIFO_MODE),
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE           ),
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE            )
    )sdram_rd_port0_inst (
    .i_rst_n                     (sdram_init_done                                   ),
    .i_port_rd_clk               (i_rd_master_0_clk                           ),
    .i_port_rd_start             (i_rd_master_0_start                         ),
    .o_port_rd_data              (o_rd_master_0_data                          ),
    .o_port_rd_data_vld          (o_rd_master_0_data_vld                      ),
    .i_port_rd_data_req          (i_rd_master_0_req                           ),
    .i_port_rd_addrs             (i_rd_master_0_addrs                         ),
    .i_port_rd_length            (i_rd_master_0_lengths                       ),
    .o_port_rd_data_ready        (o_rd_master_0_data_ready                    ),
    .i_sdram_clk                 (i_clk                                             ),
    .i_sdram_rd_done             (master_rd_wr_done&rd_shift[0]                   ),
    .i_sdram_data                (SDRAM_controller_sdram_rd_data                    ),
    .i_sdram_data_vld            (SDRAM_controller_sdram_rd_data_vld&rd_shift[0]  ),
    .o_sdram_addrs               (rd_port0_addrs                              ),
    .o_sdram_rd_lengths          (rd_port0_lengths                            ),
    .o_rd_en                     (rd_en[0]                                        ),
    .o_force_insert_signal       (rd_force_insert[0]                              )
);
    end
    else begin
    assign    o_rd_master_0_data       =  {USE_RDPORT0_DW{1'b0}}        ;
    assign    o_rd_master_0_data_vld   =  1'b0                                ;
    assign    o_rd_master_0_data_ready =  1'b0                                ;
    assign    rd_port0_addrs           =  {SDRAM_ADDRS_WIDE{1'b0}}            ;
    assign    rd_en[0]                     =  1'b0                                ;
    assign    rd_force_insert[0]           =  1'b0                                ;
    end
endgenerate

// RD_MASTER_INST(1)
generate
    if(USE_RDPORT1_DW == 16)begin
    sdram_rd_port #(
    .DATA_DW            (USE_RDPORT1_DW       ),
    .OUTPUT_MODE        (USE_RDPORT1_FIFO_MODE),
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE           ),
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE            )
    )sdram_rd_port1_inst (
    .i_rst_n                     (sdram_init_done                                   ),
    .i_port_rd_clk               (i_rd_master_1_clk                           ),
    .i_port_rd_start             (i_rd_master_1_start                         ),
    .o_port_rd_data              (o_rd_master_1_data                          ),
    .o_port_rd_data_vld          (o_rd_master_1_data_vld                      ),
    .i_port_rd_data_req          (i_rd_master_1_req                           ),
    .i_port_rd_addrs             (i_rd_master_1_addrs                         ),
    .i_port_rd_length            (i_rd_master_1_lengths                       ),
    .o_port_rd_data_ready        (o_rd_master_1_data_ready                    ),
    .i_sdram_clk                 (i_clk                                             ),
    .i_sdram_rd_done             (master_rd_wr_done&rd_shift[1]                   ),
    .i_sdram_data                (SDRAM_controller_sdram_rd_data                    ),
    .i_sdram_data_vld            (SDRAM_controller_sdram_rd_data_vld&rd_shift[1]  ),
    .o_sdram_addrs               (rd_port1_addrs                              ),
    .o_sdram_rd_lengths          (rd_port1_lengths                            ),
    .o_rd_en                     (rd_en[1]                                        ),
    .o_force_insert_signal       (rd_force_insert[1]                              )
);
    end
    else begin
    assign    o_rd_master_1_data       =  {USE_RDPORT1_DW{1'b0}}        ;
    assign    o_rd_master_1_data_vld   =  1'b0                                ;
    assign    o_rd_master_1_data_ready =  1'b0                                ;
    assign    rd_port1_addrs           =  {SDRAM_ADDRS_WIDE{1'b0}}            ;
    assign    rd_en[1]                     =  1'b0                                ;
    assign    rd_force_insert[1]           =  1'b0                                ;
    end
endgenerate

// RD_MASTER_INST(2)
generate
    if(USE_RDPORT2_DW == 16)begin
    sdram_rd_port #(
    .DATA_DW            (USE_RDPORT2_DW       ),
    .OUTPUT_MODE        (USE_RDPORT2_FIFO_MODE),
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE           ),
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE            )
    )sdram_rd_port2_inst (
    .i_rst_n                     (sdram_init_done                                   ),
    .i_port_rd_clk               (i_rd_master_2_clk                           ),
    .i_port_rd_start             (i_rd_master_2_start                         ),
    .o_port_rd_data              (o_rd_master_2_data                          ),
    .o_port_rd_data_vld          (o_rd_master_2_data_vld                      ),
    .i_port_rd_data_req          (i_rd_master_2_req                           ),
    .i_port_rd_addrs             (i_rd_master_2_addrs                         ),
    .i_port_rd_length            (i_rd_master_2_lengths                       ),
    .o_port_rd_data_ready        (o_rd_master_2_data_ready                    ),
    .i_sdram_clk                 (i_clk                                             ),
    .i_sdram_rd_done             (master_rd_wr_done&rd_shift[2]                   ),
    .i_sdram_data                (SDRAM_controller_sdram_rd_data                    ),
    .i_sdram_data_vld            (SDRAM_controller_sdram_rd_data_vld&rd_shift[2]  ),
    .o_sdram_addrs               (rd_port2_addrs                              ),
    .o_sdram_rd_lengths          (rd_port2_lengths                            ),
    .o_rd_en                     (rd_en[2]                                        ),
    .o_force_insert_signal       (rd_force_insert[2]                              )
);
    end
    else begin
    assign    o_rd_master_2_data       =  {USE_RDPORT2_DW{1'b0}}        ;
    assign    o_rd_master_2_data_vld   =  1'b0                                ;
    assign    o_rd_master_2_data_ready =  1'b0                                ;
    assign    rd_port2_addrs           =  {SDRAM_ADDRS_WIDE{1'b0}}            ;
    assign    rd_en[2]                     =  1'b0                                ;
    assign    rd_force_insert[2]           =  1'b0                                ;
    end
endgenerate

// RD_MASTER_INST(3)
generate
    if(USE_RDPORT3_DW == 16)begin
    sdram_rd_port #(
    .DATA_DW            (USE_RDPORT3_DW       ),
    .OUTPUT_MODE        (USE_RDPORT3_FIFO_MODE),
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE           ),
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE            )
    )sdram_rd_port3_inst (
    .i_rst_n                     (sdram_init_done                                   ),
    .i_port_rd_clk               (i_rd_master_3_clk                           ),
    .i_port_rd_start             (i_rd_master_3_start                         ),
    .o_port_rd_data              (o_rd_master_3_data                          ),
    .o_port_rd_data_vld          (o_rd_master_3_data_vld                      ),
    .i_port_rd_data_req          (i_rd_master_3_req                           ),
    .i_port_rd_addrs             (i_rd_master_3_addrs                         ),
    .i_port_rd_length            (i_rd_master_3_lengths                       ),
    .o_port_rd_data_ready        (o_rd_master_3_data_ready                    ),
    .i_sdram_clk                 (i_clk                                             ),
    .i_sdram_rd_done             (master_rd_wr_done&rd_shift[3]                   ),
    .i_sdram_data                (SDRAM_controller_sdram_rd_data                    ),
    .i_sdram_data_vld            (SDRAM_controller_sdram_rd_data_vld&rd_shift[3]  ),
    .o_sdram_addrs               (rd_port3_addrs                              ),
    .o_sdram_rd_lengths          (rd_port3_lengths                            ),
    .o_rd_en                     (rd_en[3]                                        ),
    .o_force_insert_signal       (rd_force_insert[3]                              )
);
    end
    else begin
    assign    o_rd_master_3_data       =  {USE_RDPORT3_DW{1'b0}}        ;
    assign    o_rd_master_3_data_vld   =  1'b0                                ;
    assign    o_rd_master_3_data_ready =  1'b0                                ;
    assign    rd_port3_addrs           =  {SDRAM_ADDRS_WIDE{1'b0}}            ;
    assign    rd_en[3]                     =  1'b0                                ;
    assign    rd_force_insert[3]           =  1'b0                                ;
    end
endgenerate

always @(negedge i_clk ) begin
    if({o_sdram_init_done,i_SDRAM_controller_sdram_selfrefresh,i_SDRAM_controller_sdram_power_down}  == 3'b100)begin
        sdram_init_done <= 1'b1;
    end
    else begin
        sdram_init_done <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if(sdram_init_done == 1'b0)begin
        {wr_shift,rd_shift} <= 9'h01;
    end
    else if(  ((({wr_shift,rd_shift} & {wr_force_insert,rd_force_insert}) == 9'd0)
            && ({wr_force_insert,rd_force_insert} > 9'd0) 
            && (locked == 1'b0)) 
          ||  ((({wr_shift,rd_shift} & {wr_en,rd_en}) == 9'd0) &&  (locked == 1'b0))
          ||  (master_rd_wr_done == 1'b1))begin
        case ({wr_shift,rd_shift})
            9'h01, 9'h02, 9'h04, 9'h08, 9'h10, 9'h20, 9'h40, 9'h80, 9'h100:
            {wr_shift,rd_shift} <= {wr_shift[3:0],rd_shift,wr_shift[4]};
            default: {wr_shift,rd_shift} <= 9'h01;
        endcase
    end
    else begin
        {wr_shift,rd_shift} <={wr_shift,rd_shift};
    end
end

always @(posedge i_clk ) begin
    if((wr_en == 5'd0) && (master_wr_en == 1'b1))begin
        locked_down <= 1'b1;
    end
    else if(rd_en == 4'd0 && (master_rd_en == 1'b1))begin
        locked_down <= 1'b1;
    end
    else begin
        locked_down <= 1'b0;
    end
end


always @(posedge i_clk ) begin
    if((sdram_init_done == 1'b0) || (locked_down == 1'b1))begin
        locked <= 1'b0;
    end
    else if( (({wr_shift,rd_shift} & {wr_force_insert,rd_force_insert}) == 9'd0)
            && ({wr_force_insert,rd_force_insert} > 9'd0) 
            && (locked == 1'b0))begin
        locked <= locked;
    end
    else if((({wr_shift,rd_shift} & {wr_en,rd_en}) != 9'd0) &&  (locked == 1'b0))begin
        locked <= 1'b1;
    end
    else if(master_rd_wr_done == 1'b1)begin
        locked <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    case ({wr_shift,rd_shift})
    (9'H1<<0): begin master_sdram_addrs      <= rd_port0_addrs      ;
                     master_sdram_rw_lengths <= rd_port0_lengths    ;
    end
    (9'H1<<1): begin master_sdram_addrs      <= rd_port1_addrs      ;
                     master_sdram_rw_lengths <= rd_port1_lengths    ;
    end
    (9'H1<<2): begin master_sdram_addrs      <= rd_port2_addrs      ;
                     master_sdram_rw_lengths <= rd_port2_lengths    ;
    end
    (9'H1<<3): begin master_sdram_addrs      <= rd_port3_addrs      ;
                     master_sdram_rw_lengths <= rd_port3_lengths    ;
    end
    (9'H1<<4): begin master_sdram_addrs      <= wr_port0_addrs      ;
                     master_sdram_rw_lengths <= wr_port0_lengths    ;
    end
    (9'H1<<5): begin master_sdram_addrs      <= wr_port1_addrs      ;
                     master_sdram_rw_lengths <= wr_port1_lengths    ;
    end
    (9'H1<<6): begin master_sdram_addrs      <= wr_port2_addrs      ;
                     master_sdram_rw_lengths <= wr_port2_lengths    ;
    end
    (9'H1<<7): begin master_sdram_addrs      <= wr_port3_addrs      ;
                     master_sdram_rw_lengths <= wr_port3_lengths    ;
    end
    (9'H1<<8): begin master_sdram_addrs      <= wr_port4_addrs      ;
                     master_sdram_rw_lengths <= wr_port4_lengths    ;
    end
        default: begin master_sdram_addrs      <= rd_port0_addrs    ;
                     master_sdram_rw_lengths <= rd_port0_lengths    ;
    end
    endcase
end

always @( * ) begin
    case (wr_shift)
     (9'H1<<0): master_sdram_wr_data <= wr_port0_wr_data;
     (9'H1<<1): master_sdram_wr_data <= wr_port1_wr_data;
     (9'H1<<2): master_sdram_wr_data <= wr_port2_wr_data;
     (9'H1<<3): master_sdram_wr_data <= wr_port3_wr_data;
     (9'H1<<4): master_sdram_wr_data <= wr_port4_wr_data;
     default: master_sdram_wr_data <=   wr_port0_wr_data;
    endcase 
 end

assign master_rd_en = (locked == 1'b1) && (rd_shift > 4'd0);
assign master_wr_en = (locked == 1'b1) && (wr_shift > 4'd0);

//不使用掩码
sdram_rw_master #(
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE)   ,
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE )     
)sdram_rw_master_inst (
    .i_clk               (i_clk                             ),        //input                                   
    .i_sdram_init_done   (sdram_init_done                   ),        //input                                   
    .i_wr_en             (master_wr_en                      ),        //input                                   
    .i_wr_lengths        (master_sdram_rw_lengths           ),        //input          [7:0]                    
    .i_wr_data           (master_sdram_wr_data              ),        //input          [SDRAM_DATA_WIDE-1:0]    
    .o_wr_data_req       (master_sdram_wr_data_req          ),        //output  reg                                                          
    .i_wr_addrs          (master_sdram_addrs                ),        //input          [SDRAM_ADDRS_WIDE-1:0]   
    .i_wr_dqm            (4'd0                              ),        //input          [3:0]                    
    .i_rd_en             (master_rd_en                      ),        //input                                   
    .i_rd_lengths        (master_sdram_rw_lengths           ),        //input          [7:0]                    
    .i_rd_addrs          (master_sdram_addrs                ),        //input          [SDRAM_ADDRS_WIDE-1:0]   
    .i_rd_dqm            (4'd0                              ),        //input          [3:0]                    
    .o_rw_over           (),        //output                                  
    .o_rd_wr_done        (master_rd_wr_done                 ),        //output  reg                                           
    .o_rw_nack           (),        //output  reg                             
    .o_sdram_wr_en_n     (SDRAM_controller_sdram_wr_en_n    ),        //output  reg                             
    .o_sdram_rd_en_n     (SDRAM_controller_sdram_rd_en_n    ),        //output  reg                                 
    .o_sdram_wr_data     (SDRAM_controller_sdram_wr_data    ),        //output         [SDRAM_DATA_WIDE-1:0]    
    .o_sdram_addrs       (SDRAM_controller_sdram_addrs      ),        //output  reg    [SDRAM_ADDRS_WIDE-1:0]   
    .o_sdram_lengths     (SDRAM_controller_sdram_lengths    ),        //output  reg    [7:0]                    
    .o_sdram_dqm         (SDRAM_controller_sdram_dqm        ),        //output  reg    [3:0]                    
    .i_sdram_busy_n      (SDRAM_controller_sdram_busy_n     ),        //input                                   
    .i_sdram_rw_ack      (SDRAM_controller_sdram_rw_ack     )         //input                                      
);

SDRAM_controller SDRAM_controller_inst(
	.O_sdram_clk                            (o_sdram_clk                            ), //output O_sdram_clk
	.O_sdram_cke                            (o_sdram_cke                            ), //output O_sdram_cke
	.O_sdram_cs_n                           (o_sdram_cs_n                           ), //output O_sdram_cs_n
	.O_sdram_cas_n                          (o_sdram_cas_n                          ), //output O_sdram_cas_n
	.O_sdram_ras_n                          (o_sdram_ras_n                          ), //output O_sdram_ras_n
	.O_sdram_wen_n                          (o_sdram_wen_n                          ), //output O_sdram_wen_n
	.O_sdram_dqm                            (o_sdram_dqm                            ), //output [3:0] O_sdram_dqm
	.O_sdram_addr                           (o_sdram_addrs                          ), //output [10:0] O_sdram_addr
	.O_sdram_ba                             (o_sdram_ba                             ), //output [1:0] O_sdram_ba
	.IO_sdram_dq                            (io_sdram_dq                            ), //inout [31:0] IO_sdram_dq
	.I_sdrc_rst_n                           (i_rst_n                                ), //input I_sdrc_rst_n
	.I_sdrc_clk                             (i_clk                                  ), //input I_sdrc_clk
	.I_sdram_clk                            (i_sdram_clk                            ), //input I_sdram_clk
	.I_sdrc_selfrefresh                     (i_SDRAM_controller_sdram_selfrefresh     ), //input I_sdrc_selfrefresh
	.I_sdrc_power_down                      (i_SDRAM_controller_sdram_power_down      ), //input I_sdrc_power_down
	.I_sdrc_wr_n                            (SDRAM_controller_sdram_wr_en_n         ), //input I_sdrc_wr_n
	.I_sdrc_rd_n                            (SDRAM_controller_sdram_rd_en_n         ), //input I_sdrc_rd_n
	.I_sdrc_addr                            (SDRAM_controller_sdram_addrs           ), //input [20:0] I_sdrc_addr
	.I_sdrc_data_len                        (SDRAM_controller_sdram_lengths         ), //input [7:0] I_sdrc_data_len
	.I_sdrc_dqm                             (SDRAM_controller_sdram_dqm             ), //input [3:0] I_sdrc_dqm
	.I_sdrc_data                            (SDRAM_controller_sdram_wr_data         ), //input [31:0] I_sdrc_data
	.O_sdrc_data                            (SDRAM_controller_sdram_rd_data         ), //output [31:0] O_sdrc_data
	.O_sdrc_init_done                       (o_sdram_init_done                      ), //output O_sdrc_init_done
	.O_sdrc_busy_n                          (SDRAM_controller_sdram_busy_n          ), //output O_sdrc_busy_n
	.O_sdrc_rd_valid                        (SDRAM_controller_sdram_rd_data_vld     ), //output O_sdrc_rd_valid
	.O_sdrc_wrd_ack                         (SDRAM_controller_sdram_rw_ack          ) //output O_sdrc_wrd_ack
);

endmodule