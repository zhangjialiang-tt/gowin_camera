
//可见光配置太多了 软核报资源不够了
module i2c_reg_buff 
#(
    parameter CLK_REQ = 30_000_000
)(
    input                   i_clk           ,
    input                   i_rst_n         ,
    input           [31:0]  i_apb_data      ,
    input                   i_update        ,
    output reg      [31:0]  o_apb_data        

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


//i_apb_data
//31    全局复位  高复位
//30    开始计数 与0-27同步下发
//29    不管延时 0 不管 1 管
//0-27  计数
 
//用于在上电时序完成后在除可见光操作延时时配置
reg             [depth2width(CLK_REQ)-1:0]    time_cnt       ;
reg             [27:0]                        time_cnt_buff  ;
reg             [1:0]                         write_start_dly; 
reg             [15:0]                        lens           ;   

reg             [1:0]                         update_dly    ;

always @(posedge i_clk ) begin
    update_dly <= {update_dly[0],i_update};
end

always @(posedge i_clk ) begin
    write_start_dly <= {write_start_dly[0],i_apb_data[30]};
end

always @(posedge i_clk ) begin
    if(write_start_dly == 2'b01)begin
        time_cnt_buff <= i_apb_data[27:0];
    end
    else begin
        time_cnt_buff <= time_cnt_buff;
    end
end

always @(posedge i_clk ) begin
    if(write_start_dly == 2'b01)begin
        time_cnt <= {depth2width(CLK_REQ){1'b0}};
    end
    else if(time_cnt == time_cnt_buff)begin
        time_cnt <= time_cnt;
    end
    else begin
        time_cnt <= time_cnt + 1'b1;
    end
end


//o_apb_data 
//0-7   写数据
//8-15  地址
//16    1 有寄存器操作  0 无
//18    操作许可 1许可 0不许可
//19    延时1ms
wire                update_en;
assign              update_en = (update_dly == 2'b10) && ({o_apb_data[16],o_apb_data[18]} == 2'b11);
always @(posedge i_clk ) begin
    if(i_apb_data[31] == 1'b1)begin
        lens <= 16'd0;
    end
    else if(update_en)begin
        lens <= lens +1'b1;
    end
    else begin
        lens <= lens;
    end
end
////////////////////////////////////////////////////////
// wire       [9:0]          rom_addr = ((lens[9:0]>= (10 - 1) )&& (lens[9:0]<= (521 - 1))) ? lens[9:0] - (10 - 1) : 0; 
wire       [10:0]          rom_addr = lens; 
wire       [15:0]          rom_data;
reg        [31:0]          apb_data ;
// Gowin_ROM16 i2c_reg_rom(
//     .dout                               (rom_data                  ),//output [15:0] dout
//     .ad                                 (rom_addr                  ) //input [8:0] ad
// );

Gowin_pROM i2c_reg_rom(
    .dout                               (rom_data                       ),//output [18:0] dout
    .clk                                (i_clk                          ),//input clk
    .oce                                (1'd1                           ),//input oce
    .ce                                 (1'd1    ),//input ce
    .reset                              (!i_rst_n                       ),//input reset
    .ad                                 (rom_addr                       ) //input [9:0] ad
);
////////////////////////////////////////////////////////
always @(posedge i_clk ) begin
    if(i_apb_data[31] == 1'b1)begin
        {o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'hf0};    //复位要三次
    end
    else if(update_en)begin
        case (lens)
            16'd000  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'hf0};
            16'd001  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'hf0};      
            16'd002  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b1,1'b1,8'hf0,8'h00};      //回读ID f0
            16'd003  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b1,1'b1,8'hf1,8'h00};      //回读ID f1
            16'd004  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfc,8'h06};
            16'd005  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hf6,8'h00};
            16'd006  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hf7,8'h1d};
            16'd007  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hf8,8'h84};
            16'd008  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hf9,8'hfe};
            16'd009  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            // 16'd010  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h03,8'h04};
            // 16'd011  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h04,8'he2};
            // 16'd012  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h09,8'h00};
            // 16'd013  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0a,8'h00};
            // 16'd014  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0b,8'h00};
            // 16'd015  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0c,8'h00};
            // 16'd016  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0d,8'h04};
            // 16'd017  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0e,8'hc0};
            // 16'd018  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0f,8'h06};
            // 16'd019  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h10,8'h52};
            // 16'd020  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h12,8'h2e};
            // 16'd021  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h17,8'h14};
            // 16'd022  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h18,8'h22};
            // 16'd023  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h19,8'h0e};
            // 16'd024  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1a,8'h01};
            // 16'd025  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1b,8'h4b};
            // 16'd026  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1c,8'h07};
            // 16'd027  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1d,8'h10};
            // 16'd028  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1e,8'h88};
            // 16'd029  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1f,8'h78};
            // 16'd030  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h20,8'h03};
            // 16'd031  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h21,8'h40};
            // 16'd032  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h22,8'ha0};
            // 16'd033  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h24,8'h16};
            // 16'd034  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h25,8'h01};
            // 16'd035  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h26,8'h10};
            // 16'd036  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2d,8'h60};
            // 16'd037  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h30,8'h01};
            // 16'd038  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h31,8'h90};
            // 16'd039  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h33,8'h06};
            // 16'd040  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h34,8'h01};
            // 16'd041  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h80,8'h7f};
            // 16'd042  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h81,8'h26};
            // 16'd043  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h82,8'hfa};
            // 16'd044  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h83,8'h00};
            // 16'd045  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h84,8'h02};        //输出模式 8'h6 -->RGB    8'h02 --> YUV422  YUYV YUYV
            // 16'd046  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h86,8'h03};
            // 16'd047  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h88,8'h03};
            // 16'd048  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h89,8'h03};
            // 16'd049  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h85,8'h08};
            // 16'd050  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h8a,8'h00};
            // 16'd051  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h8b,8'h00};
            // 16'd052  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb0,8'h55};
            // 16'd053  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc3,8'h00};
            // 16'd054  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc4,8'h80};
            // 16'd055  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc5,8'h90};
            // 16'd056  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc6,8'h3b};
            // 16'd057  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc7,8'h46};
            // 16'd058  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hec,8'h06};
            // 16'd059  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hed,8'h04};
            // 16'd060  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hee,8'h60};
            // 16'd061  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hef,8'h90};
            // 16'd062  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb6,8'h01};
            // 16'd063  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h90,8'h01};
            // 16'd064  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h91,8'h00};
            // 16'd065  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h92,8'h00};
            // 16'd066  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h93,8'h00};
            // 16'd067  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h94,8'h00};
            // 16'd068  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h95,8'h04};
            // 16'd069  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h96,8'hb0};
            // 16'd070  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h97,8'h06};
            // 16'd071  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h98,8'h40};
            // 16'd072  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h40,8'h42};
            // 16'd073  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h41,8'h00};
            // 16'd074  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h43,8'h5b};
            // 16'd075  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h5e,8'h00};
            // 16'd076  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h5f,8'h00};
            // 16'd077  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h60,8'h00};
            // 16'd078  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h61,8'h00};
            // 16'd079  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h62,8'h00};
            // 16'd080  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h63,8'h00};
            // 16'd081  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h64,8'h00};
            // 16'd082  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h65,8'h00};
            // 16'd083  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h66,8'h20};
            // 16'd084  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h67,8'h20};
            // 16'd085  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h68,8'h20};
            // 16'd086  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h69,8'h20};
            // 16'd087  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h76,8'h00};
            // 16'd088  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6a,8'h08};
            // 16'd089  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6b,8'h08};
            // 16'd090  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6c,8'h08};
            // 16'd091  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6d,8'h08};
            // 16'd092  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6e,8'h08};
            // 16'd093  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6f,8'h08};
            // 16'd094  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h70,8'h08};
            // 16'd095  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h71,8'h08};
            // 16'd096  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h76,8'h00};
            // 16'd097  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h72,8'hf0};
            // 16'd098  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h7e,8'h3c};
            // 16'd099  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h7f,8'h00};
            // 16'd100  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd101  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h48,8'h15};
            // 16'd102  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h49,8'h00};
            // 16'd103  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4b,8'h0b};
            // 16'd104  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            // 16'd105  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h09,8'h00};
            // 16'd106  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0b,8'h11};
            // 16'd107  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0c,8'h10};
            // 16'd108  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h11,8'h10};
            // 16'd109  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h13,8'h6b};
            // 16'd110  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h17,8'h00};
            // 16'd111  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1c,8'h11};
            // 16'd112  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1e,8'h61};
            // 16'd113  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1f,8'h35};
            // 16'd114  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h20,8'h40};
            // 16'd115  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h22,8'h40};
            // 16'd116  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h23,8'h20};
            // 16'd117  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd118  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0f,8'h04};
            // 16'd119  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            // 16'd120  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h12,8'h35};
            // 16'd121  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h15,8'hb0};
            // 16'd122  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h10,8'h31};
            // 16'd123  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3e,8'h28};
            // 16'd124  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3f,8'hb0};
            // 16'd125  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h40,8'h90};
            // 16'd126  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h41,8'h0f};	
            // 16'd127  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd128  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h90,8'h6c};
            // 16'd129  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h91,8'h03};
            // 16'd130  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h92,8'hcb};
            // 16'd131  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h94,8'h33};
            // 16'd132  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h95,8'h84};
            // 16'd133  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h97,8'h65};
            // 16'd134  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha2,8'h11};
            // 16'd135  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h80,8'hc1};
            // 16'd136  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h81,8'h08};
            // 16'd137  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h82,8'h05};
            // 16'd138  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h83,8'h08};
            // 16'd139  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h84,8'h0a};
            // 16'd140  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h86,8'hf0};
            // 16'd141  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h87,8'h50};
            // 16'd142  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h88,8'h15};
            // 16'd143  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h89,8'hb0};
            // 16'd144  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h8a,8'h30};
            // 16'd145  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h8b,8'h10};
            // 16'd146  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            // 16'd147  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h21,8'h04};
            // 16'd148  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd149  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha3,8'h50};
            // 16'd150  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha4,8'h20};
            // 16'd151  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha5,8'h40};
            // 16'd152  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha6,8'h80};
            // 16'd153  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hab,8'h40};
            // 16'd154  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hae,8'h0c};
            // 16'd155  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb3,8'h46};
            // 16'd156  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb4,8'h64};
            // 16'd157  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb6,8'h38};
            // 16'd158  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb7,8'h01};
            // 16'd159  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb9,8'h2b};
            // 16'd160  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3c,8'h04};
            // 16'd161  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3d,8'h15};
            // 16'd162  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4b,8'h06};
            // 16'd163  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h20};
            // 16'd164  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd165  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h10,8'h09};
            // 16'd166  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h11,8'h0d};
            // 16'd167  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h12,8'h13};
            // 16'd168  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h13,8'h19};
            // 16'd169  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h14,8'h27};
            // 16'd170  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h15,8'h37};
            // 16'd171  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h16,8'h45};
            // 16'd172  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h17,8'h53};
            // 16'd173  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h18,8'h69};
            // 16'd174  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h19,8'h7d};
            // 16'd175  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1a,8'h8f};
            // 16'd176  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1b,8'h9d};
            // 16'd177  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1c,8'ha9};
            // 16'd178  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1d,8'hbd};
            // 16'd179  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1e,8'hcd};
            // 16'd180  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h1f,8'hd9};
            // 16'd181  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h20,8'he3};
            // 16'd182  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h21,8'hea};
            // 16'd183  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h22,8'hef};
            // 16'd184  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h23,8'hf5};
            // 16'd185  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h24,8'hf9};
            // 16'd186  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h25,8'hff};
            // 16'd187  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            // 16'd188  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc6,8'h20};
            // 16'd189  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc7,8'h2b};
            // 16'd190  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            // 16'd191  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h26,8'h0f};
            // 16'd192  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h27,8'h14};
            // 16'd193  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h28,8'h19};
            // 16'd194  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h29,8'h1e};
            // 16'd195  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2a,8'h27};
            // 16'd196  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2b,8'h33};
            // 16'd197  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2c,8'h3b};
            // 16'd198  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2d,8'h45};
            // 16'd199  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2e,8'h59};
            // 16'd200  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2f,8'h69};
            // 16'd201  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h30,8'h7c};
            // 16'd202  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h31,8'h89};
            // 16'd203  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h32,8'h98};
            // 16'd204  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h33,8'hae};
            // 16'd205  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h34,8'hc0};
            // 16'd206  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h35,8'hcf};
            // 16'd207  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h36,8'hda};
            // 16'd208  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h37,8'he2};
            // 16'd209  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h38,8'he9};
            // 16'd210  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h39,8'hf3};
            // 16'd211  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3a,8'hf9};
            // 16'd212  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h3b,8'hff};
            // 16'd213  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd1,8'h32};
            // 16'd214  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd2,8'h32};
            // 16'd215  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd3,8'h40};
            // 16'd216  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd6,8'hf0};
            // 16'd217  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd7,8'h10};
            // 16'd218  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd8,8'hda};
            // 16'd219  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hdd,8'h14};
            // 16'd220  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hde,8'h86};
            // 16'd221  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hed,8'h80};
            // 16'd222  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hee,8'h00};
            // 16'd223  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hef,8'h3f};
            // 16'd224  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd8,8'hd8};
            // 16'd225  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            // 16'd226  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9f,8'h40};
            // 16'd227  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc2,8'h14};
            // 16'd228  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc3,8'h0d};
            // 16'd229  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc4,8'h0c};
            // 16'd230  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc8,8'h15};
            // 16'd231  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc9,8'h0d};
            // 16'd232  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hca,8'h0a};
            // 16'd233  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hbc,8'h24};
            // 16'd234  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hbd,8'h10};
            // 16'd235  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hbe,8'h0b};
            // 16'd236  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb6,8'h25};
            // 16'd237  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb7,8'h16};
            // 16'd238  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb8,8'h15};
            // 16'd239  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc5,8'h00};
            // 16'd240  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc6,8'h00};
            // 16'd241  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc7,8'h00};
            // 16'd242  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcb,8'h00};
            // 16'd243  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcc,8'h00};
            // 16'd244  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcd,8'h00};
            // 16'd245  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hbf,8'h07};
            // 16'd246  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc0,8'h00};
            // 16'd247  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc1,8'h00};
            // 16'd248  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb9,8'h00};
            // 16'd249  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hba,8'h00};
            // 16'd250  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hbb,8'h00};
            // 16'd251  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'haa,8'h01};
            // 16'd252  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hab,8'h01};
            // 16'd253  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hac,8'h00};
            // 16'd254  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'had,8'h05};
            // 16'd255  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hae,8'h06};
            // 16'd256  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'haf,8'h0e};
            // 16'd257  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb0,8'h0b};
            // 16'd258  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb1,8'h07};
            // 16'd259  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb2,8'h06};
            // 16'd260  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb3,8'h17};
            // 16'd261  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb4,8'h0e};
            // 16'd262  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hb5,8'h0e};
            // 16'd263  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd0,8'h09};
            // 16'd264  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd1,8'h00};
            // 16'd265  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd2,8'h00};
            // 16'd266  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd6,8'h08};
            // 16'd267  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd7,8'h00};
            // 16'd268  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd8,8'h00};
            // 16'd269  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd9,8'h00};
            // 16'd270  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hda,8'h00};
            // 16'd271  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hdb,8'h00};
            // 16'd272  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd3,8'h0a};
            // 16'd273  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd4,8'h00};
            // 16'd274  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hd5,8'h00};
            // 16'd275  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha4,8'h00};
            // 16'd276  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha5,8'h00};
            // 16'd277  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha6,8'h77};
            // 16'd278  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha7,8'h77};
            // 16'd279  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha8,8'h77};
            // 16'd280  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha9,8'h77};
            // 16'd281  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha1,8'h80};
            // 16'd282  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha2,8'h80};
            // 16'd283  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            // 16'd284  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hdf,8'h0d};
            // 16'd285  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hdc,8'h25};
            // 16'd286  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hdd,8'h30};
            // 16'd287  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he0,8'h77};
            // 16'd288  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he1,8'h80};
            // 16'd289  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he2,8'h77};
            // 16'd290  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he3,8'h90};
            // 16'd291  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he6,8'h90};
            // 16'd292  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he7,8'ha0};
            // 16'd293  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he8,8'h90};
            // 16'd294  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he9,8'ha0};
            // 16'd295  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4f,8'h00};
            // 16'd296  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4f,8'h00};
            // 16'd297  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4b,8'h01};
            // 16'd298  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4f,8'h00};
            // 16'd299  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd300  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h71};
            // 16'd301  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h01};
            // 16'd302  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd303  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h91};
            // 16'd304  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h01};
            // 16'd305  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd306  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h70};
            // 16'd307  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h01};
            // 16'd308  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd309  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h90};
            // 16'd310  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd311  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd312  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hb0};
            // 16'd313  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd314  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd315  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8f};
            // 16'd316  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd317  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd318  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h6f};
            // 16'd319  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd320  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd321  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'haf};
            // 16'd322  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd323  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd324  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hd0};
            // 16'd325  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd326  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd327  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hf0};
            // 16'd328  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd329  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd330  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hcf};
            // 16'd331  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd332  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd333  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hef};
            // 16'd334  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h02};
            // 16'd335  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd336  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h6e};
            // 16'd337  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd338  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd339  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8e};
            // 16'd340  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd341  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd342  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hae};
            // 16'd343  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd344  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd345  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hce};
            // 16'd346  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd347  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd348  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h4d};
            // 16'd349  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd350  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd351  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h6d};
            // 16'd352  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd353  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd354  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8d};
            // 16'd355  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd356  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd357  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'had};
            // 16'd358  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd359  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd360  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hcd};
            // 16'd361  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd362  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd363  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h4c};
            // 16'd364  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd365  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd366  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h6c};
            // 16'd367  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd368  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd369  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8c};
            // 16'd370  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd371  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd372  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hac};
            // 16'd373  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd374  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd375  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hcc};
            // 16'd376  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd377  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd378  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hcb};
            // 16'd379  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd380  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd381  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h4b};
            // 16'd382  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd383  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd384  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h6b};
            // 16'd385  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd386  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd387  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8b};
            // 16'd388  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd389  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd390  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hab};
            // 16'd391  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h03};
            // 16'd392  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd393  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8a};
            // 16'd394  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd395  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd396  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'haa};
            // 16'd397  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd398  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd399  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hca};
            // 16'd400  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd401  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd402  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hca};
            // 16'd403  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd404  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd405  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hc9};
            // 16'd406  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd407  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd408  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8a};
            // 16'd409  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd410  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd411  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h89};
            // 16'd412  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd413  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd414  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'ha9};
            // 16'd415  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h04};
            // 16'd416  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd417  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h0b};
            // 16'd418  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd419  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd420  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h0a};
            // 16'd421  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd422  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd423  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'heb};
            // 16'd424  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd425  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h01};
            // 16'd426  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hea};
            // 16'd427  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd428  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd429  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h09};
            // 16'd430  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd431  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd432  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h29};
            // 16'd433  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd434  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd435  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h2a};
            // 16'd436  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd437  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd438  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h4a};
            // 16'd439  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h05};
            // 16'd440  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd441  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h8a};
            // 16'd442  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd443  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd444  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h49};
            // 16'd445  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd446  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd447  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h69};
            // 16'd448  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd449  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd450  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h89};
            // 16'd451  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd452  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd453  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'ha9};
            // 16'd454  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd455  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd456  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h48};
            // 16'd457  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd458  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd459  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h68};
            // 16'd460  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd461  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd462  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h69};
            // 16'd463  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h06};
            // 16'd464  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd465  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hca};
            // 16'd466  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd467  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd468  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hc9};
            // 16'd469  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd470  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd471  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'he9};
            // 16'd472  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd473  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h03};
            // 16'd474  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h09};
            // 16'd475  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd476  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd477  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hc8};
            // 16'd478  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd479  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd480  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'he8};
            // 16'd481  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd482  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd483  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'ha7};
            // 16'd484  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd485  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd486  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'hc7};
            // 16'd487  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd488  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h02};
            // 16'd489  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'he7};
            // 16'd490  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd491  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4c,8'h03};
            // 16'd492  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4d,8'h07};
            // 16'd493  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4e,8'h07};
            // 16'd494  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h4f,8'h01};
            // 16'd495  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h50,8'h80};
            // 16'd496  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h51,8'ha8};
            // 16'd497  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h52,8'h47};
            // 16'd498  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h53,8'h38};
            // 16'd499  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h54,8'hc7};
            // 16'd500  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h56,8'h0e};
            // 16'd501  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h58,8'h08};
            // 16'd502  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h5b,8'h00};
            // 16'd503  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h5c,8'h74};
            // 16'd504  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h5d,8'h8b};
            // 16'd505  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h61,8'hdb};
            // 16'd506  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h62,8'hb8};
            // 16'd507  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h63,8'h86};
            // 16'd508  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h64,8'hc0};
            // 16'd509  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h65,8'h04};
            // 16'd510  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h67,8'ha8};
            // 16'd511  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h68,8'hb0};
            // 16'd512  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h69,8'h00};
            // 16'd513  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6a,8'ha8};
            // 16'd514  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6b,8'hb0};
            // 16'd515  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6c,8'haf};
            // 16'd516  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6d,8'h8b};
            // 16'd517  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6e,8'h50};
            // 16'd518  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h6f,8'h18};
            // 16'd519  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h73,8'hf0};
            // 16'd520  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h70,8'h0d};
            // 16'd521  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h71,8'h60};
            16'd522  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h72,8'h80};
            16'd523  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h74,8'h01};
            16'd524  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h75,8'h01};
            16'd525  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h7f,8'h0c};
            16'd526  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h76,8'h70};
            16'd527  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h77,8'h58};
            16'd528  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h78,8'ha0};
            16'd529  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h79,8'h5e};
            16'd530  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h7a,8'h54};
            16'd531  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h7b,8'h58};
            16'd532  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            16'd533  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc0,8'h01};
            16'd534  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc1,8'h44};
            16'd535  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc2,8'hfd};
            16'd536  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc3,8'h04};
            16'd537  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc4,8'hF0};
            16'd538  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc5,8'h48};
            16'd539  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc6,8'hfd};
            16'd540  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc7,8'h46};
            16'd541  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc8,8'hfd};
            16'd542  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hc9,8'h02};
            16'd543  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hca,8'he0};
            16'd544  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcb,8'h45};
            16'd545  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcc,8'hec};
            16'd546  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcd,8'h48};
            16'd547  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hce,8'hf0};
            16'd548  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hcf,8'hf0};
            16'd549  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he3,8'h0c};
            16'd550  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he4,8'h4b};
            16'd551  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'he5,8'he0};
            16'd552  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            16'd553  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9f,8'h40};
            16'd554  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            16'd555  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hf2,8'h0f};
            16'd556  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            16'd557  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h40,8'hbf};
            16'd558  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h46,8'hcf};
            16'd559  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            16'd560  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h05,8'h01};
            16'd561  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h06,8'h30};
            16'd562  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h07,8'h00};
            16'd563  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h08,8'h0c};
            16'd564  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            16'd565  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h25,8'h01};
            16'd566  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h26,8'h75};
            16'd567  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h27,8'h01};
            16'd568  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h28,8'h75};
            16'd569  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h29,8'h01};
            16'd570  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2a,8'h75};
            16'd571  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2b,8'h01};
            16'd572  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2c,8'h75};
            16'd573  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2d,8'h01};
            16'd574  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h2e,8'h75};
            16'd575  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            16'd576  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            16'd577  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b1,1'b0,1'b1,8'h00,8'h0a};    //延时10ms
            16'd578  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfd,8'h01};
            16'd579  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfa,8'h00};
            16'd580  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h99,8'h11};
            16'd581  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9a,8'h06};
            16'd582  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9b,8'h01};
            16'd583  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9c,8'h23};
            16'd584  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9d,8'h00};
            16'd585  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9e,8'h00};
            16'd586  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9f,8'h01};
            16'd587  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha0,8'h23};
            16'd588  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha1,8'h00};
            16'd589  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'ha2,8'h00};
            16'd590  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h90,8'h01};
            16'd591  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h91,8'h00};
            16'd592  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h92,8'h00};
            16'd593  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h93,8'h00};
            16'd594  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h94,8'h00};
            16'd595  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h95,8'h02};        //600
            16'd596  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h96,8'h58};
            16'd597  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h97,8'h03};        //800
            16'd598  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h98,8'h20};
            16'd599  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hec,8'h02};
            16'd600  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hed,8'h02};
            16'd601  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hee,8'h30};
            16'd602  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hef,8'h48};
            16'd603  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h02};
            16'd604  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h9d,8'h08};
            16'd605  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h01};
            16'd606  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h74,8'h00};
            16'd607  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h01,8'h04};
            16'd608  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h02,8'h60};
            16'd609  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h03,8'h02};
            16'd610  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h04,8'h48};
            16'd611  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h05,8'h18};
            16'd612  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h06,8'h50};
            16'd613  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h07,8'h10};
            16'd614  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h08,8'h38};
            16'd615  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h0a,8'h80};
            16'd616  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h21,8'h04};
            16'd617  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'hfe,8'h00};
            16'd618  :{o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,8'h20,8'h03};            
                 
            default: begin
                if((lens >= 10) && (lens <= 521))
                    {o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b1,rom_data};
                else 
                    {o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b0,8'hfe,8'hf0};
                // {o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b0,8'hfe,8'hf0};
            end
        endcase

        // if((lens >= 0) && (lens <= 618))
        //     {o_apb_data[19],o_apb_data[17:0]} <= rom_data;
        // else 
        //     {o_apb_data[19],o_apb_data[17:0]} <= {1'b0,1'b0,1'b0,8'hfe,8'hf0};
    end
    else begin
        {o_apb_data[19],o_apb_data[17:0]} <= {o_apb_data[19],o_apb_data[17:0]};
    end
