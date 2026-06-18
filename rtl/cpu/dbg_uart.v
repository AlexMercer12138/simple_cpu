`timescale 1ns / 1ps

//================================================================================
// Module: dbg_uart
// Description:
//   UART debug command frontend for MERC32.
//
// Frame format:
//   Request : 55 AA CMD LEN PAYLOAD CHECKSUM
//   Response: 55 AA CMD STATUS LEN PAYLOAD CHECKSUM
//
// Checksum:
//   Request checksum  = 8-bit sum of CMD, LEN, and PAYLOAD bytes.
//   Response checksum = 8-bit sum of CMD, STATUS, LEN, and PAYLOAD bytes.
//
// Payload byte order:
//   Multi-byte fields are little-endian.
//
// Demo command set:
//   0x01 PING
//   0x02 GET_INFO
//   0x10 CPU_RESET_ASSERT
//   0x11 CPU_RESET_RELEASE
//   0x12 CPU_RESET_PULSE
//   0x20 HALT
//   0x21 RUN
//   0x22 STEP
//   0x23 GET_STATUS
//   0x30 LB_WRITE payload: addr[31:0], data[31:0]
//   0x31 LB_READ  payload: addr[31:0]
//
// Notes:
//   - dbg_req/dbg_wren/dbg_addr/dbg_wdata/dbg_rdata/dbg_rack use the same
//     request/ack style as the core internal local bus.
//   - dbg_req is a one-clock request pulse. The command executor waits for
//     dbg_rack before returning a UART response.
//   - Debug bus accesses are rejected unless cpu_halted is high or
//     dbg_cpu_rst_n is low.
//   - dbg_step_req is a one-clock pulse. The core still needs a debug-step port
//     before STEP can execute an instruction.
//================================================================================

module dbg_uart #(
    parameter           SYS_CLK_FREQ        = 50_000_000,
    parameter   [23:0]  BAUD_RATE           = 24'd115200,
    parameter           FIFO_DEPTH          = 8,
    parameter           MAX_PAYLOAD         = 64,
    parameter           RESET_PULSE_CYCLES  = 16
) (
    input                               clk,
    input                               rst_n,

    input                               uart_rx,
    output                              uart_tx,

    output  reg                         dbg_cpu_rst_n,
    output  reg                         dbg_halt_req,
    output  reg                         dbg_step_req,
    output                              dbg_busy,
    input                               cpu_halted,
    input       [15:0]                  cpu_pc,

    output  reg                         dbg_req,
    output  reg                         dbg_wren,
    output  reg [31:0]                  dbg_addr,
    output  reg [31:0]                  dbg_wdata,
    input       [31:0]                  dbg_rdata,
    input                               dbg_rack
);

    localparam  [7:0]   SOF0            = 8'h55;
    localparam  [7:0]   SOF1            = 8'haa;

    localparam  [7:0]   CMD_PING        = 8'h01;
    localparam  [7:0]   CMD_GET_INFO    = 8'h02;
    localparam  [7:0]   CMD_RST_ASSERT  = 8'h10;
    localparam  [7:0]   CMD_RST_RELEASE = 8'h11;
    localparam  [7:0]   CMD_RST_PULSE   = 8'h12;
    localparam  [7:0]   CMD_HALT        = 8'h20;
    localparam  [7:0]   CMD_RUN         = 8'h21;
    localparam  [7:0]   CMD_STEP        = 8'h22;
    localparam  [7:0]   CMD_STATUS      = 8'h23;
    localparam  [7:0]   CMD_LB_WRITE    = 8'h30;
    localparam  [7:0]   CMD_LB_READ     = 8'h31;

    localparam  [7:0]   RSP_OK          = 8'h00;
    localparam  [7:0]   RSP_BAD_CMD     = 8'h01;
    localparam  [7:0]   RSP_BAD_LEN     = 8'h02;
    localparam  [7:0]   RSP_BAD_SUM     = 8'h03;
    localparam  [7:0]   RSP_BUSY        = 8'h04;
    localparam  [7:0]   RSP_DENY_RUN    = 8'h05;

    localparam  [2:0]   RX_SOF0         = 3'd0;
    localparam  [2:0]   RX_SOF1         = 3'd1;
    localparam  [2:0]   RX_CMD          = 3'd2;
    localparam  [2:0]   RX_LEN          = 3'd3;
    localparam  [2:0]   RX_PAYLOAD      = 3'd4;
    localparam  [2:0]   RX_CHECKSUM     = 3'd5;

    localparam  [1:0]   EX_IDLE         = 2'd0;
    localparam  [1:0]   EX_MEM_WRITE    = 2'd1;
    localparam  [1:0]   EX_MEM_READ     = 2'd2;

    localparam          MAX_FRAME        = MAX_PAYLOAD + 6;

    wire                                rx_valid;
    wire                                rx_ready;
    wire    [7:0]                       rx_data;
    wire    [3:0]                       rx_data_cnt;
    wire                                tx_valid;
    wire                                tx_ready;
    wire    [7:0]                       tx_data;
    wire    [3:0]                       tx_data_cnt;
    wire                                rx_fire;
    wire                                tx_fire;
    wire                                mem_access_ok;

    reg     [2:0]                       rx_state;
    reg     [7:0]                       req_cmd;
    reg     [7:0]                       req_len;
    reg     [7:0]                       req_idx;
    reg     [7:0]                       req_sum;
    reg     [7:0]                       req_status;
    reg                                 req_oversize;
    reg                                 frame_valid;
    reg     [7:0]                       payload [0:MAX_PAYLOAD-1];

    reg     [1:0]                       ex_state;
    reg     [7:0]                       active_cmd;
    reg     [31:0]                      active_rdata;

    reg                                 tx_active;
    reg     [8:0]                       tx_idx;
    reg     [8:0]                       tx_frame_len;
    reg     [7:0]                       tx_frame [0:MAX_FRAME-1];

    reg     [31:0]                      reset_pulse_cnt;

    integer                             i;

    assign rx_ready      = ~frame_valid;
    assign rx_fire       = rx_valid & rx_ready;
    assign tx_valid      = tx_active;
    assign tx_data       = tx_frame[tx_idx];
    assign tx_fire       = tx_valid & tx_ready;
    assign dbg_busy      = frame_valid | tx_active | (ex_state != EX_IDLE);
    assign mem_access_ok = (~dbg_cpu_rst_n) | cpu_halted;

    task start_response;
        input   [7:0]   rsp_cmd;
        input   [7:0]   rsp_status;
        input   [7:0]   rsp_len;
        integer         k;
        reg     [7:0]   sum;
        begin
            tx_frame[0] = SOF0;
            tx_frame[1] = SOF1;
            tx_frame[2] = rsp_cmd;
            tx_frame[3] = rsp_status;
            tx_frame[4] = rsp_len;

            sum = rsp_cmd + rsp_status + rsp_len;
            for (k = 0; k < MAX_PAYLOAD; k = k + 1) begin
                if (k < rsp_len) begin
                    sum = sum + tx_frame[5+k];
                end
            end
            tx_frame[5+rsp_len] = sum;

            tx_frame_len <= {1'b0, rsp_len} + 9'd6;
            tx_idx <= 9'd0;
            tx_active <= 1'b1;
        end
    endtask

    task load_status_payload;
        reg [31:0] status_word;
        begin
            status_word = 32'h0;
            status_word[0] = ~dbg_cpu_rst_n;
            status_word[1] = dbg_halt_req;
            status_word[2] = cpu_halted;
            status_word[3] = frame_valid;
            status_word[4] = tx_active;
            status_word[5] = ex_state != EX_IDLE;
            status_word[6] = reset_pulse_cnt != 0;
            status_word[7] = dbg_req;

            tx_frame[5]  = status_word[7:0];
            tx_frame[6]  = status_word[15:8];
            tx_frame[7]  = status_word[23:16];
            tx_frame[8]  = status_word[31:24];
            tx_frame[9]  = cpu_pc[7:0];
            tx_frame[10] = cpu_pc[15:8];
            tx_frame[11] = 8'h00;
            tx_frame[12] = 8'h00;
        end
    endtask

    uart_top #(
        .SYS_CLK_FREQ                   (SYS_CLK_FREQ   ),
        .FIFO_DEPTH                     (FIFO_DEPTH     ))
    u_uart_top (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),
        .baud_rate                      (BAUD_RATE      ),
        .stop_bit                       (1'b0           ),
        .parity_type                    (2'b00          ),

        .m_axis_rx_tvalid               (rx_valid       ),
        .m_axis_rx_tready               (rx_ready       ),
        .m_axis_rx_tdata                (rx_data        ),
        .rx_data_cnt                    (rx_data_cnt    ),

        .s_axis_tx_tvalid               (tx_valid       ),
        .s_axis_tx_tready               (tx_ready       ),
        .s_axis_tx_tdata                (tx_data        ),
        .tx_data_cnt                    (tx_data_cnt    ),

        .uart_rx                        (uart_rx        ),
        .uart_tx                        (uart_tx        )
    );

    always @(posedge clk) begin
        if(!rst_n) begin
            dbg_cpu_rst_n <= 1'b1;
            dbg_halt_req <= 1'b0;
            dbg_step_req <= 1'b0;

            dbg_req <= 1'b0;
            dbg_wren <= 1'b0;
            dbg_addr <= 32'h0;
            dbg_wdata <= 32'h0;

            rx_state <= RX_SOF0;
            req_cmd <= 8'h0;
            req_len <= 8'h0;
            req_idx <= 8'h0;
            req_sum <= 8'h0;
            req_status <= RSP_OK;
            req_oversize <= 1'b0;
            frame_valid <= 1'b0;

            ex_state <= EX_IDLE;
            active_cmd <= 8'h0;
            active_rdata <= 32'h0;

            tx_active <= 1'b0;
            tx_idx <= 9'd0;
            tx_frame_len <= 9'd0;
            reset_pulse_cnt <= 32'd0;

            for (i = 0; i < MAX_PAYLOAD; i = i + 1) begin
                payload[i] <= 8'h0;
            end
            for (i = 0; i < MAX_FRAME; i = i + 1) begin
                tx_frame[i] <= 8'h0;
            end
        end else begin
            dbg_step_req <= 1'b0;
            dbg_req <= 1'b0;
            dbg_wren <= 1'b0;

            if (reset_pulse_cnt != 0) begin
                reset_pulse_cnt <= reset_pulse_cnt - 1'b1;
                if (reset_pulse_cnt == 1) begin
                    dbg_cpu_rst_n <= 1'b1;
                end
            end

            if (tx_fire) begin
                if (tx_idx == tx_frame_len - 1'b1) begin
                    tx_active <= 1'b0;
                    tx_idx <= 9'd0;
                end else begin
                    tx_idx <= tx_idx + 1'b1;
                end
            end

            if (rx_fire) begin
                case (rx_state)
                    RX_SOF0: begin
                        rx_state <= (rx_data == SOF0) ? RX_SOF1 : RX_SOF0;
                    end
                    RX_SOF1: begin
                        rx_state <=
                            (rx_data == SOF1) ? RX_CMD :
                            (rx_data == SOF0) ? RX_SOF1 :
                                                RX_SOF0;
                    end
                    RX_CMD: begin
                        req_cmd <= rx_data;
                        req_sum <= rx_data;
                        req_status <= RSP_OK;
                        rx_state <= RX_LEN;
                    end
                    RX_LEN: begin
                        req_len <= rx_data;
                        req_idx <= 8'd0;
                        req_sum <= req_sum + rx_data;
                        req_oversize <= rx_data > MAX_PAYLOAD;
                        rx_state <= (rx_data == 0) ? RX_CHECKSUM : RX_PAYLOAD;
                    end
                    RX_PAYLOAD: begin
                        req_sum <= req_sum + rx_data;
                        if (req_idx < MAX_PAYLOAD) begin
                            payload[req_idx] <= rx_data;
                        end
                        req_idx <= req_idx + 1'b1;
                        rx_state <= (req_idx == req_len - 1'b1) ? RX_CHECKSUM : RX_PAYLOAD;
                    end
                    RX_CHECKSUM: begin
                        frame_valid <= 1'b1;
                        req_status <=
                            (rx_data != req_sum) ? RSP_BAD_SUM :
                            req_oversize         ? RSP_BAD_LEN :
                                                   RSP_OK;
                        rx_state <= RX_SOF0;
                    end
                    default: begin
                        rx_state <= RX_SOF0;
                    end
                endcase
            end

            case (ex_state)
                EX_IDLE: begin
                    if (frame_valid && !tx_active) begin
                        if (req_status != RSP_OK) begin
                            frame_valid <= 1'b0;
                            start_response(req_cmd, req_status, 8'd0);
                        end else begin
                            case (req_cmd)
                                CMD_PING: begin
                                    frame_valid <= 1'b0;
                                    tx_frame[5] = 8'h4f; // O
                                    tx_frame[6] = 8'h4b; // K
                                    start_response(req_cmd, RSP_OK, 8'd2);
                                end
                                CMD_GET_INFO: begin
                                    frame_valid <= 1'b0;
                                    tx_frame[5]  = 8'd1;
                                    tx_frame[6]  = 8'd4;
                                    tx_frame[7]  = 8'd4;
                                    tx_frame[8]  = 8'b0000_1111;
                                    tx_frame[9]  = 8'h4d; // M
                                    tx_frame[10] = 8'h33; // 3
                                    tx_frame[11] = 8'h32; // 2
                                    tx_frame[12] = 8'h44; // D
                                    start_response(req_cmd, RSP_OK, 8'd8);
                                end
                                CMD_RST_ASSERT: begin
                                    frame_valid <= 1'b0;
                                    dbg_cpu_rst_n <= 1'b0;
                                    reset_pulse_cnt <= 32'd0;
                                    start_response(req_cmd, RSP_OK, 8'd0);
                                end
                                CMD_RST_RELEASE: begin
                                    frame_valid <= 1'b0;
                                    dbg_cpu_rst_n <= 1'b1;
                                    reset_pulse_cnt <= 32'd0;
                                    start_response(req_cmd, RSP_OK, 8'd0);
                                end
                                CMD_RST_PULSE: begin
                                    frame_valid <= 1'b0;
                                    dbg_cpu_rst_n <= 1'b0;
                                    reset_pulse_cnt <= RESET_PULSE_CYCLES;
                                    start_response(req_cmd, RSP_OK, 8'd0);
                                end
                                CMD_HALT: begin
                                    frame_valid <= 1'b0;
                                    dbg_halt_req <= 1'b1;
                                    start_response(req_cmd, RSP_OK, 8'd0);
                                end
                                CMD_RUN: begin
                                    frame_valid <= 1'b0;
                                    dbg_halt_req <= 1'b0;
                                    start_response(req_cmd, RSP_OK, 8'd0);
                                end
                                CMD_STEP: begin
                                    frame_valid <= 1'b0;
                                    if (!dbg_cpu_rst_n) begin
                                        start_response(req_cmd, RSP_DENY_RUN, 8'd0);
                                    end else begin
                                        dbg_halt_req <= 1'b1;
                                        dbg_step_req <= 1'b1;
                                        start_response(req_cmd, RSP_OK, 8'd0);
                                    end
                                end
                                CMD_STATUS: begin
                                    frame_valid <= 1'b0;
                                    load_status_payload();
                                    start_response(req_cmd, RSP_OK, 8'd8);
                                end
                                CMD_LB_WRITE: begin
                                    frame_valid <= 1'b0;
                                    if (req_len != 8'd8) begin
                                        start_response(req_cmd, RSP_BAD_LEN, 8'd0);
                                    end else if (!mem_access_ok) begin
                                        start_response(req_cmd, RSP_DENY_RUN, 8'd0);
                                    end else begin
                                        active_cmd <= req_cmd;
                                        dbg_req <= 1'b1;
                                        dbg_wren <= 1'b1;
                                        dbg_addr <= {payload[3], payload[2], payload[1], payload[0]};
                                        dbg_wdata <= {payload[7], payload[6], payload[5], payload[4]};
                                        ex_state <= EX_MEM_WRITE;
                                    end
                                end
                                CMD_LB_READ: begin
                                    frame_valid <= 1'b0;
                                    if (req_len != 8'd4) begin
                                        start_response(req_cmd, RSP_BAD_LEN, 8'd0);
                                    end else if (!mem_access_ok) begin
                                        start_response(req_cmd, RSP_DENY_RUN, 8'd0);
                                    end else begin
                                        active_cmd <= req_cmd;
                                        dbg_req <= 1'b1;
                                        dbg_wren <= 1'b0;
                                        dbg_addr <= {payload[3], payload[2], payload[1], payload[0]};
                                        ex_state <= EX_MEM_READ;
                                    end
                                end
                                default: begin
                                    frame_valid <= 1'b0;
                                    start_response(req_cmd, RSP_BAD_CMD, 8'd0);
                                end
                            endcase
                        end
                    end
                end
                EX_MEM_WRITE: begin
                    if (dbg_rack) begin
                        start_response(active_cmd, RSP_OK, 8'd0);
                        ex_state <= EX_IDLE;
                    end
                end
                EX_MEM_READ: begin
                    if (dbg_rack) begin
                        active_rdata = dbg_rdata;
                        tx_frame[5] = active_rdata[7:0];
                        tx_frame[6] = active_rdata[15:8];
                        tx_frame[7] = active_rdata[23:16];
                        tx_frame[8] = active_rdata[31:24];
                        start_response(active_cmd, RSP_OK, 8'd4);
                        ex_state <= EX_IDLE;
                    end
                end
                default: begin
                    ex_state <= EX_IDLE;
                end
            endcase
        end
    end

endmodule
