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
//  Module      : can_top
//  Description : CAN Classic top module with TX/RX and RX FIFO
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//  v1.1 - Add TEC/REC, error state machine, auto-retry, bus-off recovery
//================================================================================

//================================================================================
//  Instantiation Template
//================================================================================
/*
can_top #(
    .FIFO_DEPTH                 (4                  ))
u_can_top (
    .clk                        (clk                ),
    .rst_n                      (rst_n              ),
    .enable                     (enable             ),
    .loopback_mode              (loopback_mode      ),
    .listen_only                (listen_only        ),
    .brp                        (brp                ),
    .sjw                        (sjw                ),
    .tseg1                      (tseg1              ),
    .tseg2                      (tseg2              ),
    .tx_start                   (tx_start           ),
    .tx_id                      (tx_id              ),
    .tx_ide                     (tx_ide             ),
    .tx_rtr                     (tx_rtr             ),
    .tx_dlc                     (tx_dlc             ),
    .tx_data                    (tx_data            ),
    .tx_ready                   (tx_ready           ),
    .tx_busy                    (tx_busy            ),
    .tx_done                    (tx_done            ),
    .rx_release                 (rx_release         ),
    .rx_valid                   (rx_valid           ),
    .rx_id                      (rx_id              ),
    .rx_ide                     (rx_ide             ),
    .rx_rtr                     (rx_rtr             ),
    .rx_dlc                     (rx_dlc             ),
    .rx_data                    (rx_data            ),
    .rx_count                   (rx_count           ),
    .error_pulse                (error_pulse        ),
    .crc_error                  (crc_error          ),
    .stuff_error                (stuff_error        ),
    .form_error                 (form_error         ),
    .ack_error                  (ack_error          ),
    .bit_error                  (bit_error          ),
    .arbitration_lost           (arbitration_lost   ),
    .retry_pending              (retry_pending      ),
    .tec                        (tec                ),
    .rec                        (rec                ),
    .error_active               (error_active       ),
    .error_passive              (error_passive      ),
    .bus_off                    (bus_off            ),
    .bus_idle                   (bus_idle           ),
    .can_rx                     (can_rx             ),
    .can_tx                     (can_tx             ));
*/

//================================================================================
//  Module Definition
//================================================================================

