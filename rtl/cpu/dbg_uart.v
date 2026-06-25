//================================================================================
//
//  ███╗   ███╗███████╗██████╗  ██████╗███████╗██████╗ 
//  ████╗ ████║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
//  ██╔████╔██║█████╗  ██████╔╝██║     █████╗  ██████╔╝
//  ██║╚██╔╝██║██╔══╝  ██╔══██╗██║     ██╔══╝  ██╔══██╗
//  ██║ ╚═╝ ██║███████╗██║  ██║╚██████╗███████╗██║  ██║
//  ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝  ╚═╝
//
//--------------------------------------------------------------------------------
//  Author      : Mercer
//  Module      : dbg_uart
//  Description : UART debug command frontend for MERC32
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================

//================================================================================
//  Instantiation Template
//================================================================================
/*
dbg_uart #(
    .SYS_CLK_FREQ               (50_000_000     ),
    .BAUD_RATE                  (24'd115200     ),
    .FIFO_DEPTH                 (8              ),
    .MAX_PAYLOAD                (64             ),
    .RESET_PULSE_CYCLES         (16             ))
u_dbg_uart (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .uart_rx                    (uart_rx        ),
    .uart_tx                    (uart_tx        ),

    .dbg_cpu_rst_n              (dbg_cpu_rst_n  ),
    .dbg_halt_req               (dbg_halt_req   ),
    .dbg_step_req               (dbg_step_req   ),
    .dbg_busy                   (dbg_busy       ),
    .cpu_halted                 (cpu_halted     ),
    .cpu_pc                     (cpu_pc         ),

    .dbg_req                    (dbg_req        ),
    .dbg_wren                   (dbg_wren       ),
    .dbg_addr                   (dbg_addr       ),
    .dbg_wdata                  (dbg_wdata      ),
    .dbg_rdata                  (dbg_rdata      ),
    .dbg_rack                   (dbg_rack       ));
*/

