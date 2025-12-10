
//According to IP parameters to choose

`define SCLKDIV_DEFAULT 8'd255 // if SPI Clock Divider = 0
//`define SCLKDIV_DEFAULT 8'd0 // if SPI Clock Divider = 1
//`define SCLKDIV_DEFAULT 8'd1 // if SPI Clock Divider = 2
//......
//`define SCLKDIV_DEFAULT n-1 // if SPI Clock Divider = n


module ahb_spi_flash_drv
(
	input             clk          ,
	input             rst_n        ,
	//user-ctrl
    input             i_ctrl_en    , 
    input   [1:0]     i_ctrl_order , 
    input   [31:0]    i_flash_addr , 
	output            o_idel       ,
	//写flash 
    input   [31:0]    i_wr_len     , 
    output            o_wr_req     , 
	input   	      i_wr_vld     , 
    input   [31:0]    i_wr_data    , 
	//读flash
    input   [31:0]    i_rd_len     , 
    output            o_rd_vld     , 
    output  [31:0]    o_rd_data    , 
    //ahb
	output            hsel_reg     ,//1:select 
	output reg  [1:0] htrans_reg   ,//transfer type, NSEQ 10, SEQ 11, IDLE 00, BUSY 01
	output reg [31:0] haddr_reg    ,//AHB address
	output reg        hwrite_reg   ,//1:write,  0:read
	output reg [31:0] hwdata_reg   ,//AHB write data
	input      [31:0] hrdata_reg   ,//AHB read data
	output            hreadyin_reg ,//master answer to slave
	input             hreadyout_reg,//answer from slave
	input       [1:0] hresp_reg    ,//slave transfer response,OKAY, ERROR, RETRY, SPLIT
	//test-window
    output	   [31:0] o_flash_id   
);

//===================== MACHINE STATE =======================================================
localparam	IDLE                 =  5'd00; 
localparam	SET_TRANS_FMT        =  5'd01;

localparam	RDID_SET_CTRL        =  5'd02; //Read Identification
localparam	RDID_SET_CMD         =  5'd03;
localparam	RDID_GET_READ_DATA   =  5'd04;

localparam	SE_WREN_SET_CTRL     =  5'd05; //Sector Erase
localparam	SE_WREN_SET_CMD      =  5'd06; 
localparam	SE_SET_TRANS_CTRL    =  5'd07; 
localparam	SE_SET_ADDR          =  5'd08;  
localparam	SE_SET_CMD           =  5'd09;  

localparam	WR_WAIT_RDY          =  5'd10;   
localparam	WR_WREN_SET_CTRL     =  5'd11; //write
localparam	WR_WREN_SET_CMD      =  5'd12; 
localparam	WR_SET_CTRL          =  5'd13; 
localparam	WR_SET_DATA          =  5'd14; 	
localparam	WR_SET_ADDR          =  5'd15;
localparam	WR_SET_CMD           =  5'd16;

localparam	RD_WAIT_RDY          =  5'd17;  
localparam	RD_SET_CTRL          =  5'd18; //read	
localparam	RD_SET_RST           =  5'd19; 	
localparam	RD_SET_ADDR          =  5'd20;
localparam	RD_SET_CMD           =  5'd21;
localparam	RD_GET_READ_DATA     =  5'd22;

localparam	SPI_CTRL_IDLE        =  5'd23;

//---------------- SPI ORDER -------------------------
localparam	SPI_ER     =  2'd0;
localparam	SPI_WR     =  2'd1;
localparam	SPI_RD     =  2'd2;
//----------------- flash 硬件特性，保持时间-------------------------------------

parameter WN = (`SCLKDIV_DEFAULT==8'hff) ? 1 : ((`SCLKDIV_DEFAULT+1)*2);
//30M
	// localparam	SE_CMD_TIME        =  32'd6_000_000*WN;//30MHz, 200ms
	// localparam	WREN_CMD_TIME      =  12'd38*WN;
	// localparam	WR_CMD_TIME        =  16'd3600*WN; //50MHz, 6000->120us  //25MHz, 3000->120us
	// localparam	RD_CMD_TIME        =  12'd153*WN;

    // localparam	SE_CMD_TIME        =  32'd9_000_000*WN;//30MHz, 200ms
    // localparam	WREN_CMD_TIME      =  12'd38*WN;
    // localparam	WR_CMD_TIME        =  16'd3750*WN; //50MHz, 6000->120us  //25MHz, 3000->120us
    // localparam	RD_CMD_TIME        =  12'd153*WN;
