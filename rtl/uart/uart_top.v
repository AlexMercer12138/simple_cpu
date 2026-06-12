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
//  Module      : uart_top
//  Description : UART top module with TX/RX and FIFO
//  Wechat      : zxw895674551
//  Email       : alexmercer@outlook.com
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
uart_top #(
    .SYS_CLK_FREQ               (50_000_000         ),
    .FIFO_DEPTH                 (8                  ))
u_uart_top (
    .clk                        (clk                ),
    .rst_n                      (rst_n              ),

    .s_axis_tvalid              (s_axis_tx_tvalid   ),
    .s_axis_tready              (s_axis_tx_tready   ),
    .s_axis_tdata               (s_axis_tx_tdata    ),
    .tx_data_cnt                (tx_data_cnt        ),
    .m_axis_tvalid              (m_axis_rx_tvalid   ),
    .m_axis_tready              (m_axis_rx_tready   ),
    .m_axis_tdata               (m_axis_rx_tdata    ),
    .rx_data_cnt                (rx_data_cnt        ),

    .uart_rx                    (uart_rx            ),
    .uart_tx                    (uart_tx            ));
*/

//================================================================================
//  Module Definition
//================================================================================

module uart_top #(
    parameter SYS_CLK_FREQ      = 50_000_000,
    parameter FIFO_DEPTH        = 8
) (
    input   wire                clk,
    input   wire                rst_n,

    input   wire [23:0]         baud_rate,
    input   wire                stop_bit,
    input   wire [1:0]          parity_type,

    // rx data
    output  wire                m_axis_rx_tvalid,
    input   wire                m_axis_rx_tready,
    output  wire [7:0]          m_axis_rx_tdata,
    output  reg [3:0]           rx_data_cnt,
    // tx data
    input   wire                s_axis_tx_tvalid,
    output  wire                s_axis_tx_tready,
    input   wire [7:0]          s_axis_tx_tdata,
    output  reg [3:0]           tx_data_cnt,

    input   wire                uart_rx,
    output  reg                 uart_tx
);

    localparam ADDR_WIDTH       = $clog2(FIFO_DEPTH);

    reg                         rx_valid;
    wire                        rx_ready;
    reg     [7:0]               rx_data;
    wire                        tx_valid;
    reg                         tx_ready;
    wire    [7:0]               tx_data;

    reg     [31:0]              i;
    reg     [31:0]              div_dividend;
    reg     [31:0]              div_divisor;
    reg     [31:0]              div_quotient;
    reg     [5:0]               div_cnt;
    reg                         div_busy;
    reg     [32:0]              div_remainder;
    reg                         parity_en;
    reg     [1:0]               stop_bit_cnt;
    reg     [31:0]              baud_cnt;

always @(posedge clk) begin
    if(!rst_n) begin
        baud_cnt <= 0;
        parity_en <= 0;
        stop_bit_cnt <= 0;
    end else begin
        baud_cnt <= ~div_busy ? div_quotient : baud_cnt;
        parity_en <= |parity_type;
        stop_bit_cnt <= stop_bit ? 2 : 1;
    end
end

