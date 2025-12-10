//ZC23A/GW_PHONE_FPGA/ip/wb_usb_bridge/wb_usb_bridge.v
module wb_usb_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    // System Signals
    input i_wb_clk,   // Wishbone Clock
    input i_wb_rst_n,

    input i_usb_clk,   // USB Clock
    input i_usb_rst_n,

    // Wishbone Interface (Slave)
    input                       i_wb_cyc,
    input                       i_wb_stb,
    input                       i_wb_we,
    input      [ADDR_WIDTH-1:0] i_wb_adr,
    input      [DATA_WIDTH-1:0] i_wb_dat,
    input      [           3:0] i_wb_sel,
    output reg [DATA_WIDTH-1:0] o_wb_dat,
    output reg                  o_wb_ack,

    // USB Controller Interface
    // RX Path (USB -> CPU)
    input       i_usb_rxact,
    input       i_usb_rxval,
    input [7:0] i_usb_rxdat,
    input [3:0] i_endpt_sel,

    // TX Path (CPU -> USB)
    input              i_txact,
    input              i_txpop,
    output reg  [11:0] o_txdat_len,  // To USB Logic
    output reg         o_txcork,     // 0=Ready, 1=Hold
    output wire [ 7:0] o_txdat,
    output reg         o_txval,
    output reg         o_rxrdy,

    // Control
    output reg o_os_type
);

    localparam EP_IAP2 = 4'd2;

    // ----------------------------------------------------------
    // 1. Control Signal Synchronization (WB <-> USB)
    // ----------------------------------------------------------

    // Global Reset for FIFOs (High Active)
    wire fifo_rst;
    assign fifo_rst = (~i_wb_rst_n) | (~i_usb_rst_n);

    // WB Domain Signals
    reg         wb_tx_trigger;  // Pulse to start TX
    reg  [11:0] wb_tx_len_reg;  // Length register
    reg         wb_tx_busy;  // Busy flag
    reg         wb_os_type_reg;

    // USB Domain Signals
    wire        usb_tx_start_pulse;  // Synced start pulse
    wire        usb_tx_done_pulse;  // Pulse from FSM when done
    reg         usb_tx_busy_internal;

    // Handshake: WB Trigger -> USB Start
    sync_pulse u_sync_start (
        .clk_in   (i_wb_clk),
        .rst_n_in (i_wb_rst_n),
        .pulse_in (wb_tx_trigger),
        .clk_out  (i_usb_clk),
        .rst_n_out(i_usb_rst_n),
        .pulse_out(usb_tx_start_pulse)
    );

    // Handshake: USB Done -> WB Clear Busy
    wire wb_tx_done_pulse;
    sync_pulse u_sync_done (
        .clk_in   (i_usb_clk),
        .rst_n_in (i_usb_rst_n),
        .pulse_in (usb_tx_done_pulse),
        .clk_out  (i_wb_clk),
        .rst_n_out(i_wb_rst_n),
        .pulse_out(wb_tx_done_pulse)
    );

    // OS Type Synchronization (Quasi-static, 2-FF is enough)
    reg [1:0] os_type_sync;
    always @(posedge i_usb_clk or negedge i_usb_rst_n) begin
        if (!i_usb_rst_n) begin
            os_type_sync <= 2'b00;
            o_os_type    <= 1'b1;
        end else begin
            os_type_sync <= {os_type_sync[0], wb_os_type_reg};
            o_os_type    <= os_type_sync[1];
        end
    end

    // ----------------------------------------------------------
    // 2. FIFOs (DC_FIFO IP)
    // ----------------------------------------------------------

    // TX FIFO: Write in WB domain, Read in USB domain
    wire tx_fifo_wr;
    wire tx_fifo_full;  // WB domain
    wire tx_fifo_empty;  // USB domain

    DC_FIFO #(
        .FIFO_MODE ("ShowAhead"),
        .DATA_WIDTH(8),
        .FIFO_DEPTH(1024)
    ) u_tx_fifo (
        .Reset(fifo_rst),

        // Write (WB Domain)
        .WrClk (i_wb_clk),
        .WrEn  (tx_fifo_wr),
        .WrDNum(),
        .WrFull(tx_fifo_full),
        .WrData(i_wb_dat[7:0]),

        // Read (USB Domain)
        .RdClk  (i_usb_clk),
        .RdEn   (i_txpop && !tx_fifo_empty),
        .RdDNum (),
        .RdEmpty(tx_fifo_empty),
        .DataVal(),
        .RdData (o_txdat)
    );

    // RX FIFO: Write in USB domain, Read in WB domain
    wire       rx_fifo_wr;
    reg        rx_fifo_rd;
    wire       rx_fifo_full;  // USB domain
    wire       rx_fifo_empty;  // WB domain
    wire [7:0] rx_fifo_dout;

    assign rx_fifo_wr = i_usb_rxval && (i_endpt_sel == EP_IAP2);

    DC_FIFO #(
        .FIFO_MODE ("ShowAhead"),
        .DATA_WIDTH(8),
        .FIFO_DEPTH(1024)
    ) u_rx_fifo (
        .Reset(fifo_rst),

        // Write (USB Domain)
        .WrClk (i_usb_clk),
        .WrEn  (rx_fifo_wr),
        .WrDNum(),
        .WrFull(rx_fifo_full),
        .WrData(i_usb_rxdat),

        // Read (WB Domain)
        .RdClk  (i_wb_clk),
        .RdEn   (rx_fifo_rd),
        .RdDNum (),
        .RdEmpty(rx_fifo_empty),
        .DataVal(),
        .RdData (rx_fifo_dout)
    );

    // ----------------------------------------------------------
    // 3. USB Domain State Machine (TX Control)
    // ----------------------------------------------------------
    reg [11:0] usb_byte_cnt;
    reg        usb_state_active;

    always @(posedge i_usb_clk or negedge i_usb_rst_n) begin
        if (!i_usb_rst_n) begin
            o_txcork         <= 1'b1;
            o_txdat_len      <= 12'd0;
            usb_byte_cnt     <= 12'd0;
            usb_state_active <= 1'b0;
        end else begin
            if (usb_tx_start_pulse) begin
                // Latch length from WB domain (Assumes WB holds reg stable during trigger)
                o_txdat_len      <= wb_tx_len_reg;
                usb_byte_cnt     <= 12'd0;
                o_txcork         <= 1'b0;  // Open Cork
                usb_state_active <= 1'b1;
            end else if (usb_state_active) begin
                if (i_txpop) begin
                    usb_byte_cnt <= usb_byte_cnt + 12'd1;
                    // Check for last byte
                    if (usb_byte_cnt == o_txdat_len - 12'd1) begin
                        o_txcork         <= 1'b1;  // Close Cork
                        usb_state_active <= 1'b0;  // Done
                    end
                end
            end
        end
    end

    assign usb_tx_done_pulse = (usb_state_active && i_txpop && (usb_byte_cnt == o_txdat_len - 12'd1));

    // ----------------------------------------------------------
    // 4. Wishbone Interface Logic (WB Domain)
    // ----------------------------------------------------------

    // Busy Flag Logic
    always @(posedge i_wb_clk or negedge i_wb_rst_n) begin
        if (!i_wb_rst_n) wb_tx_busy <= 1'b0;
        else if (wb_tx_trigger) wb_tx_busy <= 1'b1;
        else if (wb_tx_done_pulse) wb_tx_busy <= 1'b0;
    end

    // WB Access
    assign tx_fifo_wr = (i_wb_cyc && i_wb_stb && i_wb_we && i_wb_adr[4:0] == 5'h0 && !tx_fifo_full && !o_wb_ack);

    always @(posedge i_wb_clk or negedge i_wb_rst_n) begin
        if (!i_wb_rst_n) begin
            o_wb_ack       <= 1'b0;
            o_wb_dat       <= 32'd0;
            rx_fifo_rd     <= 1'b0;
            wb_tx_trigger  <= 1'b0;
            wb_tx_len_reg  <= 12'd0;
            wb_os_type_reg <= 1'b0;
        end else begin
            // Autoclear strobes
            o_wb_ack      <= 1'b0;
            rx_fifo_rd    <= 1'b0;
            wb_tx_trigger <= 1'b0;

            if (i_wb_cyc && i_wb_stb && !o_wb_ack) begin
                o_wb_ack <= 1'b1;

                if (i_wb_we) begin  // WRITE
                    case (i_wb_adr[4:0])
                        5'h0: ;  // Handled by tx_fifo_wr assign
                        5'h8: begin
                            wb_tx_len_reg <= i_wb_dat[11:0];
                            wb_tx_trigger <= 1'b1;  // Trigger Pulse
                        end
                        5'hC: wb_os_type_reg <= i_wb_dat[0];
                        default: ;
                    endcase
                end else begin  // READ
                    case (i_wb_adr[4:0])
                        5'h0: begin
                            if (!rx_fifo_empty) begin
                                o_wb_dat   <= {24'd0, rx_fifo_dout};
                                rx_fifo_rd <= 1'b1;
                            end else begin
                                o_wb_dat <= 32'hFFFFFFFF;
                            end
                        end
                        5'h4: o_wb_dat <= {29'd0, wb_tx_busy, tx_fifo_full, !rx_fifo_empty};
                        5'hC: o_wb_dat <= {31'd0, wb_os_type_reg};
                        5'h10: o_wb_dat <= 32'h57425247;  // "WBRG" - WishBridge signature
                        default: o_wb_dat <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule

// ----------------------------------------------------------
// Helpers: Sync Pulse
// ----------------------------------------------------------

module sync_pulse (
    input      clk_in,
    input      rst_n_in,
    input      pulse_in,
    input      clk_out,
    input      rst_n_out,
    output reg pulse_out
);
    reg       toggle;
    reg [2:0] sync;

    always @(posedge clk_in or negedge rst_n_in)
        if (!rst_n_in) toggle <= 0;
        else if (pulse_in) toggle <= ~toggle;

    always @(posedge clk_out or negedge rst_n_out)
        if (!rst_n_out) sync <= 3'd0;
        else sync <= {sync[1:0], toggle};

    always @(posedge clk_out or negedge rst_n_out)
        if (!rst_n_out) pulse_out <= 0;
        else pulse_out <= (sync[2] ^ sync[1]);
endmodule
