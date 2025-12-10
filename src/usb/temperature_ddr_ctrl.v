module temperature_ddr_ctrl (
    input  wire                                                               clk                           ,// 系统时钟
    input  wire                                                               rst_n                         ,// 异步复位，低电平有效
    input  wire             [3:0]                                             temp_range                    ,// 挡位
    input  wire                                                               ddr_init_done                 ,// DDR初始化完成信号
    input  wire                                                               flash_load_en                 ,// Flash加载数据使能
    input  wire                                                               flash_wr_en                   ,// Flash写入数据使能
    input  wire                                                               send_low_cmd                  ,// 发送低温参数包指令
    input  wire                                                               send_high_cmd                 ,// 发送高温参数包指令
    input  wire                                                               send_guogai_cmd               ,// 发送锅盖指令
    input  wire                                                               update_temp_param             ,// 更新测温参数信号

    input  wire                                                               write_temp_en                 ,// 写测温参数使能信号
    input  wire             [  15: 0]                                         temp_cmd                      ,// 8位CMD地址信号
    input  wire             [  15: 0]                                         temp_param_in                 ,// 测温参数输入（32位）

    input  wire                                                               temp_rd_data_valid            ,// 测温参数读数据有效信号
    input  wire             [  15: 0]                                         temp_rd_data                  ,// 测温参数读数据（32位）
    input  wire                                                               temp_param_req                ,

    output       [  15: 0]                                                    o_shutterCorCoef              ,
    output       [  15: 0]                                                    o_LensCorCoef                 ,
    output       [  15: 0]                                                    o_Compensate_flag             ,
    output       [  15: 0]                                                    o_Emiss_Humidy          ,//湿度 发射率
    output       [  15: 0]                                                    o_EnTemp_Distance       ,//距离 环境温度
    output       [  15: 0]                                                    o_Transs                ,//透过率
    output       [  15: 0]                                                    o_near_kf                     ,
    output       [  15: 0]                                                    o_near_b                      ,
    output       [  15: 0]                                                    o_far_kf                      ,
    output       [  15: 0]                                                    o_far_b                       ,
    output       [  15: 0]                                                    o_pro_kf                      ,
    output       [  15: 0]                                                    o_pro_b                       ,
    output       [  15: 0]                                                    o_pro_kf_far                  ,
    output       [  15: 0]                                                    o_pro_b_far                   ,
    output       [  15: 0]                                                    o_reflectTemp                 , 
    output       [  15: 0]                                                    o_x_fusion_offset             ,
    output       [  15: 0]                                                    o_y_fusion_offset             ,
    output       [  15: 0]                                                    o_fusion_amp_factor           , 

    output reg                                                                read_low_en                   ,// 读取低温参数使能信号
    output reg                                                                read_high_en                  ,// 读取高温参数使能信号
    output reg                                                                read_guogai_en                ,// 读取高温参数使能信号
    output reg                                                                send_done_pulse               ,// 参数包发送完成脉冲信号
    output reg                                                                read_temp_en                  ,// 读测温参数使能信号
    output reg                                                                write_temp_en_out             ,// 写测温参数使能信号输出
    output reg              [   7: 0]                                         current_cmd                   ,// 当前操作的CMD地址
    output reg              [  15: 0]                                         temp_param_out                ,// 测温参数输出（32位）
    output reg                                                                temp_param_valid               // 测温参数输出有效信号
);

    parameter                           SEND_L_WAIT_TIME            = 32'd1_000_000       ;
    parameter                           SEND_H_WAIT_TIME            = 32'd1_000_000       ;
    parameter                           PARAM_TOTAL_NUM             = 'h400                ; // 测温参数数量（39+6=45）
    parameter                           TEMP_PARAM_NUM              = 28                   ;

