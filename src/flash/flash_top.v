module flash_top (
    //glb
    input                           i_clk               ,
    input                           i_rst_n             ,
    //users         
    //trig rd    
    input                           i_mem_busyn         ,       
    input                           i_mcu_en            ,// 
    input   [31:0]                  i_mcu_flash_addrs   ,
    input   [31:0]                  i_mcu_ddr_addrs     ,
    input                           i_mcu_option        ,// 0读flash 1写
    input   [31:0]                  i_mcu_lens          ,
    input   [3:0]                   i_mcu_ctrl_sel      ,// 
    
    output  reg                     o_flash2ddr         ,
    output  reg                     o_ddr2flash         ,
    output  reg                     o_param_load        ,
    output  reg   [15:0]            o_flash_rd_data     ,
    output  reg                     o_flash_rd_data_vld ,    
    output  reg                     o_mem_wr_start      ,
    output  reg   [31:0]            o_mem_wr_addrs      ,
    output  reg   [31:0]            o_mem_wr_lens       ,
    
    input         [15:0]            i_mem_rd_data       ,
    input                           i_mem_rd_data_vld   ,
    output  reg                     o_mem_rd_start      ,
    output  reg   [31:0]            o_mem_rd_addrs      ,
    output  reg   [31:0]            o_mem_rd_lens       ,
    output                          o_data_req          ,

    input         [15:0]            i_param_data        ,
    input                           i_param_data_vld    ,
    //trig wr           
    output  reg                     o_busy          ,
    output                          o_flash_done       ,
    //flash         
    output                          O_flash_ck      ,
    output                          O_flash_cs_n    ,
    inout                           IO_flash_do     ,
    output                          IO_flash_di     ,
    //test          
    output                          flash_id
    
);

//def==========================================
//usr-arb
reg     [1:0]               en_dly                  ;
reg                         rw_sync                 ;
reg     [31:0]              lens_cnt                ;
reg     [15:0]              wait_done_cnt           ;
reg     [15:0]              wait_start_cnt          ;

reg                         flash_start             ;
reg                         flash_dir               ;
reg     [31:0]              flash_addr              ;
reg     [31:0]              flash_lens              ;

wire    [15:0]              flash_wr_data           ;
wire                        flash_wr_data_vld       ;

 wire                       flash_rd_data_vld       ;
 wire    [15:0]             flash_rd_data           ;  
 reg                        flash_rd_data_vld_dly   ; 

///////////////////////////////////////////////
//          写DDR 相关信号
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    o_mem_wr_addrs <= i_mcu_ddr_addrs ;
    o_mem_wr_lens  <= i_mcu_lens      ;
    o_mem_rd_addrs <= i_mcu_ddr_addrs ;
    o_mem_rd_lens  <= i_mcu_lens      ;
