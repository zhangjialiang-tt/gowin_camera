
//===========================================
module usb_descriptor #(
    // Vendor ID to report in device descriptor.
parameter                           VENDORID                    = 16'h33AA             ,//Gowin USB Vender ID
    // Product ID to report in device descriptor.
parameter                           PRODUCTID                   = 16'h0120             ,
    // Product version to report in device descriptor.
parameter                           VERSIONBCD                  = 16'h0100             ,
    // Optional description of manufacturer (max 126 characters).
parameter                           VENDORSTR                   = "Wuhan Guide Infrared Co., Ltd.",
parameter                           VENDORSTR_LEN               = 30                   ,
    // Optional description of product (max 126 characters).
parameter                           PRODUCTSTR                  = "ZX10A"              ,
parameter                           PRODUCTSTR_LEN              = 10                   ,
    // Optional product serial number (max 126 characters).
parameter                           SERIALSTR                   = "ZX01A19"            ,
parameter                           SERIALSTR_LEN               = 11                   ,
parameter                           SERIALSTR_LEN_MAX           = 30                   ,
    // Support high speed mode.
parameter                           HSSUPPORT                   = 0                    ,
    // Set to true if the device never draws power from the USB bus.
parameter                           SELFPOWERED                 = 0                    ,
parameter                           SERIALSTR6                  = "com.guidesensmart.EyeSearch2",
parameter                           SERIALSTR6_LEN              = 25                   
)
(

    input                       i_clk                   ,
    input                       i_rst_n                 ,

    input           [15:0]      i_pid                   ,
    input           [15:0]      i_vid                   ,

    input           [3:0]       i_endpt_sel             ,
    input                       i_usb_rxval             ,
    input           [7:0]       i_usb_rxdat             ,

    input           [15:0]      i_descrom_raddr         ,
    output          [7:0]       o_descrom_rdat          ,
    output          [15:0]      o_desc_dev_addr         ,
    output          [15:0]      o_desc_dev_len          ,
    output          [15:0]      o_desc_qual_addr        ,
    output          [15:0]      o_desc_qual_len         ,
    output          [15:0]      o_desc_fscfg_addr       ,
    output          [15:0]      o_desc_fscfg_len        ,
    output          [15:0]      o_desc_hscfg_addr       ,
    output          [15:0]      o_desc_hscfg_len        ,
    output          [15:0]      o_desc_oscfg_addr       ,
    output          [15:0]      o_desc_strlang_addr     ,
    output          [15:0]      o_desc_strvendor_addr   ,
    output          [15:0]      o_desc_strvendor_len    ,
    output          [15:0]      o_desc_strproduct_addr  ,
    output          [15:0]      o_desc_strproduct_len   ,
    output          [15:0]      o_desc_strserial_addr   ,
    output  reg     [15:0]      o_desc_strserial_len    ,
    output                      o_descrom_have_strings  
);
// Descriptor ROM
localparam  DESC_DEV_ADDR         = 0;
localparam  DESC_DEV_LEN          = 18;
localparam  DESC_QUAL_ADDR        = 20;
localparam  DESC_QUAL_LEN         = 10;
localparam  DESC_FSCFG_ADDR       = 32;
localparam  DESC_FSCFG_LEN        = 64;
localparam  DESC_HSCFG_ADDR       = DESC_FSCFG_ADDR;
localparam  DESC_HSCFG_LEN        = DESC_FSCFG_LEN;
localparam  DESC_OSCFG_ADDR       = DESC_HSCFG_ADDR + DESC_HSCFG_LEN;
localparam  DESC_OSCFG_LEN        = 1 ;
localparam  DESC_STRLANG_ADDR     = DESC_OSCFG_ADDR + DESC_OSCFG_LEN;
localparam  DESC_STRVENDOR_ADDR   = DESC_STRLANG_ADDR + 4;
localparam  DESC_STRVENDOR_LEN    = 2 + 2*VENDORSTR_LEN;
localparam  DESC_STRPRODUCT_ADDR  = DESC_STRVENDOR_ADDR + DESC_STRVENDOR_LEN;
localparam  DESC_STRPRODUCT_LEN   = 2 + 2*PRODUCTSTR_LEN;
localparam  DESC_STRSERIAL_ADDR   = DESC_STRPRODUCT_ADDR + DESC_STRPRODUCT_LEN;
localparam  DESC_STRSERIAL_LEN    = 2 + 2*SERIALSTR_LEN_MAX;
localparam  DESC_END_ADDR         = DESC_STRSERIAL_ADDR + DESC_STRSERIAL_LEN;