module can_top #(
    parameter FIFO_DEPTH = 4
)(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            enable,
    input   wire            loopback_mode,
    input   wire            listen_only,
    input   wire    [9:0]   brp,
    input   wire    [1:0]   sjw,
    input   wire    [3:0]   tseg1,
    input   wire    [3:0]   tseg2,

    input   wire            tx_start,
    input   wire    [28:0]  tx_id,
    input   wire            tx_ide,
    input   wire            tx_rtr,
    input   wire    [3:0]   tx_dlc,
    input   wire    [63:0]  tx_data,
    output  wire            tx_ready,
    output  wire            tx_busy,
    output  wire            tx_done,

    input   wire            rx_release,
    output  wire            rx_valid,
    output  wire    [28:0]  rx_id,
    output  wire            rx_ide,
    output  wire            rx_rtr,
    output  wire    [3:0]   rx_dlc,
    output  wire    [63:0]  rx_data,
    output  wire    [2:0]   rx_count,

    output  wire            error_pulse,
    output  wire            crc_error,
    output  wire            stuff_error,
    output  wire            form_error,
    output  wire            ack_error,
    output  wire            bit_error,
    output  wire            arbitration_lost,
    output  wire            retry_pending,
    output  wire [7:0]      tec,
    output  wire [7:0]      rec,
    output  wire            error_active,
    output  wire            error_passive,
    output  wire            bus_off,
    output  wire            bus_idle,

    input   wire            can_rx,
    output  wire            can_tx
);

    wire                    tq_tick;
    wire                    sample_tick;
    wire                    bit_tick;
    wire                    sync_tick;
    wire                    tx_line;
    wire                    rx_line;
    wire                    tx_busy_int;
    wire                    rx_frame_valid;
    wire    [28:0]          rx_frame_id;
    wire                    rx_frame_ide;
    wire                    rx_frame_rtr;
    wire    [3:0]           rx_frame_dlc;
    wire    [63:0]          rx_frame_data;
    wire                    rx_fifo_full;
    wire                    rx_fifo_empty;
    wire                    rx_wr_en;

    //--------------------------------------------------------------------------------
    //  TEC / REC / Error State
    //--------------------------------------------------------------------------------
    reg     [8:0]           tec_cnt;        // 9-bit to detect 256 overflow
    reg     [7:0]           rec_cnt;        // 8-bit, saturates at 127

    assign bus_off       = (tec_cnt >= 9'd256);
    assign error_passive = (tec_cnt[7:0] >= 8'd128) || (rec_cnt >= 8'd128);
    assign error_active  = !bus_off && !error_passive;
    assign tec           = tec_cnt[7:0];
    assign rec           = rec_cnt;

    //--------------------------------------------------------------------------------
    //  Auto-retry logic
    //--------------------------------------------------------------------------------
    reg                     retry_pending_reg;

    wire                    retry_start = retry_pending_reg & bus_idle & ~tx_busy_int & enable & ~bus_off;

    assign retry_pending = retry_pending_reg;

    //--------------------------------------------------------------------------------
    //  Bus-off recovery counter
    //--------------------------------------------------------------------------------
    reg     [6:0]           recovery_cnt;  // 0-127

    //--------------------------------------------------------------------------------
    //  Output assignments
    //--------------------------------------------------------------------------------
    assign can_tx      = (listen_only || bus_off) ? 1'b1 : tx_line;
    assign rx_line     = loopback_mode ? 1'b1 : can_rx;
    assign tx_busy     = tx_busy_int;
    assign tx_ready    = enable & ~tx_busy_int & ~bus_off;
    assign rx_wr_en    = loopback_mode ? (tx_done & ~rx_fifo_full) : (rx_frame_valid & ~rx_fifo_full);
    assign error_pulse = crc_error | stuff_error | form_error | ack_error | bit_error | (rx_frame_valid & rx_fifo_full);

    can_bit_timing u_can_bit_timing (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .enable         (enable         ),
        .brp            (brp            ),
        .sjw            (sjw            ),
        .tseg1          (tseg1          ),
        .tseg2          (tseg2          ),
        .can_rx         (rx_line        ),
        .tq_tick        (tq_tick        ),
        .sample_tick    (sample_tick    ),
        .bit_tick       (bit_tick       ),
        .sync_tick      (sync_tick      ),
        .bus_idle       (bus_idle       ));

    can_tx u_can_tx (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .enable         (enable         ),
        .loopback_mode  (loopback_mode  ),
        .listen_only    (listen_only    ),
        .start          (tx_start | retry_start),
        .tx_id          (tx_id          ),
        .tx_ide         (tx_ide         ),
        .tx_rtr         (tx_rtr         ),
        .tx_dlc         (tx_dlc         ),
        .tx_data        (tx_data        ),
        .bit_tick       (bit_tick       ),
        .sample_tick    (sample_tick    ),
        .bus_idle       (bus_idle       ),
        .can_rx         (rx_line        ),
        .can_tx         (tx_line        ),
        .busy           (tx_busy_int    ),
        .done           (tx_done        ),
        .ack_error      (ack_error      ),
        .bit_error      (bit_error      ),
        .arbitration_lost(arbitration_lost));

    can_rx u_can_rx (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .enable         (enable         ),
        .sample_tick    (sample_tick    ),
        .can_rx         (rx_line        ),
        .frame_valid    (rx_frame_valid ),
        .frame_id       (rx_frame_id    ),
        .frame_ide      (rx_frame_ide   ),
        .frame_rtr      (rx_frame_rtr   ),
        .frame_dlc      (rx_frame_dlc   ),
        .frame_data     (rx_frame_data  ),
        .crc_error      (crc_error      ),
        .stuff_error    (stuff_error    ),
        .form_error     (form_error     ));

    can_fifo #(
        .FIFO_DEPTH     (FIFO_DEPTH     ))
    u_can_fifo (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .wr_en          (rx_wr_en       ),
        .wr_id          (loopback_mode ? tx_id : rx_frame_id),
        .wr_ide         (loopback_mode ? tx_ide : rx_frame_ide),
        .wr_rtr         (loopback_mode ? tx_rtr : rx_frame_rtr),
        .wr_dlc         (loopback_mode ? (tx_dlc > 4'd8 ? 4'd8 : tx_dlc) : rx_frame_dlc),
        .wr_data        (loopback_mode ? tx_data : rx_frame_data),
        .rd_en          (rx_release     ),
        .rd_valid       (rx_valid       ),
        .rd_id          (rx_id          ),
        .rd_ide         (rx_ide         ),
        .rd_rtr         (rx_rtr         ),
        .rd_dlc         (rx_dlc         ),
        .rd_data        (rx_data        ),
        .full           (rx_fifo_full   ),
        .empty          (rx_fifo_empty  ),
        .count          (rx_count       ));

    //--------------------------------------------------------------------------------
    //  TEC / REC / Retry / Bus-off Recovery sequential logic
    //--------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            tec_cnt          <= 9'd0;
            rec_cnt          <= 8'd0;
            retry_pending_reg <= 1'b0;
            recovery_cnt     <= 7'd0;
        end else begin
            //--- TEC update ---
            if (bit_error) begin
                tec_cnt <= tec_cnt + 9'd8;
            end else if (ack_error) begin
                tec_cnt <= tec_cnt + 9'd8;
            end else if (tx_done) begin
                if (tec_cnt > 9'd0)
                    tec_cnt <= tec_cnt - 9'd1;
            end

            //--- Bus-off recovery ---
            if (bus_off) begin
                if (bus_idle && bit_tick) begin
                    recovery_cnt <= recovery_cnt + 7'd1;
                end
                if (recovery_cnt == 7'd127) begin
                    tec_cnt      <= 9'd0;
                    rec_cnt      <= 8'd0;
                    recovery_cnt <= 7'd0;
                end
            end else begin
                recovery_cnt <= 7'd0;
            end

            //--- REC update ---
            if (crc_error || stuff_error || form_error) begin
                if (rec_cnt >= 8'd120)
                    rec_cnt <= 8'd127;
                else
                    rec_cnt <= rec_cnt + 8'd8;
            end else if (rx_frame_valid) begin
                if (rec_cnt > 8'd0)
                    rec_cnt <= rec_cnt - 8'd1;
            end

            //--- Auto-retry pending ---
            if (!enable || bus_off) begin
                retry_pending_reg <= 1'b0;
            end else if (arbitration_lost || ack_error || bit_error) begin
                retry_pending_reg <= 1'b1;
            end else if (tx_done) begin
                retry_pending_reg <= 1'b0;
            end
        end
    end

endmodule
