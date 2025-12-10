/**
 * USB发送模块 - 代码升级包执行状态反馈
 * 基于标准USB协议，以状态机方式实现指令发送
 * 协议格式：协议头(1B) + 协议命令(2B) + 数据校验(4B) + 数据(4B) + 协议尾(1B)
 * 示例功能：导入代码升级包执行状态 (命令: 0x0008)
 */

 module usb_cmd_feedback (
    // 系统信号
    input               clk,                // 系统时钟
    input               rst_n,              // 异步复位，低电平有效
    
    // 控制信号
    input               i_txact,            // 发送激活信号
    input               i_txpop,            // 发送弹出信号（数据读取请求）
    input               i_txpktfin_o,       // 数据包结束指示
    
    // 状态输入
    input      [7:0]    i_update_type,
    input               upgrade_status,     // 
    
    // USB数据输出
    output reg          o_cmd_en,
    output reg [7:0]    o_txdat,           // USB发送数据
    output reg [15:0]   o_txdat_len,        // 发送数据长度
    output reg          o_txcork,          // 发送阻塞指示
    output reg          tx_busy            // 发送忙指示
);

// ============================ 参数定义 ============================
// 状态机状态定义
    localparam                          [   3: 0] IDLE                        = 4'b0000              ;   // 空闲状态
    localparam                          [   3: 0] SEND_HEADER                 = 4'b0001              ;   // 发送协议头
    localparam                          [   3: 0] SEND_CMD                    = 4'b0011              ;   // 发送协议命令
    localparam                          [   3: 0] SEND_RESERVED               = 4'b0010              ;   // 发送保留位
    localparam                          [   3: 0] SEND_DATA_LEN               = 4'b0110              ;   // 发送数据长度
    localparam                          [   3: 0] SEND_CHECKSUM               = 4'b0111              ;   // 发送数据校验
    localparam                          [   3: 0] SEND_DATA                   = 4'b0101              ;   // 发送数据
    localparam                          [   3: 0] SEND_TAIL                   = 4'b0100              ;   // 发送协议尾
    localparam                          [   3: 0] SEND_WAIT                   = 4'b1100              ;   // 发送等待
    localparam                          [   3: 0] FINISH                      = 4'b1000              ;   // 发送完成

// USB协议常量定义
    localparam                          [   7: 0] PROTO_HEADER                = 8'h02                ; // 协议头固定值
    localparam                          [   7: 0] PROTO_TAIL                  = 8'h03                ; // 协议尾固定值
    localparam                          [   7: 0] RESERVED_BYTE               = 8'h00                ;    // 保留位固定值
    localparam                          [  15: 0] CMD_UPGRADE_STATUS          = 16'h0008             ; // 升级状态查询命令
    localparam                          [  15: 0] CMD_PARAM_IMPORT_STATUS     = 16'h003a             ; //参数包导入查询命令
    localparam                          [  15: 0] GUOGAI_UPDATE_STATUS        = 16'h0057;
// 数据校验常量（根据协议表格）
    localparam                          [  31: 0] DATA_LENGTH                 = 32'h00000004         ; // 数据长度固定为4字节
    localparam                          [  31: 0] DATA_CHECKSUM               = 32'h00000004         ; // 数据校验值

wire [15:0]     cmd_status;
// ============================ 内部寄存器 ============================
reg     [   3: 0]        current_state               ;// 当前状态
reg     [   3: 0]        next_state                  ;// 下一状态
reg     [   3: 0]        byte_counter                ;// 字节计数器
reg     [  31: 0]        tx_data                     ;// 待发送数据缓存
reg                      upgrade_status_ff0          ;
reg                      upgrade_status_ff1          ;

wire                     start_feedback              ;// 开始反馈信号
reg     [   6: 0]        send_end_cnt                ;
reg                      send_status                 ;
reg                      usb_retrans_en              ;

assign cmd_status = i_update_type == 7       ? CMD_UPGRADE_STATUS : 
                    i_update_type == 8'h56   ? GUOGAI_UPDATE_STATUS : CMD_PARAM_IMPORT_STATUS;
