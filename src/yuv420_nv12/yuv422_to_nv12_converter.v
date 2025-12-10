module yuv422_to_nv12_converter #(
    parameter UV420_TYPE = "NV12",
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 1024,
    parameter IMG_WIDTH = 800,
    parameter IMG_HEIGHT = 600,
    parameter BURST_LEN_WORDS = 256,
    parameter Y_FIFO_THRESHOLD = 256,
    parameter UV_FIFO_THRESHOLD = 256
) (
    input wire i_clk,
    input wire i_rst_n,

    // Input YUV422 data
    input wire [DATA_WIDTH-1:0] i_data,
    input wire                  i_hsync,
    input wire                  i_vsync,

    // SDRAM control signals
    input  wire [31:0] i_addrs0,
    input  wire [31:0] i_addrs1,
    input  wire [31:0] i_addrs2,
    input  wire [ 1:0] o_fcnt,
    output reg         o_mem_y_wr_start,
    output wire [31:0] o_mem_y_wr_addrs,
    output wire [31:0] o_mem_y_wr_lengths,
    output wire [15:0] o_mem_y_wr_data,
    output wire        o_mem_y_wr_data_vld,
    output reg         o_mem_uv_wr_start,
    output wire [31:0] o_mem_uv_wr_addrs,
    output wire [31:0] o_mem_uv_wr_lengths,
    output wire [15:0] o_mem_uv_wr_data,
    output wire        o_mem_uv_wr_data_vld,

    // Status
    output wire o_frame_done
);

    function integer depth2width;
        input [31:0] depth;
        begin : fnDepth2Width
            if (depth > 1) begin
                for (depth2width = 0; depth > 0; depth2width = depth2width + 1) depth = depth >> 1;
            end else depth2width = 0;
        end
    endfunction
    //----------------------------------------------------------------
    // Local Parameters
    //----------------------------------------------------------------
    localparam H_ACTIVE_CLKS = IMG_WIDTH * 2;
    localparam V_ACTIVE_LINES = IMG_HEIGHT;
    localparam Y_PLANE_SIZE_BYTES = IMG_WIDTH * IMG_HEIGHT;
    localparam UV_PLANE_SIZE_BYTES = IMG_WIDTH * IMG_HEIGHT / 2;
    localparam Y_TOTAL_WORDS = Y_PLANE_SIZE_BYTES / 2;
    localparam UV_TOTAL_WORDS = UV_PLANE_SIZE_BYTES / 2;
    localparam BURST_LEN_BYTES = BURST_LEN_WORDS * 2;
    localparam COMPRESSD_FRAME_SIZE = IMG_WIDTH * (IMG_HEIGHT / 2 + IMG_HEIGHT / 4);  //360000
    localparam WAIT_NUM = 50;  //IMG_WIDTH*4;
    reg  [depth2width(WAIT_NUM)-1:0] fcnt_wait;
    //----------------------------------------------------------------
    // Internal Signals
    //----------------------------------------------------------------
    // 1. Input Processing & Counters
    reg  [                     11:0] hcnt;
    reg  [                     10:0] vcnt;
    wire                             h_active;
    wire                             v_active;
    reg  [                    3-1:0] frame_count;
    wire is_y_component, is_uv_component;
    wire is_u_component, is_v_component;
    // Y channel processing
    reg  [DATA_WIDTH-1:0] y0_reg;
    wire [          15:0] y_data_combined;
    wire                  y_data_combined_valid;
    // UV channel processing
    wire [DATA_WIDTH-1:0] prev_line_uv;
    reg  [           8:0] uv_sum;
    reg  [DATA_WIDTH-1:0] uv_avg;
    reg  [DATA_WIDTH-1:0] u_avg_reg;
    wire [          15:0] uv_data_combined;
    wire                  uv_data_combined_valid;
    // FIFO interfaces
    wire                  y_fifo_wr_en;
    wire [          15:0] y_fifo_wr_data;
    wire                  y_fifo_full;
    wire [          10:0] y_fifo_wnum;
    wire                  y_fifo_rd_en;
    wire [          15:0] y_fifo_rd_data;
    wire                  y_fifo_empty;
    wire                  uv_line_buffer_fifo_wr_en;
    wire [           7:0] uv_line_buffer_fifo_wr_data;
    wire                  uv_line_buffer_fifo_full;
    wire                  uv_line_buffer_fifo_rden;
    wire [           7:0] uv_line_buffer_fifo_rd_data;
    wire                  uv_line_buffer_fifo_empty;
    wire                  uv_fifo_wr_en;
    wire [          15:0] uv_fifo_wr_data;
    wire                  uv_fifo_full;
    wire [          10:0] uv_fifo_wnum;
    wire                  uv_fifo_rd_en;
    wire [          15:0] uv_fifo_rd_data;
    wire                  uv_fifo_empty;
    // SDRAM Write Controller
    reg [2:0] state, next_state;
    localparam IDLE = 3'b000;
    localparam WR_Y_START = 3'b001;
    localparam WR_Y_DATA = 3'b010;
    localparam WR_UV_START = 3'b101;
    localparam WR_UV_DATA = 3'b110;
    localparam FRAME_DONE = 3'b111;
    reg  [31:0] sdrm_address;
    reg  [31:0] plane_y_sdrm_address;
    reg  [31:0] plane_uv_sdrm_address;
    reg  [31:0] y_addr_offset;
    reg  [31:0] uv_addr_offset;
    reg  [31:0] mem_wr_addrs_reg;
    reg         mem_wr_start_reg;
    reg         mem_wr_data_vld_reg;
    reg  [15:0] mem_wr_data_reg;
    reg  [10:0] burst_cnt;
    reg         y_plane_done;
    reg         uv_plane_done;
    reg         frame_done_pulse;
    // Write requests based on FIFO thresholds
    wire        y_wr_req;
    wire        uv_wr_req;
    wire        vsync_negedge;

    //----------------------------------------------------------------
    // 1. Input Processing & Counters (Your code is kept as is)
    //----------------------------------------------------------------
    assign h_active = i_hsync;
    assign v_active = i_vsync;

    capture_edge #(
        .EDGE("falling")
    ) inst_valid_neg (
        .i_Sys_clk  (i_clk),
        .i_Rst_n    (i_rst_n),
        .i_Din_valid(i_vsync),
        .o_Dout_edge(vsync_negedge)
    );
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            frame_count <= 0;
        end else if (vsync_negedge) begin
            if (frame_count == 3'd2) frame_count <= 0;
            else frame_count <= frame_count + 1;
        end
    end
    assign o_fcnt = frame_count;
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            sdrm_address          <= i_addrs0;
            plane_y_sdrm_address  <= i_addrs0;
            plane_uv_sdrm_address <= i_addrs0;
        end else begin
            case (frame_count)
                2'd0: begin
                    sdrm_address          <= i_addrs0;
                    plane_y_sdrm_address  <= i_addrs0;
                    plane_uv_sdrm_address <= i_addrs0 + Y_PLANE_SIZE_BYTES / 4;
                end
                2'd1: begin
                    sdrm_address          <= i_addrs1;
                    plane_y_sdrm_address  <= i_addrs1;
                    plane_uv_sdrm_address <= i_addrs1 + Y_PLANE_SIZE_BYTES / 4;
                end
                2'd2: begin
                    sdrm_address          <= i_addrs2;
                    plane_y_sdrm_address  <= i_addrs2;
                    plane_uv_sdrm_address <= i_addrs2 + Y_PLANE_SIZE_BYTES / 4;
                end
                default: begin
                    sdrm_address <= i_addrs0;
                end
            endcase
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            hcnt <= 'd0;
            vcnt <= 'd0;
        end else if (!v_active) begin
            hcnt <= 'd0;
            vcnt <= 'd0;
        end else if (h_active) begin
            if (hcnt == H_ACTIVE_CLKS - 1) begin
                hcnt <= 'd0;
                vcnt <= vcnt + 1;
            end else begin
                hcnt <= hcnt + 1;
            end
        end else begin
            hcnt <= 'd0;
        end
    end

    assign is_y_component  = h_active && (hcnt[0] == 1'b0);
    assign is_uv_component = h_active && (hcnt[0] == 1'b1);
    assign is_u_component  = is_uv_component && (hcnt[1] == 1'b0);
    assign is_v_component  = is_uv_component && (hcnt[1] == 1'b1);

    //----------------------------------------------------------------
    // 2. Y-Channel Processing (Your code is kept as is)
    //----------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            y0_reg <= 'd0;
        end else if (is_y_component && hcnt[1] == 1'b0) begin
            y0_reg <= i_data;
        end
    end

    assign y_data_combined_valid       = is_y_component && (hcnt[1] == 1'b1);
    assign y_data_combined             = {i_data, y0_reg};
    assign y_fifo_wr_en                = y_data_combined_valid;
    assign y_fifo_wr_data              = y_data_combined;

    //----------------------------------------------------------------
    // 3. UV-Channel Processing and Downsampling (Your code is kept as is)
    //----------------------------------------------------------------
    assign uv_line_buffer_fifo_wr_en   = is_uv_component && (vcnt[0] == 1'b0);
    assign uv_line_buffer_fifo_wr_data = i_data;
    assign uv_line_buffer_fifo_rden    = is_uv_component && (vcnt[0] == 1'b1) && !uv_line_buffer_fifo_empty;
    assign prev_line_uv                = uv_line_buffer_fifo_rd_data;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            uv_sum <= 'd0;
            uv_avg <= 'd0;
        end else if (is_uv_component && vcnt[0] == 1'b1) begin
            uv_sum <= i_data + prev_line_uv;
            uv_avg <= uv_sum[8:1];
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            u_avg_reg <= 'd0;
        end else if (is_u_component && vcnt[0] == 1'b1) begin
            u_avg_reg <= uv_avg;
        end
    end

    // Assuming signal_delay IP is available and correctly delays the signal
    // to align with the pipelined data `uv_data_combined`.
    signal_delay #(
        .WIDTH_SIGNAL(1),
        .DELAY_SIGNAL(3)
    ) dly_demodulated_en_inst (
        .clk(i_clk),
        .rst(~i_rst_n),
        .in (is_v_component && (vcnt[0] == 1'b1)),
        .out(uv_data_combined_valid)
    );
    generate
    if (UV420_TYPE == "NV21") begin : g_NV21
        assign uv_data_combined = {uv_avg, u_avg_reg};
    end else if (UV420_TYPE == "NV12") begin : g_NV21
        assign uv_data_combined = {u_avg_reg, uv_avg};
    end
    endgenerate
    assign uv_fifo_wr_en    = uv_data_combined_valid;
    assign uv_fifo_wr_data  = uv_data_combined;

    //----------------------------------------------------------------
    // 4. FIFO Instantiations (Corrected instance names)
    //----------------------------------------------------------------
    // FIFO 1: Y data (16-bit)
    // yuv420_fifo_3 y_fifo_inst (  // <<< CORRECTED INSTANCE NAME
    //     .Data (y_fifo_wr_data),
    //     .Clk  (i_clk),
    //     .WrEn (y_fifo_wr_en && !y_fifo_full),
    //     .RdEn (y_fifo_rd_en),
    //     .Reset(!i_rst_n),
    //     .Wnum (y_fifo_wnum),
    //     .Q    (y_fifo_rd_data),
    //     .Empty(y_fifo_empty),
    //     .Full (y_fifo_full)
    // );

    // FIFO 2: UV line buffer (8-bit)
    yuv420_fifo_2 uv_line_buffer_fifo_inst (
        .Data (uv_line_buffer_fifo_wr_data),
        .Clk  (i_clk),
        .WrEn (uv_line_buffer_fifo_wr_en && !uv_line_buffer_fifo_full),
        .RdEn (uv_line_buffer_fifo_rden),
        .Reset(!i_rst_n),
        .Wnum (),
        .Q    (uv_line_buffer_fifo_rd_data),
        .Empty(uv_line_buffer_fifo_empty),
        .Full (uv_line_buffer_fifo_full)
    );

    // FIFO 3: Downsampled UV data (16-bit)
    // yuv420_fifo_3 uv_fifo_inst (  // <<< CORRECTED INSTANCE NAME
    //     .Data (uv_fifo_wr_data),
    //     .Clk  (i_clk),
    //     .WrEn (uv_fifo_wr_en && !uv_fifo_full),
    //     .RdEn (uv_fifo_rd_en),
    //     .Reset(!i_rst_n),
    //     .Wnum (uv_fifo_wnum),
    //     .Q    (uv_fifo_rd_data),
    //     .Empty(uv_fifo_empty),
    //     .Full (uv_fifo_full)
    // );

    //----------------------------------------------------------------
    // 5. SDRAM Write Controller FSM (REVISED LOGIC)
    //----------------------------------------------------------------
    assign y_wr_req  = (y_fifo_wnum >= Y_FIFO_THRESHOLD) && !y_plane_done;
    assign uv_wr_req = (uv_fifo_wnum >= UV_FIFO_THRESHOLD) && !uv_plane_done;

    // FSM State Transition
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next State Logic - Revised for interleaved Y/UV writes
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (v_active == 1'b0) begin
                    next_state = IDLE;
                end else if (y_plane_done && uv_plane_done) begin
                    next_state = FRAME_DONE;
                    // Y-plane has higher priority because its data rate is higher
                end else if (y_wr_req) begin
                    next_state = WR_Y_START;
                end else if (uv_wr_req) begin
                    next_state = WR_UV_START;
                end
            end
            WR_Y_START: begin
                next_state = WR_Y_DATA;
            end
            WR_Y_DATA: begin
                // A burst is an atomic operation, returns to IDLE only when finished
                if (burst_cnt == BURST_LEN_WORDS - 1) begin
                    next_state = IDLE;
                end
            end
            WR_UV_START: begin
                next_state = WR_UV_DATA;
            end
            WR_UV_DATA: begin
                // A burst is an atomic operation, returns to IDLE only when finished
                if (burst_cnt == BURST_LEN_WORDS - 1) begin
                    next_state = IDLE;
                end
            end
            FRAME_DONE: begin
                // Wait for vertical blanking before resetting for the next frame
                if (v_active == 1'b0) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // FSM Output Logic (Your code is kept as is, it's correct)
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            y_addr_offset       <= 32'd0;
            uv_addr_offset      <= 32'd0;
            burst_cnt           <= 'd0;
            y_plane_done        <= 1'b0;
            uv_plane_done       <= 1'b0;
            mem_wr_start_reg    <= 1'b0;
            mem_wr_data_vld_reg <= 1'b0;
            mem_wr_addrs_reg    <= 'd0;
            mem_wr_data_reg     <= 'd0;
            frame_done_pulse    <= 1'b0;
        end else begin
            mem_wr_start_reg    <= 1'b0;
            mem_wr_data_vld_reg <= 1'b0;
            frame_done_pulse    <= 1'b0;

            // if (v_active && vcnt == 0 && hcnt == 0) begin
            if (v_active == 1'b0) begin
                y_addr_offset  <= 32'd0;
                uv_addr_offset <= 32'd0;
                y_plane_done   <= 1'b0;
                uv_plane_done  <= 1'b0;
            end

            case (state)
                IDLE: begin
                    burst_cnt <= 'd0;
                end
                WR_Y_START: begin
                    mem_wr_start_reg <= 1'b1;
                    mem_wr_addrs_reg <= sdrm_address + y_addr_offset;
                end
                WR_Y_DATA: begin
                    if (!y_fifo_empty) begin
                        mem_wr_data_vld_reg <= 1'b1;
                        mem_wr_data_reg     <= y_fifo_rd_data;
                        if (burst_cnt == BURST_LEN_WORDS - 1) begin
                            burst_cnt     <= 'd0;
                            y_addr_offset <= y_addr_offset + BURST_LEN_BYTES;
                            if ((y_addr_offset + BURST_LEN_BYTES) >= Y_PLANE_SIZE_BYTES) begin
                                y_plane_done <= 1'b1;
                            end
                        end else begin
                            burst_cnt <= burst_cnt + 1;
                        end
                    end
                end
                WR_UV_START: begin
                    mem_wr_start_reg <= 1'b1;
                    mem_wr_addrs_reg <= sdrm_address + Y_PLANE_SIZE_BYTES + uv_addr_offset;
                end
                WR_UV_DATA: begin
                    if (!uv_fifo_empty) begin
                        mem_wr_data_vld_reg <= 1'b1;
                        mem_wr_data_reg     <= uv_fifo_rd_data;
                        if (burst_cnt == BURST_LEN_WORDS - 1) begin
                            burst_cnt      <= 'd0;
                            uv_addr_offset <= uv_addr_offset + BURST_LEN_BYTES;
                            if ((uv_addr_offset + BURST_LEN_BYTES) >= UV_PLANE_SIZE_BYTES) begin
                                uv_plane_done <= 1'b1;
                            end
                        end else begin
                            burst_cnt <= burst_cnt + 1;
                        end
                    end
                end
                FRAME_DONE: begin
                    frame_done_pulse <= 1'b1;
                end
            endcase
        end
    end

    // FIFO Read Enables
    assign y_fifo_rd_en  = (state == WR_Y_DATA) && !y_fifo_empty;
    assign uv_fifo_rd_en = (state == WR_UV_DATA) && !uv_fifo_empty;
    // Note: I removed `&& mem_wr_data_vld_reg` from read enable.
    // It's better to enable read whenever in the DATA state and FIFO is not empty.
    // The `mem_wr_data_vld_reg` itself depends on `!fifo_empty`, creating a potential combinational loop or just being redundant.
    // The simplified version is more robust.

    //----------------------------------------------------------------
    // 6. Output Assignments
    //----------------------------------------------------------------

    always @(posedge i_clk) begin
        if (i_vsync == 1'b0) begin
            // if(i_vsync == 1'b1)begin
            fcnt_wait <= {depth2width(WAIT_NUM) {1'b0}};
        end else if (fcnt_wait == WAIT_NUM - 1) begin
            fcnt_wait <= fcnt_wait;
        end else begin
            fcnt_wait <= fcnt_wait + 1'b1;
        end
    end

    always @(posedge i_clk) begin
        if ((fcnt_wait > WAIT_NUM - 20) && (fcnt_wait < WAIT_NUM - 10)) begin
            // o_mem_wr_start    <= 1'b1;
            o_mem_y_wr_start  <= 1'b1;
            o_mem_uv_wr_start <= 1'b1;
        end else begin
            // o_mem_wr_start    <= 1'b0;
            o_mem_y_wr_start  <= 1'b0;
            o_mem_uv_wr_start <= 1'b0;
        end
    end
    assign o_mem_wr_start    = mem_wr_start_reg;
    assign o_mem_y_wr_addrs     = plane_y_sdrm_address;  //mem_wr_addrs_reg;
    assign o_mem_y_wr_lengths   = Y_PLANE_SIZE_BYTES / 2;  //BURST_LEN_WORDS;
    assign o_mem_y_wr_data      = y_data_combined;//mem_wr_data_reg;
    assign o_mem_y_wr_data_vld  = y_data_combined_valid;//mem_wr_data_vld_reg;
    assign o_frame_done         = frame_done_pulse;

    assign o_mem_uv_wr_addrs    = plane_uv_sdrm_address;  //mem_wr_addrs_reg;
    assign o_mem_uv_wr_lengths  = UV_PLANE_SIZE_BYTES / 2;  //BURST_LEN_WORDS;
    assign o_mem_uv_wr_data     = uv_data_combined;
    assign o_mem_uv_wr_data_vld = uv_data_combined_valid;
endmodule