end


always @(posedge i_clk ) begin
    if(i_apb_data[29] == 1'b0)begin
        o_apb_data[18] <= 1'b1;
    end
    else if(time_cnt_buff >= CLK_REQ)begin
        o_apb_data[18] <= 1'b0;
    end
    else if(time_cnt < time_cnt_buff)begin
        o_apb_data[18] <= 1'b1;
    end
    else begin
        o_apb_data[18] <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    o_apb_data[31:20] <= 14'd0;
end


endmodule //i2c_reg_buff


//.c配置
       
// void gc2145_mipi_yuv_800X600_init(void)
// 	{
// 		u8 u8RdData = 0;
//         Gc2145CmosSetReg(0xfe,0xf0);        //寄存器复位  如果复位一次无法回读寄存器
//         Gc2145CmosSetReg(0xfe,0xf0);
//         Gc2145CmosSetReg(0xfe,0xf0);
// 		printf("===gc2145 mipi_yuv_800*600 configuring===\n\r");
// 		Gc2145CmosGetReg(0xf0, &u8RdData);
//         printf("ID f0----->%x\n\r",u8RdData);
//         Gc2145CmosGetReg(0xf1, &u8RdData);
//         printf("ID f1----->%x\n\r",u8RdData);

//         Gc2145CmosSetReg(0xfc,0x06);
//         Gc2145CmosSetReg(0xf6,0x00);
//         Gc2145CmosSetReg(0xf7,0x1d);
//         Gc2145CmosSetReg(0xf8,0x84);
//         // Gc2145CmosSetReg(0xfa,0x11);
//         Gc2145CmosSetReg(0xf9,0xfe);
//         // Gc2145CmosSetReg(0xf2,0x00);

//         Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0x03,0x04);
//         Gc2145CmosSetReg(0x04,0xe2);
//         Gc2145CmosSetReg(0x09,0x00);
//         Gc2145CmosSetReg(0x0a,0x00);
//         Gc2145CmosSetReg(0x0b,0x00);
//         Gc2145CmosSetReg(0x0c,0x00);
//         Gc2145CmosSetReg(0x0d,0x04);
//         Gc2145CmosSetReg(0x0e,0xc0);
//         Gc2145CmosSetReg(0x0f,0x06);
//         Gc2145CmosSetReg(0x10,0x52);
//         Gc2145CmosSetReg(0x12,0x2e);
//         Gc2145CmosSetReg(0x17,0x14);
//         Gc2145CmosSetReg(0x18,0x22);
//         Gc2145CmosSetReg(0x19,0x0e);
//         Gc2145CmosSetReg(0x1a,0x01);
//         Gc2145CmosSetReg(0x1b,0x4b);
//         Gc2145CmosSetReg(0x1c,0x07);
//         Gc2145CmosSetReg(0x1d,0x10);
//         Gc2145CmosSetReg(0x1e,0x88);
//         Gc2145CmosSetReg(0x1f,0x78);
//         Gc2145CmosSetReg(0x20,0x03);
//         Gc2145CmosSetReg(0x21,0x40);
//         Gc2145CmosSetReg(0x22,0xa0);
//         Gc2145CmosSetReg(0x24,0x16);
//         Gc2145CmosSetReg(0x25,0x01);
//         Gc2145CmosSetReg(0x26,0x10);
//         Gc2145CmosSetReg(0x2d,0x60);
//         Gc2145CmosSetReg(0x30,0x01);
//         Gc2145CmosSetReg(0x31,0x90);
//         Gc2145CmosSetReg(0x33,0x06);
//         Gc2145CmosSetReg(0x34,0x01);

//         // Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0x80,0x7f);
//         Gc2145CmosSetReg(0x81,0x26);
//         Gc2145CmosSetReg(0x82,0xfa);
//         Gc2145CmosSetReg(0x83,0x00);
//         Gc2145CmosSetReg(0x84,0x03);        //输出模式 0x6 -->RGB    0x02 --> YUV422  YUYV YUYV
//         Gc2145CmosSetReg(0x86,0x03);
//         Gc2145CmosSetReg(0x88,0x03);
//         Gc2145CmosSetReg(0x89,0x03);
//         Gc2145CmosSetReg(0x85,0x08);
//         Gc2145CmosSetReg(0x8a,0x00);
//         Gc2145CmosSetReg(0x8b,0x00);
//         Gc2145CmosSetReg(0xb0,0x55);
//         Gc2145CmosSetReg(0xc3,0x00);
//         Gc2145CmosSetReg(0xc4,0x80);
//         Gc2145CmosSetReg(0xc5,0x90);
//         Gc2145CmosSetReg(0xc6,0x3b);
//         Gc2145CmosSetReg(0xc7,0x46);
//         Gc2145CmosSetReg(0xec,0x06);
//         Gc2145CmosSetReg(0xed,0x04);
//         Gc2145CmosSetReg(0xee,0x60);
//         Gc2145CmosSetReg(0xef,0x90);
//         Gc2145CmosSetReg(0xb6,0x01);
//         Gc2145CmosSetReg(0x90,0x01);
//         Gc2145CmosSetReg(0x91,0x00);
//         Gc2145CmosSetReg(0x92,0x00);
//         Gc2145CmosSetReg(0x93,0x00);
//         Gc2145CmosSetReg(0x94,0x00);
//         Gc2145CmosSetReg(0x95,0x04);
//         Gc2145CmosSetReg(0x96,0xb0);
//         Gc2145CmosSetReg(0x97,0x06);
//         Gc2145CmosSetReg(0x98,0x40);

//         // Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0x40,0x42);
//         Gc2145CmosSetReg(0x41,0x00);
//         Gc2145CmosSetReg(0x43,0x5b);
//         Gc2145CmosSetReg(0x5e,0x00);
//         Gc2145CmosSetReg(0x5f,0x00);
//         Gc2145CmosSetReg(0x60,0x00);
//         Gc2145CmosSetReg(0x61,0x00);
//         Gc2145CmosSetReg(0x62,0x00);
//         Gc2145CmosSetReg(0x63,0x00);
//         Gc2145CmosSetReg(0x64,0x00);
//         Gc2145CmosSetReg(0x65,0x00);
//         Gc2145CmosSetReg(0x66,0x20);
//         Gc2145CmosSetReg(0x67,0x20);
//         Gc2145CmosSetReg(0x68,0x20);
//         Gc2145CmosSetReg(0x69,0x20);
//         Gc2145CmosSetReg(0x76,0x00);
//         Gc2145CmosSetReg(0x6a,0x08);
//         Gc2145CmosSetReg(0x6b,0x08);
//         Gc2145CmosSetReg(0x6c,0x08);
//         Gc2145CmosSetReg(0x6d,0x08);
//         Gc2145CmosSetReg(0x6e,0x08);
//         Gc2145CmosSetReg(0x6f,0x08);
//         Gc2145CmosSetReg(0x70,0x08);
//         Gc2145CmosSetReg(0x71,0x08);
//         Gc2145CmosSetReg(0x76,0x00);
//         Gc2145CmosSetReg(0x72,0xf0);
//         Gc2145CmosSetReg(0x7e,0x3c);
//         Gc2145CmosSetReg(0x7f,0x00);
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x48,0x15);
//         Gc2145CmosSetReg(0x49,0x00);
//         Gc2145CmosSetReg(0x4b,0x0b);
//         // Gc2145CmosSetReg(0xfe,0x00);    

