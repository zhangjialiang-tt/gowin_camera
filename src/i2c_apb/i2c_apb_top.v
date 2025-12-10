module i2c_apb_top #(
    parameter CLK_IN_FREQ = 6_000_000,
    parameter DWIDTH_BYTE = 1
)
(
    input                                   i_mc                    ,
    input                                   i_rst_n                 ,
    input                                   i_rd_clear              ,
    input    [6:0]                          i_i2c_addr              ,
    input    [7:0]                          i_i2c_reg               ,

    output                                  o_i2c_busy              ,
    input                                   i_iic_en                ,

    input                                   i_wrrd                  ,
    input      [(DWIDTH_BYTE<<3)-1:0]       i_data                  ,

    output reg                              o_rd_vld                ,
    output reg [(DWIDTH_BYTE<<3)-1:0]       o_data                  ,
    output                                  o_iic_ack               ,
    inout   wire                            io_apb_iic_scl          ,
    inout   wire                            io_apb_iic_sda         
);

//  信号定义
    // IIC SCL 与 SDA
    wire                            iic_scl_oe                  ;
    wire                            iic_scl_in                  ;
    wire                            iic_scl_out                 ;
    wire                            iic_sda_oe                  ;
    wire                            iic_sda_in                  ;
    wire                            iic_sda_out                 ;

    wire                            rd_data_vld                 ;
    wire    [(DWIDTH_BYTE<<3)-1:0]  rd_data                     ;

always @(posedge i_mc ) begin
    if((rd_data_vld == 1'b1) && (o_i2c_busy == 1'b1))begin
        o_data <= rd_data;
    end
    else begin
        o_data <= o_data;
    end
end

always @(posedge i_mc ) begin
    if(i_rd_clear == 1'b1)begin
        o_rd_vld <= 1'b0;
    end
    else if(rd_data_vld == 1'b1)begin
        o_rd_vld <= 1'b1;
    end
    else begin
        o_rd_vld <= o_rd_vld;
    end
end

reg     [1:0]           o_rd_vld_dly;


always @(posedge i_mc ) begin
    o_rd_vld_dly <= {o_rd_vld_dly[0],o_rd_vld};
end


    // IIC 驱动用户接口
    // 寄存器配置使能 ---上升沿触发
    reg iic_en_d1;
    wire iic_en_pos;
    always @(posedge i_mc or negedge i_rst_n) begin
        if (~i_rst_n) begin
            iic_en_d1 <= 1'd0;
        end else begin
            iic_en_d1 <= i_iic_en;
        end
    end
    assign iic_en_pos = i_iic_en & (~iic_en_d1);

    // IIC 驱动
    iic_master #(
        .CLK_IN_FREQ        ( CLK_IN_FREQ       ),
        .IIC_SCL_RQEQ       ( 100_000           ),
        .IIC_TIMING_T1_NS   ( 5000              ),
        .IIC_TIMING_T2_NS   ( 5000              ),
        .IIC_TIMING_T3_NS   ( 2500              ),
        .WP_TO_RS           ( 0                 ),
        .WAIT_SLAVE         ( 1                 ),
        .DATA_BYTE_NUM      ( DWIDTH_BYTE       ) 
    ) u_iic_master_to_adc (
        .i_clk              ( i_mc              ),
        .i_rst_n            ( i_rst_n           ),

        .o_iic_scl_oe       ( iic_scl_oe        ),
        .i_iic_scl_in       ( iic_scl_in        ),
        .o_iic_scl_out      ( iic_scl_out       ),
        .o_iic_sda_oe       ( iic_sda_oe        ),
        .i_iic_sda_in       ( iic_sda_in        ),
        .o_iic_sda_out      ( iic_sda_out       ),

        .i_slave_addr       ( i_i2c_addr        ),
        .i_reg_addr         ( i_i2c_reg         ),
        .i_write_data       ( i_data            ),
        .i_iic_en           ( iic_en_pos        ),
        .i_wrrd             ( i_wrrd            ),
        .o_read_vld         ( rd_data_vld       ),
        .o_read_data        ( rd_data           ),
        .o_iic_ack          ( o_iic_ack         ), //    output  reg                                 
        .o_busy             ( o_i2c_busy        ) 
    );

     
    //o
    assign io_apb_iic_scl = iic_scl_oe ? iic_scl_out : 1'bz;
    assign io_apb_iic_sda = iic_sda_oe ? iic_sda_out : 1'bz;
    //i
    assign iic_scl_in = io_apb_iic_scl;
    assign iic_sda_in = io_apb_iic_sda;

endmodule