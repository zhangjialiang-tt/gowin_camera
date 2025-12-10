module video_display #(
    parameter DW                    = 16                    ,
    parameter SDRAM_ADDRS_DW        = 21                    ,
    parameter HEAD_LENGTH           = 32                    ,
    parameter IR_IMAGE_WIDE_LENGTH  = 256                   ,
    parameter IR_IMAGE_HIGH_LENGTH  = 192                   ,
    parameter TV_IMAGE_WIDE_LENGTH  = 800                   ,
    parameter TV_IMAGE_HIGH_LENGTH  = 600                   ,
    parameter PARAM_LENGHT          = 256                     

) (
    input                               i_rst_n                     ,
    input                               i_clk                       ,
    input       [31:0]                  i_program_version0          ,
    input       [31:0]                  i_program_version1          ,
    input       [15:0]                  i_x16_data_mean             ,
    input       [15:0]                  i_center_x16_data           ,
    input       [15:0]                  i_center_y16_data           ,
    input       [15:0]                  i_sub_aver_y16              ,
    input       [15:0]                  i_shutter_state             ,            
    input       [15:0]                  i_temp_range                ,   
    input       [15:0]                  i_tr_switch_flag            ,   
    input       [15:0]                  i_temp_shutter              ,   
    input       [15:0]                  i_temp_sensor               ,   
    input       [15:0]                  i_temp_lens                 ,   
    input       [15:0]                  i_temp_shutter_pre          ,   
    input       [15:0]                  i_temp_sensor_pre           ,   
    input       [15:0]                  i_temp_lens_pre             ,   
    input       [15:0]                  i_temp_shutter_start        ,   
    input       [15:0]                  i_temp_lens_start           ,  

    input       [  15: 0]               i_int_set                   ,
    input       [  15: 0]               i_gain                      ,
    input       [  15: 0]               i_gsk_ref                   ,
    input       [  15: 0]               i_gsk                       ,
    input       [  15: 0]               i_vbus                      ,
    input       [  15: 0]               i_vbus_ref                  ,
    input       [  15: 0]               i_rd_rc                     ,
    input       [  15: 0]               i_gfid                      ,
    input       [  15: 0]               i_csize                     ,
    input       [  15: 0]               i_occ_value                 ,
    input       [  15: 0]               i_occ_step                  ,
    input       [  15: 0]               i_occ_thres_up              ,
    input       [  15: 0]               i_occ_thres_down            ,
    input       [  15: 0]               i_ra                        ,
    input       [  15: 0]               i_ra_thres_high             ,
    input       [  15: 0]               i_ra_thres_low              ,
    input       [  15: 0]               i_raadj                     ,
    input       [  15: 0]               i_raadj_thres_high          ,
    input       [  15: 0]               i_raadj_thres_low           ,
    input       [  15: 0]               i_rasel                     ,
    input       [  15: 0]               i_rasel_thres_high          ,
    input       [  15: 0]               i_rasel_thres_low           ,
    input       [  15: 0]               i_hssd                      ,
    input       [  15: 0]               i_hssd_thres_high           ,
    input       [  15: 0]               i_hssd_thres_low            ,
    input       [  15: 0]               i_gsk_thres_high            ,
    input       [  15: 0]               i_gsk_thres_low             ,
    input       [  15: 0]               i_nuc_step                  ,

    input       [  15: 0]               i_ShutterCorVal             ,
    input       [  15: 0]               i_shutterCorCoef              ,
    input       [  15: 0]               i_LensCorVal                  ,
    input       [  15: 0]               i_LensCorCoef                 ,
    input       [  15: 0]               i_Compensate_flag             ,
    input       [  15: 0]               i_Emiss_Humidy          ,//湿度 发射率
    input       [  15: 0]               i_EnTemp_Distance       ,//距离 环境温度
    input       [  15: 0]               i_Transs                ,//透过率
    input       [  15: 0]               i_near_kf                     ,
    input       [  15: 0]               i_near_b                      ,
    input       [  15: 0]               i_far_kf                      ,
    input       [  15: 0]               i_far_b                       ,
    input       [  15: 0]               i_pro_kf                      ,
    input       [  15: 0]               i_pro_b                       ,
    input       [  15: 0]               i_pro_kf_far                  ,
    input       [  15: 0]               i_pro_b_far                   ,
    input       [  15: 0]               i_reflectTemp                 ,         
    input       [  15: 0]               i_x_fusion_offset           ,
    input       [  15: 0]               i_y_fusion_offset           ,
    input       [  15: 0]               i_fusion_amp_factor         ,
    
    input                               i_start                     ,
    input                               i_head_vld                  ,
    input                               i_param_vld                 ,
    input       [1:0]                   i_ir_cnt                    ,
    input       [1:0]                   i_tv_cnt                    ,
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_ir_addrs0             ,
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_ir_addrs1             ,
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_ir_addrs2             ,
    output                              o_mem_ir_start              ,
    output      [SDRAM_ADDRS_DW - 1:0]  o_mem_ir_addrs              ,
    output      [31:0]                  o_mem_ir_length             ,
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_tv_addrs0             ,  
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_tv_addrs1             ,  
    input       [SDRAM_ADDRS_DW - 1:0]  i_mem_tv_addrs2             ,  
    output                              o_mem_tv_start              ,  
    output      [SDRAM_ADDRS_DW - 1:0]  o_mem_tv_addrs              ,   
    output      [31:0]                  o_mem_tv_length             ,
    output wire [DW-1:0]                o_head_data                 ,
    output wire                         o_head_data_vld             ,
    output wire [DW-1:0]                o_param_data                ,
    output wire                         o_param_data_vld                        
        
);
    