//         Gc2145CmosSetReg(0xfe,0x01);
//         // Gc2145CmosSetReg(0x01,0x04);
//         // Gc2145CmosSetReg(0x02,0xc0);
//         // Gc2145CmosSetReg(0x03,0x04);
//         // Gc2145CmosSetReg(0x04,0x90);
//         // Gc2145CmosSetReg(0x05,0x30);
//         // Gc2145CmosSetReg(0x06,0x90);
//         // Gc2145CmosSetReg(0x07,0x30);
//         // Gc2145CmosSetReg(0x08,0x80);
//         Gc2145CmosSetReg(0x09,0x00);
//         // Gc2145CmosSetReg(0x0a,0x82);
//         Gc2145CmosSetReg(0x0b,0x11);
//         Gc2145CmosSetReg(0x0c,0x10);
//         Gc2145CmosSetReg(0x11,0x10);
//         Gc2145CmosSetReg(0x13,0x6b);
//         Gc2145CmosSetReg(0x17,0x00);
//         Gc2145CmosSetReg(0x1c,0x11);
//         Gc2145CmosSetReg(0x1e,0x61);
//         Gc2145CmosSetReg(0x1f,0x35);
//         Gc2145CmosSetReg(0x20,0x40);
//         Gc2145CmosSetReg(0x22,0x40);
//         Gc2145CmosSetReg(0x23,0x20);
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x0f,0x04);
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x12,0x35);
//         Gc2145CmosSetReg(0x15,0xb0);
//         Gc2145CmosSetReg(0x10,0x31);
//         Gc2145CmosSetReg(0x3e,0x28);
//         Gc2145CmosSetReg(0x3f,0xb0);
//         Gc2145CmosSetReg(0x40,0x90);
//         Gc2145CmosSetReg(0x41,0x0f);	

