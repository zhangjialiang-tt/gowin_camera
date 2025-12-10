module ahb_spi_flash_ctrl(
    input                       i_clk           ,
    input                       i_rst_n         ,
    //user
    input                       i_wr_en         ,
    input                       i_rd_en         ,
    input       [31:0]          i_lens          ,
    input       [31:0]          i_addrs         ,

    output                      o_done          ,
    //ahb
    input                       i_flash_on      , // flash id准备好
    output                      o_ahb_en        , // 触发指令驱动
    output      [1:0]           o_ahb_order     , // 指令方向
    output      [31:0]          o_ahb_addrs     , // 指令地址
    output      [31:0]          o_ahb_lens      , // 指令长度
    input                       i_ahb_idle        // AHB空闲了
);

localparam IDLE         = 9'b000000000; 
localparam FLASH_ER     = 9'b000000001; 
localparam FLASH_WR     = 9'b000000010;
localparam FLASH_RD     = 9'b000000100; 
// localparam FLASH_RD_END      = 9'b000001000;
// localparam FLASH_WR_WAIT     = 9'b000010000; 
// localparam FLASH_WR_START    = 9'b000100000;
// localparam FLASH_WR_ING      = 9'b001000000; 
// localparam FLASH_WR_END      = 9'b010000000; 
// localparam FLASH_RD_WR_END   = 9'b100000000; 
localparam FLASH_ER_BLOCK   = 32'h10000; 
//==========================================================================================
reg [1:0] wr_en_dly      ;
reg [1:0] rd_en_dly      ;
reg [1:0] flash_idle_dly ;
reg [8:0] state_c        ;

//er sector size 0xfff
wire [31:0] erase_start_addr;
wire [31:0] erase_end_addr;
assign erase_start_addr = FLASH_ER_BLOCK == 32'h10000 ? (i_addrs & 32'hFFFF0000) : (i_addrs & 32'hFFFFF000);
assign erase_end_addr = FLASH_ER_BLOCK == 32'h10000 ?  (i_addrs + i_lens) & 32'hFFFF0000 : (i_addrs + i_lens) & 32'hFFFFF000;

//o
reg flash_start_en      ;
reg [1:0] flash_order   ;
reg [31:0] flash_addrs  ;
// reg [31:0] flash_lens   ;
reg busy;

assign o_done       = ~busy;
assign o_ahb_en    = flash_start_en ;
assign o_ahb_order = flash_order    ;
assign o_ahb_addrs = flash_addrs    ;
assign o_ahb_lens  = i_lens         ;

//==========================================================================================
always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        wr_en_dly <= 1'b0;
    end else begin
        wr_en_dly <= {wr_en_dly[0],i_wr_en};
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        rd_en_dly <= 1'b0;
    end else begin
        rd_en_dly <= {rd_en_dly[0],i_rd_en};
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        flash_idle_dly <= 1'b0;
    end else begin
        flash_idle_dly <= {flash_idle_dly[0],i_ahb_idle};
    end
end

// AHB Machine
always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        flash_start_en <= 1'b0;
        busy <= 1'b0;
        state_c <= IDLE;
    end
    else begin
        case (state_c)
            IDLE : begin
                if(wr_en_dly == 2'b01)begin
                    flash_addrs <= erase_start_addr;
                    flash_order <= 2'd0;
                    flash_start_en <= 1'b1;
                    busy <= 1'b1;
                    state_c <= FLASH_ER;
                end
                else if(rd_en_dly == 2'b01)begin
                    flash_addrs <= i_addrs;
                    flash_order <= 2'd2;
                    flash_start_en <= 1'b1;
                    busy <= 1'b1;
                    state_c <= FLASH_RD;
                end
                else begin
                    flash_start_en <= 1'b0;
                    busy <= 1'b0;
                    state_c <= IDLE;
                end
            end

            FLASH_ER : begin
                if(2'b01 == flash_idle_dly) begin
                    if(flash_addrs < erase_end_addr) begin
                        flash_addrs <= flash_addrs + FLASH_ER_BLOCK;
                        flash_order <= 2'd0;
                        flash_start_en <= 1'b1;
                        state_c <= FLASH_ER;
                    end else begin
                        flash_addrs <= i_addrs;
                        flash_order <= 2'd1;
                        flash_start_en <= 1'b1;
                        state_c <= FLASH_WR;
                    end
                end else begin
                    flash_start_en <= 1'b0;
                    state_c <= FLASH_ER;
                end
            end

            FLASH_WR : begin
                if(2'b01 == flash_idle_dly) begin
                    flash_start_en <= 1'b0;
                    busy <= 1'b0;
                    state_c <= IDLE;
                end else begin
                    flash_start_en <= 1'b0;
                    state_c <= FLASH_WR;
                end
            end
            
            FLASH_RD : begin
                if(2'b01 == flash_idle_dly) begin
                    // if(flash_addrs < i_addrs + i_lens) begin
                    //     flash_addrs <= flash_addrs + 1'b1;
                    //     flash_order <= 2'd2;
                    //     flash_start_en <= 1'b1;
                    //     state_c <= FLASH_RD;
                    // end else begin
                    //     flash_start_en <= 1'b0;
                    //     busy <= 1'b0;
                    //     state_c <= IDLE;
                    // end
                    flash_start_en <= 1'b0;
                    busy <= 1'b0;
                    state_c <= IDLE;
                end else begin
                    flash_start_en <= 1'b0;
                    state_c <= FLASH_RD;
                end
            end

            default: state_c <= IDLE;

        endcase
    end
end

endmodule