// 状态定义：使用独热码（One-Hot Encoding）
localparam [4:0] 
    IDLE                = 5'b00000,                                // 空闲状态
    CHECK_DDR_INIT      = 5'b00001,                                // 检查DDR初始化状态
    WAIT_K_LOAD         = 5'b00011,                                // 等待K数据加载完成
    WAIT_LOW_TIMER      = 5'b00010,                                // 低温参数包计时等待状态
    READ_LOW_PARAM      = 5'b00110,                                // 读取低温参数状态
    WAIT_LOW_LOAD       = 5'b00111,                                // 等待低温数据加载到DDR
    WAIT_HIGH_TIMER     = 5'b00101,                                // 高温参数包计时等待状态
    READ_HIGH_PARAM     = 5'b00100,                                // 读取高温参数状态
    WAIT_HIGH_LOAD      = 5'b01100,                                // 等待高温数据加载到DDR

    WAIT_GUOGAI_TIMER   = 5'b01101,                                // 高温参数包计时等待状态
    READ_GUOGAI_PARAM   = 5'b01111,                                // 读取高温参数状态
    WAIT_GUOGAI_LOAD    = 5'b01110,                                // 等待高温数据加载到DDR

    READ_TEMP_START     = 5'b01010,                                // 开始读取测温参数
    READ_TEMP_PARAM     = 5'b01011,                                // 读取测温参数状态
    WAIT_TEMP_READ      = 5'b01001,                                // 等待测温参数读取完成
    CHECK_WRITE_EN      = 5'b01000,                                // 检查写使能状态
    WRITE_TEMP_START    = 5'b11000,                                // 开始写入测温参数
    WRITE_TEMP_PARAM    = 5'b11001,                                // 写测温参数状态
    WAIT_WRITE_COMPLETE = 5'b11011,                                // 等待写入完成
    SEND_DONE           = 5'b11010;                                // 完成状态

reg     [   5: 0]        current_state,            next_state;

// 计数器
reg     [  27: 0]        timer_count                 ;
reg     [  15: 0]        param_counter               ;// 参数计数器（0-44）

// Flash读数据有效信号的边沿检测
reg                      flash_load_en_d1            ;
wire                     flash_rd_data_falling_edge  ;
// Flash写数据有效信号的边沿检测
reg                      flash_wr_en_d1            ;
wire                     flash_wr_en_falling_edge  ;
// 测温参数读数据有效信号的边沿检测
reg                      temp_rd_data_valid_d1       ;
wire                     temp_rd_data_rising_edge    ;
wire                     temp_rd_data_falling_edge   ;

// 33个测温参数存储寄存器
reg     [  15: 0]        temp_params[0:TEMP_PARAM_NUM-1]  ;

// 参数名称定义
// localparam [159:0] PARAM_NAMES [0:44] = '{
//     "环温修正开关", "镜筒温漂校正开关", "快门温漂校正开关", "设置反射温度", "距离补偿开关（距离修正）",
//     "常温档镜筒温漂修正系数", "高温档镜筒温漂修正系数", "设置低温档远距离KF", "设置低温档远距离B", 
//     "设置低温档近距离KF", "设置低温档近距离B", "设置二次校温低温档远距离B2", "设置二次校温低温档远距离KF2",
//     "设置高温档远距离KF", "设置高温档远距离B", "设置高温档近距离KF", "设置高温档近距离B", 
//     "设置二次校温高温档远距离B2", "设置二次校温高温档远距离KF2", "设置透过率", "设置测温范围",
//     "设置发射率", "设置湿度", "设置距离", "发射率开关", "透过率开关", "设置环境温度",
//     "预留参数27", "预留参数28", "预留参数29", "预留参数30", "预留参数31", "预留参数32", 
//     "预留参数33", "预留参数34", "预留参数35", "预留参数36", "预留参数37", "预留参数38",
//     "高温档快门温漂修正系数", "低温档快门温漂修正系数", "设置二次校温低温档近距离B2",
//     "设置二次校温低温档近距离KF2", "设置二次校温高温档近距离B2", "设置二次校温高温档近距离KF2"
// };

reg                      usb_cmd_flag0               ;
reg                      usb_cmd_flag1               ;
wire                     usb_cmd_flag1_pdge          ;
assign          usb_cmd_flag1_pdge = temp_cmd[8] ? usb_cmd_flag1 ^ usb_cmd_flag0 : 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        usb_cmd_flag0 <= 0;
        usb_cmd_flag1 <= 0;
    end
    else begin
        usb_cmd_flag0 <= update_temp_param;
        usb_cmd_flag1 <= usb_cmd_flag0;
    end
end

