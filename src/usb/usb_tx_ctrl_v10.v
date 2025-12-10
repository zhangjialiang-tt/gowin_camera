//16bit 25hz
//tv -->600*800
//it -->256*192
//head -->32
//param -->256
module usb_tx_ctrl_v10 #(
    parameter               FIFO_INIT_WAIT_TIME = 150           ,
    parameter               TIME_CNT            = 60000         ,
    parameter               FRAME_RATE          = 30            ,
    parameter               HEAD_LENGTH         = 32            ,
    parameter               IR_LENGTH           = 256*192       ,
    parameter               TV_LENGTH           = 800*600       ,
    parameter               PARAM_LENGHT        = 256           ,
    parameter               PARAM_L_LENGTH      = 535146        ,//字节  
    parameter               PARAM_H_LENGTH      = 633146        ,//字节  
    parameter               PARAM_L_TOTAL_LEN   = 540672        ,//字节  
    parameter               PARAM_H_TOTAL_LEN   = 638976         //字节   
) (
    input                           i_clk                       ,
    input                           i_rst_n                     ,

    input                           i_pclk                      ,
    input                           i_ir_init_done              ,
    input           [15:0]          i_head_data                 ,
    input                           i_head_data_vld             ,
    output     reg                  o_head_data_req             ,
    input           [15:0]          i_ir_data                   ,
    input                           i_ir_data_vld               ,
    input                           i_ir_data_ready             , 
    output     reg                  o_ir_data_req               ,
    input           [15:0]          i_tv_data                   ,
    input                           i_tv_data_vld               ,
    output     reg                  o_tv_data_req               ,
    input                           i_tv_data_ready             ,
    input           [15:0]          i_param_data                ,
    input                           i_param_data_vld            ,
    output     reg                  o_param_req                 ,
    output     reg                  o_start                     ,


    input                           i_os_type                   ,

    input                           i_param_load                ,
    input                           i_flash_rd_data_ready       ,
    input                           i_flash_rd_data_vld         ,
    input           [15:0]          i_flash_rd_data             ,
    input           [7:0]           i_update_type               ,
    input           [7:0]           i_cmd_data                  ,
    output                          o_flash_rd_en               ,
    output                          o_ddr_rd_start              ,
    output  reg                        o_ddr_rd_en                 ,
    output                          o_send_end                  ,
    input                           i_state_rst                 ,

    input           [3:0]           i_endpt                     ,
    output  wire    [7:0]           o_txdat                     ,
    output  wire    [11:0]          o_txdat_len                 ,
    output  reg                     o_txcork                    ,   //  数据准备好时拉低，未准备好拉高（控制端点时恒为 0）
    input                           i_txpop                     ,
    input                           i_txact                      ,
    input                           i_txpktfin_o
);
parameter  PROGRAM_UPDATE_PACKAGE   = 32'h0007; 
parameter  PARAMETER_UPDATE_PACKAGE = 32'h0036; 
parameter  DATA_LOW_UPDATE_PACKAGE  = 32'h0038; 
parameter  DATA_HIGH_UPDATE_PACKAGE = 32'h0039; 
parameter  PARAMETER_SEND_PACKAGE   = 32'h003b; 
parameter  GUOGAI_UPDATE_PACKAGE    = 32'h0056; 
parameter  GUOGAI_SEND_PACKAGE      = 32'h005a;

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
//  参数定义
    localparam VIDEO_ENDPT_IOS     = 5'b00001                       ;
    localparam VIDEO_ENDPT_ANDROID = 5'b10010                       ;

    localparam FRAME_BURST_NUM     = ((HEAD_LENGTH + IR_LENGTH + TV_LENGTH + PARAM_LENGHT)/256);
    localparam PARAM_L_BURST_NUM   = ((PARAM_L_TOTAL_LEN)/512);
    localparam PARAM_H_BURST_NUM   = ((PARAM_H_TOTAL_LEN)/512);
    localparam FIFO_INIT_END       = 'd5 + FIFO_INIT_WAIT_TIME          ; 

    // localparam IDLE                = 11'b000_0000_0000                  ;
    // localparam FIFO_RST            = 11'b000_0000_0001                  ; 
    // localparam FIFO_INIT_WAIT      = 11'b000_0000_0010                  ;
    // localparam GET_HEAD            = 11'b000_0000_0100                  ;
    // localparam GET_IR_DATA_WAIT    = 11'b000_0000_1000                  ;  
    // localparam GET_IR_DATA         = 11'b000_0001_0000                  ;  
    // localparam GET_TV_DATA_WAIT    = 11'b000_0010_0000                  ;       
    // localparam GET_TV_DATA         = 11'b000_0100_0000                  ;
    // localparam GET_PARAM_PRE       = 11'b000_1000_0000                  ; 
    // localparam GET_PARAM           = 11'b001_0000_0000                  ; 
    // localparam FILL_WR             = 11'b010_0000_0000                  ; 
    // localparam DONE                = 11'b100_0000_0000                  ; 

    localparam IDLE                = 4'b0000                  ;
    localparam FIFO_RST            = 4'b0001                  ; 
    localparam FIFO_INIT_WAIT      = 4'b0011                  ;
    localparam GET_HEAD            = 4'b0010                  ;

    localparam GET_IR_DATA_WAIT    = 4'b0110                  ;  
    localparam GET_IR_DATA         = 4'b0111                  ;  
    localparam GET_TV_DATA_WAIT    = 4'b0101                  ;       
    localparam GET_TV_DATA         = 4'b0100                  ;

    localparam GET_PARAM_PRE       = 4'b1100                  ; 
    localparam GET_PARAM           = 4'b1101                  ; 
    localparam PARAM_RD_FLASH      = 4'b1111                  ;
    localparam PARAM_DATA_WAIT     = 4'b1110                  ; 
    localparam PARAM_DATA          = 4'b1010                  ;
    localparam FILL_WR             = 4'b1011                  ; 
    localparam DONE                = 4'b1001                  ; 