//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x90,0x6c);
//         Gc2145CmosSetReg(0x91,0x03);
//         Gc2145CmosSetReg(0x92,0xcb);
//         Gc2145CmosSetReg(0x94,0x33);
//         Gc2145CmosSetReg(0x95,0x84);
//         Gc2145CmosSetReg(0x97,0x65);
//         Gc2145CmosSetReg(0xa2,0x11);
//         // Gc2145CmosSetReg(0xfe,0x00);

//         // Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x80,0xc1);
//         Gc2145CmosSetReg(0x81,0x08);
//         Gc2145CmosSetReg(0x82,0x05);
//         Gc2145CmosSetReg(0x83,0x08);
//         Gc2145CmosSetReg(0x84,0x0a);
//         Gc2145CmosSetReg(0x86,0xf0);
//         Gc2145CmosSetReg(0x87,0x50);
//         Gc2145CmosSetReg(0x88,0x15);
//         Gc2145CmosSetReg(0x89,0xb0);
//         Gc2145CmosSetReg(0x8a,0x30);
//         Gc2145CmosSetReg(0x8b,0x10);

//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x21,0x04);
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0xa3,0x50);
//         Gc2145CmosSetReg(0xa4,0x20);
//         Gc2145CmosSetReg(0xa5,0x40);
//         Gc2145CmosSetReg(0xa6,0x80);
//         Gc2145CmosSetReg(0xab,0x40);
//         Gc2145CmosSetReg(0xae,0x0c);
//         Gc2145CmosSetReg(0xb3,0x46);
//         Gc2145CmosSetReg(0xb4,0x64);
//         Gc2145CmosSetReg(0xb6,0x38);
//         Gc2145CmosSetReg(0xb7,0x01);
//         Gc2145CmosSetReg(0xb9,0x2b);
//         Gc2145CmosSetReg(0x3c,0x04);
//         Gc2145CmosSetReg(0x3d,0x15);
//         Gc2145CmosSetReg(0x4b,0x06);
//         Gc2145CmosSetReg(0x4c,0x20);
//         // Gc2145CmosSetReg(0xfe,0x00);

