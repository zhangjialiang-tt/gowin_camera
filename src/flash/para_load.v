module para_load (
    input                       i_clk                   ,
    input                       i_rst_n                 ,
    input                       i_param_load            ,
    input                       i_update                ,
    input                       i_option                ,
    input      [15:0]           i_data                  ,
    input                       i_data_vld              ,
    input                       i_data_req              ,
    output reg [15:0]           o_data                  ,
    output reg                  o_data_vld              ,                      

    input      [31:0]           i_apb32bus0             ,
    output     [31:0]           o_apb32bus0               
);

wire                        Empty       ;    
reg                         wr_en       ;
reg        [15:0]           wr_data     ;    
reg                         mcu_en_dly  ;
wire                        rd_en       ;      
reg        [1:0]            update_dly  ;

reg                         data_vld_dly;

flash_fifo flash_fifo_para_load_inst(
		.Data               (wr_data            ), //input [15:0] Data
		.WrReset            (i_apb32bus0[31]    ), //input WrReset
		.RdReset            (i_apb32bus0[31]    ), //input RdReset
		.WrClk              (i_clk              ), //input WrClk
		.RdClk              (i_clk              ), //input RdClk
		.WrEn               (wr_en              ), //input WrEn
		.RdEn               (rd_en              ), //input RdEn
		.Almost_Empty       (), //output Almost_Empty
		.Almost_Full        (), //output Almost_Full
		.Q                  (o_apb32bus0[15:0]          ), //output [15:0] Q
		.Empty              (Empty                      ), //output Empty
		.Full               () //output Full
	);

assign o_apb32bus0[31:16] = {16{(~Empty)}};
assign rd_en = ({i_option,i_data_req} == 2'b11)? 1'b1 : (({i_option,update_dly} == 3'b001)? 1'b1 : 1'b0); 

always @(posedge i_clk ) begin
    update_dly <= {update_dly[0],i_update};
end

always @(posedge i_clk ) begin
   o_data <= o_apb32bus0[15:0]; 
end

always @(posedge i_clk ) begin
    if({i_param_load,i_data_req} == 2'b11)begin
        o_data_vld <= 1'b1;
    end
    else begin
        o_data_vld <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if((i_option == 1'b0) && (i_data_vld) && (i_param_load == 1'b1))begin
        wr_en <= 1'b1;
    end
    else if((i_option == 1'b1) && ({mcu_en_dly,i_apb32bus0[16]} == 2'b01))begin
        wr_en <= 1'b1;
    end
    else begin
       wr_en <= 1'b0;
    end
end

always @(posedge i_clk ) begin
    if((i_option == 1'b0) && (i_data_vld == 1'b1))begin
        wr_data <= i_data;
    end
    else if((i_option == 1'b1) && ({mcu_en_dly,i_apb32bus0[16]} == 2'b01))begin
        wr_data <= i_apb32bus0[15:0];
    end
    else begin
       wr_data <= 16'd0;
    end
end

always @(posedge i_clk ) begin
    mcu_en_dly <= i_apb32bus0[16];
    data_vld_dly <=  i_data_vld;
end




endmodule