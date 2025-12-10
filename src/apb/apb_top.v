`include "apb_reg_define.v"
//apb_top

module apb_top
#(
  parameter     ADDR_WIDTH  = `APB_AW,
  parameter     DATA_WIDTH  = `APB_DW,
  parameter     NUM_REG     = `APB_REG_NUM,
  parameter     ADDR_BASE1  = `APB_REG_ADDR_BASE1
)
(
  input clk    ,
  input resetn ,

  input     [15:0]              i_ir_x16_mean           ,
  input     [15:0]              i_temp_sensor           ,
  input     [15:0]              i_temp_shutter          ,
  input     [15:0]              i_temp_lens             ,
  input     [3:0]               i_temp_range            ,
  input     [31:0]              i_usb_cmd               ,
  input     [31:0]              i_irq_sel               ,
  output    [DATA_WIDTH-1:0]    o_program_version0      ,
  output    [DATA_WIDTH-1:0]    o_program_version1      ,  
  output    [DATA_WIDTH-1:0]    risv_i2c_apb_bus_d1     ,
  input     [DATA_WIDTH-1:0]    risv_i2c_apb_bus_c1     ,
  output    [DATA_WIDTH-1:0]    risv_wr_en_bus0         ,
  output                        o_calc_b_en             ,
  output    [20:0]              o_b_addrs               ,
  output    [20:0]              o_k_addrs               ,
  output    [31:0]              o_mem_addrs             ,
  output    [31:0]              o_flash_addrs           ,
  output    [31:0]              o_flash_data_lens       ,
  input     [31:0]              i_risv_rd_bus0          ,
  output    [31:0]              o_risv_wr_bus0          ,
  input     [31:0]              i_param_apb32bus0       ,
  output    [31:0]              o_param_apb32bus0       ,
  output reg                    o_sensor_update_param   ,
//   output                        o_ir_freeze             ,
  output    [3:0]               o_temp_range            ,
  output    [DATA_WIDTH-1:0]    o_irq_ack               ,
  output    [7:0]               o_calc_b_num            ,
  output                        o_ir_init_done          ,
  input     [DATA_WIDTH-1:0]    i_iic_reg_addrsdata     ,
  output    [DATA_WIDTH-1:0]    o_iic_reg_ctrl          ,
  output  reg                   o_iic_update            ,       

  output    [  15: 0]           o_int_set             ,
  output    [  15: 0]           o_gain                ,
  output    [  15: 0]           o_gsk_ref             ,
  output    [  15: 0]           o_gsk                 ,
  output    [  15: 0]           o_vbus                ,
  output    [  15: 0]           o_vbus_ref            ,
  output    [  15: 0]           o_rd_rc               ,
  output    [  15: 0]           o_gfid                ,
  output    [  15: 0]           o_csize               ,
  output    [  15: 0]           o_occ_value           ,
  output    [  15: 0]           o_occ_step            ,
  output    [  15: 0]           o_occ_thres_up        ,
  output    [  15: 0]           o_occ_thres_down      ,
  output    [  15: 0]           o_ra                  ,
  output    [  15: 0]           o_ra_thres_high       ,
  output    [  15: 0]           o_ra_thres_low        ,
  output    [  15: 0]           o_raadj               ,
  output    [  15: 0]           o_raadj_thres_high    ,
  output    [  15: 0]           o_raadj_thres_low     ,
  output    [  15: 0]           o_rasel               ,
  output    [  15: 0]           o_rasel_thres_high    ,
  output    [  15: 0]           o_rasel_thres_low     ,
  output    [  15: 0]           o_hssd                ,
  output    [  15: 0]           o_hssd_thres_high     ,
  output    [  15: 0]           o_hssd_thres_low      ,
  output    [  15: 0]           o_gsk_thres_high      ,
  output    [  15: 0]           o_gsk_thres_low       ,
  output    [  15: 0]           o_nuc_step            ,

  output    [  15: 0]           o_calc_temp_sensor    ,
  output    [  15: 0]           o_calc_temp_shutter   ,
  output    [  15: 0]           o_calc_temp_lens      ,

  input                         apb_PSEL                ,
  input     [ADDR_WIDTH-1:0]    apb_PADDR               ,
  input     [3:0]               apb_PSTRB               ,
  input     [2:0]               apb_PPROT               ,
  input                         apb_PENABLE             ,
  input                         apb_PWRITE              ,
  input     [DATA_WIDTH-1:0]    apb_PWDATA              ,
  output                        apb_PREADY              ,
  output    [DATA_WIDTH-1:0]    apb_PRDATA              ,
  output                        apb_PSLVERROR           
);

//--------------------- APB3 Master [1] ---------------------------//
///////////////////////////////////////////////////////////////////////////////
  // regs & wires
    localparam [1:0]    IDLE   = 2'b00,
                        SETUP  = 2'b01,
                        ACCESS = 2'b10;

    reg    [DATA_WIDTH-1:0] slaveReg [0:NUM_REG-1];
    reg    [DATA_WIDTH-1:0] slaveRegOut;
    reg    [1:0]            busState,
                            busNext;
    reg                     slaveReady;
    wire                    actWrite,
                            actRead;

///////////////////////////////////////////////////////////////////////////////
   // machines
    always@(posedge clk or negedge resetn)
    begin
        if(!resetn)
            busState <= IDLE;
        else
            busState <= busNext;
    end

    always@(*)
    begin
        busNext = busState;

        case(busState)
            IDLE:
            begin
                if(apb_PSEL && !apb_PENABLE)
                    busNext = SETUP;
                else
                    busNext = IDLE;
            end
            SETUP:
            begin
                if(apb_PSEL && apb_PENABLE)
                    busNext = ACCESS;
                else
                    busNext = IDLE;
            end
            ACCESS:
            begin
                if(apb_PREADY)
                    busNext = IDLE;
                else
                    busNext = ACCESS;
            end
            default:
            begin
                busNext = IDLE;
            end
        endcase
    end


    assign actWrite = apb_PWRITE  & (busState == ACCESS);
    assign actRead  = !apb_PWRITE & (busState == ACCESS);
    assign apb_PRDATA = slaveRegOut;
    assign apb_PREADY = slaveReady & & (busState !== IDLE);
    assign apb_PSLVERROR = 1'b0;

    always@ (posedge clk)
    begin
        slaveReady <= actWrite | actRead;
    end

///////////////////////////////////////////////////////////////////////////////
// 读写缓存REGS
    genvar gen_i;
    generate
    for(gen_i=0; gen_i<NUM_REG; gen_i=gen_i+1)
    begin : gen_regs

        always@ (posedge clk or negedge resetn)
            if(!resetn)
                slaveReg[gen_i] <= {DATA_WIDTH{1'b0}};
            else if(actWrite & apb_PADDR == ((gen_i << 2)))
                slaveReg[gen_i] <= apb_PWDATA;

    end
    endgenerate

// 写->寄存器
    always@ (posedge clk or negedge resetn)
    if(!resetn)
        slaveRegOut <= {DATA_WIDTH{1'b0}};
    else if(actRead)
    begin
        case (apb_PADDR)
            // 只读
            `APB_REG_ADDR_AD_VALUE_AVERAGE_TOTAL    :slaveRegOut <= {16'h0000,i_ir_x16_mean};
            `APB_REG_ADDR_LENS_TEMP                 :slaveRegOut <= {16'h0000,i_temp_lens};
            `APB_REG_ADDR_SHUTTER_TEMP              :slaveRegOut <= {16'h0000,i_temp_shutter};
            `APB_REG_ADDR_FPA_TEMP                  :slaveRegOut <= {16'h0000,i_temp_sensor};
            `APB_REG_ADDR_SWITCH_RANGE              :slaveRegOut <= {25'h0000000,o_ir_init_done,3'd0,i_temp_range};
            `APB_REG_ADDR_USB_ORDER                 :slaveRegOut <= i_usb_cmd;
            `APB_REG_IRQ_SEL                        :slaveRegOut <= i_irq_sel;
            // I2C-APB
            `APB_REG_ADDR_I2C_APB_BUS_C1            :slaveRegOut <= risv_i2c_apb_bus_c1;
            `APB_REG_ADDR_EN_BUS0                   :slaveRegOut <= risv_wr_en_bus0;
            `APB_REG_TV_IIC_RW_REG                  :slaveRegOut <= i_iic_reg_addrsdata;
            `APB_REG_ADDR_RD_BUS0                   :slaveRegOut <= i_risv_rd_bus0;

            `APB_REG_ADDR_SENSOR_PARA0              :slaveRegOut <= i_param_apb32bus0 ;
 
            default                                 :slaveRegOut <= 0;
        endcase
    end

always @(posedge clk ) begin
    if((actRead == 1'b1) && (apb_PADDR == `APB_REG_TV_IIC_RW_REG))begin
        o_iic_update <= 1'b1;
    end
    else begin
        o_iic_update <= 1'b0;
    end
