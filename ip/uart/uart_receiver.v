module uart_receiver #(
    parameter CLK_FREQUENCY = 60_000_000                ,   //  模块工作时钟
    parameter BAUD_RATE     = 115_200                   ,   //  波特率
    parameter CHECK_MODE    = "NO"                      ,   //  奇偶校验，NO / ODD / EVEN
    parameter CNT_NUM       = CLK_FREQUENCY / BAUD_RATE ,   //  （无需例化）单 bit 持续时钟数
    parameter CNT_NUM_HALF  = CNT_NUM / 2               ,   //  （无需例化）bit 采样点
    parameter CNT_WIDTH     = $clog2(CNT_NUM)               //  （无需例化）波特率计数器位宽
) (
    input                       i_clk           ,
    input                       i_rst_n         ,

    input                       i_rxd           ,
    
    output  reg                 o_rx_vld        ,   //  数据有效信号 脉冲
    output  reg     [7:0]       o_rx_data           //  接收到的数据
);
//  参数定义
    reg     [CNT_WIDTH - 1:0]   baud_cnt    ;
    reg     [3:0]               bit_cnt     ;

    reg                         rxd_r1      ;
    reg                         rxd_r2      ;
    reg                         rx_busy     ;

    reg                         check       ;

//  寄存 i_rxd 判断起始位
    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            rxd_r1 <= 1'd1;
            rxd_r2 <= 1'd1;
        end
        else begin
            rxd_r1 <= i_rxd;
            rxd_r2 <= rxd_r1;
        end
    end

//  接收状态
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            rx_busy <= 1'd0;
        end
        else if ((CHECK_MODE == "ODD" || CHECK_MODE == "EVEN") && bit_cnt == 4'd9 && baud_cnt == (CNT_NUM - 1)) begin
            rx_busy <= 1'd0;
        end
        else if (CHECK_MODE != "ODD" && CHECK_MODE != "EVEN" && bit_cnt == 4'd8 && baud_cnt == (CNT_NUM - 1)) begin
            rx_busy <= 1'd0;
        end
        else if (rxd_r2 && ~rxd_r1) begin
            rx_busy <= 1'd1;
        end
        else begin
            rx_busy <= rx_busy;
        end
    end

//  波特率计数器
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            baud_cnt <= 1'd0;
        end
        else if (baud_cnt == (CNT_NUM - 1)) begin
            baud_cnt <= 1'd0;
        end
        else if (rx_busy) begin
            baud_cnt <= baud_cnt + 1'd1;
        end
        else begin
            baud_cnt <= 1'd0;
        end
    end

//  比特计数器
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            bit_cnt <= 1'd0;
        end
        else if ((CHECK_MODE == "ODD" || CHECK_MODE == "EVEN") && bit_cnt == 4'd9 && baud_cnt == (CNT_NUM - 1)) begin
            bit_cnt <= 1'd0;
        end
        else if (CHECK_MODE != "ODD" && CHECK_MODE != "EVEN" && bit_cnt == 4'd8 && baud_cnt == (CNT_NUM - 1)) begin
            bit_cnt <= 1'd0;
        end
        else if (baud_cnt == (CNT_NUM - 1)) begin
            bit_cnt <= bit_cnt + 1'd1;
        end
        else begin
            bit_cnt <= bit_cnt;
        end
    end

//  采样数据
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_rx_data <= 1'd0;
        end
        else if (baud_cnt == (CNT_NUM_HALF - 1) && bit_cnt > 1'd0 && bit_cnt < 4'd9) begin
            o_rx_data <= {i_rxd, o_rx_data[7:1]};
        end
        else begin
            o_rx_data <= o_rx_data;
        end
    end

//  奇偶校验计算
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            check <= 1'd0;
        end
        else if (CHECK_MODE == "ODD" && bit_cnt == 1'd0) begin
            check <= 1'd1;
        end
        else if (CHECK_MODE == "ODD" && baud_cnt == (CNT_NUM_HALF - 1) && bit_cnt > 1'd0 && bit_cnt < 4'd9 && i_rxd) begin
            check <= ~check;
        end
        else if (CHECK_MODE == "EVEN" && bit_cnt == 1'd0) begin
            check <= 1'd0;
        end
        else if (CHECK_MODE == "EVEN" && baud_cnt == (CNT_NUM_HALF - 1) && bit_cnt > 1'd0 && bit_cnt < 4'd9 && i_rxd) begin
            check <= ~check;
        end
        else begin
            check <= check;
        end
    end

//  输出数据有效信号
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_rx_vld <= 1'd0;
        end
        else if (CHECK_MODE != "ODD" && CHECK_MODE != "EVEN" && baud_cnt == (CNT_NUM_HALF - 1) && bit_cnt == 4'd8) begin
            o_rx_vld <= 1'd1;
        end
        else if ((CHECK_MODE == "ODD" || CHECK_MODE == "EVEN") && baud_cnt == (CNT_NUM_HALF - 1) && bit_cnt == 4'd9 && check == i_rxd) begin
            o_rx_vld <= 1'd1;
        end
        else begin
            o_rx_vld <= 1'd0;
        end
    end
endmodule