always @(posedge clk) begin
    if(!rst_n) begin
        div_busy <= 0;
        div_cnt <= 0;
        div_dividend <= 0;
        div_divisor <= 0;
        div_remainder <= 0;
        div_quotient <= 0;
    end else begin
        div_busy <= 
            div_divisor != baud_rate ? 1 : 
            div_cnt == 31 ? 0 : 
            div_busy;
        div_cnt <= 
            div_divisor != baud_rate ? 0 : 
            div_busy ? (div_cnt == 31 ? 0 : div_cnt + 1) : 
            div_cnt;
        div_dividend <= 
            div_divisor != baud_rate ? SYS_CLK_FREQ : 
            div_busy ? {div_dividend[30:0], 1'b0} : 
            SYS_CLK_FREQ;
        div_divisor <= baud_rate;
        div_remainder <= 
            div_divisor != baud_rate ? 0 : 
            div_busy ? 
                ({div_remainder[31:0], div_dividend[31]} >= div_divisor ? 
                    {div_remainder[31:0], div_dividend[31]} - div_divisor : 
                    {div_remainder[31:0], div_dividend[31]}) : 
            div_remainder;
        div_quotient <= 
            div_divisor != baud_rate ? 0 : 
            div_busy ? 
                ({div_remainder[31:0], div_dividend[31]} >= div_divisor ? 
                    {div_quotient[30:0], 1'b1} : 
                    {div_quotient[30:0], 1'b0}) : 
            div_quotient;
    end
end

//================================================================================
//  Receiver buffer
//================================================================================

    reg     [ADDR_WIDTH-1:0]    rx_wr_ptr;
    reg     [ADDR_WIDTH-1:0]    rx_rd_ptr;
    reg     [7:0]               rx_buffer [0:FIFO_DEPTH-1];

    assign m_axis_rx_tdata = rx_buffer[rx_rd_ptr];
    assign m_axis_rx_tvalid = |rx_data_cnt;
    assign rx_ready = ~rx_data_cnt[ADDR_WIDTH];

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_wr_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (rx_valid & rx_ready) begin
            rx_wr_ptr <= rx_wr_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_rd_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (m_axis_rx_tvalid & m_axis_rx_tready) begin
            rx_rd_ptr <= rx_rd_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            for (i = 0;i < FIFO_DEPTH;i = i + 1) begin
                rx_buffer[i] <= 0;
            end
        end else if(rx_valid & rx_ready) begin
            rx_buffer[rx_wr_ptr] <= rx_data;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_data_cnt <= {ADDR_WIDTH+1{1'b0}};
        end else begin
            case({rx_valid,rx_ready,m_axis_rx_tvalid,m_axis_rx_tready})
                4'b1100,4'b1110,4'b1101:rx_data_cnt <= rx_data_cnt + 1'b1;
                4'b0011,4'b0111,4'b1011:rx_data_cnt <= rx_data_cnt - 1'b1;
                default:rx_data_cnt <= rx_data_cnt;
            endcase
        end 
    end

//================================================================================
//  Transmitter buffer
//================================================================================

    reg     [ADDR_WIDTH-1:0]    tx_wr_ptr;
    reg     [ADDR_WIDTH-1:0]    tx_rd_ptr;
    reg     [7:0]               tx_buffer [0:FIFO_DEPTH-1];

    assign tx_data = tx_buffer[tx_rd_ptr];
    assign tx_valid = |tx_data_cnt;
    assign s_axis_tx_tready = ~tx_data_cnt[ADDR_WIDTH];

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_wr_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (s_axis_tx_tvalid & s_axis_tx_tready) begin
            tx_wr_ptr <= tx_wr_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_rd_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (tx_valid & tx_ready) begin
            tx_rd_ptr <= tx_rd_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            for (i = 0;i < FIFO_DEPTH;i = i + 1) begin
                tx_buffer[i] <= 0;
            end
        end else if(s_axis_tx_tvalid & s_axis_tx_tready) begin
            tx_buffer[tx_wr_ptr] <= s_axis_tx_tdata;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_data_cnt <= {ADDR_WIDTH+1{1'b0}};
        end else begin
            case({s_axis_tx_tvalid,s_axis_tx_tready,tx_valid,tx_ready})
                4'b1100,4'b1110,4'b1101:tx_data_cnt <= tx_data_cnt + 1'b1;
                4'b0011,4'b0111,4'b1011:tx_data_cnt <= tx_data_cnt - 1'b1;
                default:tx_data_cnt <= tx_data_cnt;
            endcase
        end 
    end

//================================================================================
//  Uart receiver
//================================================================================

    reg                         rx_ff0;
    reg                         rx_ff1;
    reg                         rx_ff2;
    reg                         rx_parity;
    reg                         rx_busy;
    reg     [9:0]               rx_baud_cnt;
    reg     [3:0]               rx_bit_cnt;
    reg                         rx_pass;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_ff0 <= 1'b1;
            rx_ff1 <= 1'b1;
            rx_ff2 <= 1'b1;
        end else begin
            rx_ff0 <= uart_rx;
            rx_ff1 <= rx_ff0;
            rx_ff2 <= rx_ff1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_busy <= 1'b0;
        end else begin
            rx_busy <= 
                rx_ff2 & ~rx_ff1 ? 1'b1 : 
                (rx_bit_cnt == 8 + parity_en) && (rx_baud_cnt == baud_cnt - 1) ? 1'b0 : 
                rx_busy;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_baud_cnt <= 10'd0;
        end else if (rx_busy) begin
            rx_baud_cnt <= 
                (rx_baud_cnt == baud_cnt - 1) ? 10'd0 : 
                rx_baud_cnt + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_bit_cnt <= 4'd0;
        end else if (rx_baud_cnt == baud_cnt - 1) begin
            rx_bit_cnt <= 
                (rx_bit_cnt == 8 + parity_en) ? 4'd0 : 
                rx_bit_cnt + 1'd1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_data <= 8'd0;
            rx_parity <= 1'b0;
        end else if (rx_baud_cnt == baud_cnt / 2 - 1) begin
            case (rx_bit_cnt)
                4'd1: rx_data[0] <= rx_ff2;
                4'd2: rx_data[1] <= rx_ff2;
                4'd3: rx_data[2] <= rx_ff2;
                4'd4: rx_data[3] <= rx_ff2;
                4'd5: rx_data[4] <= rx_ff2;
                4'd6: rx_data[5] <= rx_ff2;
                4'd7: rx_data[6] <= rx_ff2;
                4'd8: rx_data[7] <= rx_ff2;
                4'd9: rx_parity <= rx_ff2;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_pass <= 1'b0;
        end else begin
            rx_pass <= 
                parity_type == 1 ? rx_parity == ^~rx_data : 
                parity_type == 2 ? rx_parity == ^rx_data : 
                1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 
                (rx_valid & rx_ready) ? 1'b0 : 
                (rx_bit_cnt == 8 + parity_en) && (rx_baud_cnt == baud_cnt - 1) && rx_pass ? 1'b1 : 
                rx_valid;
        end
    end

//================================================================================
//  Uart transmitter
//================================================================================

    reg     [7:0]       tx_ff;
    reg                 tx_busy;
    reg     [9:0]       tx_baud_cnt;
    reg     [3:0]       tx_bit_cnt;
    reg                 tx_parity;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_busy <= 1'b0;
        end else begin
            tx_busy <= 
                tx_valid & tx_ready ? 1'b1 : 
                (tx_bit_cnt == 8 + parity_en + stop_bit_cnt) && (tx_baud_cnt == baud_cnt - 1) ? 1'b0 : 
                tx_busy;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_ff <= 8'd0;
        end else if (tx_valid & tx_ready) begin
            tx_ff <= tx_data;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
            tx_baud_cnt <= 10'd0;
        else if (tx_busy) begin
            tx_baud_cnt <= 
                (tx_baud_cnt == baud_cnt - 1) ? 10'd0 : 
                tx_baud_cnt + 1'd1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_bit_cnt <= 4'd0;
        end else if (tx_baud_cnt == baud_cnt - 1) begin
            tx_bit_cnt <= 
                (tx_bit_cnt == 8 + parity_en + stop_bit_cnt) ? 4'd0 : 
                tx_bit_cnt + 1'd1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_parity <= 1'b0;
        end else if (~tx_busy) begin
            tx_parity <= 
                parity_type == 1 ? ^~tx_ff : 
                parity_type == 2 ? ^tx_ff : 
                1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            uart_tx <= 1'b1;
        end else if (tx_busy) begin
            case (tx_bit_cnt)
                4'd0:  uart_tx <= 1'b0;
                4'd1:  uart_tx <= tx_ff[0];
                4'd2:  uart_tx <= tx_ff[1];
                4'd3:  uart_tx <= tx_ff[2];
                4'd4:  uart_tx <= tx_ff[3];
                4'd5:  uart_tx <= tx_ff[4];
                4'd6:  uart_tx <= tx_ff[5];
                4'd7:  uart_tx <= tx_ff[6];
                4'd8:  uart_tx <= tx_ff[7];
                4'd9:  uart_tx <= tx_parity;
                default: uart_tx <= 1'b1;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_ready <= 1'b1;
        end else begin
            tx_ready <= 
                tx_valid & tx_ready ? 1'b0 : 
                (tx_bit_cnt == 8 + parity_en + stop_bit_cnt) && (tx_baud_cnt == baud_cnt - 1) ? 1'b1 : 
                tx_ready;
        end
    end

endmodule