//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x10,0x09);
//         Gc2145CmosSetReg(0x11,0x0d);
//         Gc2145CmosSetReg(0x12,0x13);
//         Gc2145CmosSetReg(0x13,0x19);
//         Gc2145CmosSetReg(0x14,0x27);
//         Gc2145CmosSetReg(0x15,0x37);
//         Gc2145CmosSetReg(0x16,0x45);
//         Gc2145CmosSetReg(0x17,0x53);
//         Gc2145CmosSetReg(0x18,0x69);
//         Gc2145CmosSetReg(0x19,0x7d);
//         Gc2145CmosSetReg(0x1a,0x8f);
//         Gc2145CmosSetReg(0x1b,0x9d);
//         Gc2145CmosSetReg(0x1c,0xa9);
//         Gc2145CmosSetReg(0x1d,0xbd);
//         Gc2145CmosSetReg(0x1e,0xcd);
//         Gc2145CmosSetReg(0x1f,0xd9);
//         Gc2145CmosSetReg(0x20,0xe3);
//         Gc2145CmosSetReg(0x21,0xea);
//         Gc2145CmosSetReg(0x22,0xef);
//         Gc2145CmosSetReg(0x23,0xf5);
//         Gc2145CmosSetReg(0x24,0xf9);
//         Gc2145CmosSetReg(0x25,0xff);
//         Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0xc6,0x20);
//         Gc2145CmosSetReg(0xc7,0x2b);
         
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x26,0x0f);
//         Gc2145CmosSetReg(0x27,0x14);
//         Gc2145CmosSetReg(0x28,0x19);
//         Gc2145CmosSetReg(0x29,0x1e);
//         Gc2145CmosSetReg(0x2a,0x27);
//         Gc2145CmosSetReg(0x2b,0x33);
//         Gc2145CmosSetReg(0x2c,0x3b);
//         Gc2145CmosSetReg(0x2d,0x45);
//         Gc2145CmosSetReg(0x2e,0x59);
//         Gc2145CmosSetReg(0x2f,0x69);
//         Gc2145CmosSetReg(0x30,0x7c);
//         Gc2145CmosSetReg(0x31,0x89);
//         Gc2145CmosSetReg(0x32,0x98);
//         Gc2145CmosSetReg(0x33,0xae);
//         Gc2145CmosSetReg(0x34,0xc0);
//         Gc2145CmosSetReg(0x35,0xcf);
//         Gc2145CmosSetReg(0x36,0xda);
//         Gc2145CmosSetReg(0x37,0xe2);
//         Gc2145CmosSetReg(0x38,0xe9);
//         Gc2145CmosSetReg(0x39,0xf3);
//         Gc2145CmosSetReg(0x3a,0xf9);
//         Gc2145CmosSetReg(0x3b,0xff);
         
