`timescale 1ns / 1ps

module dbg_uart_tb;

    parameter           CLK_PERIOD          = 10;
    parameter           RESET_DELAY         = 100;
    parameter           SIM_TIMEOUT         = 2000000;
    parameter           SYS_CLK_FREQ        = 1000000;
    parameter   [23:0]  BAUD_RATE           = 24'd100000;
    parameter           BIT_CYCLES          = 10;

    reg                                 clk = 1'b0;
    reg                                 rst_n = 1'b0;

    reg                                 uart_rx = 1'b1;
    wire                                uart_tx;

    wire                                dbg_cpu_rst_n;
    wire                                dbg_halt_req;
    wire                                dbg_step_req;
    wire                                dbg_busy;
    reg                                 cpu_halted = 1'b0;
    reg     [15:0]                      cpu_pc = 16'h1234;

    wire                                dbg_req;
    wire                                dbg_wren;
    wire    [31:0]                      dbg_addr;
    wire    [31:0]                      dbg_wdata;
    reg     [31:0]                      dbg_rdata = 32'h0;
    reg                                 dbg_rack = 1'b0;

    reg     [7:0]                       tx_payload [0:15];
    reg     [7:0]                       expected [0:31];
    integer                             expected_len;
    integer                             fail_count;
    reg                                 step_seen;

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial #(RESET_DELAY) rst_n = 1'b1;

    initial #(SIM_TIMEOUT) begin
        $display("DBG_UART_TB_TIMEOUT");
        $finish;
    end

    initial begin
        // $dumpfile("dbg_uart_tb.vcd");
        // $dumpvars(0, dbg_uart_tb);
    end

    dbg_uart #(
        .SYS_CLK_FREQ                   (SYS_CLK_FREQ       ),
        .BAUD_RATE                      (BAUD_RATE          ),
        .FIFO_DEPTH                     (8                  ),
        .MAX_PAYLOAD                    (64                 ),
        .RESET_PULSE_CYCLES             (8                  ))
    dbg_uart_inst (
        .clk                            (clk                ),
        .rst_n                          (rst_n              ),

        .uart_rx                        (uart_rx            ),
        .uart_tx                        (uart_tx            ),

        .dbg_cpu_rst_n                  (dbg_cpu_rst_n      ),
        .dbg_halt_req                   (dbg_halt_req       ),
        .dbg_step_req                   (dbg_step_req       ),
        .dbg_busy                       (dbg_busy           ),
        .cpu_halted                     (cpu_halted         ),
        .cpu_pc                         (cpu_pc             ),

        .dbg_req                        (dbg_req            ),
        .dbg_wren                       (dbg_wren           ),
        .dbg_addr                       (dbg_addr           ),
        .dbg_wdata                      (dbg_wdata          ),
        .dbg_rdata                      (dbg_rdata          ),
        .dbg_rack                       (dbg_rack           )
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            step_seen <= 1'b0;
        end else if (dbg_step_req) begin
            step_seen <= 1'b1;
        end
    end

    task uart_send_byte;
        input   [7:0]                   byte_data;
        integer                         bit_idx;
        begin
            uart_rx <= 1'b0;
            repeat (BIT_CYCLES) @(posedge clk);

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx <= byte_data[bit_idx];
                repeat (BIT_CYCLES) @(posedge clk);
            end

            uart_rx <= 1'b1;
            repeat (BIT_CYCLES) @(posedge clk);
        end
    endtask

    task uart_recv_byte;
        output  [7:0]                   byte_data;
        integer                         bit_idx;
        integer                         wait_cnt;
        begin
            wait_cnt = 0;
            byte_data = 8'h00;

            while ((uart_tx == 1'b1) && (wait_cnt < 20000)) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end

            if (wait_cnt >= 20000) begin
                $display("FAIL: UART RX timeout");
                fail_count = fail_count + 1;
            end else begin
                repeat (BIT_CYCLES + (BIT_CYCLES / 2)) @(posedge clk);

                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    byte_data[bit_idx] = uart_tx;
                    repeat (BIT_CYCLES) @(posedge clk);
                end
            end
        end
    endtask

    task send_request;
        input   [7:0]                   cmd;
        input   [7:0]                   len;
        reg     [7:0]                   sum;
        integer                         byte_idx;
        begin
            sum = cmd + len;

            uart_send_byte(8'h55);
            uart_send_byte(8'hAA);
            uart_send_byte(cmd);
            uart_send_byte(len);

            for (byte_idx = 0; byte_idx < len; byte_idx = byte_idx + 1) begin
                sum = sum + tx_payload[byte_idx];
                uart_send_byte(tx_payload[byte_idx]);
            end

            uart_send_byte(sum);
            uart_rx <= 1'b1;
        end
    endtask

    task check_byte;
        input   [255:0]                 tag;
        input   [7:0]                   actual;
        input   [7:0]                   expect;
        begin
            if (actual !== expect) begin
                $display("FAIL: %0s actual=%02x expect=%02x", tag, actual, expect);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_bit;
        input   [255:0]                 tag;
        input                           actual;
        input                           expect;
        begin
            if (actual !== expect) begin
                $display("FAIL: %0s actual=%b expect=%b", tag, actual, expect);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_word;
        input   [255:0]                 tag;
        input   [31:0]                  actual;
        input   [31:0]                  expect;
        begin
            if (actual !== expect) begin
                $display("FAIL: %0s actual=%08x expect=%08x", tag, actual, expect);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task expect_response;
        integer                         byte_idx;
        reg     [7:0]                   rx_byte;
        begin
            for (byte_idx = 0; byte_idx < expected_len; byte_idx = byte_idx + 1) begin
                uart_recv_byte(rx_byte);
                check_byte("response byte", rx_byte, expected[byte_idx]);
            end
        end
    endtask

    task wait_dbg_idle;
        integer                         wait_cnt;
        begin
            wait_cnt = 0;
            while (dbg_busy && (wait_cnt < 20000)) begin
                @(negedge clk);
                wait_cnt = wait_cnt + 1;
            end

            if (wait_cnt >= 20000) begin
                $display("FAIL: dbg_busy timeout");
                fail_count = fail_count + 1;
            end

            repeat (20) @(posedge clk);
        end
    endtask

    task wait_debug_request;
        input                           expect_wren;
        input   [31:0]                  expect_addr;
        input   [31:0]                  expect_wdata;
        integer                         wait_cnt;
        begin
            wait_cnt = 0;
            while ((dbg_req != 1'b1) && (wait_cnt < 20000)) begin
                @(negedge clk);
                wait_cnt = wait_cnt + 1;
            end

            if (wait_cnt >= 20000) begin
                $display("FAIL: debug request timeout");
                fail_count = fail_count + 1;
            end else begin
                check_bit("debug write enable", dbg_wren, expect_wren);
                check_word("debug address", dbg_addr, expect_addr);

                if (expect_wren) begin
                    check_word("debug write data", dbg_wdata, expect_wdata);
                end
            end
        end
    endtask

    task ack_debug_bus;
        input   [31:0]                  read_data;
        begin
            dbg_rdata <= read_data;
            @(posedge clk);
            dbg_rack <= 1'b1;
            @(posedge clk);
            dbg_rack <= 1'b0;
        end
    endtask

    task set_empty_response;
        input   [7:0]                   cmd;
        input   [7:0]                   status;
        begin
            expected_len = 6;
            expected[0] = 8'h55;
            expected[1] = 8'hAA;
            expected[2] = cmd;
            expected[3] = status;
            expected[4] = 8'd0;
            expected[5] = cmd + status;
        end
    endtask

    task set_ping_response;
        begin
            expected_len = 8;
            expected[0] = 8'h55;
            expected[1] = 8'hAA;
            expected[2] = 8'h01;
            expected[3] = 8'h00;
            expected[4] = 8'd2;
            expected[5] = 8'h4F;
            expected[6] = 8'h4B;
            expected[7] = 8'h9D;
        end
    endtask

    task set_status_response;
        input   [7:0]                   status_byte;
        begin
            expected_len = 14;
            expected[0] = 8'h55;
            expected[1] = 8'hAA;
            expected[2] = 8'h23;
            expected[3] = 8'h00;
            expected[4] = 8'd8;
            expected[5] = status_byte;
            expected[6] = 8'h00;
            expected[7] = 8'h00;
            expected[8] = 8'h00;
            expected[9] = cpu_pc[7:0];
            expected[10] = cpu_pc[15:8];
            expected[11] = 8'h00;
            expected[12] = 8'h00;
            expected[13] = 8'h23 + 8'h00 + 8'd8 + status_byte +
                           cpu_pc[7:0] + cpu_pc[15:8];
        end
    endtask

    task set_lb_read_response;
        input   [31:0]                  read_data;
        begin
            expected_len = 10;
            expected[0] = 8'h55;
            expected[1] = 8'hAA;
            expected[2] = 8'h31;
            expected[3] = 8'h00;
            expected[4] = 8'd4;
            expected[5] = read_data[7:0];
            expected[6] = read_data[15:8];
            expected[7] = read_data[23:16];
            expected[8] = read_data[31:24];
            expected[9] = 8'h31 + 8'h00 + 8'd4 +
                          read_data[7:0] + read_data[15:8] +
                          read_data[23:16] + read_data[31:24];
        end
    endtask

    task run_simple_command;
        input   [7:0]                   cmd;
        input   [7:0]                   len;
        begin
            fork
                expect_response();
                send_request(cmd, len);
            join

            wait_dbg_idle();
        end
    endtask

    initial begin
        fail_count = 0;
        expected_len = 0;
        step_seen = 1'b0;

        tx_payload[0] = 8'h00;
        tx_payload[1] = 8'h00;
        tx_payload[2] = 8'h00;
        tx_payload[3] = 8'h00;
        tx_payload[4] = 8'h00;
        tx_payload[5] = 8'h00;
        tx_payload[6] = 8'h00;
        tx_payload[7] = 8'h00;

        wait (rst_n == 1'b1);
        repeat (100) @(posedge clk);

        set_ping_response();
        run_simple_command(8'h01, 8'd0);

        set_status_response(8'h08);
        run_simple_command(8'h23, 8'd0);

        set_empty_response(8'h20, 8'h00);
        run_simple_command(8'h20, 8'd0);
        check_bit("halt request after HALT", dbg_halt_req, 1'b1);

        step_seen = 1'b0;
        cpu_halted <= 1'b1;
        set_empty_response(8'h22, 8'h00);
        run_simple_command(8'h22, 8'd0);
        check_bit("step pulse seen", step_seen, 1'b1);
        check_bit("halt request after STEP", dbg_halt_req, 1'b1);

        tx_payload[0] = 8'h04;
        tx_payload[1] = 8'h00;
        tx_payload[2] = 8'h10;
        tx_payload[3] = 8'h00;
        tx_payload[4] = 8'hEF;
        tx_payload[5] = 8'hCD;
        tx_payload[6] = 8'hAB;
        tx_payload[7] = 8'h89;

        fork
            wait_debug_request(1'b1, 32'h00100004, 32'h89ABCDEF);
            send_request(8'h30, 8'd8);
        join

        set_empty_response(8'h30, 8'h00);
        fork
            expect_response();
            ack_debug_bus(32'h00000000);
        join
        wait_dbg_idle();

        tx_payload[0] = 8'h08;
        tx_payload[1] = 8'h00;
        tx_payload[2] = 8'h10;
        tx_payload[3] = 8'h00;

        fork
            wait_debug_request(1'b0, 32'h00100008, 32'h00000000);
            send_request(8'h31, 8'd4);
        join

        set_lb_read_response(32'h12345678);
        fork
            expect_response();
            ack_debug_bus(32'h12345678);
        join
        wait_dbg_idle();

        set_empty_response(8'h21, 8'h00);
        run_simple_command(8'h21, 8'd0);
        check_bit("halt request after RUN", dbg_halt_req, 1'b0);

        if (fail_count == 0) begin
            $display("DBG_UART_TB_PASS");
        end else begin
            $display("DBG_UART_TB_FAIL fail_count=%0d", fail_count);
        end

        $finish;
    end

endmodule
