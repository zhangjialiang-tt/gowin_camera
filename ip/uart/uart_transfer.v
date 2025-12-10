module uart_transfer #(
    parameter CLK_FREQUENCY = 60_000_000                ,   //  模块工作时钟
    parameter BAUD_RATE     = 115_200                   ,   //  波特率
    parameter CHECK_MODE    = "NO"                      ,   //  奇偶校验，NO / ODD / EVEN
    parameter CNT_NUM       = CLK_FREQUENCY / BAUD_RATE ,   //  （无需例化）单 bit 持续时钟数
    parameter CNT_WIDTH     = $clog2(CNT_NUM)               //  （无需例化）波特率计数器位宽
) (
    input                       i_clk           ,
    input                       i_rst_n         ,

    output  reg                 o_busy          ,   //  模块忙信号
    input                       i_tx_en         ,   //  发送数据
    input           [7:0]       i_tx_data       ,

    output  reg                 o_txd            
);
//  参数定义
    reg     [CNT_WIDTH - 1:0]   baud_cnt    ;
    reg     [3:0]               bit_cnt     ;

    reg     [7:0]               data        ;

    reg     [3:0]               check       ;

//  模块忙信号
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_busy <= 1'd0;
        end
        else if (~o_busy && i_tx_en) begin
            o_busy <= 1'd1;
        end
        else if ((CHECK_MODE == "ODD" || CHECK_MODE == "EVEN") && baud_cnt == (CNT_NUM - 1) && bit_cnt == 4'd10) begin
            o_busy <= 1'd0;
        end
        else if ((CHECK_MODE != "ODD" && CHECK_MODE != "EVEN") && baud_cnt == (CNT_NUM - 1) && bit_cnt == 4'd9) begin
            o_busy <= 1'd0;
        end
        else begin
            o_busy <= o_busy;
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
        else if (o_busy) begin
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
        else if ((CHECK_MODE == "ODD" || CHECK_MODE == "EVEN") && baud_cnt == (CNT_NUM - 1) && bit_cnt == 4'd10) begin
            bit_cnt <= 1'd0;
        end
        else if ((CHECK_MODE != "ODD" && CHECK_MODE != "EVEN") && baud_cnt == (CNT_NUM - 1) && bit_cnt == 4'd9) begin
            bit_cnt <= 1'd0;
        end
        else if (baud_cnt == (CNT_NUM - 1)) begin
            bit_cnt <= bit_cnt + 1'd1;
        end
        else begin
            bit_cnt <= bit_cnt;
        end
    end

//  寄存需要发送的数据
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            data <= 1'd0;
        end
        else if (~o_busy && i_tx_en) begin
            data <= i_tx_data;
        end
        else begin
            data <= data;
        end
    end

//  计算校验
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            check <= 1'd0;
        end
        else begin
            check <= data[0] + data[1] + data[2] + data[3] + data[4] + data[5] + data[6] + data[7];
        end
    end

//  输出 TXD
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_txd <= 1'd1;
        end
        else if (o_busy) begin
            case (bit_cnt)
                4'd0   : o_txd <= 1'd0;
                4'd1   : o_txd <= data[0];
                4'd2   : o_txd <= data[1];
                4'd3   : o_txd <= data[2];
                4'd4   : o_txd <= data[3];
                4'd5   : o_txd <= data[4];
                4'd6   : o_txd <= data[5];
                4'd7   : o_txd <= data[6];
                4'd8   : o_txd <= data[7];
                4'd9   : begin
                    if (CHECK_MODE == "ODD") begin
                        o_txd <= ~check[0];
                    end
                    else if (CHECK_MODE == "EVEN") begin
                        o_txd <= check[0];
                    end
                    else begin
                        o_txd <= 1'd1;
                    end
                end
                default: o_txd <= 1'd1;
            endcase
        end
        else begin
            o_txd <= 1'd1;
        end
    end
endmodule