reg             [15:0]                      data_dly                    ;
reg                                         fifo_wr_en                  ;
reg             [depth2width(TIME_CNT)-1:0] cnt                         ;
reg             [3:0]                        state_c                     ;
reg                                         fifo_video_rst              ;
wire            [10:0]                      fifo_wr_num                 ;
wire            [11:0]                      fifo_rd_num                 ;
wire                                        fifo_rd_en                  ;
wire                                        fifo_video_tx_almost_empty  ;   
wire                                        fifo_empty                  ;
wire                                        fifo_full                   ;

reg            [depth2width(HEAD_LENGTH)-1:0]   head_cnt0               ;
reg            [depth2width(HEAD_LENGTH)-1:0]   head_cnt1               ;

reg                                             ir_cnt1_clac_en         ;
reg            [depth2width(IR_LENGTH)-1:0]     ir_cnt0                 ;
reg            [depth2width(IR_LENGTH)-1:0]     ir_cnt1                 ;

reg                                             tv_cnt1_clac_en         ;
reg            [depth2width(TV_LENGTH)-1:0]     tv_cnt0                 ;
reg            [depth2width(TV_LENGTH)-1:0]     tv_cnt1                 ;

reg            [depth2width(PARAM_LENGHT)-1:0]  param_cnt0              ;
reg            [depth2width(PARAM_LENGHT)-1:0]  param_cnt1              ;

reg            [9:0]                            ir_rd_cnt               ;
reg            [9:0]                            tv_rd_cnt               ;


reg            [depth2width(FRAME_BURST_NUM)-1:0] burst_num             ;
reg            [7:0]                             fill_cnt               ;
reg                                              fill_vld               ;    
reg            [8:0]                             vidoe_tx_cnt           ;    

reg                                              video_endpt            ;
wire                                             fifo_video_tx_almost_full; 

reg            [5:0]                            cnt_wait = 0                ;
reg                                             cnt_wait_flag           ;
reg            [1:0]                            ir_init_done_dly        ;             
wire                                            param_packet_send_en;
reg            [1:0]                            param_packet_send_en_reg0;
reg                                             param_load_en_reg0 = 0;
reg                                             param_load_en_reg1 = 0;
wire                                            param_load_en_ndge;
wire                                            param_load_en_pdge;
reg                                             param_send_en= 0;   
reg            [21:0]                           param_rd_cnt_reg= 0;   
reg            [21:0]                           param_rd_cnt_reg0= 0; 
reg            [21:0]                           param_rd_cnt_reg1= 0; 
reg            [21:0]                           param_rd_cnt_reg2= 0; 
wire           [31:0]                           param_rd_lens;  
wire           [31:0]                           param_rd_lens01;  
wire           [31:0]                           param_total_lens;  
reg            [3:0]                            state_c_reg0                     ;
reg                                             init_param_send_done=0;
reg            [15:0]                           head_data;
reg                                             head_data_val;

reg                                             param_packet_cnt1_clac_en         ;
reg            [22-1:0]                         param_packet_cnt0                 ;
reg            [22-1:0]                         param_packet_cnt1                 ;
reg            [10-1:0]                         param_packet_cnt                  ;
reg            [1:0]                            state_rst_ff0        ;  
reg            [1:0]                            send_packet_type;
wire                                            send_end_en;
reg             [10 : 0]                        send_packet_cnt;
reg             [10 : 0]                        send_packet_cnt_ff0;
reg             [10 : 0]                        send_packet_cnt_ff1;
reg                                             send_packet_err;

wire            [   7: 0]                       fifo_rd_data                ;
wire                                            ep2_tx_afull                ;
wire            [   9: 0]                       ram_wr_addr                 ;
wire            [   7: 0]                       ram_wr_data                 ;
wire                                            ram_wr_en                   ;
wire            [   9: 0]                       ram_rd_addr                 ;
wire            [   7: 0]                       ram_rd_data                 ;
reg                                             usb_retrans_en              ;

