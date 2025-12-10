module usb_cmd_parsing (
    input                       i_usb_user_clk          ,
    input                       i_rst_n                 ,

    input           [3:0]       i_endpt_sel             ,
    input                       i_usb_rxact             ,
    input                       i_usb_rxval             ,
    input           [7:0]       i_usb_rxdat             ,

    input                       i_os_type               ,
    //update
    output          [7:0]       o_data_update           ,
    output          [7:0]       o_cmd_data              ,
    output                      o_data_update_vld       ,
    output          [31:0]      o_update_lens           ,
    output          [7:0]       o_update_type           ,
    output  reg                 o_state_rst             ,
    input                       i_update_end            ,    

    output  reg                 o_usb_cmd_flag          ,             
    output  reg     [31:0]      o_cmd                   ,
    output  reg     [15:0]      o_data                  ,
    output  reg                 o_usb_cmd_en                 
);
//  参数定义
    parameter  PROGRAM_UPDATE_PACKAGE   = 32'h0007; 
    parameter  PARAMETER_UPDATE_PACKAGE = 32'h0036; 
    parameter  DATA_LOW_UPDATE_PACKAGE  = 32'h0038; 
    parameter  DATA_HIGH_UPDATE_PACKAGE = 32'h0039; 
    parameter  PARAMETER_SEND_PACKAGE   = 32'h003b; 
    parameter  PARAMETER_SEND_STATE     = 32'h003E; 
    parameter  GUOGAI_UPDATE_PACKAGE    = 32'h0056; 
    parameter  GUOGAI_SEND_PACKAGE      = 32'h005a;

    reg [7:0] cmd_temp_range;
//  信号定义
    reg     [3:0]       endpt_sel_r1    ;
    reg                 usb_rxact_r1    ;
    reg                 usb_rxval_r1    ;
    reg     [7:0]       usb_rxdat_r1    ;
    reg     [3:0]       endpt_sel_r2    ;
    reg                 usb_rxact_r2    ;
    reg                 usb_rxval_r2    ;
    reg     [7:0]       usb_rxdat_r2    ;

    reg     [135:0]     rx_data         ;
    reg                 usb_cmd_en      ;
    reg     [1:0]       update_end_reg0  ;
    
    reg     [  21: 0]        i                           ;
    reg     [   7: 0]        cnt[3:0]                    ;
    reg     [  21: 0]        pack_cnt                    ;
    reg     [   2: 0]        det_sta                     ;
    reg     [  15: 0]        packtype                    ;
    reg     [   7: 0]        packtype_ff0                ;
    reg     [   7: 0]        updata_data                 ;
    reg                      updata_vld                  ;
    reg     [   3: 0]        cnt_wait                    ;
    wire                     updata_en;
    assign                   updata_en =  (PROGRAM_UPDATE_PACKAGE  == packtype) || (GUOGAI_UPDATE_PACKAGE      == packtype) || 
                                          (DATA_LOW_UPDATE_PACKAGE == packtype) || (DATA_HIGH_UPDATE_PACKAGE   == packtype) ? 1 : 0;
//  寄存数据
    always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            endpt_sel_r1    <= 4'd0;
            usb_rxact_r1    <= 1'd0;
            usb_rxval_r1    <= 1'd0;
            usb_rxdat_r1    <= 8'd0;
            endpt_sel_r2    <= 4'd0;
            usb_rxact_r2    <= 1'd0;
            usb_rxval_r2    <= 1'd0;
            usb_rxdat_r2    <= 8'd0;
            update_end_reg0 <= 0;
        end
        else begin
            endpt_sel_r1    <= i_endpt_sel;
            usb_rxact_r1    <= i_usb_rxact;
            usb_rxval_r1    <= i_usb_rxval;
            usb_rxdat_r1    <= i_usb_rxdat;
            endpt_sel_r2    <= endpt_sel_r1;
            usb_rxact_r2    <= usb_rxact_r1;
            usb_rxval_r2    <= usb_rxval_r1;
            usb_rxdat_r2    <= usb_rxdat_r1;
            update_end_reg0 <={update_end_reg0[0],i_update_end};
        end
    end