//         // Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0xd1,0x32);
//         Gc2145CmosSetReg(0xd2,0x32);
//         Gc2145CmosSetReg(0xd3,0x40);
//         Gc2145CmosSetReg(0xd6,0xf0);
//         Gc2145CmosSetReg(0xd7,0x10);
//         Gc2145CmosSetReg(0xd8,0xda);
//         Gc2145CmosSetReg(0xdd,0x14);
//         Gc2145CmosSetReg(0xde,0x86);
//         Gc2145CmosSetReg(0xed,0x80);
//         Gc2145CmosSetReg(0xee,0x00);
//         Gc2145CmosSetReg(0xef,0x3f);
//         Gc2145CmosSetReg(0xd8,0xd8);
         
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x9f,0x40);
         
//         // Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0xc2,0x14);
//         Gc2145CmosSetReg(0xc3,0x0d);
//         Gc2145CmosSetReg(0xc4,0x0c);
//         Gc2145CmosSetReg(0xc8,0x15);
//         Gc2145CmosSetReg(0xc9,0x0d);
//         Gc2145CmosSetReg(0xca,0x0a);
//         Gc2145CmosSetReg(0xbc,0x24);
//         Gc2145CmosSetReg(0xbd,0x10);
//         Gc2145CmosSetReg(0xbe,0x0b);
//         Gc2145CmosSetReg(0xb6,0x25);
//         Gc2145CmosSetReg(0xb7,0x16);
//         Gc2145CmosSetReg(0xb8,0x15);
//         Gc2145CmosSetReg(0xc5,0x00);
//         Gc2145CmosSetReg(0xc6,0x00);
//         Gc2145CmosSetReg(0xc7,0x00);
//         Gc2145CmosSetReg(0xcb,0x00);
//         Gc2145CmosSetReg(0xcc,0x00);
//         Gc2145CmosSetReg(0xcd,0x00);
//         Gc2145CmosSetReg(0xbf,0x07);
//         Gc2145CmosSetReg(0xc0,0x00);
//         Gc2145CmosSetReg(0xc1,0x00);
//         Gc2145CmosSetReg(0xb9,0x00);
//         Gc2145CmosSetReg(0xba,0x00);
//         Gc2145CmosSetReg(0xbb,0x00);
//         Gc2145CmosSetReg(0xaa,0x01);
//         Gc2145CmosSetReg(0xab,0x01);
//         Gc2145CmosSetReg(0xac,0x00);
//         Gc2145CmosSetReg(0xad,0x05);
//         Gc2145CmosSetReg(0xae,0x06);
//         Gc2145CmosSetReg(0xaf,0x0e);
//         Gc2145CmosSetReg(0xb0,0x0b);
//         Gc2145CmosSetReg(0xb1,0x07);
//         Gc2145CmosSetReg(0xb2,0x06);
//         Gc2145CmosSetReg(0xb3,0x17);
//         Gc2145CmosSetReg(0xb4,0x0e);
//         Gc2145CmosSetReg(0xb5,0x0e);
//         Gc2145CmosSetReg(0xd0,0x09);
//         Gc2145CmosSetReg(0xd1,0x00);
//         Gc2145CmosSetReg(0xd2,0x00);
//         Gc2145CmosSetReg(0xd6,0x08);
//         Gc2145CmosSetReg(0xd7,0x00);
//         Gc2145CmosSetReg(0xd8,0x00);
//         Gc2145CmosSetReg(0xd9,0x00);
//         Gc2145CmosSetReg(0xda,0x00);
//         Gc2145CmosSetReg(0xdb,0x00);
//         Gc2145CmosSetReg(0xd3,0x0a);
//         Gc2145CmosSetReg(0xd4,0x00);
//         Gc2145CmosSetReg(0xd5,0x00);
//         Gc2145CmosSetReg(0xa4,0x00);
//         Gc2145CmosSetReg(0xa5,0x00);
//         Gc2145CmosSetReg(0xa6,0x77);
//         Gc2145CmosSetReg(0xa7,0x77);
//         Gc2145CmosSetReg(0xa8,0x77);
//         Gc2145CmosSetReg(0xa9,0x77);
//         Gc2145CmosSetReg(0xa1,0x80);
//         Gc2145CmosSetReg(0xa2,0x80);
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0xdf,0x0d);
//         Gc2145CmosSetReg(0xdc,0x25);
//         Gc2145CmosSetReg(0xdd,0x30);
//         Gc2145CmosSetReg(0xe0,0x77);
//         Gc2145CmosSetReg(0xe1,0x80);
//         Gc2145CmosSetReg(0xe2,0x77);
//         Gc2145CmosSetReg(0xe3,0x90);
//         Gc2145CmosSetReg(0xe6,0x90);
//         Gc2145CmosSetReg(0xe7,0xa0);
//         Gc2145CmosSetReg(0xe8,0x90);
//         Gc2145CmosSetReg(0xe9,0xa0);
//         // Gc2145CmosSetReg(0xfe,0x00);
         
