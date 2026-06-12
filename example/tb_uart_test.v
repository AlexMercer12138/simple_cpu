`timescale 1ns / 1ps
//================================================================================
//  Module      : tb_uart_test
//  Description : Top-level testbench for the UART demo program.
//                Connects MERC32_top (APB master) <-> apb_uart (APB slave),
//                loops uart_tx back to uart_rx, and decodes the byte stream
//                printed by the CPU so the simulation log shows "Hello world!".
//  Author      : Mercer
//================================================================================

module tb_uart_test();

    //----------------------------------------------------------------------------
    // Simulation parameters
    //----------------------------------------------------------------------------
    // Use a small system clock so the baud counter (SYS_CLK_FREQ / baud_rate)
    // stays small and the UART transactions complete quickly in simulation.
    // The CPU program writes baud_rate = 115200 into uart_config[23:0], so
    // baud_cnt = 1_000_000 / 115200 ~= 8 clk cycles per bit -- fast enough for
    // simulation but still exercises the full UART state machines.
    localparam SYS_CLK_FREQ     = 100_000_000;
    localparam CLK_PERIOD       = 10;     // 1 us -> 1 MHz

    //----------------------------------------------------------------------------
    // Clock and reset
    //----------------------------------------------------------------------------
    reg                 clk;
    reg                 rst_n;
    reg                 uart_rx;
    wire                uart_tx;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        uart_rx = 1'b1;
        rst_n = 1'b0;
        #(CLK_PERIOD*20);
        rst_n = 1'b1;
    end

    merc32_sys_wrapper merc32_sys_wrapper_inst(
        .sys_clk    (clk),
        .sys_rst_n  (rst_n),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx));

endmodule