//  接收指令
    always @(posedge i_usb_user_clk ) begin
        if (~i_os_type && endpt_sel_r2 == 4'd1 && usb_rxact_r2 && usb_rxval_r2) begin
            usb_cmd_en <= 1'b1;
        end
        else if (i_os_type && endpt_sel_r2 == 4'd2 && usb_rxact_r2 && usb_rxval_r2) begin
            usb_cmd_en <= 1'b1;
        end
        else begin
            usb_cmd_en <= 1'b0;
        end
    end

always @(posedge i_usb_user_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            rx_data <= 136'd0;
        end
        else if (~i_os_type && endpt_sel_r2 == 4'd1 && usb_rxact_r2 && usb_rxval_r2) begin
            rx_data <= {rx_data[127:0], usb_rxdat_r2};
        end
        else if (i_os_type && endpt_sel_r2 == 4'd2 && usb_rxact_r2 && usb_rxval_r2) begin
            rx_data <= {rx_data[127:0], usb_rxdat_r2};
        end
        else begin
            rx_data <= rx_data;
        end
    end

reg             usb_cmd_flag0 = 0;
always @(posedge i_usb_user_clk ) begin
    if(usb_cmd_en == 1'b0)begin
        o_usb_cmd_en <= 1'b0;
    end
    else if(rx_data[135:128] == 8'h02 && rx_data[103:96] == 8'h04 && rx_data[7:0] == 8'h03)begin
        o_usb_cmd_en <= 1'b1;
    end
    else begin
        o_usb_cmd_en <= 1'b0;
    end
end

wire [8*1-1:0]      rx_data0;
wire [8*2-1:0]      rx_data1;
wire [8*1-1:0]      rx_data2;
wire [8*1-1:0]      rx_data3;
wire [8*1-1:0]      rx_data4;
assign rx_data0 = rx_data[135:128];
assign rx_data1 = rx_data[127:112];
assign rx_data2 = rx_data[103:96];
assign rx_data3 = rx_data[7:0];
always @(posedge i_usb_user_clk) begin
    
    if(o_usb_cmd_en & !updata_en)
        o_usb_cmd_flag <= ~o_usb_cmd_flag;
    else 
        o_usb_cmd_flag <= o_usb_cmd_flag;
end
// assign  o_usb_cmd_flag = !updata_en ? usb_cmd_flag0 : 0;

always @(posedge i_usb_user_clk ) begin
    if(usb_cmd_en == 1'b0)begin
        o_cmd  <= o_cmd ;
        o_data <= o_data;
    end
    else if(rx_data[135:128] == 8'h02 && rx_data[103:96] == 8'h04 && rx_data[7:0] == 8'h03)begin
        o_cmd  <= rx_data[127:112] ;
        o_data <= {rx_data[31:24],rx_data[39:32]};
    end
    else begin
        o_cmd  <= o_cmd ;
        o_data <= o_data;
    end
end
///////////////////////////////////////////////
//      程序升级数据包接收
///////////////////////////////////////////////
wire                cmd_val;
assign cmd_val =    (PROGRAM_UPDATE_PACKAGE     == {rx_data[7:0],packtype}) || (GUOGAI_UPDATE_PACKAGE      == {rx_data[7:0],packtype}) || (DATA_LOW_UPDATE_PACKAGE == {rx_data[7:0],packtype}) ||
                    (DATA_HIGH_UPDATE_PACKAGE   == {rx_data[7:0],packtype}) || (PARAMETER_SEND_PACKAGE     == {rx_data[7:0],packtype}) || (PARAMETER_SEND_STATE    == {rx_data[7:0],packtype}) ||
                    (GUOGAI_SEND_PACKAGE        == {rx_data[7:0],packtype});
always @(posedge i_usb_user_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        det_sta <= 1'd0;
        cnt_wait <= 1'b0;
        i <= 1'b0;
        packtype <= 'b0;
        updata_data <= 1'd0;
        updata_vld  <= 1'd0;
        o_state_rst <= 0;
    end
    else if(usb_cmd_en) begin
        case(det_sta)
            3'd0:
            begin
                packtype    <= 'b0;
                o_state_rst <= 0;
                cnt_wait    <= 1'b0;
                i           <= 1'b0;
                updata_data <= 1'd0;
                updata_vld  <= 1'd0;
                if('h2 == rx_data[7:0])
                    det_sta <= det_sta + 1'd1;
                else
                    det_sta <= 3'd0;
            end
            3'd1:
            begin
                // if(cmd_val) begin
                    // packtype <= 1'b0;
                     det_sta <= det_sta + 1'd1;
                // end 
                // else det_sta <= 3'd0;
                packtype[7:0]<= rx_data[7:0];
                // o_state_rst  <= (rx_data[7:0] == PARAMETER_SEND_PACKAGE) || (rx_data[7:0] == PARAMETER_SEND_STATE) ? 1 : 0;
            end
            3'd2:
            begin
                if(cnt_wait < 1) begin
                    cnt_wait <= cnt_wait + 1'd1;
                    if(cmd_val) begin
                       det_sta <= det_sta;
                    end 
                    else det_sta <= 3'd0;
                    packtype[15:8]<= rx_data[7:0];
                end else begin
                    cnt_wait <= 1'b0;
                    det_sta <= det_sta + 1'd1;
                    i <= 1'b0;
                end
            end
            3'd3://lens
            begin
                if(i < 3) begin
                    cnt[i] <= rx_data[7:0];
                    i <= i + 1'd1;
                end else begin
                    i <= 1'b0;
                    pack_cnt <= {rx_data[7:0],cnt[2],cnt[1],cnt[0]};
                    det_sta <= det_sta + 1'd1;
                end
            end
            3'd4://crc
            begin
                i   <= 1'b0;
                if(cnt_wait < 3) begin
                    cnt_wait <= cnt_wait + 1'd1;
                end else begin
                    cnt_wait <= 1'b0;
                    det_sta <= det_sta + 1'd1;
                end
            end
            3'd5://data
            begin
                o_state_rst <= 0;
                if(i < (pack_cnt)) begin
                    i <= i + 1'd1;
                    updata_data <= rx_data[7:0];
                    updata_vld <= 1'b1;
                end else begin
                    updata_data <= rx_data[7:0];
                    updata_vld <= 1'b0;
                    det_sta <= 1'd0;
                end
            end
        endcase
    end else begin
        if(update_end_reg0[1])
            packtype <= 0;
        else 
            packtype <= packtype;

        if(updata_en)
        // if((packtype == DATA_LOW_UPDATE_PACKAGE) ||(packtype == DATA_HIGH_UPDATE_PACKAGE)||(packtype == PROGRAM_UPDATE_PACKAGE)||(packtype == GUOGAI_UPDATE_PACKAGE))
        // if((packtype == DATA_LOW_UPDATE_PACKAGE) ||(packtype == DATA_HIGH_UPDATE_PACKAGE)||(packtype == PROGRAM_UPDATE_PACKAGE)||(packtype == GUOGAI_UPDATE_PACKAGE) || (packtype == PARAMETER_UPDATE_PACKAGE))
            det_sta     <= det_sta;
        else 
            det_sta     <= 1'd0;

        updata_vld  <= 1'b0;
    end
end
reg     [   31: 0]                          cmd_data;
reg     [   4: 0]                          send_rst_cmd_cnt;
reg     [   4: 0]                          send_low_cmd_cnt;
reg     [   4: 0]                          send_high_cmd_cnt;
always @(posedge i_usb_user_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        cmd_data            <= 1'b0;
        packtype_ff0        <= 0;
        send_low_cmd_cnt    <= 0;
        send_high_cmd_cnt   <= 0;
        send_rst_cmd_cnt    <= 0;
    end
    else begin
        if(updata_vld)
            cmd_data <= {cmd_data[23:0],updata_data};
        else 
            cmd_data <= cmd_data; 

        if(update_end_reg0[1])
            packtype_ff0 <= 0;
        else if(usb_cmd_en && cmd_val)
            packtype_ff0 <= packtype[7:0];
        else 
            packtype_ff0 <= packtype_ff0;

        if(usb_cmd_en && (PARAMETER_SEND_PACKAGE == rx_data[7:0]))
            send_low_cmd_cnt <= send_low_cmd_cnt +1;
        else 
            send_low_cmd_cnt <= send_low_cmd_cnt;

    end
end

assign o_data_update            = updata_data;
assign o_data_update_vld        = updata_en ? updata_vld : 0;
assign o_update_lens            = pack_cnt;
assign o_update_type            = packtype_ff0;    
assign o_cmd_data               = cmd_data[31:24];                 
endmodule