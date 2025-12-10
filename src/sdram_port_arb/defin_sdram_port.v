`ifndef _DEFINE_SDRAM_PORT_V_
`define _DEFINE_SDRAM_PORT_V_


//  \字符后面不能有空格

`define WR_SETTING(NUM, DW )                               \
    .USE_WRPORT``NUM``_DW    ``(DW    )                   

`define RD_SETTING(NUM, DW,FIFO_MODE)                       \
    .USE_RDPORT``NUM``_DW    ``(DW     ),                    \
    .USE_RDPORT``NUM``_FIFO_MODE ``(FIFO_MODE  )       



`define WR_MASTER_INST(NUM)                                                                             \
generate                                                                                                \
    if(USE_WRPORT``NUM``_DW == 16)begin                                                                 \
sdram_wr_port #(                                                                                        \
    .DATA_DW             (USE_WRPORT``NUM``_DW                              ),                          \
    .SDRAM_ADDRS_WIDE    (SDRAM_ADDRS_WIDE                                  ),                          \
    .SDRAM_DATA_WIDE     (SDRAM_DATA_WIDE                                   )                           \
)sdram_wr_port_``NUM``_inst (                                                                           \
    .i_rst_n                     (sdram_init_done                           ),                          \
    .i_port_wr_clk               (i_wr_master_``NUM``_clk                   ),                          \
    .i_port_wr_start             (i_wr_master_``NUM``_start                 ),                          \
    .i_port_wr_data              (i_wr_master_``NUM``_data                  ),                          \
    .i_port_wr_data_vld          (i_wr_master_``NUM``_wen                   ),                          \
    .i_port_wr_addrs             (i_wr_master_``NUM``_addrs                 ),                          \
    .i_port_wr_length            (i_wr_master_``NUM``_lengths               ),                          \
    .i_sdram_clk                 (i_clk                                     ),                          \
    .i_sdram_rd_done             (master_rd_wr_done&wr_shift[NUM]           ),                          \
    .o_sdram_data                (wr_port``NUM``_wr_data                    ),                          \
    .i_sdram_data_req            (master_sdram_wr_data_req&wr_shift[NUM]    ),                          \
    .o_sdram_addrs               (wr_port``NUM``_addrs                      ),                          \
    .o_sdram_wr_lengths          (wr_port``NUM``_lengths                    ),                          \
    .o_wr_en                     (wr_en[NUM]                                ),                          \
    .o_force_insert_signal       (wr_force_insert[NUM]                      )                           \
);                                                                                                      \
    end                                                                                                 \
    else begin                                                                                          \
        assign wr_en[NUM]                = 1'b0                         ;                               \
        assign wwr_port``NUM``_addrs     = {SDRAM_ADDRS_WIDE{1'b0}}     ;                               \
        assign wr_port``NUM``_wr_data    = {SDRAM_DATA_WIDE{1'b0}}      ;                               \
        assign wr_force_insert[NUM]      = 1'b0                         ;                               \
    end                                                                                                 \
endgenerate                                                                                           


`define RD_MASTER_INST(NUM)                                                                             \
generate                                                                                                \
    if(USE_RDPORT``NUM``_DW == 16)begin                                                                 \
    sdram_rd_port #(                                                                                    \
    .DATA_DW            (USE_RDPORT``NUM``_DW       ),                                                  \
    .OUTPUT_MODE        (USE_RDPORT``NUM``_FIFO_MODE),                                                  \
    .SDRAM_ADDRS_WIDE   (SDRAM_ADDRS_WIDE           ),                                                  \
    .SDRAM_DATA_WIDE    (SDRAM_DATA_WIDE            )                                                   \
    )sdram_rd_port``NUM``_inst (                                                                        \
    .i_rst_n                     (sdram_init_done                                   ),                  \
    .i_port_rd_clk               (i_rd_master_``NUM``_clk                           ),                  \
    .i_port_rd_start             (i_rd_master_``NUM``_start                         ),                  \
    .o_port_rd_data              (o_rd_master_``NUM``_data                          ),                  \
    .o_port_rd_data_vld          (o_rd_master_``NUM``_data_vld                      ),                  \
    .i_port_rd_data_req          (i_rd_master_``NUM``_req                           ),                  \
    .i_port_rd_addrs             (i_rd_master_``NUM``_addrs                         ),                  \
    .i_port_rd_length            (i_rd_master_``NUM``_lengths                       ),                  \
    .o_port_rd_data_ready        (o_rd_master_``NUM``_data_ready                    ),                  \
    .i_sdram_clk                 (i_clk                                             ),                  \
    .i_sdram_rd_done             (master_rd_wr_done&rd_shift[NUM]                   ),                  \
    .i_sdram_data                (SDRAM_controller_sdram_rd_data                    ),                  \
    .i_sdram_data_vld            (SDRAM_controller_sdram_rd_data_vld&rd_shift[NUM]  ),                  \
    .o_sdram_addrs               (rd_port``NUM``_addrs                              ),                  \
    .o_sdram_rd_lengths          (rd_port``NUM``_lengths                            ),                  \
    .o_rd_en                     (rd_en[NUM]                                        ),                  \
    .o_force_insert_signal       (rd_force_insert[NUM]                              )                   \
);                                                                                                      \
    end                                                                                                 \
    else begin                                                                                          \
    assign    o_rd_master_``NUM``_data       =  {USE_RDPORT``NUM``_DW{1'b0}}        ;                   \
    assign    o_rd_master_``NUM``_data_vld   =  1'b0                                ;                   \
    assign    o_rd_master_``NUM``_data_ready =  1'b0                                ;                   \
    assign    rd_port``NUM``_addrs           =  {SDRAM_ADDRS_WIDE{1'b0}}            ;                   \
    assign    rd_en[NUM]                     =  1'b0                                ;                   \
    assign    rd_force_insert[NUM]           =  1'b0                                ;                   \
    end                                                                                                 \
endgenerate                                                                                               

`endif 
