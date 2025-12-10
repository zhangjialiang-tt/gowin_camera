module  param_parse #(
    parameter SHUTTER_OPEN = 2'b01 ,
    parameter SHUTTER_CLOS = 2'b10  
)
(
    input                   i_rst_n              ,
    input                   i_clk                ,
    input                   i_calc_b_done        ,
    input       [1:0]       i_shutter            ,
    input       [15:0]      i_temp_sensor        ,
    input       [15:0]      i_temp_lens          ,
    input       [15:0]      i_temp_shutter       ,
    output reg              o_shutter_state      ,
    output reg  [15:0]      o_temp_shutter_pre   ,
    output reg  [15:0]      o_temp_sensor_pre    ,
    output reg  [15:0]      o_temp_lens_pre      ,
    output reg  [15:0]      o_temp_shutter_start ,
    output reg  [15:0]      o_temp_lens_start      
);


reg                         shutter_state_dly   ;
reg                         flag                ;
reg                         calc_b_done_dly     ;
reg         [1:0]           shutter             ;

always @(posedge i_clk ) begin
    shutter_state_dly <= o_shutter_state;
    shutter <= i_shutter;
end

//检测快门开启、闭合状态
always @(posedge i_clk or negedge i_rst_n ) begin
    if(!i_rst_n)begin
        o_shutter_state <= 1'b0;
    end
    else if(shutter == SHUTTER_CLOS)begin
        o_shutter_state <= 1'b0;
    end
    else if(shutter == SHUTTER_OPEN)begin
        o_shutter_state <= 1'b1;
    end
    else begin
        o_shutter_state <= o_shutter_state;
    end
end

//获取开机快门温度 镜头温度
always @(posedge i_clk ) begin
    calc_b_done_dly <= i_calc_b_done;
end


always @(posedge i_clk or negedge i_rst_n ) begin
    if(!i_rst_n)begin
        flag <= 1'b0;
    end
    else if({flag,calc_b_done_dly} == 2'b01 )begin
        flag <= 1'b1;
    end
    else begin
        flag <= flag;
    end
end

//开机快门温
always @(posedge i_clk ) begin
    if({flag,calc_b_done_dly} == 2'b01 )begin
        o_temp_shutter_start <= i_temp_shutter;
    end
    else begin
        o_temp_shutter_start <= o_temp_shutter_start;
    end 
end

//开机镜头温
always @(posedge i_clk ) begin
    if({flag,calc_b_done_dly} == 2'b11 )begin
        o_temp_lens_start <= i_temp_lens;
    end
    else begin
        o_temp_lens_start <= o_temp_lens_start;
    end
end

//当前温度 在快门有变化时更新
always @(posedge i_clk ) begin
    if({shutter_state_dly,o_shutter_state} == 2'b10)begin
        o_temp_shutter_pre <= i_temp_shutter;
    end
    else begin
        o_temp_shutter_pre <= o_temp_shutter_pre;
    end
end

always @(posedge i_clk ) begin
    if({shutter_state_dly,o_shutter_state} == 2'b10)begin
        o_temp_sensor_pre <= i_temp_sensor;
    end
    else begin
        o_temp_sensor_pre <= o_temp_sensor_pre;
    end
end

always @(posedge i_clk ) begin
    if({shutter_state_dly,o_shutter_state} == 2'b10)begin
        o_temp_lens_pre <= i_temp_lens ;
    end
    else begin
        o_temp_lens_pre <= o_temp_lens_pre;
    end
end

endmodule