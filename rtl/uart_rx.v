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
//  Module      : uart_rx
//  Description : UART receiver with 8-N-1 format and mid-bit sampling
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
uart_rx #(
    .CLK_FREQ                   (50_000_000     ),
    .BAUD_RATE                  (115200         ))
u_uart_rx (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .uart_rx                    (uart_rx        ),
    .rx_data                    (rx_data        ),
    .rx_valid                   (rx_valid       ));
*/

//================================================================================
//  Module Definition
//================================================================================
module uart_rx #(
    parameter CLK_FREQ                  = 50_000_000,
    parameter BAUD_RATE                 = 115200
)(
    input                               clk,
    input                               rst_n,

    input                               uart_rx,
    output  reg     [7:0]               rx_data,
    output  reg                         rx_valid
);

    localparam BAUD_CNT                 = CLK_FREQ / BAUD_RATE;
    localparam BAUD_HALF                = BAUD_CNT / 2;
    localparam CNT_WIDTH                = 16;

    reg     [CNT_WIDTH-1:0]             baud_cnt;
    reg     [2:0]                       bit_cnt;
    reg     [7:0]                       shift_reg;
    reg                                 rx_sync_d0;
    reg                                 rx_sync_d1;
    reg                                 rx_busy;

    wire                                rx_fall;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync_d0 <= 1'b1;
            rx_sync_d1 <= 1'b1;
        end else begin
            rx_sync_d0 <= uart_rx;
            rx_sync_d1 <= rx_sync_d0;
        end
    end

    assign rx_fall = ~rx_sync_d0 & rx_sync_d1;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_busy   <= 1'b0;
            baud_cnt  <= {CNT_WIDTH{1'b0}};
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            if (!rx_busy) begin
                if (rx_fall) begin
                    rx_busy  <= 1'b1;
                    baud_cnt <= BAUD_HALF - 1;
                    bit_cnt  <= 3'd0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= BAUD_CNT - 1;

                    if (bit_cnt == 3'd0) begin
                        if (rx_sync_d1) begin
                            rx_busy <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else if (bit_cnt == 3'd8) begin
                        if (rx_sync_d1) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        rx_busy  <= 1'b0;
                        bit_cnt  <= 3'd0;
                    end else begin
                        shift_reg <= {rx_sync_d1, shift_reg[7:1]};
                        bit_cnt   <= bit_cnt + 3'd1;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1;
                end
            end
        end
    end

endmodule