assign  o_desc_dev_addr        = DESC_DEV_ADDR        ;
assign  o_desc_dev_len         = DESC_DEV_LEN         ;
assign  o_desc_qual_addr       = DESC_QUAL_ADDR       ;
assign  o_desc_qual_len        = DESC_QUAL_LEN        ;
assign  o_desc_fscfg_addr      = DESC_FSCFG_ADDR      ;
assign  o_desc_fscfg_len       = DESC_FSCFG_LEN       ;
assign  o_desc_hscfg_addr      = DESC_HSCFG_ADDR      ;
assign  o_desc_hscfg_len       = DESC_HSCFG_LEN       ;
assign  o_desc_oscfg_addr      = DESC_OSCFG_ADDR      ;
assign  o_desc_strlang_addr    = DESC_STRLANG_ADDR    ;
assign  o_desc_strvendor_addr  = DESC_STRVENDOR_ADDR  ;
assign  o_desc_strvendor_len   = DESC_STRVENDOR_LEN   ;
assign  o_desc_strproduct_addr = DESC_STRPRODUCT_ADDR ;
assign  o_desc_strproduct_len  = DESC_STRPRODUCT_LEN  ;
assign  o_desc_strserial_addr  = DESC_STRSERIAL_ADDR  ;
// assign  o_desc_strserial_len   = DESC_STRSERIAL_LEN   ;

parameter SERIALSTR4 = "MFI Configure";
parameter SERIALSTR4_LEN = 13;
parameter SERIALSTR5 = "iAP Interface";
parameter SERIALSTR5_LEN = 13;
// parameter SERIALSTR6 = "com.guidesensmart.ZC23A";
// parameter SERIALSTR6 = "com.guidesensmart.ZC23B";
// parameter SERIALSTR6 = "com.guidesensmart.EyeSearch2";
// parameter SERIALSTR6_LEN = 25;

