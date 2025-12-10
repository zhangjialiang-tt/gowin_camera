module unsigned_divider #(
    parameter NUMER_DW   =  16                                      ,
    parameter DENOM_DW   =  16                                     
) (
    input                                       i_clk               ,
    input                                       i_rst_n             ,
    input                                       i_div_en            ,
    input           [NUMER_DW-1:0]              i_numer             ,
    input           [DENOM_DW-1:0]              i_denom             ,
    output reg      [NUMER_DW-1:0]              o_quotient          ,
    output reg                                  o_quotient_vld           
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



localparam IDLE   = 3'b000;
localparam STATE1 = 3'b001;
localparam STATE2 = 3'b010;
localparam STATE3 = 3'b100;


reg         [2:0]                               state_c     ;

reg         [NUMER_DW-1:0]                      numer_buff  ;
reg         [DENOM_DW-1:0]                      denom_buff  ;
reg         [depth2width(NUMER_DW)-1:0]         cnt         ;

reg         [DENOM_DW:0]                        numer_high  ;


always @(posedge i_clk ) begin
    if(!i_rst_n)begin
        state_c <= IDLE;
    end
    else begin
        case (state_c)
    IDLE   : begin
        if(i_div_en == 1'b1)begin
            state_c <= STATE1;
        end
        else begin
            state_c <= IDLE;
        end
    end
    STATE1 :state_c <= STATE2;
    STATE2 :begin
        if(|cnt ==1'b0)begin
            state_c <= STATE3;
        end
        else begin
            state_c <= STATE1;
        end
    end
    STATE3 : state_c <= IDLE;
            default: state_c <= IDLE;
        endcase
    end
end

always @(posedge i_clk ) begin
    if((state_c == IDLE) && i_div_en == 1'b1)begin
        numer_buff <= i_numer;
        denom_buff <= i_denom;
    end
    else begin
        numer_buff <= numer_buff;
        denom_buff <= denom_buff;
    end
end

always @(posedge i_clk ) begin
    if((i_div_en == 1'b1) && (state_c ==IDLE))begin
       numer_high <= {(DENOM_DW+1){1'b0}}; 
    end
    else if(state_c == STATE1)begin
        numer_high <= {numer_high[DENOM_DW-1:0],numer_buff[cnt]};
    end
    else if(state_c == STATE2 && numer_high >= {1'b0,denom_buff})begin
        numer_high <= numer_high - {1'b0,denom_buff};
    end
    else begin
        numer_high <= numer_high;
    end
end

always @(posedge i_clk ) begin
    if((i_div_en == 1'b1) && (state_c ==IDLE))begin
        cnt <= NUMER_DW-1;
    end
    else if(state_c ==STATE2)begin
        cnt <= cnt-1'b1;
    end
    else begin
        cnt <= cnt;
    end
end

always @(posedge i_clk ) begin
    if((state_c == STATE2) && {1'b0,denom_buff}  <= numer_high)begin
        o_quotient <= {o_quotient[NUMER_DW-2:0],1'b1};
    end
    else if(state_c == STATE2)begin
        o_quotient <= {o_quotient[NUMER_DW-2:0],1'b0};
    end
    else begin
        o_quotient <= o_quotient;
    end
end


always @(posedge i_clk ) begin
    if(state_c == STATE3)begin
        o_quotient_vld <= 1'b1;        
    end
    else begin
        o_quotient_vld <= 1'b0;
    end
end

endmodule