// 参数更新逻辑
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 初始化所有参数寄存器
        temp_params[20]      <= 16'd0                     ;      
        temp_params[4]       <= 16'd0                     ;
        temp_params[0]       <= 8'b0011_0110              ;
        temp_params[1]       <= {8'd95,8'd60}             ;
        temp_params[2]       <= {8'd23,8'd15}             ;
        temp_params[18]      <= 16'd1                     ;
        temp_params[8]       <= 16'd10000                 ;
        temp_params[9]       <= 16'd0                     ;
        temp_params[6]       <= 16'd10000                 ;
        temp_params[7]       <= 16'd0                     ;
        temp_params[22]      <= 16'd10000                 ;
        temp_params[21]      <= 16'd0                     ;
        temp_params[11]      <= 16'd10000                 ;
        temp_params[10]      <= 16'd0                     ;
        temp_params[3]       <= 16'd23                    ;

        temp_params[19]      <= 16'd0                     ;
        temp_params[5]       <= 16'd0                     ;
        temp_params[14]      <= 16'd10000                 ;
        temp_params[15]      <= 16'd0                     ;
        temp_params[12]      <= 16'd10000                 ;
        temp_params[13]      <= 16'd0                     ;
        temp_params[24]      <= 16'd10000                 ;
        temp_params[23]      <= 16'd0                     ;
        temp_params[17]      <= 16'd10000                 ;
        temp_params[16]      <= 16'd0                     ;

        temp_params[25]      <= 16'd0                     ;
        temp_params[26]      <= 16'd0                     ;
        temp_params[27]      <= 16'd0                     ;
    end else begin
        // 在读取测温参数时，根据有效信号更新参数
        if (current_state == WAIT_TEMP_READ && temp_rd_data_valid) begin
            if (param_counter < TEMP_PARAM_NUM) begin
                temp_params[param_counter] <= temp_rd_data;
            end
            else begin
                temp_params[0][3] <= 0;
            end
        end
        // 外部更新信号（优先级高于读取更新）
        else 
            if (usb_cmd_flag1_pdge) begin
            // 根据CMD地址更新对应的参数寄存器
            case (temp_cmd[7:0])
                8'h00: temp_params[0][6]    <= temp_param_in;   // 0x100: 环温修正开关
                8'h01: temp_params[0][5]    <= temp_param_in;   // 0x101: 镜筒温漂校正开关
                8'h02: temp_params[0][4]    <= temp_param_in;   // 0x102: 快门温漂校正开关
                8'h03: temp_params[3]       <= temp_param_in;   // 0x103: 设置反射温度
                8'h04: temp_params[0][2]    <= temp_param_in;   // 0x104: 距离补偿开关（距离修正）
                8'h05: temp_params[4]       <= temp_param_in;   // 0x105: 常温档镜筒温漂修正系数
                8'h06: temp_params[5]       <= temp_param_in;   // 0x106: 高温档镜筒温漂修正系数
                8'h07: temp_params[6]       <= temp_param_in;   // 0x107: 设置低温档远距离KF
                8'h08: temp_params[7]       <= temp_param_in;   // 0x108: 设置低温档远距离B
                8'h09: temp_params[8]       <= temp_param_in;   // 0x109: 设置低温档近距离KF
                8'h10: temp_params[9]       <= temp_param_in;  // 0x110: 设置低温档近距离B
                8'h11: temp_params[10]      <= temp_param_in;  // 0x111: 设置二次校温低温档远距离B2
                8'h12: temp_params[11]      <= temp_param_in;  // 0x112: 设置二次校温低温档远距离KF2
                8'h13: temp_params[12]      <= temp_param_in;  // 0x113: 设置高温档远距离KF
                8'h14: temp_params[13]      <= temp_param_in;  // 0x114: 设置高温档远距离B
                8'h15: temp_params[14]      <= temp_param_in;  // 0x115: 设置高温档近距离KF
                8'h16: temp_params[15]      <= temp_param_in;  // 0x116: 设置高温档近距离B
                8'h17: temp_params[16]      <= temp_param_in;  // 0x117: 设置二次校温高温档远距离B2
                8'h18: temp_params[17]      <= temp_param_in;  // 0x118: 设置二次校温高温档远距离KF2
                8'h19: temp_params[18]      <= temp_param_in;  // 0x119: 设置透过率
                // 8'h20: temp_params[19]      <= temp_param_in;  // 0x120: 设置测温范围
                8'h21: temp_params[1][15:8] <= temp_param_in;  // 0x121: 设置发射率
                8'h22: temp_params[1][7:0]  <= temp_param_in;  // 0x122: 设置湿度
                8'h23: temp_params[2][7:0]  <= temp_param_in;  // 0x123: 设置距离
                8'h24: temp_params[0][1]    <= temp_param_in;  // 0x124: 发射率开关
                8'h25: temp_params[0][0]    <= temp_param_in;  // 0x125: 透过率开关
                8'h26: temp_params[2][15:8] <= temp_param_in;  // 0x126: 设置环境温度
                // 0x138-0x143: 特殊参数
                8'h38: temp_params[19]      <= temp_param_in;  // 0x138: 高温档快门温漂修正系数
                8'h39: temp_params[20]      <= temp_param_in;  // 0x139: 低温档快门温漂修正系数
                8'h40: temp_params[21]      <= temp_param_in;  // 0x140: 设置二次校温低温档近距离B2
                8'h41: temp_params[22]      <= temp_param_in;  // 0x141: 设置二次校温低温档近距离KF2
                8'h42: temp_params[23]      <= temp_param_in;  // 0x142: 设置二次校温高温档近距离B2
                8'h43: temp_params[24]      <= temp_param_in;  // 0x143: 设置二次校温高温档近距离KF2
                8'h90: temp_params[25]      <= temp_param_in;  // 0x190: 设置融合x偏移
                8'h91: temp_params[26]      <= temp_param_in;  // 0x191: 设置融合y偏移
                8'h92: temp_params[27]      <= temp_param_in;  // 0x192: 设置融合放大倍数
                default: ; // 保持原值
            endcase
            end
    end