frame_head_generate #(
  .DW                               (DW                         ),
  .HEAD_LENGTH                      (HEAD_LENGTH                )          
)
frame_head_generate_inst
(
    .i_rst_n                        (i_rst_n                    ),        //input                               
    .i_clk                          (i_clk                      ),        //input                               
    .i_head_vld                     (i_head_vld                 ),        //input                               
    .o_head                         (o_head_data                ),        //output reg  [DW-1:0]                
    .o_head_vld                     (o_head_data_vld            )         //output reg                             
);

param_line #(
    .PARAM_LENGHT (PARAM_LENGHT     ),
    .DW           (DW               ) 
)param_line_inst (
    .i_rst_n                 (i_rst_n                   ),        //input                       
    .i_clk                   (i_clk                     ),        //input      
    .i_program_version0      (i_program_version0        ),        //input           [31:0]
    .i_program_version1      (i_program_version1        ),        //input           [31:0]                 
    .i_param_vld             (i_param_vld               ),        //input   
    .i_x16_data_mean         (i_x16_data_mean           ),        //input           [15:0]  
    .i_center_x16_data       (i_center_x16_data         ),
    .i_center_y16_data       (i_center_y16_data         ),
    .i_sub_aver_y16          (i_sub_aver_y16            ),                
    .i_shutter_state         (i_shutter_state           ),        //input                       
    .i_temp_range            (i_temp_range              ),        //input           [7:0]       
    .i_tr_switch_flag        (i_tr_switch_flag          ),        //input                       
    .i_temp_shutter          (i_temp_shutter            ),        //input           [15:0]      
    .i_temp_sensor           (i_temp_sensor             ),        //input           [15:0]      
    .i_temp_lens             (i_temp_lens               ),        //input           [15:0]      
    .i_temp_shutter_pre      (i_temp_shutter_pre        ),        //input           [15:0]      
    .i_temp_sensor_pre       (i_temp_sensor_pre         ),        //input           [15:0]      
    .i_temp_lens_pre         (i_temp_lens_pre           ),        //input           [15:0]      
    .i_temp_shutter_start    (i_temp_shutter_start      ),        //input           [15:0]      
    .i_temp_lens_start       (i_temp_lens_start         ),        //input           [15:0]     
    
    .i_int_set               (i_int_set                       ),
    .i_gain                  (i_gain                          ),
    .i_gsk_ref               (i_gsk_ref                       ),
    .i_gsk                   (i_gsk                           ),
    .i_vbus                  (i_vbus                          ),
    .i_vbus_ref              (i_vbus_ref                      ),
    .i_rd_rc                 (i_rd_rc                         ),
    .i_gfid                  (i_gfid                          ),
    .i_csize                 (i_csize                         ),
    .i_occ_value             (i_occ_value                     ),
    .i_occ_step              (i_occ_step                      ),
    .i_occ_thres_up          (i_occ_thres_up                  ),
    .i_occ_thres_down        (i_occ_thres_down                ),
    .i_ra                    (i_ra                            ),
    .i_ra_thres_high         (i_ra_thres_high                 ),
    .i_ra_thres_low          (i_ra_thres_low                  ),
    .i_raadj                 (i_raadj                         ),
    .i_raadj_thres_high      (i_raadj_thres_high              ),
    .i_raadj_thres_low       (i_raadj_thres_low               ),
    .i_rasel                 (i_rasel                         ),
    .i_rasel_thres_high      (i_rasel_thres_high              ),
    .i_rasel_thres_low       (i_rasel_thres_low               ),
    .i_hssd                  (i_hssd                          ),
    .i_hssd_thres_high       (i_hssd_thres_high               ),
    .i_hssd_thres_low        (i_hssd_thres_low                ),
    .i_gsk_thres_high        (i_gsk_thres_high                ),
    .i_gsk_thres_low         (i_gsk_thres_low                 ),
    .i_nuc_step              (i_nuc_step                      ),

    .i_ShutterCorVal         (i_ShutterCorVal        ),
    .i_shutterCorCoef        (i_shutterCorCoef                ),
    .i_LensCorVal            (i_LensCorVal                    ),
    .i_LensCorCoef           (i_LensCorCoef                   ),
    .i_Compensate_flag       (i_Compensate_flag               ),
    .i_Emiss_Humidy          (i_Emiss_Humidy                  ),
    .i_EnTemp_Distance       (i_EnTemp_Distance               ),
    .i_Transs                (i_Transs                        ),
    .i_near_kf               (i_near_kf                       ),
    .i_near_b                (i_near_b                        ),
    .i_far_kf                (i_far_kf                        ),
    .i_far_b                 (i_far_b                         ),
    .i_pro_kf                (i_pro_kf                        ),
    .i_pro_b                 (i_pro_b                         ),
    .i_pro_kf_far            (i_pro_kf_far                    ),
    .i_pro_b_far             (i_pro_b_far                     ),
    .i_reflectTemp           (i_reflectTemp                   ),
    .i_x_fusion_offset       (i_x_fusion_offset               ),
    .i_y_fusion_offset       (i_y_fusion_offset               ),
    .i_fusion_amp_factor     (i_fusion_amp_factor             ),

    .o_param_data            (o_param_data              ),        //output  reg     [DW-1:0]    
    .o_param_data_vld        (o_param_data_vld          )         //output  reg                    
);


