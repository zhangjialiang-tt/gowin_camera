

module param_line #(
    parameter PROTOCOLS_VERSION0 = 6'd0,
    parameter PROTOCOLS_VERSION1 = 6'd0,
    parameter PROTOCOLS_VERSION2 = 4'd0,
    parameter PARAM_LENGHT = 256 ,
    parameter DW           = 16
) (
    input                       i_rst_n                 ,
    input                       i_clk                   ,
    input           [31:0]      i_program_version0      ,
    input           [31:0]      i_program_version1      ,
    input                       i_param_vld             ,
    input                       i_shutter_state         ,
    input           [7:0]       i_temp_range            ,
    input                       i_tr_switch_flag        ,
    input           [15:0]      i_x16_data_mean         ,
    input           [15:0]      i_center_x16_data       ,
    input           [15:0]      i_center_y16_data       ,
    input           [15:0]      i_sub_aver_y16          ,
    input           [15:0]      i_temp_shutter          ,
    input           [15:0]      i_temp_sensor           ,
    input           [15:0]      i_temp_lens             ,
    input           [15:0]      i_temp_shutter_pre      ,
    input           [15:0]      i_temp_sensor_pre       ,
    input           [15:0]      i_temp_lens_pre         ,
    input           [15:0]      i_temp_shutter_start    ,
    input           [15:0]      i_temp_lens_start       ,

    input       [  15: 0]       i_int_set               ,
    input       [  15: 0]       i_gain                  ,
    input       [  15: 0]       i_gsk_ref               ,
    input       [  15: 0]       i_gsk                   ,
    input       [  15: 0]       i_vbus                  ,
    input       [  15: 0]       i_vbus_ref              ,
    input       [  15: 0]       i_rd_rc                 ,
    input       [  15: 0]       i_gfid                  ,
    input       [  15: 0]       i_csize                 ,
    input       [  15: 0]       i_occ_value             ,
    input       [  15: 0]       i_occ_step              ,
    input       [  15: 0]       i_occ_thres_up          ,
    input       [  15: 0]       i_occ_thres_down        ,
    input       [  15: 0]       i_ra                    ,
    input       [  15: 0]       i_ra_thres_high         ,
    input       [  15: 0]       i_ra_thres_low          ,
    input       [  15: 0]       i_raadj                 ,
    input       [  15: 0]       i_raadj_thres_high      ,
    input       [  15: 0]       i_raadj_thres_low       ,
    input       [  15: 0]       i_rasel                 ,
    input       [  15: 0]       i_rasel_thres_high      ,
    input       [  15: 0]       i_rasel_thres_low       ,
    input       [  15: 0]       i_hssd                  ,
    input       [  15: 0]       i_hssd_thres_high       ,
    input       [  15: 0]       i_hssd_thres_low        ,
    input       [  15: 0]       i_gsk_thres_high        ,
    input       [  15: 0]       i_gsk_thres_low         ,
    input       [  15: 0]       i_nuc_step              ,

    input       [  15: 0]       i_ShutterCorVal         ,//快门温漂修正量
    input       [  15: 0]       i_shutterCorCoef        ,//快门温漂系数
    input       [  15: 0]       i_LensCorVal            ,//镜筒温漂修正量
    input       [  15: 0]       i_LensCorCoef           ,//镜筒温漂系数
    input       [  15: 0]       i_Compensate_flag       ,//环温修正开关  镜筒温漂校正开关 快门温漂校正开关 快门温度校正开关 距离补偿开关 透过率开关 发射率开关
    input       [  15: 0]       i_Emiss_Humidy          ,//湿度 发射率
    input       [  15: 0]       i_EnTemp_Distance       ,//距离 环境温度
    input       [  15: 0]       i_Transs                ,//透过率

    input       [  15: 0]       i_near_kf               ,
    input       [  15: 0]       i_near_b                ,
    input       [  15: 0]       i_far_kf                ,
    input       [  15: 0]       i_far_b                 ,
    input       [  15: 0]       i_pro_kf                ,
    input       [  15: 0]       i_pro_b                 ,
    input       [  15: 0]       i_pro_kf_far            ,
    input       [  15: 0]       i_pro_b_far             ,
    input       [  15: 0]       i_reflectTemp           ,

    input       [  15: 0]       i_x_fusion_offset        ,
    input       [  15: 0]       i_y_fusion_offset          ,
    input       [  15: 0]       i_fusion_amp_factor                ,
    // input       [  15: 0]       i_raadj_thres_high      ,
    // input       [  15: 0]       i_raadj_thres_low       ,
    // input       [  15: 0]       i_rasel                 ,
    // input       [  15: 0]       i_rasel_thres_high      ,
    // input       [  15: 0]       i_rasel_thres_low       ,
    // input       [  15: 0]       i_hssd                  ,
    // input       [  15: 0]       i_hssd_thres_high       ,
    // input       [  15: 0]       i_hssd_thres_low        ,
    // input       [  15: 0]       i_gsk_thres_high        ,
    // input       [  15: 0]       i_gsk_thres_low         ,
    // input       [  15: 0]       i_nuc_step              ,

    output  reg     [DW-1:0]    o_param_data            ,
    output  reg                 o_param_data_vld            
);  
    