//         // Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x4f,0x00);
//         Gc2145CmosSetReg(0x4f,0x00);
//         Gc2145CmosSetReg(0x4b,0x01);
//         Gc2145CmosSetReg(0x4f,0x00);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x71);
//         Gc2145CmosSetReg(0x4e,0x01);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x91);
//         Gc2145CmosSetReg(0x4e,0x01);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x70);
//         Gc2145CmosSetReg(0x4e,0x01);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x90);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xb0);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8f);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x6f);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xaf);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xd0);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xf0);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xcf);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xef);
//         Gc2145CmosSetReg(0x4e,0x02);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x6e);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8e);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xae);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xce);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x4d);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x6d);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8d);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xad);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xcd);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x4c);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x6c);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8c);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xac);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xcc);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xcb);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x4b);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x6b);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8b);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xab);
//         Gc2145CmosSetReg(0x4e,0x03);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8a);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xaa);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xca);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xca);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xc9);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x8a);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0x89);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xa9);
//         Gc2145CmosSetReg(0x4e,0x04);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x0b);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x0a);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xeb);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x01);
//         Gc2145CmosSetReg(0x4d,0xea);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x09);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x29);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x2a);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x4a);
//         Gc2145CmosSetReg(0x4e,0x05);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x8a);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x49);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x69);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x89);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xa9);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x48);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x68);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0x69);
//         Gc2145CmosSetReg(0x4e,0x06);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xca);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xc9);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xe9);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x03);
//         Gc2145CmosSetReg(0x4d,0x09);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xc8);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xe8);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xa7);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xc7);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x02);
//         Gc2145CmosSetReg(0x4d,0xe7);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4c,0x03);
//         Gc2145CmosSetReg(0x4d,0x07);
//         Gc2145CmosSetReg(0x4e,0x07);
//         Gc2145CmosSetReg(0x4f,0x01);
//         Gc2145CmosSetReg(0x50,0x80);
//         Gc2145CmosSetReg(0x51,0xa8);
//         Gc2145CmosSetReg(0x52,0x47);
//         Gc2145CmosSetReg(0x53,0x38);
//         Gc2145CmosSetReg(0x54,0xc7);
//         Gc2145CmosSetReg(0x56,0x0e);
//         Gc2145CmosSetReg(0x58,0x08);
//         Gc2145CmosSetReg(0x5b,0x00);
//         Gc2145CmosSetReg(0x5c,0x74);
//         Gc2145CmosSetReg(0x5d,0x8b);
//         Gc2145CmosSetReg(0x61,0xdb);
//         Gc2145CmosSetReg(0x62,0xb8);
//         Gc2145CmosSetReg(0x63,0x86);
//         Gc2145CmosSetReg(0x64,0xc0);
//         Gc2145CmosSetReg(0x65,0x04);
//         Gc2145CmosSetReg(0x67,0xa8);
//         Gc2145CmosSetReg(0x68,0xb0);
//         Gc2145CmosSetReg(0x69,0x00);
//         Gc2145CmosSetReg(0x6a,0xa8);
//         Gc2145CmosSetReg(0x6b,0xb0);
//         Gc2145CmosSetReg(0x6c,0xaf);
//         Gc2145CmosSetReg(0x6d,0x8b);
//         Gc2145CmosSetReg(0x6e,0x50);
//         Gc2145CmosSetReg(0x6f,0x18);
//         Gc2145CmosSetReg(0x73,0xf0);
//         Gc2145CmosSetReg(0x70,0x0d);
//         Gc2145CmosSetReg(0x71,0x60);
//         Gc2145CmosSetReg(0x72,0x80);
//         Gc2145CmosSetReg(0x74,0x01);
//         Gc2145CmosSetReg(0x75,0x01);
//         Gc2145CmosSetReg(0x7f,0x0c);
//         Gc2145CmosSetReg(0x76,0x70);
//         Gc2145CmosSetReg(0x77,0x58);
//         Gc2145CmosSetReg(0x78,0xa0);
//         Gc2145CmosSetReg(0x79,0x5e);
//         Gc2145CmosSetReg(0x7a,0x54);
//         Gc2145CmosSetReg(0x7b,0x58);
//         // Gc2145CmosSetReg(0xfe,0x00);
         
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0xc0,0x01);
//         Gc2145CmosSetReg(0xc1,0x44);
//         Gc2145CmosSetReg(0xc2,0xfd);
//         Gc2145CmosSetReg(0xc3,0x04);
//         Gc2145CmosSetReg(0xc4,0xF0);
//         Gc2145CmosSetReg(0xc5,0x48);
//         Gc2145CmosSetReg(0xc6,0xfd);
//         Gc2145CmosSetReg(0xc7,0x46);
//         Gc2145CmosSetReg(0xc8,0xfd);
//         Gc2145CmosSetReg(0xc9,0x02);
//         Gc2145CmosSetReg(0xca,0xe0);
//         Gc2145CmosSetReg(0xcb,0x45);
//         Gc2145CmosSetReg(0xcc,0xec);
//         Gc2145CmosSetReg(0xcd,0x48);
//         Gc2145CmosSetReg(0xce,0xf0);
//         Gc2145CmosSetReg(0xcf,0xf0);
//         Gc2145CmosSetReg(0xe3,0x0c);
//         Gc2145CmosSetReg(0xe4,0x4b);
//         Gc2145CmosSetReg(0xe5,0xe0);
         
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x9f,0x40);
//         // Gc2145CmosSetReg(0xfe,0x00);
         