end

assign      o_shutterCorCoef    = temp_range == 1 ? temp_params[20] : temp_params[19];
assign      o_LensCorCoef       = temp_range == 1 ? temp_params[4]  : temp_params[5];
assign      o_Compensate_flag   = temp_params[0];
assign      o_Emiss_Humidy      = temp_params[1];
assign      o_EnTemp_Distance   = temp_params[2];
assign      o_Transs            = temp_params[18];
assign      o_near_kf           = temp_range == 1 ? temp_params[8] : temp_params[14];
assign      o_near_b            = temp_range == 1 ? temp_params[9]: temp_params[15];
assign      o_far_kf            = temp_range == 1 ? temp_params[6]: temp_params[12];
assign      o_far_b             = temp_range == 1 ? temp_params[7]: temp_params[13];
assign      o_pro_kf            = temp_range == 1 ? temp_params[22]: temp_params[24];
assign      o_pro_b             = temp_range == 1 ? temp_params[21]: temp_params[23];
assign      o_pro_kf_far        = temp_range == 1 ? temp_params[11]: temp_params[17];
assign      o_pro_b_far         = temp_range == 1 ? temp_params[10]: temp_params[16];
assign      o_reflectTemp       = temp_params[3];

assign      o_x_fusion_offset   = temp_params[25];
assign      o_y_fusion_offset   = temp_params[26];
assign      o_fusion_amp_factor = temp_params[27];
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
// 第一段触发器：状态寄存器时序逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state           <= IDLE;
        flash_load_en_d1        <= 1'b0;
        flash_wr_en_d1          <= 1'b0;
        temp_rd_data_valid_d1   <= 1'b0;
    end else begin
        current_state           <= next_state;
        flash_load_en_d1        <= flash_load_en;
        flash_wr_en_d1          <= flash_wr_en;
        temp_rd_data_valid_d1   <= temp_rd_data_valid;
    end
end

// 检测flash_load_en的下降沿
assign flash_rd_data_falling_edge   = flash_load_en_d1  && !flash_load_en;
assign flash_wr_en_falling_edge     = flash_wr_en_d1    && !flash_wr_en;
// 检测temp_rd_data_valid的边沿
assign temp_rd_data_rising_edge     = !temp_rd_data_valid_d1 && temp_rd_data_valid;
assign temp_rd_data_falling_edge    = temp_rd_data_valid_d1 && !temp_rd_data_valid;