// ========================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        upgrade_status_ff0 <= 0;
        upgrade_status_ff1 <= 0;
    end else begin
        upgrade_status_ff0 <= (i_update_type == 7 || i_update_type == 8'h38 || i_update_type == 8'h39 || i_update_type == 8'h56) ? upgrade_status : 0;
        upgrade_status_ff1 <= upgrade_status_ff0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_cmd_en <= 0;
    end else begin
        if(current_state == FINISH && i_txpktfin_o)
            o_cmd_en <= 0;
        else if(upgrade_status_ff0 & !upgrade_status_ff1)
            o_cmd_en <= 1;
        else 
            o_cmd_en <= o_cmd_en;
    end
end
assign start_feedback = !upgrade_status_ff0 & upgrade_status_ff1;
// ============================ 状态机主逻辑 ============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= 0;
    end else begin
        current_state <= next_state;
    end
end

// 状态转移逻辑
always @(*) begin
    case (current_state)
        IDLE: begin
            // 接收到开始信号且USB发送激活时进入发送流程
            if (start_feedback) begin
                next_state = SEND_HEADER;
            end else begin
                next_state = IDLE;
            end
        end
        
        SEND_HEADER: begin
            // 协议头发送完成后进入命令发送状态
            // if (byte_counter == 4'd1 && i_txpop) begin
            if (!i_txact) begin    
                next_state = SEND_CMD;
            end else begin
                next_state = SEND_HEADER;
            end
        end
        
        SEND_CMD: begin
            // 2字节命令发送完成后进入保留位发送状态
            if (byte_counter == 4'd1 && i_txpop) begin
                next_state = SEND_RESERVED;
            end else begin
                next_state = SEND_CMD;
            end
        end
        
        SEND_RESERVED: begin
            // 1字节保留位发送完成后进入数据长度发送状态
            if (i_txpop) begin//byte_counter == 4'd1 && 
                next_state = SEND_DATA_LEN;
            end else begin
                next_state = SEND_RESERVED;
            end
        end
        
        SEND_DATA_LEN: begin
            // 4字节数据长度发送完成后进入校验发送状态
            if (byte_counter == 4'd3 && i_txpop) begin
                next_state = SEND_CHECKSUM;
            end else begin
                next_state = SEND_DATA_LEN;
            end
        end
        
        SEND_CHECKSUM: begin
            // 4字节校验发送完成后进入数据发送状态
            if (byte_counter == 4'd3 && i_txpop) begin
                next_state = SEND_DATA;
            end else begin
                next_state = SEND_CHECKSUM;
            end
        end
        
        SEND_DATA: begin
            // 4字节数据发送完成后进入协议尾发送
            if (byte_counter == 4'd3 && i_txpop) begin
                next_state = SEND_TAIL;
            end else begin
                next_state = SEND_DATA;
            end
        end
        
        SEND_TAIL: begin
            // 协议尾发送完成后进入结束状态
            if (i_txpop) begin//byte_counter == 4'd1 && 
                next_state = SEND_WAIT;
            end else begin
                next_state = SEND_TAIL;
            end
        end
        SEND_WAIT: begin
            // 协议尾发送完成后进入结束状态
            if (i_txpop) begin//
                next_state = FINISH;
            end else begin
                next_state = SEND_WAIT;
            end
        end
        FINISH: begin
            // 等待包结束指示，然后返回空闲状态
            if (i_txpktfin_o) begin//
                next_state = IDLE;
            end else if (usb_retrans_en) begin//
                next_state = SEND_HEADER;
            end else begin
                next_state = FINISH;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

// ============================ 输出控制逻辑 ============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_txdat <= 8'h00;
        o_txdat_len <= 16'h0000;
        o_txcork <= 1'b1;
        tx_busy <= 1'b0;
        byte_counter <= 4'd0;
        tx_data <= 32'h00000001;
    end else begin
        case (current_state)
            IDLE: begin
                o_txdat <= 8'h00;
                o_txcork <= 1'b1;
                tx_busy <= 1'b0;
                byte_counter <= 4'd0;
                // 准备升级状态数据：success=0, fail=1
                if(start_feedback)
                    tx_data <= 32'h00000000;
                else 
                    tx_data <= 32'h00000001;
            end
            
            SEND_HEADER: begin
                tx_busy <= 1'b1;

                if (!i_txact) begin
                    // if (byte_counter == 4'd0) begin
                        // 发送协议头
                        o_txcork <= 1'b0;  // 阻塞指示，数据正在发送
                        o_txdat <= PROTO_HEADER;
                        // byte_counter <= byte_counter + 4'd1;
                    // end
                end
                // 设置总数据长度：1(头) + 2(命令) + 1(保留) + 4(数据长度) + 4(校验) + 4(数据) + 1(尾) = 17字节
                o_txdat_len <= 16'h0011;
            end
            
            SEND_CMD: begin
                if (i_txpop) begin
                    case (byte_counter)
                        4'd0: begin
                            // 发送命令低字节 (0x08)
                            o_txdat <= cmd_status[7:0];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd1: begin
                            // 发送命令高字节 (0x00)
                            o_txdat <= cmd_status[15:8];
                            // byte_counter <= byte_counter + 4'd1;
                        end
                        default: byte_counter <= 4'd0;  // 重置计数器
                    endcase
                end
            end
            
            SEND_RESERVED: begin
                if (i_txpop) begin
                    // if (byte_counter == 4'd0) begin
                        // 发送保留位（固定为0x00）
                        o_txdat <= RESERVED_BYTE;
                        byte_counter <= 0;
                        // byte_counter <= byte_counter + 4'd1;
                    // end
                end
                
            end
            
            SEND_DATA_LEN: begin
                if (i_txpop) begin
                    
                    case (byte_counter)
                        4'd0: begin
                            // 发送数据长度字节1 (0x04)
                            o_txdat <= DATA_LENGTH[7:0];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd1: begin
                            // 发送数据长度字节2 (0x00)
                            o_txdat <= DATA_LENGTH[15:8];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd2: begin
                            // 发送数据长度字节3 (0x00)
                            o_txdat <= DATA_LENGTH[23:16];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd3: begin
                            // 发送数据长度字节4 (0x00)
                            o_txdat <= DATA_LENGTH[31:24];
                            // byte_counter <= byte_counter + 4'd1;
                            byte_counter <= 0;
                        end
                        default: byte_counter <= 4'd0;
                    endcase
                end
            end
            
            SEND_CHECKSUM: begin
                if (i_txpop) begin
                    case (byte_counter)
                        4'd0: begin
                            // 发送校验字节1 (0x04)
                            o_txdat <= DATA_CHECKSUM[7:0];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd1: begin
                            // 发送校验字节2 (0x00)
                            o_txdat <= DATA_CHECKSUM[15:8];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd2: begin
                            // 发送校验字节3 (0x00)
                            o_txdat <= DATA_CHECKSUM[23:16];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd3: begin
                            // 发送校验字节4 (0x00)
                            o_txdat <= DATA_CHECKSUM[31:24];
                            // byte_counter <= byte_counter + 4'd1;
                            byte_counter <= 0;
                        end
                        default: byte_counter <= 4'd0;
                    endcase
                end
            end
            
            SEND_DATA: begin
                if (i_txpop) begin
                    case (byte_counter)
                        4'd0: begin
                            // 发送数据字节1 (状态值)
                            o_txdat <= tx_data[7:0];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd1: begin
                            // 发送数据字节2 (0x00)
                            o_txdat <= tx_data[15:8];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd2: begin
                            // 发送数据字节3 (0x00)
                            o_txdat <= tx_data[23:16];
                            byte_counter <= byte_counter + 4'd1;
                        end
                        4'd3: begin
                            // 发送数据字节4 (0x00)
                            o_txdat <= tx_data[31:24];
                            // byte_counter <= byte_counter + 4'd1;
                            byte_counter <= 0;
                        end
                        default: byte_counter <= 4'd0;
                    endcase
                end
            end
            
            SEND_TAIL: begin
                if (i_txpop) begin
                    // if (byte_counter == 4'd0) begin
                        // 发送协议尾
                        o_txdat <= PROTO_TAIL;
                        // byte_counter <= byte_counter + 4'd1;
                    // end
                end

            end
            SEND_WAIT: begin
                byte_counter <= 4'd0;
                if (i_txpop) begin//i_txpktfin_o
                    tx_busy <= 1'b0;  // 清除忙指示
                    o_txdat <= 8'h00;
                    o_txcork <= 1'b1;  // 清除阻塞指示
                end
            end

            FINISH: begin
                byte_counter <= 4'd0;
                tx_busy <= 1'b0;  // 清除忙指示
                o_txdat <= 8'h00;
                o_txcork <= 1'b1;  // 清除阻塞指示
            end
            
            default: begin
                o_txdat <= 8'h00;
                o_txcork <= 1'b1;
                tx_busy <= 1'b0;
                byte_counter <= 4'd0;
            end
        endcase
    end
end
/////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_end_cnt <= 0;
    end
    else if (current_state == FINISH) begin
        send_end_cnt <=  send_end_cnt +1'd1;
    end
    else begin
        send_end_cnt <= 9'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_status <= 0;
    end
    else if ((send_end_cnt > 0) && (send_end_cnt < 70)) begin
        if(i_txpktfin_o)
            send_status <=  1'd1;
        else 
            send_status <= send_status;
    end
    else begin
        send_status <= 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        usb_retrans_en <= 0;
    end
    else if (send_end_cnt == 70  && send_status == 0) begin
        usb_retrans_en  <= 1;
    end
    else begin
        usb_retrans_en  <= 0;
    end
end
endmodule