function integer depth2width;
input [31:0] depth;
begin : fnDepth2Width
    if (depth > 1) begin
        for (depth2width=0; depth>0; depth2width = depth2width + 1)
            depth = depth>>1;
        end
    else
    depth2width = 0;
end
endfunction

reg                     [depth2width(PARAM_LENGHT)-1:0]             cnt                 ;
reg                     [DW-1:0]                                    xro_data            ;
reg                                                                 xro_calc_flag       ;   
reg                                                                 shutter_state_r1    ;
reg                                                                 shutter_state_r2    ;
reg                     [7:0]                                       temp_range          ;

reg                     [15:0]                                      program_version0    ;
reg                     [15:0]                                      program_version1    ;
reg                     [15:0]                                      program_version2    ;
reg                     [15:0]                                      devicenumber        ;


always @(posedge i_clk ) begin
    devicenumber     <= i_program_version0[31:16];
    program_version0 <= i_program_version0[15:0];
    program_version1 <= i_program_version1[31:16];
    program_version2 <= i_program_version1[15:0];
end


always @(posedge i_clk ) begin
    temp_range <= i_temp_range;
end

//  寄存参数输入
always @(posedge i_clk ) begin
    if (~i_rst_n) begin
        shutter_state_r1 <= 1'd0;
        shutter_state_r2 <= 1'd0;
    end
    else begin
        shutter_state_r1 <= i_shutter_state;
        shutter_state_r2 <= shutter_state_r1;
    end
end