assign                                          param_packet_send_en   = (i_update_type == PARAMETER_SEND_PACKAGE || (i_update_type == GUOGAI_SEND_PACKAGE))    ? 1 : 0;
assign                                          o_flash_rd_en          =  ((state_c ==  PARAM_RD_FLASH) || (state_c ==  PARAM_DATA_WAIT)||(state_c ==  PARAM_DATA))&& param_packet_send_en_reg0[1];  
assign                                          o_ddr_rd_start         = o_flash_rd_en && param_load_en_ndge;  
// assign                                          o_ddr_rd_en            = (!fifo_video_tx_almost_full) && (param_packet_cnt == 11) && (param_rd_cnt_reg < (param_rd_lens))&& (param_packet_cnt1_clac_en)&&(state_c ==  PARAM_DATA);  
// assign                                          o_send_end             = (param_packet_send_en_reg0[1] && (head_data_val == 1'b1) && (param_packet_cnt == (1023))) ? 1 : 0;
assign                                          o_send_end             = (param_packet_send_en_reg0[1] && (state_c == (DONE)) && !init_param_send_done) ? 1 : 0;
always @(posedge i_pclk ) begin
    ir_init_done_dly            <={ir_init_done_dly[0],i_ir_init_done};
    param_packet_send_en_reg0   <={param_packet_send_en_reg0[0],param_packet_send_en};
    state_rst_ff0               <={state_rst_ff0[0],i_state_rst};
    
    if(param_packet_send_en_reg0[0] & !param_packet_send_en_reg0[1])
        init_param_send_done <= 0;
    else if(i_update_type == 32'h003E)
    // if(ir_init_done_dly && state_c == FIFO_INIT_WAIT)
    // if(o_param_send_end && (i_cmd_data == 2))
        init_param_send_done <= 1;
    else 
        init_param_send_done <= init_param_send_done;
end
//////////////////////////////////////////////////////////////////////
always @(posedge i_clk) begin
    // if({video_endpt,i_txpop} == 2'b11)
    if(state_c == FIFO_INIT_WAIT)begin
        if(param_packet_send_en_reg0[0])
            send_packet_type <= (i_cmd_data == 1) ? 1 : 2;
        else 
            send_packet_type <=0;
    end
    else 
        send_packet_type <= send_packet_type;
end
//////////////////////////////////////////////////////////////////////
always @(posedge i_pclk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        cnt <= {depth2width(TIME_CNT){1'b0}};
    end
    // else if((ir_init_done_dly == 1'b0 && state_c == IDLE))begin 
    //    cnt <= {depth2width(TIME_CNT){1'b0}};
    // end
    else if((cnt == TIME_CNT -1) || (state_rst_ff0[0] && (!state_rst_ff0[1])))begin
        cnt <= {depth2width(TIME_CNT){1'b0}};
    end
    // else if(cnt == TIME_CNT -1)begin
    //     if(send_packet_cnt == (FRAME_BURST_NUM) || (state_c == IDLE ) || (state_c == FIFO_RST ) || (state_c == FIFO_INIT_WAIT ))
    //         cnt <= {depth2width(TIME_CNT){1'b0}};
    //     else 
    //         cnt <= cnt;
    // end
    else if(param_packet_send_en_reg0[0] && ((state_c == PARAM_DATA)||(state_c == PARAM_DATA_WAIT)||(state_c == PARAM_RD_FLASH)))begin
        cnt <= cnt;
    end
    else begin
        cnt <= cnt + 1'b1;
    end
end

reg [31:0] time_cnt;
always @(posedge i_pclk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        time_cnt <= 0;
    end
    else if(state_c == FIFO_RST && cnt == 'd5)begin
        time_cnt <= 0;
    end
    else begin
        time_cnt <= time_cnt + 1'b1;
    end
end
reg             exception_en;
always @(posedge i_pclk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        exception_en <= 0;
    end
    else if(state_c == FIFO_RST && cnt == 'd5)begin
        if(time_cnt > 1100000)
            exception_en <= 1;
        else 
            exception_en <= 0;
    end
    else begin
        exception_en <= 0;
    end
end
// always @(posedge i_pclk or negedge i_rst_n) begin
//     if(!i_rst_n)begin
//         cnt <= {depth2width(TIME_CNT){1'b0}};
//     end
//     else if(state_c == DONE)begin 
//         cnt <= {depth2width(TIME_CNT){1'b0}};
//     end
//     else if((state_c != PARAM_DATA )&& param_packet_send_en)begin 
//         cnt <= cnt + 1'b1;
//     end
//     else begin
//         cnt <= cnt;
//     end
// end

always @(posedge i_pclk ) begin
    if(cnt == {depth2width(TIME_CNT){1'b0}})begin
        state_c <= IDLE;
    end
    else begin
        case (state_c)
IDLE          : if(cnt == 'd1)begin
                    state_c <= FIFO_RST;
                end
                else begin
                    state_c <= state_c;
                end
FIFO_RST      : if(cnt == 'd5)begin
                    state_c <= FIFO_INIT_WAIT;
                end
                else begin
                    state_c <= state_c;
                end
FIFO_INIT_WAIT: if(cnt == FIFO_INIT_END)begin
                    if(param_packet_send_en_reg0[0])
                        state_c <= PARAM_RD_FLASH;
                    else if(ir_init_done_dly[1] && init_param_send_done)
                    // else if(1)
                        state_c <= GET_HEAD;
                    else 
                        state_c <= state_c;
                end
                else begin
                    state_c <= state_c;
                end
GET_HEAD        :if((i_head_data_vld == 1'b1) && (head_cnt1 == HEAD_LENGTH - 1))begin
                    state_c <= GET_IR_DATA_WAIT;
                end
                else begin
                    state_c <= state_c;
                end
GET_IR_DATA_WAIT : if(fifo_video_tx_almost_full == 1'b0)begin  
                    state_c <= GET_IR_DATA;
                end
                else begin
                    state_c <= state_c;
                end
GET_IR_DATA :  if((i_ir_data_vld == 1'b1) && (ir_cnt0 == IR_LENGTH -1))begin
                    state_c <= GET_TV_DATA_WAIT;
                end
                else if((i_ir_data_vld == 1'b1) && (ir_cnt0[7:0] == 8'hff))begin
                    state_c <= GET_IR_DATA_WAIT;
                end
                else begin
                    state_c <= state_c;
                end    
GET_TV_DATA_WAIT :if(fifo_video_tx_almost_full == 1'b0)begin       
                    state_c <= GET_TV_DATA;
                  end
                  else begin
                      state_c <= state_c;
                  end
GET_TV_DATA     :if((i_tv_data_vld == 1'b1) && (tv_cnt0 == TV_LENGTH -1))begin
                    state_c <= GET_PARAM_PRE;
                end
                else if((i_tv_data_vld == 1'b1) && (tv_cnt0[7:0] == 8'hff))begin
                    state_c <= GET_TV_DATA_WAIT;
                end
                else begin
                    state_c <= state_c;
                end    
GET_PARAM_PRE   : if(fifo_video_tx_almost_full == 1'b0)begin        
                        state_c <= GET_PARAM;
                   end
                   else begin
                        state_c <= GET_PARAM_PRE;
                   end
GET_PARAM       : if((param_cnt1 == PARAM_LENGHT - 1) &&  (i_param_data_vld == 1'b1))begin
                    state_c <= FILL_WR;
                end
                else begin
                    state_c <= state_c;
                end
PARAM_RD_FLASH  :   if(param_packet_cnt == 50)begin
                        state_c <= PARAM_DATA_WAIT;
                    end
                    else begin
                        state_c <= state_c;
                    end                
PARAM_DATA_WAIT :   if(fifo_wr_num == 0)begin   
                        if(param_rd_cnt_reg1 == (param_total_lens)) 
                            state_c <= FILL_WR;  
                        else 
                            state_c <= PARAM_DATA;
                    end
                    else begin
                        state_c <= state_c;
                    end
PARAM_DATA      :   if(param_packet_send_en_reg0[1])begin
                        // if((param_rd_cnt_reg2 == (param_total_lens + 1)))begin
                        //     if(fifo_wr_num == 0)
                        //         state_c <= FILL_WR;
                        //     else 
                        //         state_c <= state_c;
                        // end
                        // else 
                        if((head_data_val == 1'b1) && (param_rd_cnt_reg1[7:0] == 8'hff))begin
                            state_c <= PARAM_DATA_WAIT;
                        end
                        else begin
                            state_c <= state_c;
                        end
                        // if((param_packet_cnt == 1023))
                        //     state_c <= FILL_WR;
                        // else 
                        //     state_c <= state_c;
                    end
                    else begin
                        state_c <= state_c;
                    end
FILL_WR         :  if(fill_cnt == 8'hF)begin
                        state_c <= DONE;
                   end
                   else begin
                        state_c <= state_c;
                   end
DONE            : if(send_packet_cnt == FRAME_BURST_NUM && send_packet_type == 0 || (send_packet_type != 0))begin
                        state_c <= IDLE;
                  end
                  else begin
                        state_c <= state_c;
                  end
            default: state_c <= IDLE;
        endcase
    end
end

always @(posedge i_pclk ) begin
    if(state_c != GET_PARAM)begin
      param_cnt0 <= {depth2width(PARAM_LENGHT){1'b0}};
    end
    else if(param_cnt0 == PARAM_LENGHT)begin
      param_cnt0 <= param_cnt0;
    end
    else begin
      param_cnt0 <= param_cnt0 + 1'b1;
    end
end
always @(posedge i_pclk ) begin
    if((param_cnt0 < PARAM_LENGHT) && (state_c == GET_PARAM))begin
        o_param_req <= 1'b1;
    end
    else begin
        o_param_req <= 1'b0;
    end
end

always @(posedge i_pclk ) begin
    if(state_c != GET_PARAM)begin
        param_cnt1 <= {depth2width(HEAD_LENGTH){1'b0}};
    end
    else if(i_param_data_vld == 1'b1)begin
        param_cnt1 <= param_cnt1 + 1'b1;
    end
    else begin
        param_cnt1 <= param_cnt1;
    end
end


always @(posedge i_pclk ) begin
    if(state_c == IDLE)begin
        tv_cnt0 <= {depth2width(TV_LENGTH){1'b0}};
    end
    else if((i_tv_data_vld == 1'b1) && (state_c == GET_TV_DATA))begin
        tv_cnt0 <= tv_cnt0 +1'b1;
    end
    else begin
        tv_cnt0 <= tv_cnt0;
    end
end

always @(posedge i_pclk) begin
    if(state_c == IDLE)begin
        tv_cnt1 <= {depth2width(TV_LENGTH){1'b0}};
    end
    else if(({tv_cnt1_clac_en,i_ir_data_ready} == 2'b11) && (state_c == GET_TV_DATA))begin
        tv_cnt1 <= tv_cnt1 + 1'b1;
    end
    else begin
        tv_cnt1 <= tv_cnt1;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == GET_TV_DATA_WAIT)begin
        tv_cnt1_clac_en <= 1'b1;
    end
    else if(((tv_cnt1 == TV_LENGTH-1) || tv_cnt1[7:0] == 8'hFF) && ({tv_cnt1_clac_en,i_ir_data_ready} == 2'b11))begin
        tv_cnt1_clac_en <= 1'b0;
    end
    else begin
        tv_cnt1_clac_en <= tv_cnt1_clac_en;
    end
end

always @(posedge i_pclk ) begin
    if(({tv_cnt1_clac_en,i_tv_data_ready} == 2'b11) && (state_c ==GET_TV_DATA))begin
        o_tv_data_req <= 1'b1;        
    end
    else begin
        o_tv_data_req <= 1'b0;
    end
end

//-----------------------------------
always @(posedge i_pclk ) begin
    if(state_c == IDLE)begin
        ir_cnt0 <= {depth2width(IR_LENGTH){1'b0}};
    end
    else if((i_ir_data_vld == 1'b1) && (state_c == GET_IR_DATA))begin
        ir_cnt0 <= ir_cnt0 +1'b1;
    end
    else begin
        ir_cnt0 <= ir_cnt0;
    end
end

always @(posedge i_pclk) begin
    if(state_c == IDLE)begin
        ir_cnt1 <= {depth2width(IR_LENGTH){1'b0}};
    end
    else if(({ir_cnt1_clac_en,i_ir_data_ready} == 2'b11) && (state_c == GET_IR_DATA))begin
        ir_cnt1 <= ir_cnt1 + 1'b1;
    end
    else begin
        ir_cnt1 <= ir_cnt1;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == GET_IR_DATA_WAIT)begin
        ir_cnt1_clac_en <= 1'b1;
    end
    else if(((ir_cnt1 == IR_LENGTH-1) || ir_cnt1[7:0] == 8'hFF) && ({ir_cnt1_clac_en,i_ir_data_ready} == 2'b11))begin
        ir_cnt1_clac_en <= 1'b0;
    end
    else begin
        ir_cnt1_clac_en <= ir_cnt1_clac_en;
    end
end

always @(posedge i_pclk ) begin
    if(({ir_cnt1_clac_en,i_ir_data_ready} == 2'b11) && (state_c ==GET_IR_DATA))begin
        o_ir_data_req <= 1'b1;        
    end
    else begin
        o_ir_data_req <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if((state_c == IDLE) || (state_c == FIFO_RST) || (state_c == FIFO_INIT_WAIT))begin
        burst_num <= {depth2width(FRAME_BURST_NUM){1'b0}};
    end
    else if((vidoe_tx_cnt == 9'd511) && (fifo_rd_en == 1'b1) && (!usb_retrans_en)) begin
        burst_num <= burst_num +1'b1;
    end
    else begin
        burst_num <= burst_num;
    end
end

always @(posedge i_pclk ) begin
    if(state_c != GET_HEAD)begin
      head_cnt0 <= {depth2width(HEAD_LENGTH){1'b0}};
    end
    else if(head_cnt0 == HEAD_LENGTH)begin
      head_cnt0 <= head_cnt0;
    end
    else begin
      head_cnt0 <= head_cnt0 + 1'b1;
    end
end
always @(posedge i_pclk ) begin
    if((head_cnt0 < HEAD_LENGTH) && (state_c == GET_HEAD))begin
        o_head_data_req <= 1'b1;
    end
    else begin
        o_head_data_req <= 1'b0;
    end
end

always @(posedge i_pclk ) begin
    if(state_c != GET_HEAD)begin
        head_cnt1 <= {depth2width(HEAD_LENGTH){1'b0}};
    end
    else if(i_head_data_vld == 1'b1)begin
        head_cnt1 <= head_cnt1 + 1'b1;
    end
    else begin
        head_cnt1 <= head_cnt1;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == FIFO_RST)begin
        fifo_video_rst <= 1'b1;
    end
    else begin
        fifo_video_rst <= 1'b0;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == FIFO_RST)begin
        o_start <= 1'b1;
    end
    else begin
        o_start <= 1'b0;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == FILL_WR)begin
        fill_cnt <= fill_cnt +1'b1;  
    end
    else begin
        fill_cnt <= 8'd0;
    end
end
//////////////////////////////////////////
reg             param_wr_ddr_end = 0;
assign          param_load_en_ndge = !param_load_en_reg0 & param_load_en_reg1;
assign          param_load_en_pdge = !param_load_en_reg1 & param_load_en_reg0;

// always @(posedge i_pclk ) begin
//     if(param_send_en)
//         param_wr_ddr_end <= 0;
//     else if(param_load_en_ndge && o_flash_rd_en)
//         param_wr_ddr_end <= 1;
//     else 
//         param_wr_ddr_end <= param_wr_ddr_end;
// end

always @(posedge i_pclk ) begin
    param_load_en_reg0 <= i_param_load;
    param_load_en_reg1 <= param_load_en_reg0;

    if(state_c == IDLE)
        param_send_en  <= 0;
    else if(param_load_en_ndge && o_flash_rd_en)
        param_send_en  <= 1;
    else 
        param_send_en  <= param_send_en;
end

always @(posedge i_pclk ) begin
    if(state_c == IDLE)
        param_rd_cnt_reg <= 0;
    else if(i_flash_rd_data_vld && param_send_en)
        param_rd_cnt_reg <= param_rd_cnt_reg + 1;
    else 
        param_rd_cnt_reg <= param_rd_cnt_reg;
    param_rd_cnt_reg0 <= param_rd_cnt_reg;
end
assign param_rd_lens01  = (i_update_type == GUOGAI_SEND_PACKAGE) ? IR_LENGTH * 2 :(i_cmd_data == 2)? (PARAM_H_LENGTH) : (PARAM_L_LENGTH);
assign param_rd_lens    = param_rd_lens01 >> 1;//633856   633344   535146    536064
// assign param_total_lens = (i_cmd_data == 2)? (32'd655360 >> 1) : (32'd614400 >> 1);//316928   316672   267573    268032                                                         
assign param_total_lens = (i_update_type == GUOGAI_SEND_PACKAGE) ? IR_LENGTH + 16384/2 :(i_cmd_data == 2)? (PARAM_H_TOTAL_LEN >> 1) : (PARAM_L_TOTAL_LEN >> 1);//316672 267776
always @(posedge i_pclk ) begin
    if(param_send_en)begin
        if(state_c == PARAM_RD_FLASH)begin
            if(param_packet_cnt == 50)
                param_packet_cnt <= 0;
            else 
                param_packet_cnt <= param_packet_cnt +1'b1;
        end
        else if(state_c == PARAM_DATA)begin
            if(param_packet_cnt == 11)begin
                if((param_rd_cnt_reg == (param_rd_lens-1)) && head_data_val)
                    param_packet_cnt <= param_packet_cnt +1'b1;
                else   
                    param_packet_cnt <= param_packet_cnt;
            end
            else if(param_packet_cnt == 24)begin
                // if(fifo_video_tx_almost_empty)
                //     param_packet_cnt <= param_packet_cnt +1'b1;  
                // else 
                    param_packet_cnt <= param_packet_cnt;
            end
            else param_packet_cnt <= param_packet_cnt +1'b1;     
        end
        else
            param_packet_cnt <= param_packet_cnt;               
    end
    else begin
        param_packet_cnt <= 8'd0;
    end
end

wire                state_trans;
assign  state_trans = (head_data_val == 1'b1) && (param_rd_cnt_reg1[7:0] == 8'hff);
always @(posedge i_pclk ) begin
    if(state_c == IDLE)
        param_rd_cnt_reg1 <= 0;
    // else if( param_packet_cnt == 11)begin
    //     if(o_ddr_rd_en)
    //         param_rd_cnt_reg1 <= param_rd_cnt_reg1 + 1;   
    //     else 
    //         param_rd_cnt_reg1 <= param_rd_cnt_reg1;
    // end 
    else if(head_data_val )//&& (state_c == PARAM_DATA)
        param_rd_cnt_reg1 <= param_rd_cnt_reg1 + 1;
    else 
        param_rd_cnt_reg1 <= param_rd_cnt_reg1;
    param_rd_cnt_reg2 <= param_rd_cnt_reg1;
end

always @(posedge i_pclk ) begin
    if(state_c == PARAM_DATA && (param_packet_cnt == 11) && (param_rd_cnt_reg1[7:0] < 253))begin
        o_ddr_rd_en <= 1'b1;        
    end
    else begin
        o_ddr_rd_en <= 1'b0;
    end
end
///////////////////////////////  
// always @(posedge i_pclk ) begin
//     if(state_c == IDLE)begin
//         param_packet_cnt0 <= 'd0;
//     end
//     else if((head_data_val == 1'b1) && (state_c == PARAM_DATA))begin
//         param_packet_cnt0 <= param_packet_cnt0 +1'b1;
//     end
//     else begin
//         param_packet_cnt0 <= param_packet_cnt0;
//     end
// end

// always @(posedge i_pclk) begin
//     if(state_c == IDLE)begin
//         param_packet_cnt1 <= 'd0;
//     end
//     else if((param_packet_cnt1_clac_en) && (state_c == PARAM_DATA))begin
//         param_packet_cnt1 <= param_packet_cnt1 + 1'b1;
//     end
//     else begin
//         param_packet_cnt1 <= param_packet_cnt1;
//     end
// end

always @(posedge i_pclk ) begin
    if(state_c == PARAM_DATA_WAIT)begin
        param_packet_cnt1_clac_en <= 1'b1;
    end
    else if(state_c == IDLE || ((param_rd_cnt_reg1 == param_total_lens-1) || param_rd_cnt_reg1[7:0] == 8'hFF) && (param_packet_cnt1_clac_en))begin
        param_packet_cnt1_clac_en <= 1'b0;
    end
    else begin
        param_packet_cnt1_clac_en <= param_packet_cnt1_clac_en;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == PARAM_DATA)begin
        case(param_packet_cnt)      
            8'd5 : begin
                        head_data       <= (i_update_type == GUOGAI_SEND_PACKAGE) ? {8'h5b,8'h02} : i_cmd_data == 1 ? {8'h3C,8'h02} :  {8'h3D,8'h02};
                        head_data_val   <= 1;
                    end
            8'd6 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            //数据长度        
            8'd7 : begin 
                        head_data       <= param_rd_lens01[15:0];
                        head_data_val   <= 1;
                    end
            8'd8 : begin 
                        head_data       <= param_rd_lens01[31:16];
                        head_data_val   <= 1;
                    end
            //校验  
            8'd9 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd10 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            //数据          
            8'd11 : begin 
                        head_data       <= i_flash_rd_data;
                        head_data_val   <= i_flash_rd_data_vld;
                    end
            8'd12 : begin 
                        head_data       <= 16'h0003;
                        head_data_val   <= 1;
                    end
            8'd13 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd14 : begin 
                        head_data       <= {8'h3E,8'h02};
                        head_data_val   <= 1;
                    end
            8'd15 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd16 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd17 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd18 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd19 : begin 
                        head_data       <= 16'd0;
                        head_data_val   <= 1;
                    end
            8'd20 : begin 
                        head_data       <= 16'd1;
                        head_data_val   <= 1;
                    end
            8'd22 : begin 
                        head_data       <= 16'h0003;
                        head_data_val   <= 1;
                    end
            8'd23 : begin 
                        head_data       <= 16'h0003;
                        head_data_val   <= 1;
                    end
            8'd24 : begin 
                        head_data       <= 16'h0000;
                        head_data_val   <= (param_rd_cnt_reg1[7:0] < 255) ? 1 : 0;
                    end
            default: begin
                    // if((param_packet_cnt >= 16) && (param_packet_cnt <= 1023))begin
                    //     head_data       <= 0;
                    //     head_data_val   <= 1;
                    // end
                    // else begin
                    //     head_data       <= 0;
                    //     head_data_val   <= 0;
                    // end
                    head_data       <= 0;
                    head_data_val   <= 0;
            end
        endcase
    end
    else begin
        head_data       <= 16'd0;
        head_data_val   <= 0;
    end
end

always @(posedge i_pclk ) begin
    if(state_c == FILL_WR || (state_c == PARAM_DATA) || (state_c == PARAM_DATA_WAIT))begin
        fill_vld <= 1'b1;        
    end
    else begin
        fill_vld <= 1'b0;
    end
end

wire           [4:0]     video_val;
assign                   video_val = {fill_vld,i_head_data_vld,i_ir_data_vld,i_tv_data_vld,i_param_data_vld};
always @(posedge i_pclk ) begin
    case (video_val)
        5'b00001:begin
                data_dly   <= i_param_data;
        end
        5'b00010:begin
            if(i_tv_data == 16'hbb66)begin  //规避帧头
                data_dly   <= i_tv_data - 16'd1;
            end
            else begin
                data_dly   <= i_tv_data; 
            end

        end
        5'b00100:begin
            if(i_ir_data == 16'hbb66)begin  //规避帧头 红外有符号 Y16
                data_dly   <= i_ir_data - 16'd1;
            end
            else begin
                data_dly   <= i_ir_data; 
            end 
        end
        5'b01000:begin
                data_dly   <= i_head_data;
        end 
        5'b10000:begin      //填充数据
                data_dly   <= head_data;
        end 
        default: begin
            data_dly   <= 16'd0;
        end 
    endcase
end

// assign                   video_val = {fill_vld,4'd0};
always @(posedge i_pclk ) begin
    case (video_val)
    5'b00001: if(state_c == GET_PARAM)begin
                fifo_wr_en <= 1'd1 ;
             end
             else begin
                fifo_wr_en <= 1'd0 ;
             end
    5'b00010: if(state_c == GET_TV_DATA)begin
                fifo_wr_en <= 1'd1 ;
             end
             else begin
                fifo_wr_en <= 1'd0 ;
             end
    5'b00100: if(state_c == GET_IR_DATA)begin
                fifo_wr_en <= 1'd1 ;
             end
             else begin
                fifo_wr_en <= 1'd0 ;
             end
    5'b01000: if(state_c == GET_HEAD)begin
                fifo_wr_en <= 1'd1 ;
             end 
             else begin
                fifo_wr_en <= 1'd0 ;
             end
    5'b10000: if(state_c == FILL_WR)begin
                fifo_wr_en <=  0;
             end 
             else begin
                fifo_wr_en <= head_data_val;
             end
        default: fifo_wr_en <= 1'd0 ;
    endcase
end
 
fifo_video_tx fifo_video_tx_inst(
		.Data           ({data_dly[7:0],data_dly[15:8]} ), //input [15:0] Data
        .WrReset        (fifo_video_rst                 ), //input WrReset
		.RdReset        (fifo_video_rst                 ), //input RdReset
		// .Reset          (fifo_video_rst             ), //input Reset
		.WrClk          (i_pclk                         ), //input WrClk
		.RdClk          (i_clk                          ), //input RdClk
		.WrEn           (fifo_wr_en                     ), //input WrEn
		.RdEn           (fifo_rd_en                     ), //input RdEn
		.Wnum           (fifo_wr_num                    ), //output [12:0] Wnum
		.Rnum           (fifo_rd_num                    ), //output [13:0] Rnum
		.Almost_Empty   (fifo_video_tx_almost_empty     ), //output Almost_Empty
        .Almost_Full    (fifo_video_tx_almost_full      ), //output Almost_Full
		.Q              (fifo_rd_data                        ), //output [7:0] Q
		.Empty          (fifo_empty                     ), //output Empty
		.Full           (fifo_full                      ) //output Full
	);

//  assign fifo_rd_en = (video_endpt && i_txpop) ;
    // assign fifo_rd_en = (video_endpt) & !fifo_empty & !ep2_tx_afull;
    assign fifo_rd_en = !usb_retrans_en ? (video_endpt && i_txpop) & !fifo_empty  : 0;
    assign o_txdat    = !usb_retrans_en ? fifo_rd_data : ram_rd_data;
    // assign fifo_rd_en = (video_endpt && i_txpop) & !fifo_empty ;
    // assign o_txdat    = fifo_rd_data ;
    // usb_fifo usb_fifo
    // (
    //      .i_clk         (i_clk   )//clock
    //     ,.i_reset       (!i_rst_n )//reset
    //     ,.i_usb_endpt   (video_endpt ? 2 : 0    )
    //     ,.i_usb_rxact   ()
    //     ,.i_usb_rxval   ()
    //     ,.i_usb_rxpktval()
    //     ,.i_usb_rxdat   ()
    //     ,.o_usb_rxrdy   ()
    
    //     ,.i_usb_txact   (i_txact    )
    //     ,.i_usb_txpop   (i_txpop    )
    //     ,.i_usb_txpktfin(i_txpktfin_o  && video_endpt )
    //     ,.o_usb_txcork  (o_txcork)
    //     ,.o_usb_txlen   ( )//o_txdat_len
    //     ,.o_usb_txdat   (o_txdat )
    //     //Endpoint 2
    //     ,.i_ep2_tx_clk  (i_clk       )
    //     ,.i_ep2_tx_max  (12'd512           )
    //     ,.i_ep2_tx_dval (fifo_rd_en )
    //     ,.i_ep2_tx_data (fifo_rd_data[7:0])
    //     ,.o_ep2_tx_afull(ep2_tx_afull)
    //     ,.i_ep2_rx_clk  (    )
    //     ,.i_ep2_rx_rdy  (    )
    //     ,.o_ep2_rx_dval (    )
    //     ,.o_ep2_rx_data (    )
    // );

//  reg   [21:0]       out_cnt;
//  always @(posedge i_clk) begin
//     if (o_txcork) begin
//         out_cnt <= out_cnt + 1;
//     end
//     else if (fifo_video_rst) begin
//         out_cnt <= 1'd0;
//     end
//     else begin
//         out_cnt <= out_cnt;
//     end
// end

    usb_retrans_ram usb_retrans_ram_inst(
        .dout                               (ram_rd_data               ),//output [7:0] dout
        .wre                                (ram_wr_en                 ),//input wre
        .wad                                (ram_wr_addr               ),//input [8:0] wad
        .di                                 (ram_wr_data               ),//input [7:0] di
        .rad                                (ram_rd_addr               ),//input [8:0] rad
        .clk                                (i_clk                     ) //input clk
    );
    assign  ram_wr_en   = fifo_rd_en;
    assign  ram_wr_data = !usb_retrans_en ? fifo_rd_data : 0;
    assign  ram_wr_addr = !usb_retrans_en ? vidoe_tx_cnt : 0;
    assign  ram_rd_addr =  usb_retrans_en ? vidoe_tx_cnt : 0;
/////////////////////////////////////////////////
    // always @(posedge i_clk) begin
    //     if (usb_retrans_en) begin
    //         send_end <= 9'd0;
    //     end
    //     else if (&{i_txpop,vidoe_tx_cnt} == 1'b1) begin
    //         send_end <= 1'd1;
    //     end
    //     else begin
    //         send_end <= send_end;
    //     end
    // end
////////////////////////////////////////////
reg                     send_end;
reg                     send_status;
reg     [7:0]           send_end_cnt;
always @(posedge i_clk) begin
    if (send_end_cnt == 70) begin
        send_end <= 9'd0;
    end
    else if (&{i_txpop,vidoe_tx_cnt} == 1'b1) begin
        send_end <= 1'd1;
    end
    else begin
        send_end <= send_end;
    end
end

always @(posedge i_clk) begin
    if (send_end) begin
        send_end_cnt <=  send_end_cnt +1'd1;
    end
    else begin
        send_end_cnt <= 9'd0;
    end
end

always @(posedge i_clk) begin
    if ((send_end_cnt > 0) && (send_end_cnt < 70)) begin
        if(i_txpktfin_o)
            send_status <=  1'd1;
        else 
            send_status <= send_status;
    end
    else begin
        send_status <= 0;
    end
end
reg     [10:0]          packet_fail;
always @(posedge i_clk) begin
    if (fifo_video_rst) 
        packet_fail <= 0;
    else if (send_end_cnt == 70 ) begin
        if(send_status == 0)begin
            packet_fail <= packet_fail + 1;
        end
        else begin
            packet_fail <= packet_fail;
        end
    end
    else begin
        packet_fail     <= packet_fail;
    end
end

always @(posedge i_clk) begin
    if (send_end_cnt == 70 ) begin
        if(send_status == 0)begin
            usb_retrans_en  <= 1;
        end
        else begin
            usb_retrans_en  <= 0;
        end
    end
    else begin
        usb_retrans_en  <= usb_retrans_en;
    end
end
////////////////////////////////////////////
always @(posedge i_clk) begin
    if(fifo_video_rst)begin
        send_packet_cnt <= 0;
        if(send_packet_cnt_ff0 != 1601)
            send_packet_err <= 1;
        else 
            send_packet_err <= 0;
    end
    else if(i_txpktfin_o && video_endpt)
        send_packet_cnt <=  send_packet_cnt + 1'd1;
    else begin
        send_packet_cnt <= send_packet_cnt;
        send_packet_err <= 0;
    end

    if(i_txpktfin_o && video_endpt)
        send_packet_cnt_ff0 <=  send_packet_cnt + 1'd1;    
    else
        send_packet_cnt_ff0 <= send_packet_cnt_ff0;

    if((vidoe_tx_cnt == 9'd511) && (fifo_rd_en == 1'b1) && (!usb_retrans_en))
        send_packet_cnt_ff1 <= burst_num + 1;
    else 
        send_packet_cnt_ff1 <= send_packet_cnt_ff1;

    state_c_reg0            <= state_c;    
end

wire                        txpktfin_en;
reg                         last_packet_en;
assign                      txpktfin_en            = (( ((send_packet_type == 0) && (send_packet_cnt == FRAME_BURST_NUM))     || 
                                                        ((send_packet_type == 1) && (send_packet_cnt == PARAM_L_BURST_NUM))   || 
                                                        ((send_packet_type == 2) && (send_packet_cnt == PARAM_H_BURST_NUM)))) ? 1 : 0;

reg                                 send_zlp_packet_en;
reg     [2:0]                       send_zlp_packet_cnt;
always @(posedge i_clk) begin
    // if({video_endpt,i_txpop} == 2'b11)
    if(send_zlp_packet_cnt == 2 || (state_c ==  FIFO_RST))
        send_zlp_packet_en <= 0;
    else if(txpktfin_en && ({i_os_type,i_endpt} == VIDEO_ENDPT_IOS))//&& (state_c ==  DONE)
        send_zlp_packet_en <= 1;
    else 
        send_zlp_packet_en <= send_zlp_packet_en;
end

always @(posedge i_clk) begin
    if(send_zlp_packet_en)begin
        if(i_txpktfin_o)
            send_zlp_packet_cnt <= send_zlp_packet_cnt + 1;
        else 
            send_zlp_packet_cnt <= send_zlp_packet_cnt;
    end
    else 
        send_zlp_packet_cnt <= 0;
end
//  判断是否是 Video 端点
    always @(posedge i_clk) begin
        if ({i_os_type,i_endpt} == VIDEO_ENDPT_IOS) begin
            video_endpt <= 1'd1;
        end
        else if ({i_os_type,i_endpt} == VIDEO_ENDPT_ANDROID) begin
            video_endpt <= 1'd1;
        end
        else begin
            video_endpt <= 1'd0;
        end
    end
//  o_txdat_len
    // assign o_txdat_len = 12'd512;
    assign o_txdat_len = send_zlp_packet_en ? 0 : 12'd512;
//  o_txcork
    always @(posedge i_clk) begin
        if (o_txcork == 1'b1) begin
            vidoe_tx_cnt <= 9'd0;
        end
        else if ({video_endpt,i_txpop} == 2'b11) begin
            vidoe_tx_cnt <= vidoe_tx_cnt + 9'd1;
        end
        else begin
            vidoe_tx_cnt <= vidoe_tx_cnt;
        end
    end

    always @(posedge i_clk  or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_txcork <= 1'd1;
        end
        else if (({cnt_wait_flag,video_endpt,i_txact,fifo_video_tx_almost_empty} == 4'b1100) && (vidoe_tx_cnt == 9'd0)) begin
            o_txcork <= 1'd0;
        end
        else if ((send_end_cnt == 70  && send_status == 0 && (send_packet_cnt == (FRAME_BURST_NUM - 1) || send_packet_cnt == (FRAME_BURST_NUM - 2))) && (vidoe_tx_cnt == 9'd0)) begin
            o_txcork <= 1'd0;
        end
        else if(send_zlp_packet_cnt == 2)
            o_txcork <= 1'd1;
        else if(send_zlp_packet_en)
            o_txcork <= 1'd0;
        else if (&{i_txpop,vidoe_tx_cnt} == 1'b1) begin
            o_txcork <= 1'd1;
        end
        else begin
            o_txcork <= o_txcork;
        end
    end

    always @(posedge i_clk ) begin
        if(i_txact == 1'b1)begin
            cnt_wait <= 6'd0;
        end
        else if(cnt_wait == 6'b111111)begin
            cnt_wait <= cnt_wait;
        end
        else begin
            cnt_wait <= cnt_wait +1'b1;
        end
    end


    always @(posedge i_clk ) begin
        if(cnt_wait > 6'd10)begin
            cnt_wait_flag <= 1'b1;
        end
        else begin
            cnt_wait_flag <= 1'b0;
        end
    end

//成功发送帧率测试

reg                 [4:0]                   fcnt    ;
reg                 [4:0]                   fcnt_tx ;


reg                                         flag_cc     ;
reg                 [7:0]                   data_cc     ;
reg                                         data_cc_vld ;

always @(posedge i_clk ) begin
    data_cc     <= o_txdat;
    data_cc_vld <= fifo_rd_en;
end
always @(posedge i_clk ) begin
    if((burst_num == FRAME_BURST_NUM) && (data_cc_vld == 1'b1) && (data_cc != 8'hCC))begin
        flag_cc <= 1'b1;
    end
    else begin
        flag_cc <= 1'b0;
    end
end

always @(posedge i_pclk or negedge i_rst_n) begin
    if(!i_rst_n)begin
        fcnt <= 5'd0;
    end
    else if((fcnt == (FRAME_RATE-1)) && (cnt == {depth2width(TIME_CNT){1'b0}}))begin
        fcnt <= 5'd0;
    end
    else if(cnt == {depth2width(TIME_CNT){1'b0}})begin
        fcnt <= fcnt +1'b1;
    end
    else begin
        fcnt <= fcnt;
    end
end

always @(posedge i_pclk) begin
    if((fcnt == (FRAME_RATE-1)) && (cnt == {depth2width(TIME_CNT){1'b0}}))begin
        fcnt_tx <= 5'd0;
    end
    else if((state_c == DONE) && (burst_num == FRAME_BURST_NUM))begin
        fcnt_tx <= fcnt_tx +1'b1;
    end
    else begin
        fcnt_tx <= fcnt_tx;
    end
end


endmodule