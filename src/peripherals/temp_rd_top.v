module temp_rd_top #(
    parameter CLK_IN_FREQ = 6_000_000           //MAX 16M
)
(
    input                       i_mc                    ,//6M
    input                       i_rst_n                 ,


    output  wire    [15:0]      o_temp_sensor           ,
    output  wire    [15:0]      o_temp_shutter          ,
    output  wire    [15:0]      o_temp_lens             ,

    inout   wire                io_temp_iic_scl         ,
    inout   wire                io_temp_iic_sda         
);

//  参数定义
    // 延迟计数
    localparam MS = CLK_IN_FREQ/10; // 100ms
    localparam SENSOR_INIT_IIC_DELAY = MS;

    localparam FPA_TEMP_ADDR        = 3'd0; // ADC-config寄存器地址-焦温
    localparam SHUTTER_TEMP_ADDR    = 3'd4; // ADC-config寄存器地址-快门
    localparam LENS_TEMP_ADDR       = 3'd2; // ADC-config寄存器地址-镜头


//  信号定义
    // IIC SCL 与 SDA
    wire                iic_scl_oe                  ;
    wire                iic_scl_in                  ;
    wire                iic_scl_out                 ;
    wire                iic_sda_oe                  ;
    wire                iic_sda_in                  ;
    wire                iic_sda_out                 ;
    // IIC 驱动用户接口
    reg                 iic_en                      ;
    reg     [24:0]      iic_ctrl                    ;   //  {iic_wrrd, iic_reg_addr, iic_write_data}
    wire                iic_read_vld                ;
    wire    [15:0]      iic_read_data               ;
    wire                iic_busy                    ;
    // 探测器寄存器初始化
    reg     [7:0]       adc_reg_io_cnt              ;
    reg     [23:0]      iic_delay                   ;

    // 探测器寄存器配置延迟计数器
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_delay <= 'd0;
        end
        else if (iic_en || iic_busy) begin
            iic_delay <= 'd0;
        end
        else if (iic_delay == SENSOR_INIT_IIC_DELAY) begin
            iic_delay <= iic_delay;
        end
        else begin
            iic_delay <= iic_delay + 'd1;
        end
    end

    // 初始化配置计数器
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            adc_reg_io_cnt <= 8'd0;
        end
        else if (iic_en) begin
            if(adc_reg_io_cnt == 8'd5) begin
                adc_reg_io_cnt <= 8'd0;
            end else if (adc_reg_io_cnt < 8'd5) begin
                adc_reg_io_cnt <= adc_reg_io_cnt + 8'd1;
            end
            else begin
                adc_reg_io_cnt <= adc_reg_io_cnt;
            end
        end else begin
            adc_reg_io_cnt <= adc_reg_io_cnt;
        end
    end

    // 寄存器配置使能 ---300ms写+读一次即可
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_en <= 1'd0;
        end
        else if (((iic_delay == SENSOR_INIT_IIC_DELAY - 'd1) && (1 == adc_reg_io_cnt[0])) || ((iic_delay == 1'd1) && (0 == adc_reg_io_cnt[0]))) begin // 就一个钟
            iic_en <= 1'd1;
        end
        else begin
            iic_en <= 1'd0;
        end
    end

    // 操作机
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_ctrl <= 25'd0;
        end
        else if (1) begin
            case (adc_reg_io_cnt)
                // 等待初始化完成

                // 读取
                8'd0 : iic_ctrl <= {1'd0, 8'd1      , 16'hc380} + (2'd0 << 12); //lens
                8'd1 : iic_ctrl <= {1'd1, 8'd0      , 16'h0000};
                8'd2 : iic_ctrl <= {1'd0, 8'd1      , 16'hc380} + (2'd1 << 12); //shutter
                8'd3 : iic_ctrl <= {1'd1, 8'd0      , 16'h0000};
                8'd4 : iic_ctrl <= {1'd0, 8'd1      , 16'hc380} + (2'd2 << 12); //fpa
                8'd5 : iic_ctrl <= {1'd1, 8'd0      , 16'h0000};
                default: iic_ctrl <= 25'd0;
            endcase
        end
        else begin
            iic_ctrl <= iic_ctrl;
        end
    end

    // 温度读取
    reg [15:0] fpa_temp_cur    ;
    reg [15:0] shutter_temp_cur;
    reg [15:0] lens_temp_cur   ;
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            fpa_temp_cur        <= 16'd0;
            shutter_temp_cur    <= 16'd0;
            lens_temp_cur       <= 16'd0;
        end
        else if (iic_read_vld) begin
            case (adc_reg_io_cnt)
                FPA_TEMP_ADDR       : begin
                    fpa_temp_cur <= iic_read_data[15:0];
                end
                SHUTTER_TEMP_ADDR   : begin
                    shutter_temp_cur <= iic_read_data[15:0];
                end
                LENS_TEMP_ADDR      : begin
                    lens_temp_cur <= iic_read_data[15:0];
                end
                default: ;
            endcase
        end
        else begin
            fpa_temp_cur <= fpa_temp_cur;
            shutter_temp_cur <= shutter_temp_cur;
            lens_temp_cur <= lens_temp_cur;
        end
    end

    assign o_temp_sensor    = fpa_temp_cur      ;
    assign o_temp_shutter   = shutter_temp_cur  ;
    assign o_temp_lens      = lens_temp_cur     ;

    // IIC 驱动
    iic_master #(
        .CLK_IN_FREQ        ( CLK_IN_FREQ       ),
        .IIC_SCL_RQEQ       ( 100_000           ),
        .IIC_TIMING_T1_NS   ( 5000              ),
        .IIC_TIMING_T2_NS   ( 5000              ),
        .IIC_TIMING_T3_NS   ( 2500              ),
        .WP_TO_RS           ( 0                 ),
        .WAIT_SLAVE         ( 1                 ),
        .DATA_BYTE_NUM      ( 2                 ) 
    ) u_iic_master_to_adc (
        .i_clk              ( i_mc              ),
        .i_rst_n            ( i_rst_n           ),

        .o_iic_scl_oe       ( iic_scl_oe        ),
        .i_iic_scl_in       ( iic_scl_in        ),
        .o_iic_scl_out      ( iic_scl_out       ),
        .o_iic_sda_oe       ( iic_sda_oe        ),
        .i_iic_sda_in       ( iic_sda_in        ),
        .o_iic_sda_out      ( iic_sda_out       ),

        .i_slave_addr       ( 7'b1001001        ),
        .i_reg_addr         ( iic_ctrl[23:16]    ),
        .i_write_data       ( iic_ctrl[15:0]     ),
        .i_iic_en           ( iic_en            ),
        .i_wrrd             ( iic_ctrl[24]      ),
        .o_read_vld         ( iic_read_vld      ),
        .o_read_data        ( iic_read_data     ),
        .o_busy             ( iic_busy          ) 
    );
    //o
    assign io_temp_iic_scl = iic_scl_oe ? iic_scl_out : 1'bz;
    assign io_temp_iic_sda = iic_sda_oe ? iic_sda_out : 1'bz;
    //i
    assign iic_scl_in = io_temp_iic_scl;
    assign iic_sda_in = io_temp_iic_sda;
endmodule