//================================================================================
//  Module Definition
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
    output                              dbg_step_req,
    output                              dbg_busy,
    input                               cpu_halted,
    input       [15:0]                  cpu_pc,

    output                              dbg_req,
    output                              dbg_wren,
    output  reg [31:0]                  dbg_addr,
    output  reg [31:0]                  dbg_wdata,
    input       [31:0]                  dbg_rdata,
    input                               dbg_rack
);

    localparam  [7:0]   SOF0            = 8'h55;
    localparam  [7:0]   SOF1            = 8'hAA;

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
    localparam  [7:0]   RSP_DENY_RUN    = 8'h05;

    localparam  [2:0]   RX_SOF0         = 3'd0;
    localparam  [2:0]   RX_SOF1         = 3'd1;
    localparam  [2:0]   RX_CMD          = 3'd2;
    localparam  [2:0]   RX_LEN          = 3'd3;
    localparam  [2:0]   RX_PAYLOAD      = 3'd4;
    localparam  [2:0]   RX_CHECKSUM     = 3'd5;

    localparam  [2:0]   EX_IDLE         = 3'd0;
    localparam  [2:0]   EX_LB_WR_REQ    = 3'd1;
    localparam  [2:0]   EX_LB_WR_WAIT   = 3'd2;
    localparam  [2:0]   EX_LB_RD_REQ    = 3'd3;
    localparam  [2:0]   EX_LB_RD_WAIT   = 3'd4;

    localparam          MAX_FRAME        = MAX_PAYLOAD + 6;

    wire                                rx_valid;
    wire                                rx_ready;
    wire    [7:0]                       rx_data;
    wire    [3:0]                       rx_data_cnt;
    wire                                rx_fire;

    wire                                tx_valid;
    wire                                tx_ready;
    wire    [7:0]                       tx_data;
    wire    [3:0]                       tx_data_cnt;
    wire                                tx_fire;

    wire                                frame_take;
    wire                                cmd_ok;
    wire                                cmd_step_accept;
    wire                                cmd_rst_assert;
    wire                                cmd_rst_release;
    wire                                cmd_rst_pulse;
    wire                                cmd_halt;
    wire                                cmd_run;
    wire                                cmd_lb_write_start;
    wire                                cmd_lb_read_start;
    wire                                mem_access_ok;
    wire    [31:0]                      status_word;

    reg     [2:0]                       rx_state;
    reg     [7:0]                       req_cmd;
    reg     [7:0]                       req_len;
    reg     [7:0]                       req_idx;
    reg     [7:0]                       req_sum;
    reg     [7:0]                       req_status;
    reg                                 req_oversize;
    reg                                 frame_valid;
    reg     [7:0]                       payload [0:MAX_PAYLOAD-1];

    reg     [2:0]                       ex_state;
    reg     [7:0]                       active_cmd;

    reg                                 tx_active;
    reg     [8:0]                       tx_idx;
    reg     [8:0]                       tx_frame_len;
    reg     [7:0]                       tx_frame [0:MAX_FRAME-1];

    reg     [31:0]                      reset_pulse_cnt;

    integer                             payload_init_idx;
    integer                             tx_frame_init_idx;

    assign rx_ready             = ~frame_valid;
    assign rx_fire              = rx_valid & rx_ready;

    assign tx_valid             = tx_active;
    assign tx_data              = tx_frame[tx_idx];
    assign tx_fire              = tx_valid & tx_ready;

    assign frame_take           = frame_valid & ~tx_active & (ex_state == EX_IDLE);
    assign cmd_ok               = frame_take & (req_status == RSP_OK);
    assign mem_access_ok        = (~dbg_cpu_rst_n) | cpu_halted;

    assign cmd_step_accept      = cmd_ok & (req_cmd == CMD_STEP) & dbg_cpu_rst_n;
    assign cmd_rst_assert       = cmd_ok & (req_cmd == CMD_RST_ASSERT);
    assign cmd_rst_release      = cmd_ok & (req_cmd == CMD_RST_RELEASE);
    assign cmd_rst_pulse        = cmd_ok & (req_cmd == CMD_RST_PULSE);
    assign cmd_halt             = cmd_ok & (req_cmd == CMD_HALT);
    assign cmd_run              = cmd_ok & (req_cmd == CMD_RUN);

    assign cmd_lb_write_start   = cmd_ok & (req_cmd == CMD_LB_WRITE) &
                                  (req_len == 8'd8) & mem_access_ok;
    assign cmd_lb_read_start    = cmd_ok & (req_cmd == CMD_LB_READ) &
                                  (req_len == 8'd4) & mem_access_ok;

    assign dbg_req              = (ex_state == EX_LB_WR_REQ) |
                                  (ex_state == EX_LB_RD_REQ);
    assign dbg_wren             = (ex_state == EX_LB_WR_REQ);
    assign dbg_step_req         = cmd_step_accept;

    assign dbg_busy             = frame_valid | tx_active |
                                  (ex_state != EX_IDLE) |
                                  (tx_data_cnt != 4'd0);

    assign status_word          = {
        24'h0,
        dbg_req,
        reset_pulse_cnt != 32'd0,
        ex_state != EX_IDLE,
        tx_active | (tx_data_cnt != 4'd0),
        frame_valid,
        cpu_halted,
        dbg_halt_req,
        ~dbg_cpu_rst_n
    };

    uart_top #(
        .SYS_CLK_FREQ                   (SYS_CLK_FREQ   ),
        .FIFO_DEPTH                     (FIFO_DEPTH     ))
    uart_top_inst (
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

    // RX frame parser.
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_state <= RX_SOF0;
            req_cmd <= 8'h0;
            req_len <= 8'h0;
            req_idx <= 8'h0;
            req_sum <= 8'h0;
            req_status <= RSP_OK;
            req_oversize <= 1'b0;
            frame_valid <= 1'b0;

            for (payload_init_idx = 0; payload_init_idx < MAX_PAYLOAD; payload_init_idx = payload_init_idx + 1) begin
                payload[payload_init_idx] <= 8'h0;
            end
        end else if (frame_take) begin
            frame_valid <= 1'b0;
        end else if (rx_fire) begin
            case (rx_state)
                RX_SOF0: begin
                    if (rx_data == SOF0) begin
                        rx_state <= RX_SOF1;
                    end else begin
                        rx_state <= RX_SOF0;
                    end
                end
                RX_SOF1: begin
                    if (rx_data == SOF1) begin
                        rx_state <= RX_CMD;
                    end else if (rx_data == SOF0) begin
                        rx_state <= RX_SOF1;
                    end else begin
                        rx_state <= RX_SOF0;
                    end
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

                    if (rx_data == 8'd0) begin
                        rx_state <= RX_CHECKSUM;
                    end else begin
                        rx_state <= RX_PAYLOAD;
                    end
                end
                RX_PAYLOAD: begin
                    req_sum <= req_sum + rx_data;
                    req_idx <= req_idx + 1'b1;

                    if (req_idx < MAX_PAYLOAD) begin
                        payload[req_idx] <= rx_data;
                    end

                    if (req_idx == req_len - 1'b1) begin
                        rx_state <= RX_CHECKSUM;
                    end else begin
                        rx_state <= RX_PAYLOAD;
                    end
                end
                RX_CHECKSUM: begin
                    frame_valid <= 1'b1;
                    rx_state <= RX_SOF0;

                    if (rx_data != req_sum) begin
                        req_status <= RSP_BAD_SUM;
                    end else if (req_oversize) begin
                        req_status <= RSP_BAD_LEN;
                    end else begin
                        req_status <= RSP_OK;
                    end
                end
                default: begin
                    rx_state <= RX_SOF0;
                end
            endcase
        end
    end

    // Debug bus command state.
    always @(posedge clk) begin
        if (!rst_n) begin
            ex_state <= EX_IDLE;
            active_cmd <= 8'h0;
            dbg_addr <= 32'h0;
            dbg_wdata <= 32'h0;
        end else begin
            case (ex_state)
                EX_IDLE: begin
                    if (cmd_lb_write_start) begin
                        ex_state <= EX_LB_WR_REQ;
                        active_cmd <= req_cmd;
                        dbg_addr <= {payload[3], payload[2], payload[1], payload[0]};
                        dbg_wdata <= {payload[7], payload[6], payload[5], payload[4]};
                    end else if (cmd_lb_read_start) begin
                        ex_state <= EX_LB_RD_REQ;
                        active_cmd <= req_cmd;
                        dbg_addr <= {payload[3], payload[2], payload[1], payload[0]};
                    end else begin
                        ex_state <= EX_IDLE;
                    end
                end
                EX_LB_WR_REQ: begin
                    ex_state <= EX_LB_WR_WAIT;
                end
                EX_LB_WR_WAIT: begin
                    if (dbg_rack) begin
                        ex_state <= EX_IDLE;
                    end else begin
                        ex_state <= EX_LB_WR_WAIT;
                    end
                end
                EX_LB_RD_REQ: begin
                    ex_state <= EX_LB_RD_WAIT;
                end
                EX_LB_RD_WAIT: begin
                    if (dbg_rack) begin
                        ex_state <= EX_IDLE;
                    end else begin
                        ex_state <= EX_LB_RD_WAIT;
                    end
                end
                default: begin
                    ex_state <= EX_IDLE;
                end
            endcase
        end
    end

    // CPU reset control.
    always @(posedge clk) begin
        if (!rst_n) begin
            dbg_cpu_rst_n <= 1'b1;
            reset_pulse_cnt <= 32'd0;
        end else if (cmd_rst_assert) begin
            dbg_cpu_rst_n <= 1'b0;
            reset_pulse_cnt <= 32'd0;
        end else if (cmd_rst_release) begin
            dbg_cpu_rst_n <= 1'b1;
            reset_pulse_cnt <= 32'd0;
        end else if (cmd_rst_pulse) begin
            dbg_cpu_rst_n <= 1'b0;
            reset_pulse_cnt <= RESET_PULSE_CYCLES;
        end else if (reset_pulse_cnt != 32'd0) begin
            dbg_cpu_rst_n <= (reset_pulse_cnt == 32'd1) ? 1'b1 : dbg_cpu_rst_n;
            reset_pulse_cnt <= reset_pulse_cnt - 1'b1;
        end
    end

    // Halt control.
    always @(posedge clk) begin
        if (!rst_n) begin
            dbg_halt_req <= 1'b0;
        end else if (cmd_halt | cmd_step_accept) begin
            dbg_halt_req <= 1'b1;
        end else if (cmd_run) begin
            dbg_halt_req <= 1'b0;
        end
    end

    // TX response frame builder and sender.
    always @(posedge clk) begin
        if (!rst_n) begin
            tx_active <= 1'b0;
            tx_idx <= 9'd0;
            tx_frame_len <= 9'd0;

            for (tx_frame_init_idx = 0; tx_frame_init_idx < MAX_FRAME; tx_frame_init_idx = tx_frame_init_idx + 1) begin
                tx_frame[tx_frame_init_idx] <= 8'h0;
            end
        end else if ((ex_state == EX_LB_WR_WAIT) & dbg_rack) begin
            tx_frame[0] <= SOF0;
            tx_frame[1] <= SOF1;
            tx_frame[2] <= active_cmd;
            tx_frame[3] <= RSP_OK;
            tx_frame[4] <= 8'd0;
            tx_frame[5] <= active_cmd + RSP_OK;
            tx_frame_len <= 9'd6;
            tx_idx <= 9'd0;
            tx_active <= 1'b1;
        end else if ((ex_state == EX_LB_RD_WAIT) & dbg_rack) begin
            tx_frame[0] <= SOF0;
            tx_frame[1] <= SOF1;
            tx_frame[2] <= active_cmd;
            tx_frame[3] <= RSP_OK;
            tx_frame[4] <= 8'd4;
            tx_frame[5] <= dbg_rdata[7:0];
            tx_frame[6] <= dbg_rdata[15:8];
            tx_frame[7] <= dbg_rdata[23:16];
            tx_frame[8] <= dbg_rdata[31:24];
            tx_frame[9] <= active_cmd + RSP_OK + 8'd4 +
                           dbg_rdata[7:0] + dbg_rdata[15:8] +
                           dbg_rdata[23:16] + dbg_rdata[31:24];
            tx_frame_len <= 9'd10;
            tx_idx <= 9'd0;
            tx_active <= 1'b1;
        end else if (frame_take & (req_status != RSP_OK)) begin
            tx_frame[0] <= SOF0;
            tx_frame[1] <= SOF1;
            tx_frame[2] <= req_cmd;
            tx_frame[3] <= req_status;
            tx_frame[4] <= 8'd0;
            tx_frame[5] <= req_cmd + req_status;
            tx_frame_len <= 9'd6;
            tx_idx <= 9'd0;
            tx_active <= 1'b1;
        end else if (frame_take) begin
            case (req_cmd)
                CMD_PING: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= RSP_OK;
                    tx_frame[4] <= 8'd2;
                    tx_frame[5] <= 8'h4F;
                    tx_frame[6] <= 8'h4B;
                    tx_frame[7] <= req_cmd + RSP_OK + 8'd2 + 8'h4F + 8'h4B;
                    tx_frame_len <= 9'd8;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
                CMD_GET_INFO: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= RSP_OK;
                    tx_frame[4] <= 8'd8;
                    tx_frame[5] <= 8'd1;
                    tx_frame[6] <= 8'd4;
                    tx_frame[7] <= 8'd4;
                    tx_frame[8] <= 8'b0000_1111;
                    tx_frame[9] <= 8'h4D;
                    tx_frame[10] <= 8'h33;
                    tx_frame[11] <= 8'h32;
                    tx_frame[12] <= 8'h44;
                    tx_frame[13] <= req_cmd + RSP_OK + 8'd8 +
                                    8'd1 + 8'd4 + 8'd4 + 8'b0000_1111 +
                                    8'h4D + 8'h33 + 8'h32 + 8'h44;
                    tx_frame_len <= 9'd14;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
                CMD_STEP: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= dbg_cpu_rst_n ? RSP_OK : RSP_DENY_RUN;
                    tx_frame[4] <= 8'd0;
                    tx_frame[5] <= req_cmd + (dbg_cpu_rst_n ? RSP_OK : RSP_DENY_RUN);
                    tx_frame_len <= 9'd6;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
                CMD_STATUS: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= RSP_OK;
                    tx_frame[4] <= 8'd8;
                    tx_frame[5] <= status_word[7:0];
                    tx_frame[6] <= status_word[15:8];
                    tx_frame[7] <= status_word[23:16];
                    tx_frame[8] <= status_word[31:24];
                    tx_frame[9] <= cpu_pc[7:0];
                    tx_frame[10] <= cpu_pc[15:8];
                    tx_frame[11] <= 8'h00;
                    tx_frame[12] <= 8'h00;
                    tx_frame[13] <= req_cmd + RSP_OK + 8'd8 +
                                    status_word[7:0] + status_word[15:8] +
                                    status_word[23:16] + status_word[31:24] +
                                    cpu_pc[7:0] + cpu_pc[15:8];
                    tx_frame_len <= 9'd14;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
                CMD_LB_WRITE: begin
                    if (req_len != 8'd8) begin
                        tx_frame[0] <= SOF0;
                        tx_frame[1] <= SOF1;
                        tx_frame[2] <= req_cmd;
                        tx_frame[3] <= RSP_BAD_LEN;
                        tx_frame[4] <= 8'd0;
                        tx_frame[5] <= req_cmd + RSP_BAD_LEN;
                        tx_frame_len <= 9'd6;
                        tx_idx <= 9'd0;
                        tx_active <= 1'b1;
                    end else if (!mem_access_ok) begin
                        tx_frame[0] <= SOF0;
                        tx_frame[1] <= SOF1;
                        tx_frame[2] <= req_cmd;
                        tx_frame[3] <= RSP_DENY_RUN;
                        tx_frame[4] <= 8'd0;
                        tx_frame[5] <= req_cmd + RSP_DENY_RUN;
                        tx_frame_len <= 9'd6;
                        tx_idx <= 9'd0;
                        tx_active <= 1'b1;
                    end
                end
                CMD_LB_READ: begin
                    if (req_len != 8'd4) begin
                        tx_frame[0] <= SOF0;
                        tx_frame[1] <= SOF1;
                        tx_frame[2] <= req_cmd;
                        tx_frame[3] <= RSP_BAD_LEN;
                        tx_frame[4] <= 8'd0;
                        tx_frame[5] <= req_cmd + RSP_BAD_LEN;
                        tx_frame_len <= 9'd6;
                        tx_idx <= 9'd0;
                        tx_active <= 1'b1;
                    end else if (!mem_access_ok) begin
                        tx_frame[0] <= SOF0;
                        tx_frame[1] <= SOF1;
                        tx_frame[2] <= req_cmd;
                        tx_frame[3] <= RSP_DENY_RUN;
                        tx_frame[4] <= 8'd0;
                        tx_frame[5] <= req_cmd + RSP_DENY_RUN;
                        tx_frame_len <= 9'd6;
                        tx_idx <= 9'd0;
                        tx_active <= 1'b1;
                    end
                end
                CMD_RST_ASSERT,
                CMD_RST_RELEASE,
                CMD_RST_PULSE,
                CMD_HALT,
                CMD_RUN: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= RSP_OK;
                    tx_frame[4] <= 8'd0;
                    tx_frame[5] <= req_cmd + RSP_OK;
                    tx_frame_len <= 9'd6;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
                default: begin
                    tx_frame[0] <= SOF0;
                    tx_frame[1] <= SOF1;
                    tx_frame[2] <= req_cmd;
                    tx_frame[3] <= RSP_BAD_CMD;
                    tx_frame[4] <= 8'd0;
                    tx_frame[5] <= req_cmd + RSP_BAD_CMD;
                    tx_frame_len <= 9'd6;
                    tx_idx <= 9'd0;
                    tx_active <= 1'b1;
                end
            endcase
        end else if (tx_fire) begin
            if (tx_idx == tx_frame_len - 1'b1) begin
                tx_active <= 1'b0;
                tx_idx <= 9'd0;
            end else begin
                tx_idx <= tx_idx + 1'b1;
            end
        end
    end

endmodule
