module signal_delay
#
(
    parameter	WIDTH_SIGNAL    = 8 ,
    parameter	DELAY_SIGNAL    = 3
)
(
    input                                       clk,
    input                                       rst,
    input       [WIDTH_SIGNAL-1:0]              in,

    output      [WIDTH_SIGNAL-1:0]              out
);

    reg         [WIDTH_SIGNAL-1:0]              dly_reg[0:DELAY_SIGNAL-1];

    genvar var_i;
    generate
        for (var_i=0;var_i<=DELAY_SIGNAL-1;var_i=var_i+1)
        begin:delay_generate_block
            if (var_i==0)
            begin
                always @ (posedge clk or posedge rst)
                if (rst)
                    dly_reg[var_i] <= 0;
                else
                    dly_reg[var_i] <= in;
            end
            else
            begin
                always @ (posedge clk or posedge rst)
                if (rst)
                    dly_reg[var_i] <= 0;
                else
                    dly_reg[var_i] <= dly_reg[var_i-1];
            end
        end
    endgenerate

    assign out = dly_reg[DELAY_SIGNAL-1];
endmodule

/*按如下模版使用本延迟模块

    signal_delay
    #
    (
        .WIDTH_SIGNAL       ( 8 ),      //输入输出信号的位宽
        .DELAY_SIGNAL       ( 3 )       //输出信号的延迟周期
    )
    name_signal_delay
    (
        .clk                ( clk ),    //输出信号时钟域
        .rst                ( rst ),    //异步复位信号
        .in                 ( in  ),    //信号输入
        .out                ( out )     //信号输出
    );

*/