// 第二段组合逻辑：状态转移条件
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            next_state = CHECK_DDR_INIT;
        end

        CHECK_DDR_INIT: begin
            if (ddr_init_done && flash_rd_data_falling_edge) 
                next_state = WAIT_K_LOAD;
            else
                next_state = CHECK_DDR_INIT;
        end

        WAIT_K_LOAD: begin
            if (flash_rd_data_falling_edge)
                next_state = WAIT_LOW_TIMER;
            else
                next_state = WAIT_K_LOAD;
        end

        WAIT_LOW_TIMER: begin
            if (timer_count == SEND_L_WAIT_TIME - 2)
                next_state = READ_LOW_PARAM;
            else
                next_state = WAIT_LOW_TIMER;
        end

        READ_LOW_PARAM: begin
            next_state = WAIT_LOW_LOAD;
        end

        WAIT_LOW_LOAD: begin
            if (flash_rd_data_falling_edge)
                next_state = WAIT_HIGH_TIMER;
            else
                next_state = WAIT_LOW_LOAD;
        end

        WAIT_HIGH_TIMER: begin
            if (timer_count == (SEND_H_WAIT_TIME - 2))
                next_state = READ_HIGH_PARAM;
            else
                next_state = WAIT_HIGH_TIMER;
        end

        READ_HIGH_PARAM: begin
            next_state = WAIT_HIGH_LOAD;
        end

        WAIT_HIGH_LOAD: begin
            if (flash_rd_data_falling_edge)
                next_state = WAIT_GUOGAI_TIMER;//SEND_DONE;
            else
                next_state = WAIT_HIGH_LOAD;
        end

        WAIT_GUOGAI_TIMER: begin
            if (timer_count == (SEND_H_WAIT_TIME - 2))
                next_state = READ_GUOGAI_PARAM;
            else
                next_state = WAIT_GUOGAI_TIMER;
        end

        READ_GUOGAI_PARAM: begin
            next_state = WAIT_GUOGAI_LOAD;
        end

        WAIT_GUOGAI_LOAD: begin
            if (flash_rd_data_falling_edge)
                next_state = READ_TEMP_START;//READ_TEMP_START;//SEND_DONE;
            else
                next_state = WAIT_GUOGAI_LOAD;
        end

        READ_TEMP_START: begin
            if (timer_count == (SEND_H_WAIT_TIME - 2))
                next_state = READ_TEMP_PARAM;
            else
                next_state = READ_TEMP_START;
        end

        READ_TEMP_PARAM: begin
            next_state = WAIT_TEMP_READ;
        end

        WAIT_TEMP_READ: begin
            if (temp_rd_data_valid && (param_counter == PARAM_TOTAL_NUM - 1)) begin
                next_state = CHECK_WRITE_EN;
            end else begin
                next_state = WAIT_TEMP_READ;
            end
        end

        CHECK_WRITE_EN: begin
            if (usb_cmd_flag1_pdge)
                next_state = WRITE_TEMP_START;
            else
                next_state = CHECK_WRITE_EN;
        end

        WRITE_TEMP_START: begin
            next_state = WRITE_TEMP_PARAM;
        end

        WRITE_TEMP_PARAM: begin
            next_state = WAIT_WRITE_COMPLETE;
        end

        WAIT_WRITE_COMPLETE: begin
            if (flash_wr_en_falling_edge) //begin
                // if (param_counter == PARAM_TOTAL_NUM - 1 && (temp_param_req))
                    next_state = CHECK_WRITE_EN;
                else
                    next_state = WAIT_WRITE_COMPLETE;
            // end else begin
            //     next_state = WAIT_WRITE_COMPLETE;
            // end
        end

        SEND_DONE: begin
            next_state = SEND_DONE;
        end
        
        default: next_state = IDLE;
    endcase
end