always @(posedge i_clk ) begin
    if(i_param_vld == 1'b1)begin
        cnt <= cnt + 1'b1;
    end
    else begin
        cnt <= {depth2width(PARAM_LENGHT){1'b0}}; 
    end
end

always @(posedge i_clk ) begin
    case (cnt)
        'd0    : begin
            o_param_data <= 16'hAA55;
        end
        'd1    : o_param_data <=  ('h145 + 9);    // 总长度
        // 'd1    : o_param_data <= PARAM_LENGHT-1;
        'd2    : o_param_data <= devicenumber;               // [15:0]   机器编号 #04
        'd3    : o_param_data <= {PROTOCOLS_VERSION2,PROTOCOLS_VERSION1,PROTOCOLS_VERSION0};
        'd4    : o_param_data <= 46'h4c;
        'd6    : o_param_data <= program_version0;
        'd7    : o_param_data <= program_version1;
        'd8    : o_param_data <= program_version2;
        'd15   : // 块头【探测器配置】
        begin
            o_param_data <= 16'h013B;
        end
        ////////////////////////////////////
        //      探测器
        ////////////////////////////////////
        (8'd15 + 8'd2) : begin
            o_param_data <= i_int_set; // 16'd2800;
        end
        (8'd15 + 8'd3) : begin
            o_param_data <= i_gain;
        end
        (8'd15 + 8'd4) : begin
            o_param_data <= i_gsk_ref;
        end
        (8'd15 + 8'd5) : begin
            o_param_data <= i_gsk;
        end
        (8'd15 + 8'd6) : begin
            o_param_data <= i_vbus;
        end

        (8'd15 + 8'd11) : begin
            o_param_data <= i_vbus_ref;
        end
        (8'd15 + 8'd12) : begin
            o_param_data <= i_rd_rc;
        end
        (8'd15 + 8'd13) : begin
            o_param_data <= i_gfid;
        end
        (8'd15 + 8'd14) : begin
            o_param_data <= i_csize;
        end
        (8'd15 + 8'd15) : begin
            o_param_data <= i_occ_value;
        end
        (8'd15 + 8'd16) : begin
            o_param_data <= i_occ_step;
        end
        (8'd15 + 8'd17) : begin
            o_param_data <= i_occ_thres_up;
        end
        (8'd15 + 8'd18) : begin
            o_param_data <= i_occ_thres_down;
        end

        (8'd15 + 8'd21) : begin
            o_param_data <= i_ra;
        end
        (8'd15 + 8'd22) : begin
            o_param_data <= i_ra_thres_high;
        end
        (8'd15 + 8'd24) : begin
            o_param_data <= i_ra_thres_low;
        end
        (8'd15 + 8'd25) : begin
            o_param_data <= i_raadj;
        end
        (8'd15 + 8'd34) : begin
            o_param_data <= i_raadj_thres_high;
        end
        (8'd15 + 8'd35) : begin
            o_param_data <= i_raadj_thres_low;
        end
        (8'd15 + 8'd36) : begin
            o_param_data <= i_rasel;
        end
        (8'd15 + 8'd37) : begin
            o_param_data <= i_rasel_thres_high;
        end
        (8'd15 + 8'd47) : begin
            o_param_data <= i_rasel_thres_low;
        end
        (8'd15 + 8'd48) : begin
            o_param_data <= i_hssd;
        end
        (8'd15 + 8'd49) : begin
            o_param_data <= i_hssd_thres_high;
        end
        (8'd15 + 8'd50) : begin
            o_param_data <= i_hssd_thres_low;
        end
        (8'd15 + 8'd51) : begin
            o_param_data <= i_gsk_thres_high;
        end
        (8'd15 + 8'd52) : begin
            o_param_data <= i_gsk_thres_low;
        end
        (8'd15 + 8'd53) : begin // 最后一个寄存器
            o_param_data <= i_nuc_step;
        end

        ////////////////////////////////////////////////////////////////////////////////////
        (8'd15 + (1'd1 +8'h3B)) : // 块头【测温相关信息】
        begin
            o_param_data <= 16'h0240;
        end
        
        (8'd15 + (1'd1 +8'h3B) + 8'd01) : // temp range
        begin
            o_param_data <= temp_range & 4'hf;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd02) : //  中心点 X16 x16          //78
        begin
            o_param_data <= i_center_x16_data;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd03) : //  本底均值 x16          //78
        begin
            o_param_data <= i_x16_data_mean;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd04) : //  中心点 Y16 x16          //78
        begin
            o_param_data <= i_center_y16_data;
        end

        (8'd15 + (1'd1 +8'h3B) + 8'd09) : // 开机快门温
        begin
            o_param_data <= i_temp_shutter_start; // 16'd2400;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd10) : // 开机镜筒温
        begin
            o_param_data <= i_temp_lens_start; // 16'd2200;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd11) : // 快门温
        begin
            o_param_data <= i_temp_shutter; // 16'd2500;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd12) : // 镜筒温
        begin
            o_param_data <= i_temp_lens; // 16'd2300;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd13) : // 焦温
        begin
            o_param_data <= i_temp_sensor; // 16'd2800;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd14) : // last快门温
        begin
            o_param_data <= i_temp_shutter_pre; // 16'd2800;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd15) : // 当前快门温
        begin
            o_param_data <= i_temp_shutter_pre; // 16'd2800;
        end

        (8'd15 + (1'd1 +8'h3B) + 8'd16) : // last镜筒温
        begin
            o_param_data <= i_temp_lens_pre; // 16'd2800;
        end
        (8'd15 + (1'd1 +8'h3B) + 8'd17) : // 当前镜筒温
        begin
            o_param_data <= i_temp_lens_pre; // 16'd2800;
        end
        
        (8'd15 + (1'd1 +8'h3B) + 8'd24) : //  中心点 Y16 x16          //78
        begin
            o_param_data <= i_sub_aver_y16;
        end


        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40)) : // 块头【状态信息】
        begin
            o_param_data <= 16'h031D;
        end

        // (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd1)://+_快门状态（1：关；0：开）_+
        // begin
        //     o_param_data <= (((shutter_state_r2) & 1'b1)<<2) | (i_tr_switch_flag & 1'b1);
        // end

        // (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd1)://
        // begin
        //     o_param_data <= i_ShutterCorVal;//快门温漂修正量
        // end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd2)://镜筒温漂修正量
        begin
            o_param_data <= i_shutterCorCoef;//快门温漂系数
        end
        // (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd3)://镜筒温漂修正量
        // begin
        //     o_param_data <= i_LensCorVal;
        // end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd4)://镜筒温漂系数
        begin
            o_param_data <= i_LensCorCoef;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd5)://
        begin
            o_param_data <= i_Compensate_flag;//TranssCom EmissCom DistanceComp ShutterTempCor ShutterCor LensCor EnvtCor 开关
        end

        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd6)://
        begin
            o_param_data <= i_Emiss_Humidy;//湿度 发射率
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd7)://
        begin
            o_param_data <= i_EnTemp_Distance;//距离 环境温度
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd8)://
        begin
            o_param_data <= i_Transs;//透过率
        end

        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd9) : // 
        begin
            o_param_data <= i_near_kf;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd10) : // 
        begin
            o_param_data <= i_near_b;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd11) : // 
        begin
            o_param_data <= i_far_kf;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd12) : //
        begin
            o_param_data <= i_far_b;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd13) : // 
        begin
            o_param_data <= i_pro_kf;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd14) : // 
        begin
            o_param_data <= i_pro_b;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd15) : // 
        begin
            o_param_data <= i_pro_kf_far;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd16) : // 
        begin
            o_param_data <= i_pro_b_far;
        end
        (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + 8'd20) : // 
        begin
            o_param_data <= i_reflectTemp;//反射温度 i_reflectTemp
        end

        (170) : // 
        begin
            o_param_data <= 16'h0413;
        end
        (190) : // 
        begin
            o_param_data <= 16'h0518;
        end
        (215) : // 
        begin
            o_param_data <= 16'h0627;
        end
        (255) : //
        begin
            o_param_data <= 16'h0731;
        end
        (305) : // 
        begin
            o_param_data <= 16'h0813;
        end

        ('h145) : // 使能=>0
        begin
            o_param_data <= 16'h090a;
        end
          
        ('h145 + 7): // 
        begin
            o_param_data <= i_x_fusion_offset;
        end
        ('h145 + 8): //
        begin
            o_param_data <= i_y_fusion_offset;
        end
        ('h145 + 9): //
        begin
            o_param_data <= i_fusion_amp_factor;
        end
        // (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + (1'd1 +8'h13)) : // 【校验】
        // begin
        //     o_param_data <= xro_data;
        // end
        // (8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + (1'd1 +8'h13) + 1'd1) : // 【帧尾】
        // begin
        //     o_param_data <= 16'h00F0;
        // end
        (PARAM_LENGHT-3) : // 【校验】
        begin
            o_param_data <= xro_data;
        end
        (PARAM_LENGHT-2) : // 【帧尾】
        begin
            o_param_data <= 16'h00F0;
        end
        (PARAM_LENGHT-1)  : o_param_data <= 16'hCC77;
        default: o_param_data <= {DW{1'b0}};
    endcase
end

always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        xro_calc_flag <= 1'b0;
    end
    else if((cnt == {depth2width(PARAM_LENGHT){1'b0}}) && (i_param_vld == 1'b1))begin
        xro_calc_flag <= 1'b1;
    end
    // else if((cnt == 8'd15 + (1'd1 +8'h3B) + (1'd1 +8'h40) + (1'd1 +8'h13) - 1'd1) && (i_param_vld == 1'b1))begin
    //    xro_calc_flag <= 1'b0; 
    // end
    else if((cnt == (PARAM_LENGHT-4)) && (i_param_vld == 1'b1))begin
       xro_calc_flag <= 1'b0; 
    end
    else begin
       xro_calc_flag <= xro_calc_flag; 
    end
end

always @(posedge i_clk ) begin
    if(xro_calc_flag == 1'b1)begin
        xro_data <= xro_data ^ o_param_data;
    end
    else begin
        xro_data <= 16'd0; 
    end
end

always @(posedge i_clk ) begin
    o_param_data_vld <= i_param_vld;
end

endmodule