end

always @(posedge clk ) begin
    if((actRead == 1'b1) && (apb_PADDR == `APB_REG_ADDR_SENSOR_PARA0))begin
        o_sensor_update_param <= 1'b1;
    end
    else begin
        o_sensor_update_param <= 1'b0;
    end
end

// 寄存器->读
    //读写

    assign o_calc_b_en              = slaveReg[`APB_REG_ADDR_B_CAL                  >>2];
    assign o_b_addrs                = slaveReg[`APB_REG_ADDR_B_ADDRESS              >>2];
    // assign o_ir_freeze              = slaveReg[`APB_REG_ADDR_FREEZE                 >>2];
    assign o_k_addrs                = slaveReg[`APB_REG_ADDR_K_ADDRESS              >>2];
    assign o_temp_range             = slaveReg[`APB_REG_ADDR_SWITCH_RANGE           >>2];
    assign o_ir_init_done           = slaveReg[`APB_REG_ADDR_SWITCH_RANGE           >>2] [7];
    assign o_irq_ack                = slaveReg[`APB_REG_IRQ_SEL                     >>2];
    assign o_program_version0       = slaveReg[`APB_REG_ADDR_VERSION0               >>2];
    assign o_program_version1       = slaveReg[`APB_REG_ADDR_VERSION1               >>2];
    assign o_iic_reg_ctrl           = slaveReg[`APB_REG_TV_IIC_RW_REG               >>2];
    assign o_mem_addrs              = slaveReg[`APB_REG_ADDR_DDR_TRF_ADDR           >>2];
    assign o_flash_addrs            = slaveReg[`APB_REG_ADDR_FLASH_TRF_ADDR         >>2];
    assign o_flash_data_lens        = slaveReg[`APB_REG_ADDR_TRF_DATALENS           >>2];
    assign o_risv_wr_bus0           = slaveReg[`APB_REG_ADDR_RD_BUS0                >>2];
    assign o_param_apb32bus0        = slaveReg[`APB_REG_ADDR_SENSOR_PARA0           >>2];
    //I2C-APB
    // assign risv_i2c_apb_bus_c1      = slaveReg[`APB_REG_ADDR_I2C_APB_BUS_C1            >>2];
    assign risv_i2c_apb_bus_d1      = slaveReg[`APB_REG_ADDR_I2C_APB_BUS_D1            >>2];
    //VIS
    assign risv_wr_en_bus0          = slaveReg[`APB_REG_ADDR_EN_BUS0                >>2];
    assign o_calc_b_num             = slaveReg[`APB_REG_ADDR_CALC_B_NUM             >>2];

    assign o_int_set                  = slaveReg[`APB_REG_ADDR_SENSOR_PARA1             >>2];
    assign o_gain                     = slaveReg[`APB_REG_ADDR_SENSOR_PARA2             >>2];
    assign o_gsk_ref                  = slaveReg[`APB_REG_ADDR_SENSOR_PARA3             >>2];
    assign o_gsk                      = slaveReg[`APB_REG_ADDR_SENSOR_PARA4             >>2];
    assign o_vbus                     = slaveReg[`APB_REG_ADDR_SENSOR_PARA5             >>2];
    assign o_vbus_ref                 = slaveReg[`APB_REG_ADDR_SENSOR_PARA6             >>2];
    assign o_rd_rc                    = slaveReg[`APB_REG_ADDR_SENSOR_PARA7             >>2];
    assign o_gfid                     = slaveReg[`APB_REG_ADDR_SENSOR_PARA8             >>2];
    assign o_csize                    = slaveReg[`APB_REG_ADDR_SENSOR_PARA9             >>2];
    assign o_occ_value                = slaveReg[`APB_REG_ADDR_SENSOR_PARA10            >>2];
    assign o_occ_step                 = slaveReg[`APB_REG_ADDR_SENSOR_PARA11            >>2];
    assign o_occ_thres_up             = slaveReg[`APB_REG_ADDR_SENSOR_PARA12            >>2];
    assign o_occ_thres_down           = slaveReg[`APB_REG_ADDR_SENSOR_PARA13            >>2];
    assign o_ra                       = slaveReg[`APB_REG_ADDR_SENSOR_PARA14            >>2];
    assign o_ra_thres_high            = slaveReg[`APB_REG_ADDR_SENSOR_PARA15            >>2];
    assign o_ra_thres_low             = slaveReg[`APB_REG_ADDR_SENSOR_PARA16            >>2];
    assign o_raadj                    = slaveReg[`APB_REG_ADDR_SENSOR_PARA17            >>2];
    assign o_raadj_thres_high         = slaveReg[`APB_REG_ADDR_SENSOR_PARA18            >>2];
    assign o_raadj_thres_low          = slaveReg[`APB_REG_ADDR_SENSOR_PARA19            >>2];
    assign o_rasel                    = slaveReg[`APB_REG_ADDR_SENSOR_PARA20            >>2];
    assign o_rasel_thres_high         = slaveReg[`APB_REG_ADDR_SENSOR_PARA21            >>2];
    assign o_rasel_thres_low          = slaveReg[`APB_REG_ADDR_SENSOR_PARA22            >>2];
    assign o_hssd                     = slaveReg[`APB_REG_ADDR_SENSOR_PARA23            >>2];
    assign o_hssd_thres_high          = slaveReg[`APB_REG_ADDR_SENSOR_PARA24            >>2];
    assign o_hssd_thres_low           = slaveReg[`APB_REG_ADDR_SENSOR_PARA25            >>2];
    assign o_gsk_thres_high           = slaveReg[`APB_REG_ADDR_SENSOR_PARA26            >>2];
    assign o_gsk_thres_low            = slaveReg[`APB_REG_ADDR_SENSOR_PARA27            >>2];
    assign o_nuc_step                 = slaveReg[`APB_REG_ADDR_SENSOR_PARA28            >>2];

    assign o_calc_temp_sensor         = slaveReg[`APB_REG_ADDR_CALC_FPA_TEMP            >>2];
    assign o_calc_temp_shutter        = slaveReg[`APB_REG_ADDR_CALC_SHUTTER_TEMP        >>2];
    assign o_calc_temp_lens           = slaveReg[`APB_REG_ADDR_CALC_LENS_TEMP           >>2];
endmodule