`timescale 1ns / 1ps
//================================================================================
//  Module      : tb_apb_uart
//  Description : Testbench for apb_uart (length-controlled APB R/W + UART loopback)
//  Author      : Mercer
//================================================================================

module tb_apb_uart();

    localparam SYS_CLK_FREQ = 1_000_000;
    localparam BAUD_RATE    = 115200;
    localparam STOP_BIT_CNT = 1;
    localparam PARITY_TYPE  = "none";

    localparam CLK_PERIOD   = 1000;

    localparam ADDR_CTRL    = 32'h0000_0000;
    localparam ADDR_RX_BUF  = 32'h0000_0004;
    localparam ADDR_RX_STAT = 32'h0000_0008;
    localparam ADDR_TX_BUF  = 32'h0000_000C;
    localparam ADDR_TX_STAT = 32'h0000_0010;

    reg                 s_apb_pclk;
    reg                 s_apb_presetn;

    reg                 s_apb_psel;
    reg                 s_apb_penable;
    reg                 s_apb_pwrite;
    reg     [31:0]      s_apb_paddr;
    reg     [31:0]      s_apb_pwdata;

    wire                s_apb_pready;
    wire                s_apb_pslverr;
    wire    [31:0]      s_apb_prdata;

    wire                serial_line;

    integer             err_cnt;
    reg     [31:0]      rd_data;
    reg     [31:0]      tx_word;
    reg     [31:0]      rx_word;

    apb_uart #(
        .SYS_CLK_FREQ   (SYS_CLK_FREQ   ),
        .BAUD_RATE      (BAUD_RATE      ),
        .STOP_BIT_CNT   (STOP_BIT_CNT   ),
        .PARITY_TYPE    (PARITY_TYPE    ))
    u_apb_uart (
        .s_apb_pclk     (s_apb_pclk     ),
        .s_apb_presetn  (s_apb_presetn  ),

        .s_apb_psel     (s_apb_psel     ),
        .s_apb_penable  (s_apb_penable  ),
        .s_apb_pwrite   (s_apb_pwrite   ),
        .s_apb_paddr    (s_apb_paddr    ),
        .s_apb_pwdata   (s_apb_pwdata   ),

        .s_apb_pready   (s_apb_pready   ),
        .s_apb_pslverr  (s_apb_pslverr  ),
        .s_apb_prdata   (s_apb_prdata   ),

        .uart_rx        (serial_line    ),
        .uart_tx        (serial_line    ));

    initial begin
        s_apb_pclk = 1'b0;
        forever #(CLK_PERIOD/2) s_apb_pclk = ~s_apb_pclk;
    end

    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge s_apb_pclk);
            s_apb_psel    <= 1'b1;
            s_apb_penable <= 1'b0;
            s_apb_pwrite  <= 1'b1;
            s_apb_paddr   <= addr;
            s_apb_pwdata  <= data;
            @(posedge s_apb_pclk);
            s_apb_penable <= 1'b1;
            wait (s_apb_pready);
            @(posedge s_apb_pclk);
            s_apb_psel    <= 1'b0;
            s_apb_penable <= 1'b0;
            s_apb_pwrite  <= 1'b0;
            s_apb_paddr   <= 32'd0;
            s_apb_pwdata  <= 32'd0;
            $display("[%0t] APB WR addr=0x%08h data=0x%08h", $time, addr, data);
        end
    endtask

    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge s_apb_pclk);
            s_apb_psel    <= 1'b1;
            s_apb_penable <= 1'b0;
            s_apb_pwrite  <= 1'b0;
            s_apb_paddr   <= addr;
            @(posedge s_apb_pclk);
            s_apb_penable <= 1'b1;
            wait (s_apb_pready);
            @(posedge s_apb_pclk);
            data = s_apb_prdata;
            s_apb_psel    <= 1'b0;
            s_apb_penable <= 1'b0;
            s_apb_paddr   <= 32'd0;
            $display("[%0t] APB RD addr=0x%08h data=0x%08h", $time, addr, data);
        end
    endtask

    task check(input [255:0] tag, input [31:0] act, input [31:0] exp);
        begin
            if (act !== exp) begin
                $display("[%0t] [FAIL] %0s: expect 0x%08h, got 0x%08h", $time, tag, exp, act);
                err_cnt = err_cnt + 1;
            end else begin
                $display("[%0t] [PASS] %0s: 0x%08h", $time, tag, act);
            end
        end
    endtask

    initial begin
        s_apb_presetn = 1'b0;
        s_apb_psel    = 1'b0;
        s_apb_penable = 1'b0;
        s_apb_pwrite  = 1'b0;
        s_apb_paddr   = 32'd0;
        s_apb_pwdata  = 32'd0;
        err_cnt       = 0;
        rd_data       = 32'd0;
        tx_word       = 32'h12_34_56_78;
        rx_word       = 32'd0;

        #(CLK_PERIOD*20);
        s_apb_presetn = 1'b1;
        #(CLK_PERIOD*20);

        $display("\n========== TEST 1 : write TX BUF first, then start TX/RX ==========");
        // Step 1: Write data to TX buffer FIRST
        apb_write(ADDR_TX_BUF, tx_word);

        // Step 2: Start TX/RX with ctrl[0]=RX en, ctrl[2:1]=RX len=3 (4 bytes),
        //         ctrl[4]=TX en, ctrl[6:5]=TX len=3 (4 bytes), ctrl[7]=auto clear
        apb_write(ADDR_CTRL, 32'h0000_00FF);

        // Wait a few cycles for ctrl to take effect
        @(posedge s_apb_pclk);
        @(posedge s_apb_pclk);

        // Wait for TX done (tx_cnt == tx_len == 3, tx_valid should go low)
        wait (u_apb_uart.tx_valid == 1'b0);
        $display("[%0t] TX done, tx_status=0x%08h", $time, u_apb_uart.uart_tx_status);

        // Wait for RX done (rx_cnt == rx_len == 3, rx_ready should go low)
        wait (u_apb_uart.rx_ready == 1'b0);
        $display("[%0t] RX done, rx_status=0x%08h", $time, u_apb_uart.uart_rx_status);

        $display("\n========== TEST 2 : read RX BUF and verify ==========");
        apb_read (ADDR_RX_BUF, rd_data);
        rx_word = rd_data;
        check("rx_buf == tx_word", rx_word, tx_word);

        apb_read (ADDR_RX_STAT, rd_data);
        check("rx_status after read", rd_data & 32'h7, 32'd0);

        $display("\n========== TEST 3 : second round transfer (3 bytes) ==========");
        tx_word = 32'hAA_55_A5_00;
        apb_write(ADDR_TX_BUF, tx_word);
        // TX len=2 (3 bytes), RX len=2 (3 bytes)
        apb_write(ADDR_CTRL, 32'h0000_0055);
        @(posedge s_apb_pclk);
        @(posedge s_apb_pclk);
        wait (u_apb_uart.rx_ready == 1'b0);
        apb_read (ADDR_RX_BUF, rd_data);
        check("round2 rx_buf[31:8]", rd_data[31:8], tx_word[31:8]);

        $display("\n========== TEST 4 : third round transfer (2 bytes) ==========");
        tx_word = 32'hDE_AD_00_00;
        apb_write(ADDR_TX_BUF, tx_word);
        // TX len=2 (3 bytes), RX len=2 (3 bytes)
        apb_write(ADDR_CTRL, 32'h0000_0033);
        @(posedge s_apb_pclk);
        @(posedge s_apb_pclk);
        wait (u_apb_uart.rx_ready == 1'b0);
        apb_read (ADDR_RX_BUF, rd_data);
        check("round2 rx_buf[31:16]", rd_data[31:16], tx_word[31:16]);

        $display("\n========== TEST 5 : single byte transfer ==========");
        tx_word = 32'hF0_00_00_00;
        apb_write(ADDR_TX_BUF, tx_word);
        // TX len=0 (1 byte), RX len=0 (1 byte)
        apb_write(ADDR_CTRL, 32'h0000_0011);
        @(posedge s_apb_pclk);
        @(posedge s_apb_pclk);
        wait (u_apb_uart.rx_ready == 1'b0);
        apb_read (ADDR_RX_BUF, rd_data);
        check("round3 rx_buf[7:0]", rd_data[31:24], tx_word[31:24]);

        #(CLK_PERIOD*50);
        $display("\n==================================================");
        if (err_cnt == 0)
            $display("              TEST PASS");
        else
            $display("              TEST FAIL : %0d errors", err_cnt);
        $display("==================================================\n");
        $finish;
    end

    initial begin
        #(CLK_PERIOD*200000);
        $display("[%0t] TIMEOUT! errors=%0d", $time, err_cnt);
        $finish;
    end

    initial begin
        $dumpfile("tb_apb_uart.vcd");
        $dumpvars(0, tb_apb_uart);
    end

endmodule
