`timescale 1ns / 1ps
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
//  Module      : uart_debug
//  Description : UART-based debug bridge with configurable serial protocol.
//
//  Protocol Frame Format:
//    [SOP] [CMD] [LEN] [DATA0..DATAn] [CHK]
//     0x5A  1B    1B     0~255B        1B
//
//    SOP : 0x5A (Start of Packet)
//    CMD : Command byte (high nibble = group, low nibble = sub-command)
//    LEN : Number of data bytes following
//    DATA: Payload (0 ~ 255 bytes)
//    CHK : XOR checksum from CMD to last DATA byte
//
//  Downstream Commands (Host -> FPGA):
//    CMD  Name      LEN  DATA          Function
//    0x01 DBG_HALT   1   [0]=1 halt/0 resume   Control dbg_halt
//    0x02 DBG_STEP   0   -                      Generate dbg_step pulse
//    0x03 DBG_RST    0   -                      Reset CPU (reserved)
//    0x10 DBG_WR     N   data stream            Output to dbg_dt with dbg_dv
//    0x11 DBG_RD     1   [0]=N                  Request N bytes upstream (reserved)
//    0x20~0xFF       -   -                      Extended (reserved)
//
//  Upstream Responses (FPGA -> Host):
//    CMD  Name      LEN  DATA          Function
//    0x81 ACK_HALT   1   [0]=halt status        Halt acknowledge
//    0x82 ACK_STEP   0   -                      Step complete acknowledge
//    0x91 ACK_RD     N   upstream data           dbg_ut data response
//    0xFF ACK_ERR    1   [0]=error code          Error response
//
//  Wechat      : zxw895674551
//  Email       : alexmercer@outlook.com
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================
//  Instantiation Template
//================================================================================
/*
uart_debug #(
    .CLK_FREQ                   (50_000_000     ),
    .BAUD_RATE                  (115200         ))
u_uart_debug (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .uart_rx                    (uart_rx        ),
    .uart_tx                    (uart_tx        ),

    .dbg_step                   (dbg_step       ),
    .dbg_halt                   (dbg_halt       ),
    .dbg_dt                     (dbg_dt         ),
    .dbg_dv                     (dbg_dv         ),
    .dbg_ut                     (dbg_ut         ),
    .dbg_uv                     (dbg_uv         ));
*/

//================================================================================
//  Module Definition
//================================================================================
module uart_debug #(
    parameter CLK_FREQ                  = 50_000_000,
    parameter BAUD_RATE                 = 115200
)(
    input                               clk,
    input                               rst_n,

    input                               uart_rx,
    output                              uart_tx,

    output  reg                         dbg_step,
    output  reg                         dbg_halt,
    output  reg     [7:0]               dbg_dt,
    output  reg                         dbg_dv,

    input           [7:0]               dbg_ut,
    input                               dbg_uv
);

    //----------------------------------------------------------------------------
    // Protocol constants
    //----------------------------------------------------------------------------
    localparam SOP                      = 8'h5A;

    localparam CMD_DBG_HALT             = 8'h01;
    localparam CMD_DBG_STEP             = 8'h02;
    localparam CMD_DBG_RST              = 8'h03;
    localparam CMD_DBG_WR               = 8'h10;
    localparam CMD_DBG_RD               = 8'h11;

    localparam CMD_ACK_HALT             = 8'h81;
    localparam CMD_ACK_STEP             = 8'h82;
    localparam CMD_ACK_RD               = 8'h91;
    localparam CMD_ACK_ERR              = 8'hFF;

    localparam ERR_BAD_CHK              = 8'h01;
    localparam ERR_BAD_LEN              = 8'h02;
    localparam ERR_BAD_CMD              = 8'h03;

    //----------------------------------------------------------------------------
    // RX parser state machine
    //----------------------------------------------------------------------------
    localparam ST_RX_IDLE               = 3'd0;
    localparam ST_RX_CMD                = 3'd1;
    localparam ST_RX_LEN                = 3'd2;
    localparam ST_RX_DATA               = 3'd3;
    localparam ST_RX_CHK                = 3'd4;

    reg     [2:0]                       rx_state;
    reg     [7:0]                       rx_cmd;
    reg     [7:0]                       rx_len;
    reg     [7:0]                       rx_len_cnt;
    reg     [7:0]                       rx_chk;
    reg     [7:0]                       rx_data_buf;
    reg                                 rx_frame_valid;

    //----------------------------------------------------------------------------
    // TX response state machine
    //----------------------------------------------------------------------------
    localparam ST_TX_IDLE               = 3'd0;
    localparam ST_TX_SOP                = 3'd1;
    localparam ST_TX_CMD                = 3'd2;
    localparam ST_TX_LEN                = 3'd3;
    localparam ST_TX_DATA               = 3'd4;
    localparam ST_TX_CHK                = 3'd5;

    reg     [2:0]                       tx_state;
    reg     [7:0]                       tx_cmd;
    reg     [7:0]                       tx_len;
    reg     [7:0]                       tx_len_cnt;
    reg     [7:0]                       tx_chk;
    reg     [7:0]                       tx_data_buf;
    reg                                 tx_busy;

    //----------------------------------------------------------------------------
    // Response queue (single-entry, sufficient for debug)
    //----------------------------------------------------------------------------
    reg                                 resp_pending;
    reg     [7:0]                       resp_cmd;
    reg     [7:0]                       resp_len;
    reg     [7:0]                       resp_data_0;

    //----------------------------------------------------------------------------
    // Upstream data buffer
    //----------------------------------------------------------------------------
    reg                                 ut_pending;
    reg     [7:0]                       ut_data;

    //----------------------------------------------------------------------------
    // UART RX / TX instantiation
    //----------------------------------------------------------------------------
    wire    [7:0]                       rx_byte;
    wire                                rx_byte_valid;
    wire                                tx_ready;
    reg     [7:0]                       tx_byte;
    reg                                 tx_byte_valid;

    uart_rx #(
        .CLK_FREQ                      (CLK_FREQ       ),
        .BAUD_RATE                     (BAUD_RATE      ))
    u_uart_rx (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .uart_rx                        (uart_rx        ),
        .rx_data                        (rx_byte        ),
        .rx_valid                       (rx_byte_valid  ));

    uart_tx #(
        .CLK_FREQ                      (CLK_FREQ       ),
        .BAUD_RATE                     (BAUD_RATE      ))
    u_uart_tx (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .tx_data                        (tx_byte        ),
        .tx_valid                       (tx_byte_valid  ),
        .tx_ready                       (tx_ready       ),
        .uart_tx                        (uart_tx        ));

    //----------------------------------------------------------------------------
    // RX frame parser
    //----------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_state        <= ST_RX_IDLE;
            rx_cmd          <= 8'd0;
            rx_len          <= 8'd0;
            rx_len_cnt      <= 8'd0;
            rx_chk          <= 8'd0;
            rx_data_buf     <= 8'd0;
            rx_frame_valid  <= 1'b0;
        end else begin
            rx_frame_valid <= 1'b0;

            if (rx_byte_valid) begin
                case (rx_state)
                    ST_RX_IDLE: begin
                        if (rx_byte == SOP) begin
                            rx_state <= ST_RX_CMD;
                            rx_chk   <= 8'd0;
                        end
                    end

                    ST_RX_CMD: begin
                        rx_cmd   <= rx_byte;
                        rx_chk   <= rx_byte;
                        rx_state <= ST_RX_LEN;
                    end

                    ST_RX_LEN: begin
                        rx_len     <= rx_byte;
                        rx_len_cnt <= 8'd0;
                        rx_chk     <= rx_chk ^ rx_byte;
                        rx_state   <= (rx_byte == 8'd0) ? ST_RX_CHK : ST_RX_DATA;
                    end

                    ST_RX_DATA: begin
                        rx_data_buf <= rx_byte;
                        rx_chk      <= rx_chk ^ rx_byte;
                        rx_len_cnt  <= rx_len_cnt + 8'd1;
                        if (rx_len_cnt + 8'd1 == rx_len) begin
                            rx_state <= ST_RX_CHK;
                        end
                    end

                    ST_RX_CHK: begin
                        rx_state <= ST_RX_IDLE;
                        if (rx_chk == rx_byte) begin
                            rx_frame_valid <= 1'b1;
                        end
                    end

                    default: rx_state <= ST_RX_IDLE;
                endcase
            end
        end
    end

    //----------------------------------------------------------------------------
    // Frame dispatch: generate debug signals and response requests
    //----------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            dbg_step      <= 1'b0;
            dbg_halt      <= 1'b0;
            dbg_dt        <= 8'd0;
            dbg_dv        <= 1'b0;
            resp_pending  <= 1'b0;
            resp_cmd      <= 8'd0;
            resp_len      <= 8'd0;
            resp_data_0   <= 8'd0;
        end else begin
            dbg_step <= 1'b0;
            dbg_dv   <= 1'b0;

            if (rx_frame_valid) begin
                case (rx_cmd)
                    CMD_DBG_HALT: begin
                        dbg_halt    <= rx_data_buf[0];
                        resp_pending <= 1'b1;
                        resp_cmd    <= CMD_ACK_HALT;
                        resp_len    <= 8'd1;
                        resp_data_0 <= rx_data_buf[0];
                    end

                    CMD_DBG_STEP: begin
                        dbg_step    <= 1'b1;
                        resp_pending <= 1'b1;
                        resp_cmd    <= CMD_ACK_STEP;
                        resp_len    <= 8'd0;
                        resp_data_0 <= 8'd0;
                    end

                    CMD_DBG_RST: begin
                        resp_pending <= 1'b1;
                        resp_cmd    <= CMD_ACK_ERR;
                        resp_len    <= 8'd1;
                        resp_data_0 <= ERR_BAD_CMD;
                    end

                    CMD_DBG_WR: begin
                        dbg_dt <= rx_data_buf;
                        dbg_dv <= 1'b1;
                        resp_pending <= 1'b0;
                    end

                    CMD_DBG_RD: begin
                        resp_pending <= 1'b1;
                        resp_cmd    <= CMD_ACK_ERR;
                        resp_len    <= 8'd1;
                        resp_data_0 <= ERR_BAD_CMD;
                    end

                    default: begin
                        resp_pending <= 1'b1;
                        resp_cmd    <= CMD_ACK_ERR;
                        resp_len    <= 8'd1;
                        resp_data_0 <= ERR_BAD_CMD;
                    end
                endcase
            end
        end
    end

    //----------------------------------------------------------------------------
    // Upstream data capture (dbg_ut / dbg_uv -> TX response)
    //----------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            ut_pending <= 1'b0;
            ut_data    <= 8'd0;
        end else if (dbg_uv && !ut_pending) begin
            ut_pending <= 1'b1;
            ut_data    <= dbg_ut;
        end else if (ut_pending && tx_state == ST_TX_IDLE && !resp_pending) begin
            ut_pending <= 1'b0;
        end
    end

    //----------------------------------------------------------------------------
    // TX frame builder state machine
    //----------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            tx_state       <= ST_TX_IDLE;
            tx_busy        <= 1'b0;
            tx_byte        <= 8'd0;
            tx_byte_valid  <= 1'b0;
            tx_cmd         <= 8'd0;
            tx_len         <= 8'd0;
            tx_len_cnt     <= 8'd0;
            tx_chk         <= 8'd0;
            tx_data_buf    <= 8'd0;
            resp_pending   <= 1'b0;
        end else begin
            tx_byte_valid <= 1'b0;

            case (tx_state)
                ST_TX_IDLE: begin
                    if (resp_pending) begin
                        tx_cmd      <= resp_cmd;
                        tx_len      <= resp_len;
                        tx_data_buf <= resp_data_0;
                        resp_pending <= 1'b0;
                        tx_state    <= ST_TX_SOP;
                        tx_len_cnt  <= 8'd0;
                        tx_chk      <= 8'd0;
                    end else if (ut_pending) begin
                        tx_cmd      <= CMD_ACK_RD;
                        tx_len      <= 8'd1;
                        tx_data_buf <= ut_data;
                        ut_pending  <= 1'b0;
                        tx_state    <= ST_TX_SOP;
                        tx_len_cnt  <= 8'd0;
                        tx_chk      <= 8'd0;
                    end
                end

                ST_TX_SOP: begin
                    if (tx_ready) begin
                        tx_byte       <= SOP;
                        tx_byte_valid <= 1'b1;
                        tx_state      <= ST_TX_CMD;
                    end
                end

                ST_TX_CMD: begin
                    if (tx_ready) begin
                        tx_byte       <= tx_cmd;
                        tx_byte_valid <= 1'b1;
                        tx_chk        <= tx_cmd;
                        tx_state      <= ST_TX_LEN;
                    end
                end

                ST_TX_LEN: begin
                    if (tx_ready) begin
                        tx_byte       <= tx_len;
                        tx_byte_valid <= 1'b1;
                        tx_chk        <= tx_chk ^ tx_len;
                        tx_state      <= (tx_len == 8'd0) ? ST_TX_CHK : ST_TX_DATA;
                    end
                end

                ST_TX_DATA: begin
                    if (tx_ready) begin
                        tx_byte       <= tx_data_buf;
                        tx_byte_valid <= 1'b1;
                        tx_chk        <= tx_chk ^ tx_data_buf;
                        tx_len_cnt    <= tx_len_cnt + 8'd1;
                        if (tx_len_cnt + 8'd1 == tx_len) begin
                            tx_state <= ST_TX_CHK;
                        end
                    end
                end

                ST_TX_CHK: begin
                    if (tx_ready) begin
                        tx_byte       <= tx_chk;
                        tx_byte_valid <= 1'b1;
                        tx_state      <= ST_TX_IDLE;
                    end
                end

                default: tx_state <= ST_TX_IDLE;
            endcase
        end
    end

endmodule