//50m
    // localparam	SE_CMD_TIME        =  32'd10_000_000*WN;//50MHz, 10000000->200ms
    // localparam	WREN_CMD_TIME      =  12'd63*WN;
    // localparam	WR_CMD_TIME        =  16'd6000*WN; //50MHz, 6000->120us  //25MHz, 3000->120us
    // localparam	RD_CMD_TIME        =  12'd255*WN;
//50m
	localparam	SE_CMD_TIME        =  32'd12_000_000*WN;//30MHz, 200ms
	localparam	WREN_CMD_TIME      =  12'd72*WN;
	localparam	WR_CMD_TIME        =  16'd7200*WN; //50MHz, 6000->120us  //25MHz, 3000->120us
	localparam	RD_CMD_TIME        =  12'd306*WN;
//===================== FLASH ADDR ============================================
// One block max address is 00FFFFH
// One sector max address is 000FFFH
    localparam  CHECK_MAX_ADDRESS    =  32'h0000_00dd;

// Because bitstream occupies 896Kbytes Flash space
// user opreation address offset	
	localparam  OFFSET_ADDRESS       =  32'h000E_0000;

	localparam  WR_DATA_BYTES       	 =  32;
	localparam  RD_DATA_BYTES       	 =  64;
	localparam  FLASH_WR_CTRL_REG_DATA   =  32'h6101_F000;//32'h610x_x000 ((8'hxx + 1 )代表一次传输几个字节，超过4个byte就增加WR_SET_DATA传输时钟)
//===================== REGS & WIRES ==========================================
//machine
reg  [31:0] wr_addr_reg;
reg  [31:0] rd_addr_reg;

reg  [4:0]  current_state;
reg  [4:0]  next_state;

reg  [7:0]  cnt;

reg  [31:0] se_cmd_cnt;
reg  [11:0] wren_cmd_cnt;
reg  [15:0] wr_cmd_cnt;
reg  [11:0] rd_cmd_cnt;

//start
reg ctrl_en_pos_state;
//wr
reg wr_req;
reg wr_vld_sync;
reg [31:0] wr_data_reg;
reg wr_done;
//rd
reg  [31:0] rd_flash_id;
reg         rd_vld;
reg  [31:0] rd_data;
reg rd_done;
reg		[4:0]				data_bytes_cnt;
wire	[4:0]				flash_rd_burst_length;
wire	[4:0]				flash_wr_burst_length;
assign flash_rd_burst_length 		= (RD_DATA_BYTES>>2)-1;
assign flash_wr_burst_length 		= (WR_DATA_BYTES>>2)-1;
// wr
assign o_wr_req = wr_req;
// flash read
assign o_flash_id 	= rd_flash_id;
assign o_rd_data 	= rd_data;
assign o_rd_vld 	= rd_vld;

//ahb
assign hsel_reg  = 1'b1;
assign hreadyin_reg = 1'b1;

//==================== DETECT EN POSEDGE =====================================
//posedge enable spi ctrl
wire ctrl_en_pos;
reg ctrl_en_d1;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		ctrl_en_d1 <= 8'd0;
	else begin
		ctrl_en_d1 <= i_ctrl_en;
    end
end
assign ctrl_en_pos = i_ctrl_en & (!ctrl_en_d1);

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		ctrl_en_pos_state <= 1'b0;
	else if(ctrl_en_pos)
		ctrl_en_pos_state <= 1'b1;
    else if(current_state != SPI_CTRL_IDLE)
        ctrl_en_pos_state <= 1'b0;
	else
		ctrl_en_pos_state <= ctrl_en_pos_state;
end

//==================== OPERATION END SIG ==========================================
assign o_idel = (current_state == SPI_CTRL_IDLE);

//==================== CREAT WR REQUIRE SIGNAL =====================================
// pullup req for 1 clk after ctrl order sent
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_req <= 1'b0;
	// else if((current_state == WR_SET_CTRL) && (cnt == 2)) begin
	// else if((current_state == WR_SET_CTRL && (cnt == 1 || cnt == 2)) || (current_state == WR_SET_DATA && (cnt == 6 || cnt == 7)) ) begin
	else if((current_state == WR_SET_CTRL || (current_state == WR_SET_DATA && (data_bytes_cnt < flash_wr_burst_length))) && (cnt == 3 || cnt == 4) ) begin
		wr_req <= 1'b1;
    end else begin
		wr_req <= 1'b0;
    end
end

//==================== CATCH WR VLD DATA =====================================
// pullup req for 1 clk after ctrl order sent
reg wr_vld_dly;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin
		wr_vld_dly <= 1'b0;
    end else begin
		wr_vld_dly <= i_wr_vld;
    end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_data_reg <= 32'b0;
	// else if(i_wr_vld & (~wr_vld_dly)) begin
	// else if(i_wr_vld & (current_state == WR_SET_CTRL)) begin
	else if(i_wr_vld & (current_state == WR_SET_CTRL || current_state == WR_SET_DATA)) begin
		wr_data_reg <= i_wr_data;
    end else begin
		wr_data_reg <= wr_data_reg;
    end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_vld_sync <= 1'b0;
	else if(i_wr_vld & (~wr_vld_dly)) begin
		wr_vld_sync <= 1'b1;
    end else if(current_state == WR_SET_DATA) begin
		wr_vld_sync <= 1'b0;
    end
end

//====================WR & RD LOOP ADDR SHIFT===================================================
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_addr_reg <= OFFSET_ADDRESS;
	else if(current_state == SPI_CTRL_IDLE)
		wr_addr_reg <= i_flash_addr;
	else if(current_state == WR_SET_CMD && wr_cmd_cnt == WR_CMD_TIME)
		wr_addr_reg <= wr_addr_reg + WR_DATA_BYTES;
		// wr_addr_reg <= wr_addr_reg + 5'd2;
	else
		wr_addr_reg <= wr_addr_reg;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rd_addr_reg <= OFFSET_ADDRESS;
	else if(current_state == SPI_CTRL_IDLE)
		rd_addr_reg <= i_flash_addr;
	else if(current_state == RD_GET_READ_DATA && cnt == 8'd7)
		rd_addr_reg <= rd_addr_reg + 5'd4;
	else
		rd_addr_reg <= rd_addr_reg;
end

//==================== CMD CNT ===================================================
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cnt <= 8'd0;
	else if(hreadyout_reg)
		begin
			if(cnt == 8'd7)
				cnt <= 8'd0;
			else if(current_state == RDID_SET_CMD ||
                    current_state == RD_SET_CMD || 
			        current_state == WR_SET_CMD || 
					current_state == WR_WREN_SET_CMD || 
					current_state == SE_WREN_SET_CMD || current_state == SE_SET_CMD)
				cnt <= 8'd0;
			else
				cnt <= cnt + 1'b1;
		end
	else
		cnt <= cnt;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rd_cmd_cnt <= 12'd0;
	else if(current_state == RDID_SET_CMD ||
            current_state == RD_SET_CMD)
		begin
			if(rd_cmd_cnt >= RD_CMD_TIME)
				rd_cmd_cnt <= RD_CMD_TIME;
			else if(hreadyout_reg)
				rd_cmd_cnt <= rd_cmd_cnt + 1'b1;
			else
				rd_cmd_cnt <= rd_cmd_cnt;
		end
	else
		rd_cmd_cnt <= 12'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wr_cmd_cnt <= 16'd0;
	else if(current_state == WR_SET_CMD)
		begin
			if(wr_cmd_cnt >= WR_CMD_TIME)
				wr_cmd_cnt <= WR_CMD_TIME;
			else if(hreadyout_reg)
				wr_cmd_cnt <= wr_cmd_cnt + 1'b1;
			else
				wr_cmd_cnt <= wr_cmd_cnt;
		end
	else
		wr_cmd_cnt <= 16'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		wren_cmd_cnt <= 12'd0;
	else if(current_state == WR_WREN_SET_CMD ||
			current_state == SE_WREN_SET_CMD)
		begin
			if(wren_cmd_cnt >= WREN_CMD_TIME)
				wren_cmd_cnt <= WREN_CMD_TIME;
			else if(hreadyout_reg)
				wren_cmd_cnt <= wren_cmd_cnt + 1'b1;
			else
				wren_cmd_cnt <= wren_cmd_cnt;
		end
	else
		wren_cmd_cnt <= 12'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		se_cmd_cnt <= 32'd0;
	else if(current_state == SE_SET_CMD)
		begin
			if(se_cmd_cnt >= SE_CMD_TIME)
				se_cmd_cnt <= SE_CMD_TIME;
			else if(hreadyout_reg)
				se_cmd_cnt <= se_cmd_cnt + 1'b1;
			else
				se_cmd_cnt <= se_cmd_cnt;
		end
	else
		se_cmd_cnt <= 32'd0;
end

//=======================================================================
//FSM Control
//-----------------------------------------------
//(1)State change
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		current_state  <= IDLE;
	else
		current_state  <= next_state;
end

//-----------------------------------------------
//(2)State change condition
always@(*)
begin
	if(!rst_n)
		next_state  <= IDLE;
	else
		begin
			case(current_state)
				IDLE:
					begin
						if(cnt == 8'd7) 
							next_state <= SET_TRANS_FMT;
						else
							next_state <= IDLE;
					end
				SET_TRANS_FMT: 
					begin
						if(cnt == 8'd7)
							next_state <= RDID_SET_CTRL;
						else
							next_state <= SET_TRANS_FMT;
					end
				
                RDID_SET_CTRL: //Read Identification start
					begin
						if(cnt == 8'd7)
							next_state <= RDID_SET_CMD;
						else
							next_state <= RDID_SET_CTRL;
					end
				RDID_SET_CMD:
					begin
						if(rd_cmd_cnt == RD_CMD_TIME)
							next_state <= RDID_GET_READ_DATA;
						else
							next_state <= RDID_SET_CMD;
					end
				RDID_GET_READ_DATA:
					begin
						if(cnt == 8'd7)
							next_state <= SPI_CTRL_IDLE;
						else
							next_state <= RDID_GET_READ_DATA;
					end    
                SPI_CTRL_IDLE:
                    begin
                        if((cnt == 8'd7) && ctrl_en_pos_state) begin
                            if(SPI_ER == i_ctrl_order) // 擦flash
                                next_state <= SE_WREN_SET_CTRL;
                            else if(SPI_WR == i_ctrl_order) // 写flash
                                next_state <= WR_WAIT_RDY;
                            else if(SPI_RD == i_ctrl_order) // 读flash
                                next_state <= RD_WAIT_RDY;
                            else
                                next_state <= SPI_CTRL_IDLE;
						end else begin
							next_state <= SPI_CTRL_IDLE;
						end
                    end
                
                //ER
				SE_WREN_SET_CTRL: //Sector Erase start
					begin
						if(cnt == 8'd7)
							next_state <= SE_WREN_SET_CMD;
						else
							next_state <= SE_WREN_SET_CTRL;
					end
				SE_WREN_SET_CMD:
					begin
						if(wren_cmd_cnt == WREN_CMD_TIME)
							next_state <= SE_SET_TRANS_CTRL;
						else
							next_state <= SE_WREN_SET_CMD;
					end
				SE_SET_TRANS_CTRL:
					begin
						if(cnt == 8'd7)
							next_state <= SE_SET_ADDR;
						else
							next_state <= SE_SET_TRANS_CTRL;
					end
				SE_SET_ADDR:
					begin
						if(cnt == 8'd7)
							next_state <= SE_SET_CMD;
						else
							next_state <= SE_SET_ADDR;
					end
				SE_SET_CMD:
					begin
						if(se_cmd_cnt == SE_CMD_TIME)
							next_state <= SPI_CTRL_IDLE;
						else
							next_state <= SE_SET_CMD;
					end
                    
				//WR-LOOP
				WR_WAIT_RDY: 
					begin
						if(cnt == 8'd7 && wr_addr_reg<=(i_flash_addr + i_wr_len)) begin
							next_state <= WR_WREN_SET_CTRL;
                        end
						else if(cnt == 8'd7 && wr_addr_reg>(i_flash_addr + i_wr_len))
							next_state <= SPI_CTRL_IDLE;
						else
							next_state <= WR_WAIT_RDY;
					end
				WR_WREN_SET_CTRL: //write start
					begin
						if(cnt == 8'd7)
							next_state <= WR_WREN_SET_CMD;
						else
							next_state <= WR_WREN_SET_CTRL;
					end
				WR_WREN_SET_CMD:
					begin
						if(wren_cmd_cnt == WREN_CMD_TIME)
							next_state <= WR_SET_CTRL;
						else
							next_state <= WR_WREN_SET_CMD;
					end	
				WR_SET_CTRL:
					begin
						if((wr_vld_sync) && (cnt == 8'd7))
							next_state <= WR_SET_DATA;
						else
							next_state <= WR_SET_CTRL;
					end
				WR_SET_DATA:
					begin
						// if(cnt == 8'd7)
						if(cnt == 8'd7 && (data_bytes_cnt == flash_wr_burst_length))
							next_state <= WR_SET_ADDR;
						else
							next_state <= WR_SET_DATA;
					end
				WR_SET_ADDR:
					begin
						if(cnt == 8'd7)
							next_state <= WR_SET_CMD;
						else
							next_state <= WR_SET_ADDR;
					end
				WR_SET_CMD:
					begin
						if(wr_cmd_cnt == WR_CMD_TIME)
							next_state <= WR_WAIT_RDY;//RD_SET_CTRL;//WR_WAIT_RDY 
						else
							next_state <= WR_SET_CMD;
					end
					
				//RD-LOOP
				RD_WAIT_RDY: 
					begin
						if(cnt == 8'd7 && rd_addr_reg<=(i_flash_addr + i_rd_len))
							next_state <= RD_SET_CTRL;
						else if(cnt == 8'd7 && rd_addr_reg>(i_flash_addr + i_rd_len))
							next_state <= SPI_CTRL_IDLE;
						else
							next_state <= RD_WAIT_RDY;
					end
				RD_SET_CTRL: //read start
					begin
						if(cnt == 8'd7)
							next_state <= RD_SET_ADDR;
						else
							next_state <= RD_SET_CTRL;
					end
				RD_SET_ADDR:
					begin
						if(cnt == 8'd7)
							next_state <= RD_SET_CMD;
						else
							next_state <= RD_SET_ADDR;
					end
				RD_SET_CMD:
					begin
						if(rd_cmd_cnt == RD_CMD_TIME)
							next_state <= RD_GET_READ_DATA;
						else
							next_state <= RD_SET_CMD;
					end
				RD_GET_READ_DATA:
					begin
						if(cnt == 8'd7 && (data_bytes_cnt == flash_rd_burst_length))
							next_state <= RD_WAIT_RDY;
						else
							next_state <= RD_GET_READ_DATA;
					end
				
				default:
					begin
						next_state <= IDLE;
					end
			endcase
		end
end

//-----------------------------------------------
//(3)State output
always@(posedge clk or negedge rst_n)//(*)
begin
	if(!rst_n)
		begin
			htrans_reg       <= 2'b00          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
			haddr_reg        <= 32'h0000_0000  ;
			hwrite_reg       <= 1'b0           ;//1:write,  0:read
			hwdata_reg       <= 32'h0000_0000  ;
		end
	else
		begin
			case(next_state)//如将 next_state 改为 current_state，会使输出延时1拍/////
				IDLE:
					begin
						htrans_reg       <= 2'b00          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
						haddr_reg        <= 32'h0000_0000  ;
						hwrite_reg       <= 1'b0           ;//1:write,  0:read
						hwdata_reg       <= 32'h0000_0000  ;
					end
				
				SET_TRANS_FMT: 
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0010  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0002_0780  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				
                RDID_SET_CTRL: //read Identification
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h4200_0002  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RDID_SET_CMD:
					begin
						if(rd_cmd_cnt==12'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(rd_cmd_cnt==12'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_009F  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RDID_GET_READ_DATA:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_002C  ;
								hwrite_reg       <= 1'b0           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
                
				SE_WREN_SET_CTRL:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h4700_0000  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				SE_WREN_SET_CMD:
					begin
						if(wren_cmd_cnt==12'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(wren_cmd_cnt==12'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0006  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end	
				SE_SET_TRANS_CTRL:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h6700_0000  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end	
				SE_SET_ADDR:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0028  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= wr_addr_reg    ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				SE_SET_CMD:
					begin
						if(se_cmd_cnt==32'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(se_cmd_cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								// hwdata_reg       <= 32'h0000_0020  ;//4kB
								// hwdata_reg       <= 32'h0000_0052  ;//32kB
								hwdata_reg       <= 32'h0000_00d8  ;//64kB
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
					
					
					
				WR_WAIT_RDY:
					begin
						htrans_reg       <= 2'b00          ;
						haddr_reg        <= 32'h0000_0000  ;
						hwrite_reg       <= 1'b0           ;
						hwdata_reg       <= 32'h0000_0000  ;
					end
				WR_WREN_SET_CTRL:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h4700_0000  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				WR_WREN_SET_CMD:
					begin
						if(wren_cmd_cnt==12'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(wren_cmd_cnt==12'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0006  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				WR_SET_CTRL:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								// hwdata_reg       <= 32'h6100_1000  ; //32'h610x_x000 ((8'hxx + 1 )代表一次传输几个字节，超过4个byte就增加WR_SET_DATA传输时钟)
								// hwdata_reg       <= 32'h6100_7000  ;
								hwdata_reg       <= FLASH_WR_CTRL_REG_DATA  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				WR_SET_DATA:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_002C  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= wr_data_reg    ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				WR_SET_ADDR:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0028  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= wr_addr_reg    ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				WR_SET_CMD:
					begin
						if(wr_cmd_cnt==16'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(wr_cmd_cnt==16'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0002  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				
				
				
				RD_WAIT_RDY:
					begin
						htrans_reg       <= 2'b00          ;
						haddr_reg        <= 32'h0000_0000  ;
						hwrite_reg       <= 1'b0           ;
						hwdata_reg       <= 32'h0000_0000  ;
					end
				RD_SET_CTRL: //read
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0020  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h6200_003f  ;
								// hwdata_reg       <= 32'h6200_0007  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RD_SET_RST: //read
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0030  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0002  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RD_SET_ADDR:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0028  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(cnt==8'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= rd_addr_reg    ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RD_SET_CMD:
					begin
						if(rd_cmd_cnt==12'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_0024  ;
								hwrite_reg       <= 1'b1           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else if(rd_cmd_cnt==12'd2)
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0003  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
				RD_GET_READ_DATA:
					begin
						if(cnt==8'd1)
							begin
								htrans_reg       <= 2'b10          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
								haddr_reg        <= 32'h0000_002C  ;
								hwrite_reg       <= 1'b0           ;//1:write,  0:read
								hwdata_reg       <= 32'h0000_0000  ;
							end
						else
							begin
								htrans_reg       <= 2'b00          ;
								haddr_reg        <= 32'h0000_0000  ;
								hwrite_reg       <= 1'b0           ;
								hwdata_reg       <= 32'h0000_0000  ;
							end
					end
					
				
				default:
					begin
						htrans_reg       <= 2'b00          ;//NSEQ 10, SEQ 11, IDLE 00, BUSY 01
						haddr_reg        <= 32'h0000_0000  ;
						hwrite_reg       <= 1'b0           ;//1:write,  0:read
						hwdata_reg       <= 32'h0000_0000  ;
					end
			endcase
		end
end

//read data
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) begin
        rd_vld          <= 1'b0;
        rd_flash_id     <= 32'd0;
		rd_data         <= 32'h0000_0000  ;
    end else begin
        case(next_state)//如将 next_state 改为 current_state，会使输出延时1拍///// 
            RDID_GET_READ_DATA:
                begin
                    if(cnt==8'd4) begin
                        rd_vld          <= 1'b1;
                        rd_flash_id     <= hrdata_reg   ;
                    end
                    else
                        rd_flash_id     <= rd_flash_id  ;
                end
            RD_GET_READ_DATA:
                begin
                    if(cnt==8'd4) begin
                        rd_vld          <= 1'b1;
                        rd_data         <= hrdata_reg[15:0]  ;
                    end
					else if(cnt==8'd5) begin
                        rd_vld          <= 1'b1;
                        rd_data         <= hrdata_reg[31:16]  ;
                    end
                    else begin
                        rd_data         <= rd_data  ;
						rd_vld          <= 1'b0;
					end
                end
            default:
				begin
                    rd_vld         <= 1'b0;
                    rd_data        <= rd_data  ;
				end
        endcase
    end
end

//==========================================================
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		data_bytes_cnt  <= 'b0;
	else if(current_state == RD_GET_READ_DATA || (current_state == WR_SET_DATA))begin
	// else if(current_state == RD_GET_READ_DATA )begin
		if(cnt == 8'd7)
			data_bytes_cnt  <= data_bytes_cnt + 1'b1;
		else 
			data_bytes_cnt  <= data_bytes_cnt;
	end
    else data_bytes_cnt <= 0;
end
endmodule