always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        o_desc_strserial_len <= 2 + 2 * SERIALSTR6_LEN;
    end
    else if (serialstr_num == 8'h00) begin
        o_desc_strserial_len <= 2 + 2 * VENDORSTR_LEN;
    end
    else if (serialstr_num == 8'h03) begin
        o_desc_strserial_len <= 2 + 2 * SERIALSTR_LEN;
    end
    else if (serialstr_num == 8'h04) begin
        o_desc_strserial_len <= 2 + 2 * SERIALSTR4_LEN;
    end
    else if (serialstr_num == 8'h05) begin
        o_desc_strserial_len <= 2 + 2 * SERIALSTR5_LEN;
    end
    else if (serialstr_num == 8'h06) begin
        o_desc_strserial_len <= 2 + 2 * SERIALSTR6_LEN;
    end
    else begin
        o_desc_strserial_len <= o_desc_strserial_len;
    end
end

// Truncate descriptor data to keep only the necessary pieces;
// either just the full-speed stuff, || full-speed plus high-speed,
// || full-speed plus high-speed plus string descriptors.

localparam descrom_have_strings = (VENDORSTR_LEN > 0 || PRODUCTSTR_LEN > 0 || SERIALSTR_LEN_MAX > 0);
localparam descrom_len = (HSSUPPORT || descrom_have_strings)?((descrom_have_strings)? DESC_END_ADDR : DESC_OSCFG_ADDR + DESC_OSCFG_LEN) : DESC_FSCFG_ADDR + DESC_FSCFG_LEN;
assign o_descrom_have_strings = descrom_have_strings;
reg [7:0] descrom [0 : descrom_len-1];
integer i;
integer z;


//  描述符仲裁
reg     [63:0]      rxcontroll_data ;
reg     [7:0]       serialstr_num   ;

always @(posedge i_clk) begin
    if (i_endpt_sel == 4'd0 && i_usb_rxval) begin
        rxcontroll_data <= {rxcontroll_data[55:0], i_usb_rxdat};
    end
    else begin
        rxcontroll_data <= rxcontroll_data;
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        serialstr_num <= 8'h00; //  默认
    end
    else if (rxcontroll_data[63:48] == 16'h8006 && rxcontroll_data[39:32] == 8'h03) begin
        serialstr_num <= rxcontroll_data[47:40];
    end
    else begin
        serialstr_num <= serialstr_num;
    end
end

//  描述符定义
always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        // device descriptor
        descrom[0]  <= 8'h12;                                   //  bLength = 18 bytes
        descrom[1]  <= 8'h01;                                   //  bDescriptorType = device descriptor
        descrom[2]  <= (HSSUPPORT) ? 8'h00 : 8'h10;             //  bcdUSB = 1.10 || 2.00
        descrom[3]  <= (HSSUPPORT) ? 8'h02 : 8'h01;
        descrom[4]  <= 8'h00;                                   //  bDeviceClass = Unspecified
        descrom[5]  <= 8'h00;                                   //  bDeviceSubClass = none
        descrom[6]  <= 8'h00;                                   //  bDeviceProtocol = none
        descrom[7]  <= 8'h40;                                   //  bMaxPacketSize0 = 64 bytes
        descrom[8]  <= VENDORID[7 : 0];                         //  idVendor
        descrom[9]  <= VENDORID[15 :8];
        descrom[10] <= PRODUCTID[7 :0];                         //  idProduct
        descrom[11] <= PRODUCTID[15 :8];
        descrom[12] <= VERSIONBCD[7 : 0];                       //  bcdDevice
        descrom[13] <= VERSIONBCD[15 : 8];
        descrom[14] <= (VENDORSTR_LEN > 0) ? 8'h01 : 8'h00;     //  iManufacturer
        descrom[15] <= (PRODUCTSTR_LEN > 0) ? 8'h02 : 8'h00;    //  iProduct
        descrom[16] <= (SERIALSTR_LEN_MAX > 0) ? 8'h03 : 8'h00;     //  iSerialNumber
        descrom[17] <= 8'h01;                                   //  bNumConfigurations = 1

        // padding
        descrom[18] <= 8'h00;
        descrom[19] <= 8'h00;

        // device qualifier
        descrom[20 + 0] <= 8'h0a;   //  bLength = 10 bytes
        descrom[20 + 1] <= 8'h06;   //  bDescriptorType = device qualifier
        descrom[20 + 2] <= 8'h00;
        descrom[20 + 3] <= 8'h02;   //  bcdUSB = 2.0
        descrom[20 + 4] <= 8'h00;   //  bDeviceClass = Unspecified
        descrom[20 + 5] <= 8'h00;   //  bDeviceSubClass = none
        descrom[20 + 6] <= 8'h00;   //  bDeviceProtocol = none
        descrom[20 + 7] <= 8'h40;   //  bMaxPacketSize0 = 64 bytes
        descrom[20 + 8] <= 8'h01;   //  bNumConfigurations = 1
        descrom[20 + 9] <= 8'h00;   //  bReserved

        // padding
        descrom[20 + 10] <= 8'h00;
        descrom[20 + 11] <= 8'h00;

        // configuration header
        descrom[DESC_FSCFG_ADDR + 0] <= 8'h09;                          //  bLength = 9 bytes
        descrom[DESC_FSCFG_ADDR + 1] <= 8'h02;                          //  bDescriptorType = configuration descriptor
        descrom[DESC_FSCFG_ADDR + 2] <= DESC_FSCFG_LEN[7:0];            //  2 wTotalLength L
        descrom[DESC_FSCFG_ADDR + 3] <= DESC_FSCFG_LEN[15:8];           //  3 wTotalLength H
        descrom[DESC_FSCFG_ADDR + 4] <= 8'h02;                          //  bNumInterfaces = 2
        descrom[DESC_FSCFG_ADDR + 5] <= 8'h01;                          //  bConfigurationValue = 1
        descrom[DESC_FSCFG_ADDR + 6] <= 8'h04;                          //  iConfiguration = none   (8'h00)
        descrom[DESC_FSCFG_ADDR + 7] <= (SELFPOWERED) ? 8'hC0 : 8'h80;  //  7 bmAttributes
        descrom[DESC_FSCFG_ADDR + 8] <= 8'h32;                          //  bMaxPower

        // Interface Descriptor (IR)
        descrom[DESC_FSCFG_ADDR + 9]  <= 8'h09; //  bLength = 9 bytes
        descrom[DESC_FSCFG_ADDR + 10] <= 8'h04; //  bDescriptorType = interface descriptor
        descrom[DESC_FSCFG_ADDR + 11] <= 8'h00; //  bInterfaceNumber = 0
        descrom[DESC_FSCFG_ADDR + 12] <= 8'h00; //  bAlternateSetting = 0
        descrom[DESC_FSCFG_ADDR + 13] <= 8'h02; //  bNumEndpoints = 3
        descrom[DESC_FSCFG_ADDR + 14] <= 8'hFF; //  bInterfaceClass = vendor specific
        descrom[DESC_FSCFG_ADDR + 15] <= 8'hF0; //  bInterfaceSubClass = F0
        descrom[DESC_FSCFG_ADDR + 16] <= 8'h00; //  bInterafceProtocol = none
        descrom[DESC_FSCFG_ADDR + 17] <= 8'h05; //  iInterface

        // Endpoint Descriptor (IN)
        descrom[DESC_FSCFG_ADDR + 18] <= 8'h07; //  bLength = 7 bytes
        descrom[DESC_FSCFG_ADDR + 19] <= 8'h05; //  bDescriptorType = endpoint descriptor
        descrom[DESC_FSCFG_ADDR + 20] <= 8'h82; //  bEndpointAddress = INPUT 2
        descrom[DESC_FSCFG_ADDR + 21] <= 8'h02; //  bmAttributes = Bulk + No Synchronization + No Data Logical
        descrom[DESC_FSCFG_ADDR + 22] <= 8'h00;
        descrom[DESC_FSCFG_ADDR + 23] <= 8'h02; //  wMaxPacketSize = 64 bytes
        descrom[DESC_FSCFG_ADDR + 24] <= 8'h00; //  bInterval = 0 ms

        // Endpoint Descriptor (OUT)
        descrom[DESC_FSCFG_ADDR + 25] <= 8'h07; //  bLength = 7 bytes
        descrom[DESC_FSCFG_ADDR + 26] <= 8'h05; //  bDescriptorType = endpoint descriptor
        descrom[DESC_FSCFG_ADDR + 27] <= 8'h02; //  bEndpointAddress = OUTPUT 2
        descrom[DESC_FSCFG_ADDR + 28] <= 8'h02; //  bmAttributes = Bulk + No Synchronization + No Data Logical
        descrom[DESC_FSCFG_ADDR + 29] <= 8'h00;
        descrom[DESC_FSCFG_ADDR + 30] <= 8'h02; //  wMaxPacketSize = 512 bytes
        descrom[DESC_FSCFG_ADDR + 31] <= 8'h00; //  bInterval = 0 ms

        // Interface Descriptor (MFI)
        descrom[DESC_FSCFG_ADDR + 32] <= 8'h09; //  bLength = 9 bytes
        descrom[DESC_FSCFG_ADDR + 33] <= 8'h04; //  bDescriptorType = interface descriptor
        descrom[DESC_FSCFG_ADDR + 34] <= 8'h01; //  bInterfaceNumber = 0
        descrom[DESC_FSCFG_ADDR + 35] <= 8'h00; //  bAlternateSetting = 0
        descrom[DESC_FSCFG_ADDR + 36] <= 8'h00; //  bNumEndpoints = 2
        descrom[DESC_FSCFG_ADDR + 37] <= 8'hFF; //  bInterfaceClass = vendor specific
        descrom[DESC_FSCFG_ADDR + 38] <= 8'hF0; //  bInterfaceSubClass = F0
        descrom[DESC_FSCFG_ADDR + 39] <= 8'h01; //  bInterafceProtocol = none
        descrom[DESC_FSCFG_ADDR + 40] <= 8'h06; //  iInterface

        descrom[DESC_FSCFG_ADDR + 41] <= 8'h09; //  bLength = 9 bytes
        descrom[DESC_FSCFG_ADDR + 42] <= 8'h04; //  bDescriptorType = interface descriptor
        descrom[DESC_FSCFG_ADDR + 43] <= 8'h01; //  bInterfaceNumber = 0
        descrom[DESC_FSCFG_ADDR + 44] <= 8'h01; //  bAlternateSetting = 0
        descrom[DESC_FSCFG_ADDR + 45] <= 8'h02; //  bNumEndpoints = 2
        descrom[DESC_FSCFG_ADDR + 46] <= 8'hFF; //  bInterfaceClass = vendor specific
        descrom[DESC_FSCFG_ADDR + 47] <= 8'hF0; //  bInterfaceSubClass = F0
        descrom[DESC_FSCFG_ADDR + 48] <= 8'h01; //  bInterafceProtocol = none
        descrom[DESC_FSCFG_ADDR + 49] <= 8'h06; //  iInterface

        // Endpoint Descriptor (IN)
        descrom[DESC_FSCFG_ADDR + 50] <= 8'h07; //  bLength = 7 bytes
        descrom[DESC_FSCFG_ADDR + 51] <= 8'h05; //  bDescriptorType = endpoint descriptor
        descrom[DESC_FSCFG_ADDR + 52] <= 8'h81; //  bEndpointAddress = INPUT 1
        descrom[DESC_FSCFG_ADDR + 53] <= 8'h02; //  bmAttributes = Bulk + No Synchronization + No Data Logical
        descrom[DESC_FSCFG_ADDR + 54] <= 8'h00;
        descrom[DESC_FSCFG_ADDR + 55] <= 8'h02; //  wMaxPacketSize = 512 bytes
        descrom[DESC_FSCFG_ADDR + 56] <= 8'h00; //  bInterval = 0 ms

        // Endpoint Descriptor (OUT)
        descrom[DESC_FSCFG_ADDR + 57] <= 8'h07; //  bLength = 7 bytes
        descrom[DESC_FSCFG_ADDR + 58] <= 8'h05; //  bDescriptorType = endpoint descriptor
        descrom[DESC_FSCFG_ADDR + 59] <= 8'h01; //  bEndpointAddress = OUTPUT 1
        descrom[DESC_FSCFG_ADDR + 60] <= 8'h02; //  bmAttributes = Bulk + No Synchronization + No Data Logical
        descrom[DESC_FSCFG_ADDR + 61] <= 8'h00;
        descrom[DESC_FSCFG_ADDR + 62] <= 8'h02; //  wMaxPacketSize = 512 bytes
        descrom[DESC_FSCFG_ADDR + 63] <= 8'h00; //  bInterval = 0 ms

        // other_speed_configuration
        descrom[DESC_OSCFG_ADDR + 0] <= 8'h07;// Other Speed Configuration Descriptor replace HS/FS

        if(descrom_len > DESC_STRLANG_ADDR)begin
            // string descriptor 0 (supported languages)
            descrom[DESC_STRLANG_ADDR + 0] <= 8'h04;                // bLength = 4
            descrom[DESC_STRLANG_ADDR + 1] <= 8'h03;                // bDescriptorType = string descriptor
            descrom[DESC_STRLANG_ADDR + 2] <= 8'h09;
            descrom[DESC_STRLANG_ADDR + 3] <= 8'h04;         // wLangId[0] = 0x0409 = English U.S.

            descrom[DESC_STRVENDOR_ADDR + 0] <= 2 + 2*VENDORSTR_LEN;
            descrom[DESC_STRVENDOR_ADDR + 1] <= 8'h03;
            for(i = 0; i < VENDORSTR_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRVENDOR_ADDR+ 2*i + 2][z] <= VENDORSTR[(VENDORSTR_LEN - 1 -i)*8+z];
                end
                descrom[DESC_STRVENDOR_ADDR+ 2*i + 3] <= 8'h00;
            end

            descrom[DESC_STRPRODUCT_ADDR + 0] <= 2 + 2*PRODUCTSTR_LEN;
            descrom[DESC_STRPRODUCT_ADDR + 1] <= 8'h03;
            for(i = 0; i < PRODUCTSTR_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRPRODUCT_ADDR + 2*i + 2][z] <= PRODUCTSTR[(PRODUCTSTR_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRPRODUCT_ADDR + 2*i + 3] <= 8'h00;
            end

            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*SERIALSTR_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < SERIALSTR_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= SERIALSTR[(SERIALSTR_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
    end
    else begin
        if (serialstr_num == 8'h00) begin
            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*VENDORSTR_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < VENDORSTR_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= VENDORSTR[(VENDORSTR_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
        else if (serialstr_num == 8'h03) begin
            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*SERIALSTR_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < SERIALSTR_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= SERIALSTR[(SERIALSTR_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
        else if (serialstr_num == 8'h04) begin
            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*SERIALSTR4_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < SERIALSTR4_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= SERIALSTR4[(SERIALSTR4_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
        else if (serialstr_num == 8'h05) begin
            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*SERIALSTR5_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < SERIALSTR5_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= SERIALSTR5[(SERIALSTR5_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
        else if (serialstr_num == 8'h06) begin
            descrom[DESC_STRSERIAL_ADDR + 0] <= 2 + 2*SERIALSTR6_LEN;
            descrom[DESC_STRSERIAL_ADDR + 1] <= 8'h03;
            for(i = 0; i < SERIALSTR6_LEN; i = i + 1) begin
                for(z = 0; z < 8; z = z + 1) begin
                    descrom[DESC_STRSERIAL_ADDR + 2*i + 2][z] <= SERIALSTR6[(SERIALSTR6_LEN - 1 - i)*8+z];
                end
                descrom[DESC_STRSERIAL_ADDR + 2*i + 3] <= 8'h00;
            end
        end
    end
    // else begin
    //     descrom[8]  <= ((i_pid != 16'h0000) && (i_pid != 16'hFFFF)) ? i_pid[7:0]  : VENDORID[7 : 0];// idVendor
    //     descrom[9]  <= ((i_pid != 16'h0000) && (i_pid != 16'hFFFF)) ? i_pid[15:8] : VENDORID[15 : 8];
    //     descrom[10] <= ((i_vid != 16'h0000) && (i_vid != 16'hFFFF)) ? i_vid[7:0]  : PRODUCTID[7 : 0];// idProduct
    //     descrom[11] <= ((i_vid != 16'h0000) && (i_vid != 16'hFFFF)) ? i_vid[15:8] : PRODUCTID[15 : 8];
    // end
end
assign o_descrom_rdat = descrom[i_descrom_raddr];
endmodule