image_data_get #(
    .SDRAM_ADDRS_DW          (SDRAM_ADDRS_DW            ),
    .IMAGE_WIDE_LENGTH       (IR_IMAGE_WIDE_LENGTH      ),
    .IMAGE_HIGH_LENGTH       (IR_IMAGE_HIGH_LENGTH      )  
)image_data_get_ir_inst (
    .i_rst_n                 (i_rst_n                   ), //input                                          
    .i_clk                   (i_clk                     ), //input                                          
    .i_image_start           (i_start                   ), //input                                         
    .i_mem_cnt               (i_ir_cnt                  ), //input           [1:0]                          
    .i_mem_addrs0            (i_mem_ir_addrs0           ), //input           [SDRAM_ADDRS_DW-1:0]            
    .i_mem_addrs1            (i_mem_ir_addrs1           ), //input           [SDRAM_ADDRS_DW-1:0]           
    .i_mem_addrs2            (i_mem_ir_addrs2           ), //input           [SDRAM_ADDRS_DW-1:0]           
    .o_mem_start             (o_mem_ir_start            ), //output  reg                                       
    .o_mem_addrs             (o_mem_ir_addrs            ), //output  reg     [SDRAM_ADDRS_DW-1:0]           
    .o_data_length           (o_mem_ir_length           )  //output          [31:0]                                                
);

image_data_get #(
    .SDRAM_ADDRS_DW          (SDRAM_ADDRS_DW            ),
    .IMAGE_WIDE_LENGTH       (TV_IMAGE_WIDE_LENGTH      ),
    .IMAGE_HIGH_LENGTH       (TV_IMAGE_HIGH_LENGTH      )  
)image_data_get_tv_inst (
    .i_rst_n                 (i_rst_n                   ), //input                                          
    .i_clk                   (i_clk                     ), //input                                          
    .i_image_start           (i_start                   ), //input                                         
    .i_mem_cnt               (i_tv_cnt                  ), //input           [1:0]                          
    .i_mem_addrs0            (i_mem_tv_addrs0           ), //input           [SDRAM_ADDRS_DW-1:0]            
    .i_mem_addrs1            (i_mem_tv_addrs1           ), //input           [SDRAM_ADDRS_DW-1:0]           
    .i_mem_addrs2            (i_mem_tv_addrs2           ), //input           [SDRAM_ADDRS_DW-1:0]           
    .o_mem_start             (o_mem_tv_start            ), //output  reg                                       
    .o_mem_addrs             (o_mem_tv_addrs            ), //output  reg     [SDRAM_ADDRS_DW-1:0]           
    .o_data_length           (o_mem_tv_length           )  //output          [31:0]                                                
);

endmodule