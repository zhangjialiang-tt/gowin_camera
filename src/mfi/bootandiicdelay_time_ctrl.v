module bootandiic_ctrl #(
    parameters
) (
    input                   i_rst_n             ,
    input                   i_clk               ,
    input                   i_i2c_busy_neg      ,
    input                   i_iic_start         ,
    input                   i_iic_ack           ,
    input                   i_loop_tx_start     ,
    input                   i_loop_tx_ack       ,
    output  reg             o_iic_dly_done      ,
    output  reg             o_oop_tx_dly_done   ,
    output  reg             o_boot_pass             
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

    localparam MS = 60_000;
    localparam PWR_DELAY_MS     = 5000;
    localparam IIC_DELAY_MS     = 15;
    localparam LOOP_TX_DELAY_MS = 200;

    localparam BOOT                   = {7'b0000000 , 1'b0 };
    localparam IDLE                   = {7'b0000001 , 1'b0 };
    localparam PWR_DELAY              = {7'b0000010 , 1'd1 };
    localparam CERITICATE_LEN_RD      = {7'b0000100 , 1'd0 };
    localparam IIC_DELAY1             = {7'b0001000 , 1'd1 };
    localparam CERITICATE_DATA_RD     = {7'b0010000 , 1'd0 };
    localparam IIC_DELAY2             = {7'b0100000 , 1'd1 };
    localparam DETECT_TX_PRE          = {7'b1000000 , 1'd1 };

reg                                         state_c         ;
reg        [depth2width(MS)-1:0]            ms_delay_cnt    ;
reg        [depth2width(PWR_DELAY_MS)-1:0]  delay_cnt       ;                                                                        state_c;         

//状态机
always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        state_c <= BOOT;
    end
    else begin
        case (state_c)
        BOOT:state_c <= PWR_DELAY;
  PWR_DELAY :if(delay_cnt == PWR_DELAY_MS-2)begin
            state_c  <= CERITICATE_LEN_RD;
            end
            else begin
                state_c <= state_c;
            end
CERITICATE_LEN_RD :if(i_i2c_busy_neg == 1'b1)begin
                state_c  <= IIC_DELAY1;
            end
            else begin
                state_c <= state_c;
            end
IIC_DELAY1 :if(delay_cnt == IIC_DELAY_MS-2)begin
                state_c  <= CERITICATE_DATA_RD;
            end
            else begin
                state_c <= state_c;
            end
CERITICATE_DATA_RD :if(i_i2c_busy_neg == 1'b1)begin
                state_c  <= IDLE  ;
            end
            else begin
                state_c <= state_c;
            end
IDLE        : if(i_iic_start == 1'b1)begin
                state_c <= IIC_DELAY2;
            end
            else if(i_loop_tx_start == 1'b1)begin
                state_c <= DETECT_TX_PRE;
            end
            else begin
                state_c <= state_c;
            end
IIC_DELAY2  : if(i_iic_ack == 1'b1)begin
                state_c <= IDLE;
            end
            else if(delay_cnt > IIC_DELAY_MS - 1)begin  //超时
                state_c <= IDLE;
            end
            else begin
                state_c <= state_c;
            end
DETECT_TX_PRE: if(i_loop_tx_ack == 1'b1)begin
                state_c <= IDLE;    
            end
            else if(delay_cnt > LOOP_TX_DELAY_MS - 1)begin
                state_c <= IDLE;
            end
            else begin
                state_c <= state_c;
            end
            default:state_c <= BOOT;
        endcase
    end
end

always @(posedge i_clk ) begin
    if((ms_delay_cnt == MS) || (state_c ==IDLE))begin
        ms_delay_cnt <= {{(depth2width(MS)-1){1'b0}},1'b1};
    end
    else if(state_c[0] == 1'b1)begin
        ms_delay_cnt <= 1'b1 + ms_delay_cnt;
    end
    else begin
        ms_delay_cnt <= {{(depth2width(MS)-1){1'b0}},1'b1};
    end
end

always @(posedge i_clk ) begin
    if((state_c[0] == 1'b1) &&(ms_delay_cnt == MS))begin
        delay_cnt <= delay_cnt + 1'b1;
    end
    else begin
        delay_cnt <= {depth2width(MS){1'b0}};
    end
end

always @(posedge i_clk ) begin
    if((o_boot_pass == 1'b1) && (delay_cnt > IIC_DELAY_MS - 2))begin
        o_iic_dly_done <= 1'b1;        
    end
    else begin
        o_iic_dly_done <= 1'b0;
    end
end


always @(posedge i_clk ) begin
    if((o_boot_pass == 1'b1) && (delay_cnt > LOOP_TX_DELAY_MS-2))begin
        o_oop_tx_dly_done <= 1'b1;        
    end
    else begin
        o_oop_tx_dly_done <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if(state_c == BOOT)begin
        o_boot_pass <= 1'b0;
    end
    else if(state_c == IDLE)begin
        o_boot_pass <= 1'b1;
    end
    else begin
        o_boot_pass <= o_boot_pass;
    end
end

endmodule