//         Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0xf2,0x0f);
         
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x40,0xbf);
//         Gc2145CmosSetReg(0x46,0xcf);
//         Gc2145CmosSetReg(0xfe,0x00);
         
//         // Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0x05,0x01);
//         Gc2145CmosSetReg(0x06,0x30);
//         Gc2145CmosSetReg(0x07,0x00);
//         Gc2145CmosSetReg(0x08,0x0c);
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x25,0x01);
//         Gc2145CmosSetReg(0x26,0x75);
//         Gc2145CmosSetReg(0x27,0x04);
//         Gc2145CmosSetReg(0x28,0x5f);
//         Gc2145CmosSetReg(0x29,0x04);
//         Gc2145CmosSetReg(0x2a,0x5f);
//         Gc2145CmosSetReg(0x2b,0x04);
//         Gc2145CmosSetReg(0x2c,0x5f);
//         Gc2145CmosSetReg(0x2d,0x04);
//         Gc2145CmosSetReg(0x2e,0x5f);
//         // Gc2145CmosSetReg(0xfe,0x00);
         
//         Gc2145CmosSetReg(0xfe,0x00);
//         // Gc2145CmosSetReg(0xfd,0x01);
//         // Gc2145CmosSetReg(0xfa,0x11);
         
//         // Gc2145CmosSetReg(0x99,0x55);
//         // Gc2145CmosSetReg(0x9a,0x06);
//         // Gc2145CmosSetReg(0x9b,0x01);
//         // Gc2145CmosSetReg(0x9c,0x23);
//         // Gc2145CmosSetReg(0x9d,0x00);
//         // Gc2145CmosSetReg(0x9e,0x00);
//         // Gc2145CmosSetReg(0x9f,0x01);
//         // Gc2145CmosSetReg(0xa0,0x23);
//         // Gc2145CmosSetReg(0xa1,0x00);
//         // Gc2145CmosSetReg(0xa2,0x00);
         
//         // Gc2145CmosSetReg(0xfe,0x00);
//         // Gc2145CmosSetReg(0x90,0x01);
//         // Gc2145CmosSetReg(0x91,0x00);
//         // Gc2145CmosSetReg(0x92,0x00);
//         // Gc2145CmosSetReg(0x93,0x00);
//         // Gc2145CmosSetReg(0x94,0x00);
//         // Gc2145CmosSetReg(0x95,0x01);
//         // Gc2145CmosSetReg(0x96,0xe0);
//         // Gc2145CmosSetReg(0x97,0x02);
//         // Gc2145CmosSetReg(0x98,0x80);
//         // Gc2145CmosSetReg(0x99,0x11);
//         // Gc2145CmosSetReg(0x9a,0x06);
         
//         // Gc2145CmosSetReg(0xfe,0x00);
//         // Gc2145CmosSetReg(0xec,0x02);
//         // Gc2145CmosSetReg(0xed,0x02);
//         // Gc2145CmosSetReg(0xee,0x30);
//         // Gc2145CmosSetReg(0xef,0x48);
//         // Gc2145CmosSetReg(0xfe,0x02);
//         // Gc2145CmosSetReg(0x9d,0x08);
//         // Gc2145CmosSetReg(0xfe,0x01);
//         // Gc2145CmosSetReg(0x74,0x00);

//         // Gc2145CmosSetReg(0xfe,0x01);
//         // Gc2145CmosSetReg(0x01,0x04);
//         // Gc2145CmosSetReg(0x02,0x60);
//         // Gc2145CmosSetReg(0x03,0x02);
//         // Gc2145CmosSetReg(0x04,0x48);
//         // Gc2145CmosSetReg(0x05,0x18);
//         // Gc2145CmosSetReg(0x06,0x50);
//         // Gc2145CmosSetReg(0x07,0x10);
//         // Gc2145CmosSetReg(0x08,0x38);
//         // Gc2145CmosSetReg(0x0a,0x80);
//         // Gc2145CmosSetReg(0x21,0x04);
//         Gc2145CmosSetReg(0xfe,0x00);
//         // Gc2145CmosSetReg(0x20,0x03);
//         // Gc2145CmosSetReg(0xfe,0x00);
//         delay_ms(10);	
// 		printf("===gc2145 mipi_yuv_800*600 configured===\n\r");
// };
// //
// // TURN VIS STREAM ON
// 	void gc2145_stream_on(void)
// 	{
// 		printf("===gc2145 stream on===\n");
		
// 		// delay_us(10000);
//         // Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0xfd,0x01);
//         Gc2145CmosSetReg(0xfa,0x00);
//         Gc2145CmosSetReg(0x99,0x11);
//         Gc2145CmosSetReg(0x9a,0x06);
//         Gc2145CmosSetReg(0x9b,0x01);
//         Gc2145CmosSetReg(0x9c,0x23);
//         Gc2145CmosSetReg(0x9d,0x00);
//         Gc2145CmosSetReg(0x9e,0x00);
//         Gc2145CmosSetReg(0x9f,0x01);
//         Gc2145CmosSetReg(0xa0,0x23);
//         Gc2145CmosSetReg(0xa1,0x00);
//         Gc2145CmosSetReg(0xa2,0x00);
//         Gc2145CmosSetReg(0x90,0x01);
//         Gc2145CmosSetReg(0x91,0x00);
//         Gc2145CmosSetReg(0x92,0x00);
//         Gc2145CmosSetReg(0x93,0x00);
//         Gc2145CmosSetReg(0x94,0x00);
//         Gc2145CmosSetReg(0x95,0x02);        //600
//         Gc2145CmosSetReg(0x96,0x58);
//         Gc2145CmosSetReg(0x97,0x03);        //800
//         Gc2145CmosSetReg(0x98,0x20);
//         // Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0xec,0x02);
//         Gc2145CmosSetReg(0xed,0x02);
//         Gc2145CmosSetReg(0xee,0x30);
//         Gc2145CmosSetReg(0xef,0x48);
//         Gc2145CmosSetReg(0xfe,0x02);
//         Gc2145CmosSetReg(0x9d,0x08);
//         Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x74,0x00);
//         // Gc2145CmosSetReg(0xfe,0x01);
//         Gc2145CmosSetReg(0x01,0x04);
//         Gc2145CmosSetReg(0x02,0x60);
//         Gc2145CmosSetReg(0x03,0x02);
//         Gc2145CmosSetReg(0x04,0x48);
//         Gc2145CmosSetReg(0x05,0x18);
//         Gc2145CmosSetReg(0x06,0x50);
//         Gc2145CmosSetReg(0x07,0x10);
//         Gc2145CmosSetReg(0x08,0x38);
//         Gc2145CmosSetReg(0x0a,0x80);
//         Gc2145CmosSetReg(0x21,0x04);
//         Gc2145CmosSetReg(0xfe,0x00);
//         Gc2145CmosSetReg(0x20,0x03);
//         // Gc2145CmosSetReg(0xfe,0x00);
//         printf("===gc2145 stream end===\n");
// 	}
// //