reg           [4:0]       flash_rd_data_falling_edge_cnt;  
reg           [31:0]      read_high_time_cnt;  
reg           [31:0]      read_low_time_cnt;  
reg           [31:0]      read_all_time_cnt;  
reg           [31:0]      ddr_init_cnt;  
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_high_time_cnt              <= 0;
        read_low_time_cnt               <= 0;
        read_all_time_cnt               <= 0;
        flash_rd_data_falling_edge_cnt  <= 0;
        ddr_init_cnt                    <= 0;
    end else begin
        
        if(flash_rd_data_falling_edge)
            flash_rd_data_falling_edge_cnt <= flash_rd_data_falling_edge_cnt + 1;
        else 
            flash_rd_data_falling_edge_cnt <= flash_rd_data_falling_edge_cnt;
        
        if(read_low_en)
            read_low_time_cnt <= read_low_time_cnt + 1;
        else 
            read_low_time_cnt <= read_low_time_cnt;

        // if(current_state[4:3] == 0)
        if((current_state[3] == 0))
            read_high_time_cnt <= read_high_time_cnt + 1;
        else 
            read_high_time_cnt <= read_high_time_cnt;

        // if((current_state[3] == 0) || (current_state == WAIT_HIGH_LOAD))
        if(flash_rd_data_falling_edge_cnt <= 4)
            read_all_time_cnt <= read_all_time_cnt + 1;
        else 
            read_all_time_cnt <= read_all_time_cnt;   

        // if(!ddr_init_done)
        // if( current_state == IDLE || current_state == CHECK_DDR_INIT || current_state == WAIT_K_LOAD || 
        //     current_state == WAIT_LOW_TIMER || current_state == READ_LOW_PARAM || current_state == WAIT_LOW_LOAD || 
        //     current_state == WAIT_HIGH_TIMER || current_state == READ_HIGH_PARAM || current_state == WAIT_HIGH_LOAD || 
        //     current_state == READ_TEMP_START || current_state == READ_TEMP_PARAM || current_state == WAIT_TEMP_READ)
        if((current_state[3] == 0) || (current_state == WAIT_HIGH_LOAD))
            ddr_init_cnt <= ddr_init_cnt + 1;
        else 
            ddr_init_cnt <= ddr_init_cnt;   
    end
