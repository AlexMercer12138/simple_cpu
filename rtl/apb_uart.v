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
//  Module      : apb_uart
//  Description : APB uart controller
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
apb_uart #(
    .SYS_CLK_FREQ               (50_000_000     ),
    .BAUD_RATE                  (115200         ),
    .STOP_BIT_CNT               (1              ),
    .PARITY_TYPE                ("none"         ))
u_apb_uart (
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

    .uart_rx                    (uart_rx        ),
    .uart_tx                    (uart_tx        ));
*/

//================================================================================
//  Module Definition
//================================================================================

module apb_uart #(
    parameter SYS_CLK_FREQ              = 50_000_000,
    parameter FIFO_DEPTH                = 8
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

    input   wire                        uart_rx,
    output  wire                        uart_tx
);

    reg                                 apb_pready;
    reg                                 apb_pslverr;
    reg     [31:0]                      apb_prdata;

    wire    [29:0]                      opt_addr;
    wire                                slv_reg_rden;
    wire                                slv_reg_wren;

    assign opt_addr     = s_apb_paddr[31:2];
    assign slv_reg_wren = s_apb_psel & s_apb_penable & s_apb_pwrite & s_apb_pready;
    assign slv_reg_rden = s_apb_psel & ~s_apb_penable & ~s_apb_pwrite;

    assign s_apb_pready  = apb_pready;
    assign s_apb_pslverr = apb_pslverr;
    assign s_apb_prdata  = apb_prdata;

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

    reg     [31:0]          uart_ctrl;
    reg     [31:0]          uart_config;
    reg     [31:0]          uart_rx_buf;
    reg     [31:0]          uart_rx_status;
    reg     [31:0]          uart_tx_buf;
    reg     [31:0]          uart_tx_status;

    wire                    soft_rst;
    reg                     rx_en;
    reg     [1:0]           rx_cnt;
    wire    [1:0]           rx_ptr;
    wire                    rx_valid;
    wire                    rx_ready;
    wire    [7:0]           rx_data;
    wire    [3:0]           rx_data_cnt;
    reg                     tx_en;
    reg     [1:0]           tx_cnt;
    wire    [1:0]           tx_ptr;
    wire                    tx_valid;
    wire                    tx_ready;
    wire    [7:0]           tx_data;
    wire    [3:0]           tx_data_cnt;

    assign  soft_rst = uart_ctrl[31];
    assign  rx_ptr = uart_rx_status[1:0];
    assign  tx_ptr = uart_tx_status[1:0];
    assign  rx_ready = rx_en & ~slv_reg_rden;
    assign  tx_valid = tx_en & ~slv_reg_wren;
    assign  tx_data  =
        tx_ptr == 2'd0 ? uart_tx_buf[31:24] :
        tx_ptr == 2'd1 ? uart_tx_buf[23:16] :
        tx_ptr == 2'd2 ? uart_tx_buf[15:08] :
        tx_ptr == 2'd3 ? uart_tx_buf[07:00] : 8'hee;

always @(posedge s_apb_pclk) begin
    if(!s_apb_presetn) begin
        rx_en <= 0;
        rx_cnt <= 0;
        tx_en <= 0;
        tx_cnt <= 0;
    end else begin
        rx_en <= uart_ctrl[0] ? 1 : rx_valid & rx_ready & rx_cnt == uart_ctrl[2:1] ? 0 : rx_en;
        rx_cnt <= rx_valid & rx_ready ? (rx_cnt == uart_ctrl[2:1] ? 0 : rx_cnt + 1) : rx_cnt;
        tx_en <= uart_ctrl[4] ? 1 : tx_valid & tx_ready & tx_cnt == uart_ctrl[6:5] ? 0 : tx_en;
        tx_cnt <= tx_valid & tx_ready ? (tx_cnt == uart_ctrl[6:5] ? 0 : tx_cnt + 1) : tx_cnt;
    end
end

always @(posedge s_apb_pclk) begin
    if(!s_apb_presetn) begin
        uart_ctrl <= 0;
        uart_tx_buf <= 0;
        uart_tx_status <= 0;
    end else if(slv_reg_wren) begin
        case(opt_addr)
            0:uart_ctrl <= s_apb_pwdata;
            1:uart_config <= s_apb_pwdata;
            4:begin
                uart_tx_buf <= s_apb_pwdata;
                uart_tx_status <= uart_tx_status & 32'hfffffffc;
            end
        endcase
    end else begin
        uart_ctrl <= uart_ctrl & 32'h7fffffee;
        uart_tx_status[8] <= tx_valid;
        uart_tx_status[7:6] <= tx_cnt;
        uart_tx_status[5:2] <= tx_data_cnt;
        uart_tx_status[1:0] <= tx_valid & tx_ready ? uart_tx_status[1:0] + 1 : uart_tx_status[1:0];
    end
end

always @(posedge s_apb_pclk) begin
    if (!s_apb_presetn) begin
        apb_prdata <= 0;
        uart_rx_status <= 0;
    end else if (slv_reg_rden) begin
        case(opt_addr)
            0:apb_prdata <= uart_ctrl;
            1:apb_prdata <= uart_config;
            2:begin
                apb_prdata <= uart_rx_buf;
                uart_rx_status <= uart_rx_status & 32'hfffffffc;
            end
            3:apb_prdata <= uart_rx_status;
            5:apb_prdata <= uart_tx_status;
        endcase
    end else begin
        uart_rx_status[8] <= rx_ready;
        uart_rx_status[7:6] <= rx_cnt;
        uart_rx_status[5:2] <= rx_data_cnt;
        uart_rx_status[1:0] <= rx_valid & rx_ready ? uart_rx_status[1:0] + 1 : uart_rx_status[1:0];
    end
end

always @(posedge s_apb_pclk) begin
    if (!s_apb_presetn) begin
        uart_rx_buf <= 0;
    end else if(rx_valid & rx_ready) begin
        case(rx_ptr)
            2'd0:uart_rx_buf[31:24] <= rx_data;
            2'd1:uart_rx_buf[23:16] <= rx_data;
            2'd2:uart_rx_buf[15:08] <= rx_data;
            2'd3:uart_rx_buf[07:00] <= rx_data;
        endcase
    end else if(slv_reg_rden && opt_addr == 1) begin
        uart_rx_buf <= 32'h0;
    end
end

    uart_top #(
        .SYS_CLK_FREQ               (SYS_CLK_FREQ       ),
        .FIFO_DEPTH                 (FIFO_DEPTH         ))
    u_uart_top (
        .clk                        (s_apb_pclk         ),
        .rst_n                      (s_apb_presetn & ~soft_rst),

        .baud_rate                  (uart_config[23:0]  ),
        .stop_bit                   (uart_config[31]    ),
        .parity_type                (uart_config[30:29] ),

        .s_axis_tx_tvalid           (tx_valid           ),
        .s_axis_tx_tready           (tx_ready           ),
        .s_axis_tx_tdata            (tx_data            ),
        .tx_data_cnt                (tx_data_cnt        ),
        .m_axis_rx_tvalid           (rx_valid           ),
        .m_axis_rx_tready           (rx_ready           ),
        .m_axis_rx_tdata            (rx_data            ),
        .rx_data_cnt                (rx_data_cnt        ),

        .uart_rx                    (uart_rx            ),
        .uart_tx                    (uart_tx            ));

endmodule