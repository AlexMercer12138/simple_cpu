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
//  Module      : apb_can
//  Description : APB CAN Classic controller
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//  v1.1 - Add ECR register, arb_lost/busoff interrupts, TEC/REC from can_top
//================================================================================

//================================================================================
//  Instantiation Template
//================================================================================
/*
apb_can #(
    .FIFO_DEPTH                 (4              ))
u_apb_can (
    .s_apb_pclk                 (s_apb_pclk     ),
    .s_apb_presetn              (s_apb_presetn  ),

    .s_apb_psel                 (s_apb_psel     ),
    .s_apb_penable              (s_apb_penable  ),
    .s_apb_pwrite               (s_apb_pwrite   ),
    .s_apb_paddr                (s_apb_paddr    ),
    .s_apb_pwdata               (s_apb_pwdata   ),

    .s_apb_pready               (s_apb_pready   ),
    .s_apb_pslverr              (s_apb_pslverr  ),
    .s_apb_prdata               (s_apb_prdata   ),
    .interrupt                  (interrupt      ),

    .can_rx                     (can_rx         ),
    .can_tx                     (can_tx         ));
*/

//================================================================================
//  Module Definition
//================================================================================

module apb_can #(
    parameter FIFO_DEPTH = 4
)(
    input   wire                        s_apb_pclk,
    input   wire                        s_apb_presetn,

    input   wire                        s_apb_psel,
    input   wire                        s_apb_penable,
    input   wire                        s_apb_pwrite,
    input   wire [31:0]                 s_apb_paddr,
    input   wire [31:0]                 s_apb_pwdata,

    output  wire                        s_apb_pready,
    output  wire                        s_apb_pslverr,
    output  wire [31:0]                 s_apb_prdata,

    output  reg                         interrupt,

    input   wire                        can_rx,
    output  wire                        can_tx
);

    localparam ADDR_CTRL       = 12'd0;
    localparam ADDR_BITTIMING  = 12'd1;
    localparam ADDR_TX_ID      = 12'd2;
    localparam ADDR_TX_CTRL    = 12'd3;
    localparam ADDR_TX_DATA0   = 12'd4;
    localparam ADDR_TX_DATA1   = 12'd5;
    localparam ADDR_RX_ID      = 12'd6;
    localparam ADDR_RX_CTRL    = 12'd7;
    localparam ADDR_RX_DATA0   = 12'd8;
    localparam ADDR_RX_DATA1   = 12'd9;
    localparam ADDR_STATUS     = 12'd10;
    localparam ADDR_INTERRUPT  = 12'd11;
    localparam ADDR_ERROR      = 12'd12;
    localparam ADDR_ECR        = 12'd13;

    reg                                 apb_pready;
    reg                                 apb_pslverr;
    reg     [31:0]                      apb_prdata;

    wire    [11:0]                      opt_addr;
    wire                                slv_reg_rden;
    wire                                slv_reg_wren;

    reg     [31:0]                      can_ctrl;
    reg     [31:0]                      can_bittiming;
    reg     [31:0]                      can_tx_id;
    reg     [31:0]                      can_tx_ctrl;
    reg     [31:0]                      can_tx_data0;
    reg     [31:0]                      can_tx_data1;
    reg     [31:0]                      can_interrupt;
    reg     [31:0]                      can_error;
    reg                                 tx_start_pulse;
    reg                                 rx_release_pulse;

    wire                                core_rst_n;
    wire                                core_enable;
    wire                                loopback_mode;
    wire                                listen_only;
    wire                                soft_rst;
    wire    [9:0]                       brp;
    wire    [1:0]                       sjw;
    wire    [3:0]                       tseg1;
    wire    [3:0]                       tseg2;
    wire                                tx_ready;
    wire                                tx_busy;
    wire                                tx_done;
    wire                                tx_ready_safe;
    wire                                tx_start_accept;
    wire                                rx_valid;
    wire    [28:0]                      rx_id;
    wire                                rx_ide;
    wire                                rx_rtr;
    wire    [3:0]                       rx_dlc;
    wire    [63:0]                      rx_data;
    wire    [2:0]                       rx_count;
    wire                                error_pulse;
    wire                                crc_error;
    wire                                stuff_error;
    wire                                form_error;
    wire                                ack_error;
    wire                                bit_error;
    wire                                arbitration_lost;
    wire                                retry_pending;
    wire                                bus_idle;
    wire    [7:0]                       tec;
    wire    [7:0]                       rec;
    wire                                error_active;
    wire                                error_passive;
    wire                                bus_off;
    wire                                rx_event;
    wire                                tx_done_event;
    wire                                error_event;
    wire                                arb_lost_event;
    wire                                busoff_event;

    assign opt_addr      = s_apb_paddr[11:2];
    assign slv_reg_wren  = s_apb_psel & s_apb_penable & s_apb_pwrite & s_apb_pready;
    assign slv_reg_rden  = s_apb_psel & ~s_apb_penable & ~s_apb_pwrite;

    assign s_apb_pready  = apb_pready;
    assign s_apb_pslverr = apb_pslverr;
    assign s_apb_prdata  = apb_prdata;

    assign soft_rst      = can_ctrl[31];
    assign core_rst_n    = s_apb_presetn & ~soft_rst;
    assign core_enable   = can_ctrl[0];
    assign listen_only   = can_ctrl[1];
    assign loopback_mode = can_ctrl[2];
    assign brp           = can_bittiming[9:0];
    assign sjw           = can_bittiming[17:16];
    assign tseg1         = can_bittiming[23:20];
    assign tseg2         = can_bittiming[27:24];
    assign rx_event      = rx_valid & ~can_interrupt[16];
    assign tx_done_event = tx_done;
    assign error_event   = error_pulse;
    assign arb_lost_event = arbitration_lost & ~can_interrupt[19];

    //--------------------------------------------------------------------------------
    //  Bus-off rising edge detection
    //--------------------------------------------------------------------------------
    reg                                 bus_off_ff;

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn)
            bus_off_ff <= 1'b0;
        else
            bus_off_ff <= bus_off;
    end

    wire bus_off_rise = bus_off & ~bus_off_ff;

    assign busoff_event  = bus_off_rise;
    assign tx_ready_safe = tx_ready & core_enable;
    assign tx_start_accept = slv_reg_wren & (opt_addr == ADDR_CTRL) & s_apb_pwdata[3] & ~bus_off &
                             (tx_ready_safe | (s_apb_pwdata[0] & ~tx_busy));

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn) begin
            apb_pready <= 1'b0;
        end else if (s_apb_psel & apb_pready) begin
            apb_pready <= 1'b0;
        end else if (s_apb_psel) begin
            apb_pready <= 1'b1;
        end
    end

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn) begin
            apb_pslverr <= 1'b0;
        end else begin
            apb_pslverr <= 1'b0;
        end
    end

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn) begin
            tx_start_pulse   <= 1'b0;
            rx_release_pulse <= 1'b0;
        end else begin
            tx_start_pulse   <= tx_start_accept;
            rx_release_pulse <= slv_reg_wren & (opt_addr == ADDR_CTRL) & s_apb_pwdata[4] & rx_valid;
        end
    end

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn) begin
            can_ctrl       <= 32'd0;
            can_bittiming  <= 32'h0111_0001;
            can_tx_id      <= 32'd0;
            can_tx_ctrl    <= 32'd0;
            can_tx_data0   <= 32'd0;
            can_tx_data1   <= 32'd0;
            can_interrupt  <= 32'd0;
            can_error      <= 32'd0;
            interrupt      <= 1'b0;
        end else begin
            if (slv_reg_wren) begin
                case (opt_addr)
                    ADDR_CTRL: begin
                        can_ctrl[2:0] <= s_apb_pwdata[2:0];
                        can_ctrl[31]  <= s_apb_pwdata[31];
                    end
                    ADDR_BITTIMING: can_bittiming <= s_apb_pwdata;
                    ADDR_TX_ID:     can_tx_id     <= s_apb_pwdata & 32'h1fff_ffff;
                    ADDR_TX_CTRL:   can_tx_ctrl   <= s_apb_pwdata & 32'h0000_003f;
                    ADDR_TX_DATA0:  can_tx_data0  <= s_apb_pwdata;
                    ADDR_TX_DATA1:  can_tx_data1  <= s_apb_pwdata;
                    ADDR_INTERRUPT: begin
                        can_interrupt[4:0] <= s_apb_pwdata[4:0];
                        can_interrupt[16]  <= s_apb_pwdata[16] ? 1'b0 : can_interrupt[16];
                        can_interrupt[17]  <= s_apb_pwdata[17] ? 1'b0 : can_interrupt[17];
                        can_interrupt[18]  <= s_apb_pwdata[18] ? 1'b0 : can_interrupt[18];
                        can_interrupt[19]  <= s_apb_pwdata[19] ? 1'b0 : can_interrupt[19];
                        can_interrupt[20]  <= s_apb_pwdata[20] ? 1'b0 : can_interrupt[20];
                    end
                    ADDR_ERROR: begin
                        can_error[5:0] <= can_error[5:0] & ~s_apb_pwdata[5:0];
                    end
                endcase
            end else begin
                can_ctrl[31] <= 1'b0;
            end

            //--- Interrupt pending set ---
            if (rx_event) begin
                can_interrupt[16] <= 1'b1;
            end
            if (tx_done_event) begin
                can_interrupt[17] <= 1'b1;
            end
            if (error_event) begin
                can_interrupt[18] <= 1'b1;
            end
            if (arb_lost_event) begin
                can_interrupt[19] <= 1'b1;
            end
            if (busoff_event) begin
                can_interrupt[20] <= 1'b1;
            end

            //--- Error sticky flags ---
            if (crc_error) begin
                can_error[0] <= 1'b1;
            end
            if (stuff_error) begin
                can_error[1] <= 1'b1;
            end
            if (form_error) begin
                can_error[2] <= 1'b1;
            end
            if (ack_error) begin
                can_error[3] <= 1'b1;
            end
            if (bit_error) begin
                can_error[4] <= 1'b1;
            end
            if (arbitration_lost) begin
                can_error[5] <= 1'b1;
            end

            //--- Interrupt output ---
            interrupt <= (can_interrupt[0] & can_interrupt[16]) |
                         (can_interrupt[1] & can_interrupt[17]) |
                         (can_interrupt[2] & can_interrupt[18]) |
                         (can_interrupt[3] & can_interrupt[19]) |
                         (can_interrupt[4] & can_interrupt[20]);
        end
    end

    always @(posedge s_apb_pclk) begin
        if (!s_apb_presetn) begin
            apb_prdata <= 32'd0;
        end else if (slv_reg_rden) begin
            case (opt_addr)
                ADDR_CTRL:      apb_prdata <= can_ctrl;
                ADDR_BITTIMING: apb_prdata <= can_bittiming;
                ADDR_TX_ID:     apb_prdata <= can_tx_id;
                ADDR_TX_CTRL:   apb_prdata <= can_tx_ctrl;
                ADDR_TX_DATA0:  apb_prdata <= can_tx_data0;
                ADDR_TX_DATA1:  apb_prdata <= can_tx_data1;
                ADDR_RX_ID:     apb_prdata <= {3'd0, rx_id};
                ADDR_RX_CTRL:   apb_prdata <= {24'd0, rx_valid, rx_ide, rx_rtr, 1'b0, rx_dlc};
                ADDR_RX_DATA0:  apb_prdata <= rx_data[63:32];
                ADDR_RX_DATA1:  apb_prdata <= rx_data[31:0];
                ADDR_STATUS:    apb_prdata <= {14'd0, bus_off, error_passive, error_active, 1'd0, bus_idle, 2'd0, rx_count, 3'd0, rx_valid, 1'b0, tx_done, tx_busy, tx_ready_safe};
                ADDR_INTERRUPT: apb_prdata <= can_interrupt;
                ADDR_ERROR:     apb_prdata <= {bus_off, error_passive, error_active, 5'd0, tec, rec, 2'd0, can_error[5:0]};
                ADDR_ECR:       apb_prdata <= {8'd0, tec, 8'd0, rec};
                default:        apb_prdata <= 32'd0;
            endcase
        end
    end

    can_top #(
        .FIFO_DEPTH     (FIFO_DEPTH     ))
    u_can_top (
        .clk            (s_apb_pclk     ),
        .rst_n          (core_rst_n     ),
        .enable         (core_enable    ),
        .loopback_mode  (loopback_mode  ),
        .listen_only    (listen_only    ),
        .brp            (brp            ),
        .sjw            (sjw            ),
        .tseg1          (tseg1          ),
        .tseg2          (tseg2          ),
        .tx_start       (tx_start_pulse ),
        .tx_id          (can_tx_id[28:0]),
        .tx_ide         (can_tx_ctrl[4] ),
        .tx_rtr         (can_tx_ctrl[5] ),
        .tx_dlc         (can_tx_ctrl[3:0]),
        .tx_data        ({can_tx_data0, can_tx_data1}),
        .tx_ready       (tx_ready       ),
        .tx_busy        (tx_busy        ),
        .tx_done        (tx_done        ),
        .rx_release     (rx_release_pulse),
        .rx_valid       (rx_valid       ),
        .rx_id          (rx_id          ),
        .rx_ide         (rx_ide         ),
        .rx_rtr         (rx_rtr         ),
        .rx_dlc         (rx_dlc         ),
        .rx_data        (rx_data        ),
        .rx_count       (rx_count       ),
        .error_pulse    (error_pulse    ),
        .crc_error      (crc_error      ),
        .stuff_error    (stuff_error    ),
        .form_error     (form_error     ),
        .ack_error      (ack_error      ),
        .bit_error      (bit_error      ),
        .arbitration_lost(arbitration_lost),
        .retry_pending  (retry_pending  ),
        .tec            (tec            ),
        .rec            (rec            ),
        .error_active   (error_active   ),
        .error_passive  (error_passive  ),
        .bus_off        (bus_off        ),
        .bus_idle       (bus_idle       ),
        .can_rx         (can_rx         ),
        .can_tx         (can_tx         ));

endmodule
