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
//  Module      : uart_tx
//  Description : UART transmitter with 8-N-1 format
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
uart_tx #(
    .CLK_FREQ                   (50_000_000     ),
    .BAUD_RATE                  (115200         ))
u_uart_tx (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .tx_data                    (tx_data        ),
    .tx_valid                   (tx_valid       ),
    .tx_ready                   (tx_ready       ),
    .uart_tx                    (uart_tx        ));
*/

//================================================================================
//  Module Definition
//================================================================================
module uart_tx #(
    parameter CLK_FREQ                  = 50_000_000,
    parameter BAUD_RATE                 = 115200
)(
    input                               clk,
    input                               rst_n,

    input       [7:0]                   tx_data,
    input                               tx_valid,
    output                              tx_ready,

    output  reg                         uart_tx
);

    localparam BAUD_CNT                 = CLK_FREQ / BAUD_RATE;
    localparam CNT_WIDTH                = 16;

    reg     [CNT_WIDTH-1:0]             baud_cnt;
    reg     [3:0]                       bit_cnt;
    reg     [7:0]                       shift_reg;
    reg                                 tx_busy;

    assign tx_ready = ~tx_busy;

    always @(posedge clk) begin
        if (!rst_n) begin
            uart_tx   <= 1'b1;
            tx_busy   <= 1'b0;
            baud_cnt  <= {CNT_WIDTH{1'b0}};
            bit_cnt   <= 4'd0;
            shift_reg <= 8'd0;
        end else begin
            if (!tx_busy) begin
                if (tx_valid) begin
                    tx_busy   <= 1'b1;
                    shift_reg <= tx_data;
                    bit_cnt   <= 4'd0;
                    baud_cnt  <= BAUD_CNT - 1;
                    uart_tx   <= 1'b0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= BAUD_CNT - 1;

                    if (bit_cnt == 4'd8) begin
                        uart_tx <= 1'b1;
                        bit_cnt <= bit_cnt + 4'd1;
                    end else if (bit_cnt == 4'd9) begin
                        tx_busy <= 1'b0;
                        bit_cnt <= 4'd0;
                    end else begin
                        uart_tx   <= shift_reg[0];
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        bit_cnt   <= bit_cnt + 4'd1;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1;
                end
            end
        end
    end

endmodule