end
///////////////////////////////////////////////
/////////写DDR开始
always @(posedge i_clk ) begin
    if((o_flash2ddr == 1'b1) && (rw_sync == 1'b1) && (i_mcu_option == 1'b0))begin
        o_mem_wr_start <= 1'b1;
    end
    else begin
        o_mem_wr_start <= 1'b0;
    end
end
///////////////////////////////////////////////
/////////读DDR开始
always @(posedge i_clk ) begin
    if((o_flash2ddr == 1'b1) && (rw_sync == 1'b1) && (i_mcu_option == 1'b1))begin
        o_mem_rd_start <= 1'b1;
    end
    else begin
        o_mem_rd_start <= 1'b0;
    end
end
///////////////////////////////////////////////
// always @(posedge i_clk ) begin
//     if((o_flash2ddr == 1'b1) && (rw_sync == 1'b1) && (i_mcu_option == 1'b0))begin
//         o_mem_wr_start <= 1'b1;
//     end
//     else begin
//         o_mem_wr_start <= 1'b0;
//     end
// end
///////////////////////////////////////////////
//      操作flash使能
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    en_dly <= {en_dly[0],i_mcu_en};
end


// reg           [4:0]       flash_rd_data_falling_edge_cnt;  
// reg           [31:0]      read_param0_time_cnt;  
// always @(posedge i_clk or negedge i_rst_n) begin
//     if (!i_rst_n) begin
//         read_param0_time_cnt              <= 0;
//         read_param1_time_cnt               <= 0;
//         read_param2_time_cnt               <= 0;
//         flash_rd_data_falling_edge_cnt  <= 0;
//         read_param3_time_cnt                    <= 0;
//     end else begin
        
//         if(en_dly == 2'b01)
//             flash_rd_data_falling_edge_cnt <= flash_rd_data_falling_edge_cnt + 1;
//         else 
//             flash_rd_data_falling_edge_cnt <= flash_rd_data_falling_edge_cnt;
        
//         if(flash_rd_data_falling_edge_cnt <= 6)
//             read_param0_time_cnt <= read_param0_time_cnt + 1;
//         else 
//             read_param0_time_cnt <= read_param0_time_cnt;
//     end
// end
///////////////////////////////////////////////
//      flash使能
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        rw_sync <= 1'b0;
    end
    else if(flash_start == 1'b1)begin
        rw_sync <= 1'b0;
    end
    else if(en_dly == 2'b01)begin
        rw_sync <= 1'b1;
    end
    else begin
        rw_sync <= rw_sync;
    end
end

always @(posedge i_clk ) begin
    if(en_dly == 2'b01)begin
       wait_start_cnt <= 16'd4096;
    end
    else if((rw_sync == 1'b1) && (wait_start_cnt > 16'd0))begin
       wait_start_cnt <= wait_start_cnt - 1'b1;
    end
    else begin
       wait_start_cnt <= 16'd0;
    end
end

always @(posedge i_clk ) begin
    if((rw_sync == 1'b1) && (i_mcu_option == 1'b0))begin
        flash_start <= 1'b1;
    end
    else if((rw_sync == 1'b1) && (i_mcu_option == 1'b1) && (wait_start_cnt == 16'd0))begin
        flash_start <= 1'b1;
    end
    else begin
        flash_start <= 1'b0;
    end
end
///////////////////////////////////////////////
//      flash操作相关信号
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    flash_addr <=  i_mcu_flash_addrs;
    flash_dir  <=  i_mcu_option;
    if(en_dly == 2'b01)    
        flash_lens <=  i_mcu_lens;
    else 
        flash_lens <=  flash_lens;
end
     
///////////////////////////////////////////////
//      读flash 计数
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        lens_cnt <= 32'd0;
    end
    else if(en_dly == 2'b01)begin
        lens_cnt <= i_mcu_lens;
    end
    else if(lens_cnt == 32'd0)begin
        lens_cnt <= lens_cnt;
    end
    else if(o_flash_rd_data_vld == 1'b1 || (flash_wr_data_vld))begin
        lens_cnt <= lens_cnt - 1'b1;
    end
    else begin
        lens_cnt <= lens_cnt;
    end
end
reg             [31:0]  lens_cnt_reg0;
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        lens_cnt_reg0 <= 32'd0;
    end
    else begin
        lens_cnt_reg0 <= lens_cnt;
    end
end
///////////////////////////////////////////////
//      加载参数状态信号
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        o_param_load <= 1'b0;
    end
    else if((lens_cnt == 32'd0) && (o_param_load == 1'b1) )begin
        o_param_load <= 1'b0;
    end
    else if((i_mcu_ctrl_sel == 4'd2) && (en_dly == 2'b01))begin
        o_param_load <= 1'b1;
    end
    else begin
        o_param_load <= o_param_load;
    end
end
///////////////////////////////////////////////
//      flash写ddr状态
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        o_flash2ddr <= 1'b0;
    end
    else if((lens_cnt == 32'd0) && (o_flash2ddr == 1'b1))begin
        o_flash2ddr <= 1'b0;
    end
    else if((i_mcu_ctrl_sel == 4'd1) && (en_dly == 2'b01) && (i_mcu_option == 1'b0))begin
        o_flash2ddr <= 1'b1;
    end
    else begin
        o_flash2ddr <= o_flash2ddr;
    end
end

///////////////////////////////////////////////
//      ddr写flash 状态
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        o_ddr2flash <= 1'b0;
    end
    // else if((lens_cnt == 32'd0) && (o_ddr2flash == 1'b1) )begin
    else if(o_flash_done)begin
        o_ddr2flash <= 1'b0;
    end
    else if((i_mcu_ctrl_sel == 4'd1) && (en_dly == 2'b01) && (i_mcu_option == 1'b1))begin
        o_ddr2flash <= 1'b1;
    end
    else begin
        o_ddr2flash <= o_ddr2flash;
    end
end
///////////////////////////////////////////////
//     flash忙碌状态
///////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(i_mem_busyn == 1'b0)begin
        o_busy <= 1'b1;
    end
    else if(en_dly == 2'b01)begin
        o_busy <= 1'b1;
    end
    else if((o_busy == 1'b1) && (|{o_flash2ddr,o_ddr2flash,o_param_load} == 1'b0))begin
        o_busy <= 1'b0;
    end
    else begin
        o_busy <= o_busy;
    end
end

always @(posedge i_clk ) begin
    flash_rd_data_vld_dly <= flash_rd_data_vld;
end

always @(posedge i_clk ) begin
    // if({flash_rd_data_vld_dly,flash_rd_data_vld} == 2'b01)begin
    if(flash_rd_data_vld)begin
        o_flash_rd_data_vld <= 1'b1;
        o_flash_rd_data     <= flash_rd_data;
    end
    else begin
        o_flash_rd_data_vld <= 1'b0;
        o_flash_rd_data     <= 16'd0;
    end
end

reg     flash_st_idle_ff;
wire    flash_st_idle;
always @(posedge i_clk ) begin
    flash_st_idle_ff <= flash_st_idle;
end
//分通道
assign flash_wr_data     = (o_ddr2flash == 1'b1)? i_mem_rd_data     : i_param_data    ;
assign flash_wr_data_vld = (o_ddr2flash == 1'b1)? i_mem_rd_data_vld : i_param_data_vld;


//-----------------------------------------------------------------
//ahb-spi-flash
ahb_spi_flash_top ahb_spi_flash_top_inst(
    //glb
    .i_clk                      ( i_clk                 ),
    .i_rst_n                    ( i_rst_n               ),

    //ddr
    .i_mcu_start                ( flash_start           ),
    .i_mcu_dir                  ( flash_dir             ),
    .i_mcu_addrs                ( flash_addr            ),
    .i_mcu_lengths              ({flash_lens[30:0],1'b0}),
    
    .o_flash_data_clk           ( ),
    .o_flash_wr_data_req        ( o_data_req            ),
    .i_flash_wr_data_vld        ( flash_wr_data_vld     ),
    .i_flash_wr_data            ( flash_wr_data         ),
    .o_flash_rd_data_vld        ( flash_rd_data_vld     ),
    .o_flash_rd_data            ( flash_rd_data         ),

    .o_done                     ( flash_st_idle         ),
    //flash
    .o_sck                      ( O_flash_ck            ),
    .o_cs                       ( O_flash_cs_n          ),
    .i_miso                     ( IO_flash_do           ),
    .o_mosi                     ( IO_flash_di           ),

    //read-id
    .flash_id                   ( flash_id              )
);
//
assign o_flash_done  = !flash_st_idle_ff & flash_st_idle;
endmodule