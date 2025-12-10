
module xbus_to_apb_bridge #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter SELECT_WIDTH = 4
)(
    // 时钟和复位
    input  wire                    clk,
    input  wire                    resetn,
    
    // XBUS总线接口
    input  wire [ADDR_WIDTH-1:0]   adr_i,    // 地址输入
    input  wire [DATA_WIDTH-1:0]   dat_i,    // 写数据输入
    input  wire                    we_i,     // 读写使能
    input  wire [SELECT_WIDTH-1:0] sel_i,    // 字节选择
    input  wire                    stb_i,    // 选通信号
    input  wire                    cyc_i,    // 周期信号
    output reg  [DATA_WIDTH-1:0]   dat_o,    // 读数据输出
    output reg                     ack_o,    // 应答信号
    
    // APB总线接口
    output reg                     apb_PSEL,     // APB选择信号
    output reg  [ADDR_WIDTH-1:0]   apb_PADDR,   // APB地址
    output reg  [SELECT_WIDTH-1:0] apb_PSTRB,   // APB字节选择
    output reg  [2:0]              apb_PPROT,   // APB保护信号
    output reg                     apb_PENABLE, // APB使能信号
    output reg                     apb_PWRITE,  // APB写使能
    output reg  [DATA_WIDTH-1:0]   apb_PWDATA,  // APB写数据
    input  wire                    apb_PREADY,  // APB就绪信号
    input  wire [DATA_WIDTH-1:0]   apb_PRDATA,  // APB读数据
    input  wire                    apb_PSLVERROR // APB错误信号
);

// 状态机定义
localparam [1:0] 
    IDLE   = 2'b00,
    SETUP  = 2'b01,
    ACCESS = 2'b10;

reg [1:0] current_state, next_state;
wire transaction_req;

// 事务请求检测
assign transaction_req = stb_i & cyc_i;

// 状态机时序逻辑
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// 状态机组合逻辑
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (transaction_req) begin
                next_state = SETUP;
            end
        end
        
        SETUP: begin
            next_state = ACCESS;
        end
        
        ACCESS: begin
            if (apb_PREADY) begin
                if (transaction_req) begin
                    next_state = SETUP;  // 连续传输
                end else begin
                    next_state = IDLE;
                end
            end
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// APB信号生成
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        apb_PSEL    <= 1'b0;
        apb_PADDR   <= {ADDR_WIDTH{1'b0}};
        apb_PSTRB   <= {SELECT_WIDTH{1'b0}};
        apb_PPROT   <= 3'b000;
        apb_PENABLE <= 1'b0;
        apb_PWRITE  <= 1'b0;
        apb_PWDATA  <= {DATA_WIDTH{1'b0}};
    end else begin
        case (current_state)
            IDLE: begin
                apb_PSEL    <= 1'b0;
                apb_PENABLE <= 1'b0;
                if (transaction_req) begin
                    // 锁存传输参数
                    apb_PADDR  <= adr_i;
                    apb_PWDATA <= dat_i;
                    apb_PWRITE <= we_i;
                    apb_PSTRB  <= sel_i;
                    apb_PPROT  <= 3'b000; // 默认保护级别
                end
            end
            
            SETUP: begin
                apb_PSEL    <= 1'b1;
                apb_PENABLE <= 1'b0;
            end
            
            ACCESS: begin
                apb_PSEL    <= 1'b1;
                apb_PENABLE <= 1'b1;
                // 为连续传输准备下一个事务
                if (apb_PREADY && transaction_req) begin
                    apb_PADDR  <= adr_i;
                    apb_PWDATA <= dat_i;
                    apb_PWRITE <= we_i;
                    apb_PSTRB  <= sel_i;
                end
            end
        endcase
    end
end

// XBUS响应信号生成
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        dat_o <= {DATA_WIDTH{1'b0}};
        ack_o <= 1'b0;
    end else begin
        // 应答信号在ACCESS状态且APB就绪时产生
        ack_o <= (current_state == ACCESS) && apb_PREADY;
        
        // 读数据在读操作完成时锁存
        if ((current_state == ACCESS) && apb_PREADY && !apb_PWRITE) begin
            dat_o <= apb_PRDATA;
        end
    end
end

endmodule
