module ahb_spi_flash_top (
    //glb
    input               i_clk                     ,
    input               i_rst_n                   ,
    //users
    input               i_mcu_start               ,
    input               i_mcu_dir                 ,
    input    [31:0]     i_mcu_addrs               ,
    input    [31:0]     i_mcu_lengths             ,

    output              o_flash_data_clk          ,
    output              o_flash_wr_data_req       ,
    input               i_flash_wr_data_vld       ,
    input    [15:0]     i_flash_wr_data           ,
    output              o_flash_rd_data_vld       ,
    output   [15:0]     o_flash_rd_data           ,

    output              o_done                    ,
    //flash
    output              o_sck                     ,
    output              o_cs                      ,
    inout               i_miso                    ,
    output              o_mosi                    ,
    //test
    output  [31:0]      flash_id
);

//defs-----------------------------------------
wire flash_start_en; //读写启动
wire [1:0] flash_order;//操作指令 er:0 wr:1 rd:2
wire [31:0] flash_addrs;//读写addrs
wire [31:0] flash_lens; //读写lens
wire flash_idel;//读写结束
wire flash_done;//操作结束
// ahb reg 
wire [31:0] haddr_reg;
wire [31:0] hrdata_reg;
wire       	hreadyin_reg;
wire       	hreadyout_reg;
wire [1:0] 	hresp_reg;
wire       	hsel_reg;
wire [1:0] 	htrans_reg;
wire       	hwrite_reg;
wire [31:0] hwdata_reg;

wire                            fifo_wr_en;             
wire    [31:0]                  fifo_wr_data;  
wire                            fifo_rd_en;             
wire    [15:0]                  fifo_rd_data;
wire                            fifo_rd_empty; 
reg                             fifo_wr_en_ff0;   
wire                            fifo_wr_en_pdge;
assign o_done = flash_done;

//-----------------------------------------
always @(posedge i_clk ) begin
    fifo_wr_en_ff0 <= fifo_wr_en;
end

assign  fifo_wr_en_pdge         = fifo_wr_en & (!fifo_wr_en_ff0);
assign  fifo_rd_en              = !fifo_rd_empty;
assign  o_flash_rd_data_vld     = fifo_wr_en;
assign  o_flash_rd_data         = fifo_wr_data[15:0];
//-----------------------------------------
reg                          flash_wr_en      ;
reg     [15:0]               flash_wr_data_ff0;
wire                         flash_wr_data_vld;
wire     [31:0]              flash_wr_data    ;
always @(posedge i_clk ) begin
    if(i_flash_wr_data_vld)begin
        flash_wr_en          <= ~flash_wr_en;
        flash_wr_data_ff0    <= i_flash_wr_data;
    end
    else begin
        flash_wr_en          <= flash_wr_en;
        flash_wr_data_ff0    <= flash_wr_data_ff0;
    end
end
assign  flash_wr_data_vld   = i_flash_wr_data_vld & flash_wr_en;
assign  flash_wr_data       = {i_flash_wr_data,flash_wr_data_ff0};
// assign  flash_wr_data_vld   = i_flash_wr_data_vld;
// assign  flash_wr_data       = i_flash_wr_data;
//controls-----------------------------------------
ahb_spi_flash_ctrl ahb_spi_flash_ctrl_inst
(
    .i_clk              ( i_clk             ),    
    .i_rst_n            ( i_rst_n           ),
    //user interface
    .i_wr_en            ( i_mcu_dir & i_mcu_start   ),
    .i_rd_en            ( (~i_mcu_dir) & i_mcu_start),
    .i_lens             ( i_mcu_lengths     ),
    .i_addrs            ( i_mcu_addrs       ),
    .o_done             ( flash_done        ),
    //calc into flash params
    .i_flash_on         ( (flash_id != 1'b0)),
    .o_ahb_en           ( flash_start_en    ),
    .o_ahb_order        ( flash_order       ),
    .o_ahb_addrs        ( flash_addrs       ),
    .o_ahb_lens         ( flash_lens        ),
    .i_ahb_idle         ( flash_idel        )
);

//drivers------------------------------------------
//---user--- ahb ctrl
ahb_spi_flash_drv ahb_spi_flash_drv_inst
(
    .clk          ( i_clk               ),//I_clk
    .rst_n        ( i_rst_n             ),
    //user-ctrl
    .i_ctrl_en    ( flash_start_en      ), 
    .i_ctrl_order ( flash_order         ), //er:0 wr:1 rd:2
    .i_flash_addr ( flash_addrs         ), 
    .o_idel       ( flash_idel          ), 
    .i_wr_len     ( flash_lens          ), //rddata是2byte 16位，则长度是偶数;
    
    .o_wr_req     ( o_flash_wr_data_req ), 
    .i_wr_vld     ( flash_wr_data_vld   ), 
    .i_wr_data    ( flash_wr_data       ), 
    .i_rd_len     ( flash_lens          ), 
    .o_rd_vld     ( fifo_wr_en          ), //抓这信号看读flash
    .o_rd_data    ( fifo_wr_data        ), //抓这信号看读flash

    //ahb
    .hsel_reg     (hsel_reg     ),
    .htrans_reg   (htrans_reg   ), //ctrl
    .haddr_reg    (haddr_reg    ), //addr
    .hwrite_reg   (hwrite_reg   ), //dir
    .hwdata_reg   (hwdata_reg   ), //wr-data
    .hrdata_reg   (hrdata_reg   ), //rd-data
    .hreadyin_reg (hreadyin_reg ), //m->s
    .hreadyout_reg(hreadyout_reg), //s->m
    .hresp_reg    (hresp_reg    ), //s->m info
    //test--get the flash_id
    .o_flash_id   ( flash_id    )
);

//---IP--- SPI Nor Flash Controller
SPI_Nor_Flash_Interface_Top SPI_Nor_Flash_Interface_Top_inst
(
    //ahb
    .I_hclk         (i_clk        ),
    .I_hresetn      (i_rst_n      ),
    .I_haddr_reg    (haddr_reg    ),
 	.O_hrdata_reg   (hrdata_reg   ),
 	.I_hreadyin_reg (hreadyin_reg ),
 	.O_hreadyout_reg(hreadyout_reg),
 	.O_hresp_reg    (hresp_reg    ),
 	.I_hsel_reg     (hsel_reg     ),
 	.I_htrans_reg   (htrans_reg   ),
 	.I_hwdata_reg   (hwdata_reg   ),
 	.I_hwrite_reg   (hwrite_reg   ),
    //spi
    .I_spi_clock    (i_clk        ), //input I_spi_clock
    .I_spi_rstn     (i_rst_n      ), //input I_spi_rstn
    //spi-flash io
    .O_flash_ck     ( o_sck       ),
	.O_flash_cs_n   ( o_cs        ),
	.IO_flash_do    ( i_miso      ),
	.IO_flash_di    ( o_mosi      )
);


endmodule //spi_flash_if