end
// 第三段时序逻辑：状态输出与控制信号生成
reg         load_low_done;
reg         load_high_done;
reg         load_guogai_done;
reg [6:0]   send_done_pulse_cnt;
reg         param_load_done;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_low_en         <= 1'b0;
        read_high_en        <= 1'b0;
        read_guogai_en      <= 1'b0;
        read_temp_en        <= 1'b0;
        write_temp_en_out   <= 1'b0;
        send_done_pulse     <= 1'b0;
        timer_count         <= 28'b0;
        load_low_done       <= 1'b0;
        load_high_done      <= 1'b0;
        send_done_pulse_cnt <= 7'b0;
        temp_param_out      <= 32'b0;
        temp_param_valid    <= 1'b0;
        current_cmd         <= 8'b0;
        param_counter       <= 6'b0;
        param_load_done     <= 1'b0;
    end else begin
        // 默认值
        read_low_en         <= 1'b0;
        read_high_en        <= 1'b0;
        read_guogai_en      <= 1'b0;
        read_temp_en        <= 1'b0;
        write_temp_en_out   <= 1'b0;
        temp_param_valid    <= 1'b0;

        // 发送完成脉冲生成逻辑
        if (send_low_cmd) begin
            if (load_low_done) begin
                if (send_done_pulse_cnt == 100) begin
                    send_done_pulse <= 1;
                    load_low_done   <= 0;
                    send_done_pulse_cnt <= 0;
                end else begin
                    send_done_pulse <= send_done_pulse;
                    load_low_done   <= load_low_done;
                    send_done_pulse_cnt <= send_done_pulse_cnt + 1;
                end
            end else begin
                send_done_pulse <= 0;
            end
        end else if (send_high_cmd) begin
            if (load_high_done) begin
                if (send_done_pulse_cnt == 100) begin
                    send_done_pulse <= 1;
                    load_high_done  <= 0;
                    send_done_pulse_cnt <= 0;
                end else begin
                    send_done_pulse <= send_done_pulse;
                    load_high_done  <= load_high_done;
                    send_done_pulse_cnt <= send_done_pulse_cnt + 1;
                end
            end else begin
                send_done_pulse <= 0;
            end
        end else if (send_guogai_cmd) begin
            if (load_guogai_done) begin
                if (send_done_pulse_cnt == 100) begin
                    send_done_pulse     <= 1;
                    load_guogai_done    <= 0;
                    send_done_pulse_cnt <= 0;
                end else begin
                    send_done_pulse     <= send_done_pulse;
                    load_guogai_done    <= load_guogai_done;
                    send_done_pulse_cnt <= send_done_pulse_cnt + 1;
                end
            end else begin
                send_done_pulse <= 0;
            end
        end else begin
            if (param_load_done) begin
                load_low_done   <= 1;
                load_high_done  <= 1;
                load_guogai_done<= 1;
            end else begin
                load_low_done   <= load_low_done;
                load_high_done  <= load_high_done;
                load_guogai_done<= load_guogai_done;
            end
        end 

        case (current_state)
            WAIT_LOW_TIMER: begin
                timer_count <= timer_count + 1;
            end

            READ_LOW_PARAM: begin
                timer_count <= 0;
                read_low_en <= 1'b1;
            end

            WAIT_LOW_LOAD: begin
                read_low_en <= 1'b1;
                if (flash_rd_data_falling_edge)
                    load_low_done <= 1;
            end

            WAIT_HIGH_TIMER: begin
                timer_count <= timer_count + 1;
            end

            READ_HIGH_PARAM: begin
                timer_count <= 0;
                read_high_en <= 1'b1;
            end

            WAIT_HIGH_LOAD: begin
                read_high_en <= 1'b1;
                if (flash_rd_data_falling_edge)begin
                    load_high_done <= 1;
                    param_load_done<= 1;
                end
                else begin
                    load_high_done <= load_high_done;
                    param_load_done<= param_load_done;
                end
            end

            WAIT_GUOGAI_TIMER: begin
                timer_count <= timer_count + 1;
            end

            READ_GUOGAI_PARAM: begin
                timer_count     <= 0;
                read_guogai_en  <= 1'b1;
            end

            WAIT_GUOGAI_LOAD: begin
                read_guogai_en          <= 1'b1;
                if (flash_rd_data_falling_edge)begin
                    load_guogai_done    <= 1;
                    param_load_done     <= 1;
                end
                else begin
                    load_guogai_done    <= load_guogai_done;
                    param_load_done     <= param_load_done;
                end
            end

            READ_TEMP_START: begin
                param_counter <= 6'b0; // 重置参数计数器
                timer_count <= timer_count + 1;
            end

            READ_TEMP_PARAM: begin
                timer_count     <= 0;
                read_temp_en    <= 1'b1;
                // if (param_counter < PARAM_TOTAL_NUM) begin
                //     current_cmd <= CMD_MAP[param_counter]; // 设置当前CMD地址
                // end
            end

            WAIT_TEMP_READ: begin
                read_temp_en <= 1'b1;
                // if (param_counter < PARAM_TOTAL_NUM) begin
                //     current_cmd <= CMD_MAP[param_counter];
                // end
                
                // 检测到数据有效信号时，更新参数并递增计数器
                if (temp_rd_data_valid) begin
                    // 参数已经在参数更新逻辑中存储
                    param_counter <= param_counter + 1;
                end
            end

            CHECK_WRITE_EN: begin
                param_counter <= 6'b0; // 重置参数计数器
            end

            WRITE_TEMP_START: begin
                param_counter <= 6'b0; // 重置参数计数器
            end

            WRITE_TEMP_PARAM: begin
                write_temp_en_out <= 1'b1;
                // temp_param_valid <= temp_param_req;
                // if (param_counter < PARAM_TOTAL_NUM) begin
                //     current_cmd <= CMD_MAP[param_counter]; // 输出当前CMD地址
                //     temp_param_out <= temp_params[param_counter]; // 输出对应参数
                // end
            end

            WAIT_WRITE_COMPLETE: begin
                write_temp_en_out <= 1'b1;
                temp_param_valid <= temp_param_req;
                if (param_counter < TEMP_PARAM_NUM) begin
                    // current_cmd <= CMD_MAP[param_counter];
                    temp_param_out <= temp_params[param_counter];
                end
                else begin
                    temp_param_out <= 0;
                end

                if (temp_param_req) begin
                    param_counter <= param_counter + 1;
                end
            end

            default: begin
                timer_count <= 28'b0;
            end
        endcase
    end
end

endmodule