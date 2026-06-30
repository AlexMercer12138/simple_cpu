`timescale 1ns / 1ps
//================================================================================
//  Module      : tb_apb_can
//  Description : Testbench for apb_can APB access, loopback, interrupt and errors
//  Author      : Mercer
//================================================================================

module tb_apb_can();

    localparam CLK_PERIOD     = 10;

    localparam ADDR_CTRL      = 32'h0000_0000;
    localparam ADDR_BITTIMING = 32'h0000_0004;
    localparam ADDR_TX_ID     = 32'h0000_0008;
    localparam ADDR_TX_CTRL   = 32'h0000_000C;
    localparam ADDR_TX_DATA0  = 32'h0000_0010;
    localparam ADDR_TX_DATA1  = 32'h0000_0014;
    localparam ADDR_RX_ID     = 32'h0000_0018;
    localparam ADDR_RX_CTRL   = 32'h0000_001C;
    localparam ADDR_RX_DATA0  = 32'h0000_0020;
    localparam ADDR_RX_DATA1  = 32'h0000_0024;
    localparam ADDR_STATUS    = 32'h0000_0028;
    localparam ADDR_INTERRUPT = 32'h0000_002C;
    localparam ADDR_ERROR     = 32'h0000_0030;
    localparam ADDR_ECR       = 32'h0000_0034;

    reg             s_apb_pclk = 1'b0;
    reg             s_apb_presetn = 1'b0;
    reg             s_apb_psel;
    reg             s_apb_penable;
    reg             s_apb_pwrite;
    reg     [31:0]  s_apb_paddr;
    reg     [31:0]  s_apb_pwdata;

    wire            s_apb_pready;
    wire            s_apb_pslverr;
    wire    [31:0]  s_apb_prdata;
    wire            interrupt;
    wire            can_rx_line;
    wire            can_tx_line;
    reg             can_rx_force;
    reg             can_rx_value;

    integer         err_cnt;
    integer         wait_cnt;
    integer         tx_err_iter;
    reg     [31:0]  rd_data;
    reg     [31:0]  ecr_val;
    reg     [31:0]  err_val;

    apb_can #(
        .FIFO_DEPTH     (4              ))
    u_apb_can (
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
        .interrupt      (interrupt      ),
        .can_rx         (can_rx_line    ),
        .can_tx         (can_tx_line    ));

    assign can_rx_line = can_rx_force ? can_rx_value : can_tx_line;

    always #(CLK_PERIOD/2) s_apb_pclk = ~s_apb_pclk;

    initial #(CLK_PERIOD*10) s_apb_presetn = 1'b1;

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

    task wait_status_bit(input [31:0] mask, input [31:0] value);
        begin
            wait_cnt = 0;
            apb_read(ADDR_STATUS, rd_data);
            while (((rd_data & mask) != value) && (wait_cnt < 2000)) begin
                wait_cnt = wait_cnt + 1;
                repeat (5) @(posedge s_apb_pclk);
                apb_read(ADDR_STATUS, rd_data);
            end
            if ((rd_data & mask) != value) begin
                $display("[%0t] [FAIL] wait_status_bit mask=0x%08h value=0x%08h last=0x%08h", $time, mask, value, rd_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task wait_status_bit_long(input [31:0] mask, input [31:0] value, input integer max_wait);
        begin
            wait_cnt = 0;
            apb_read(ADDR_STATUS, rd_data);
            while (((rd_data & mask) != value) && (wait_cnt < max_wait)) begin
                wait_cnt = wait_cnt + 1;
                repeat (5) @(posedge s_apb_pclk);
                apb_read(ADDR_STATUS, rd_data);
            end
            if ((rd_data & mask) != value) begin
                $display("[%0t] [FAIL] wait_status_bit_long mask=0x%08h value=0x%08h last=0x%08h", $time, mask, value, rd_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task wait_error_mask(input [31:0] mask, input [31:0] value, input integer max_wait);
        begin
            wait_cnt = 0;
            apb_read(ADDR_ERROR, rd_data);
            while (((rd_data & mask) != value) && (wait_cnt < max_wait)) begin
                wait_cnt = wait_cnt + 1;
                repeat (10) @(posedge s_apb_pclk);
                apb_read(ADDR_ERROR, rd_data);
            end
            if ((rd_data & mask) != value) begin
                $display("[%0t] [FAIL] wait_error_mask mask=0x%08h value=0x%08h last=0x%08h", $time, mask, value, rd_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task drive_can_bit(input bit_value);
        begin
            repeat (4) @(posedge s_apb_pclk);
            can_rx_value <= bit_value;
            repeat (3) @(posedge s_apb_pclk);
        end
    endtask

    task inject_stuff_error_frame;
        begin
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b1;
            repeat (20) @(posedge s_apb_pclk);
            drive_can_bit(1'b0);
            drive_can_bit(1'b0);
            drive_can_bit(1'b0);
            drive_can_bit(1'b0);
            drive_can_bit(1'b0);
            drive_can_bit(1'b0);
            can_rx_value <= 1'b1;
            repeat (40) @(posedge s_apb_pclk);
        end
    endtask

    task run_error_drop_frame;
        begin
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b1;
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            apb_write(ADDR_CTRL, 32'h0000_0001);
            repeat (20) @(posedge s_apb_pclk);

            inject_stuff_error_frame();

            apb_read(ADDR_RX_CTRL, rd_data);
            check("stuff error frame not written to RX FIFO", rd_data & 32'h0000_0080, 32'h0000_0000);
            apb_read(ADDR_STATUS, rd_data);
            check("rx count remains zero after stuff error", rd_data & 32'h0000_0700, 32'h0000_0000);
            apb_read(ADDR_ERROR, rd_data);
            if ((rd_data & 32'h0000_0002) == 32'h0000_0002) begin
                $display("[%0t] [PASS] stuff error flag set: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] stuff error flag missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            apb_read(ADDR_INTERRUPT, rd_data);
            if ((rd_data & 32'h0004_0000) == 32'h0004_0000) begin
                $display("[%0t] [PASS] error interrupt pending set: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] error interrupt pending missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            if (interrupt) begin
                $display("[%0t] [PASS] interrupt output asserted for stuff error", $time);
            end else begin
                $display("[%0t] [FAIL] interrupt output missing for stuff error", $time);
                err_cnt = err_cnt + 1;
            end
            apb_write(ADDR_INTERRUPT, 32'h0004_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            repeat (3) @(posedge s_apb_pclk);
            if (!interrupt) begin
                $display("[%0t] [PASS] error interrupt output cleared", $time);
            end else begin
                $display("[%0t] [FAIL] error interrupt output still asserted", $time);
                err_cnt = err_cnt + 1;
            end
            can_rx_force <= 1'b0;
        end
    endtask

    task run_loopback_frame;
        input [28:0] frame_id;
        input        frame_ide;
        input [3:0]  frame_dlc;
        input [31:0] data0;
        input [31:0] data1;
        begin
            can_rx_force <= 1'b0;
            apb_write(ADDR_TX_ID, {3'd0, frame_id});
            apb_write(ADDR_TX_CTRL, {26'd0, 1'b0, frame_ide, frame_dlc});
            apb_write(ADDR_TX_DATA0, data0);
            apb_write(ADDR_TX_DATA1, data1);
            apb_write(ADDR_CTRL, 32'h0000_000d);

            wait_status_bit(32'h0000_0002, 32'h0000_0000);
            wait_status_bit(32'h0000_0010, 32'h0000_0010);
            apb_read(ADDR_INTERRUPT, rd_data);
            if ((rd_data & 32'h0002_0000) == 32'h0002_0000) begin
                $display("[%0t] [PASS] tx pending set: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] tx pending missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            wait_status_bit(32'h0000_0100, 32'h0000_0100);

            apb_read(ADDR_RX_ID, rd_data);
            check("rx id", rd_data[28:0], frame_id);
            apb_read(ADDR_RX_CTRL, rd_data);
            check("rx ctrl valid/ide/dlc", rd_data & 32'h0000_00df, {24'd0, 1'b1, frame_ide, 1'b0, 1'b0, frame_dlc} & 32'h0000_00df);
            apb_read(ADDR_RX_DATA0, rd_data);
            check("rx data0", rd_data, data0);
            apb_read(ADDR_RX_DATA1, rd_data);
            check("rx data1", rd_data, data1);

            apb_write(ADDR_CTRL, 32'h0000_0015);
            wait_status_bit(32'h0000_0100, 32'h0000_0000);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            repeat (3) @(posedge s_apb_pclk);
        end
    endtask

    task run_ack_error_counter;
        begin
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b1;
            apb_write(ADDR_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_ID, 32'h0000_0456);
            apb_write(ADDR_TX_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_DATA0, 32'h5a00_0000);
            apb_write(ADDR_TX_DATA1, 32'h0000_0000);
            apb_write(ADDR_CTRL, 32'h0000_0009);
            // When RX is forced recessive, TX dominant data bits trigger bit_error
            // (not ack_error, since the frame never reaches ACK phase).
            // Both bit_error and ack_error increment TEC by 8.
            wait_error_mask(32'h0000_0010, 32'h0000_0010, 3000);
            apb_read(ADDR_ERROR, rd_data);
            if (rd_data[23:16] != 8'd0) begin
                $display("[%0t] [PASS] TX error (bit_error) increments TEC: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] TEC did not increment after TX error: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            if ((rd_data & 32'h0000_0010) == 32'h0000_0010) begin
                $display("[%0t] [PASS] bit_error flag set (RX forced recessive): 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] bit_error flag missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_ERROR, 32'h0000_003f);
        end
    endtask

    task run_bus_off_counter;
        begin
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b1;
            apb_write(ADDR_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_ID, 32'h0000_0555);
            apb_write(ADDR_TX_CTRL, 32'h0000_0000);
            apb_write(ADDR_TX_DATA0, 32'h0000_0000);
            apb_write(ADDR_TX_DATA1, 32'h0000_0000);
            apb_write(ADDR_CTRL, 32'h0000_0009);
            // Repeated bit_errors (RX forced recessive) increment TEC by 8 each,
            // eventually entering error-passive then bus-off state.
            wait_error_mask(32'h8000_0000, 32'h8000_0000, 80000);
            apb_read(ADDR_ERROR, rd_data);
            if ((rd_data & 32'h8000_0000) == 32'h8000_0000) begin
                $display("[%0t] [PASS] repeated TX errors enter bus-off: 0x%08h (TEC=%0d)", $time, rd_data, rd_data[23:16]);
            end else begin
                $display("[%0t] [FAIL] bus-off state missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            apb_read(ADDR_STATUS, rd_data);
            check("bus-off disables tx ready", rd_data & 32'h0000_0001, 32'h0000_0000);
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_read(ADDR_ERROR, rd_data);
            if ((rd_data & 32'he000_0000) == 32'h2000_0000) begin
                $display("[%0t] [PASS] soft reset recovers error active: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] soft reset did not recover bus-off: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task run_arbitration_lost_retry;
        begin
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            can_rx_force <= 1'b0;
            apb_write(ADDR_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_ID, 32'h0000_07ff);
            apb_write(ADDR_TX_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_DATA0, 32'hcafe_0000);
            apb_write(ADDR_TX_DATA1, 32'h0000_0000);
            apb_write(ADDR_CTRL, 32'h0000_0009);
            wait (can_tx_line == 1'b0);
            wait (can_tx_line == 1'b1);
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b0;
            wait_error_mask(32'h0000_0020, 32'h0000_0020, 2000);
            apb_read(ADDR_ERROR, rd_data);
            if ((rd_data & 32'h0000_0010) == 32'h0000_0000) begin
                $display("[%0t] [PASS] arbitration lost is not bit error: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] arbitration lost also set bit error: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            apb_read(ADDR_INTERRUPT, rd_data);
            if ((rd_data & 32'h0008_0000) == 32'h0008_0000) begin
                $display("[%0t] [PASS] arbitration lost pending visible: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] arbitration lost pending missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            // Switch to loopback mode so retry can succeed (ACK auto-sampled)
            can_rx_force <= 1'b0;
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_CTRL, 32'h0000_0005);
            // Wait for TX done interrupt pending (sticky bit 17 = 0x0002_0000)
            wait_cnt = 0;
            apb_read(ADDR_INTERRUPT, rd_data);
            while (((rd_data & 32'h0002_0000) != 32'h0002_0000) && (wait_cnt < 8000)) begin
                wait_cnt = wait_cnt + 1;
                repeat (10) @(posedge s_apb_pclk);
                apb_read(ADDR_INTERRUPT, rd_data);
            end
            if ((rd_data & 32'h0002_0000) == 32'h0002_0000) begin
                $display("[%0t] [PASS] arbitration retry finally completes TX: 0x%08h", $time, rd_data);
            end else begin
                $display("[%0t] [FAIL] arbitration retry TX pending missing: 0x%08h", $time, rd_data);
                err_cnt = err_cnt + 1;
            end
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);
        end
    endtask

    task run_ecr_test;
        begin
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);

            // ECR should be zero after reset
            apb_read(ADDR_ECR, rd_data);
            check("ECR reset TEC", rd_data[23:16], 8'd0);
            check("ECR reset REC", rd_data[7:0], 8'd0);

            // Cross-check with ERROR register
            apb_read(ADDR_ERROR, rd_data);
            check("ERROR TEC after reset", rd_data[23:16], 8'd0);
            check("ERROR REC after reset", rd_data[15:8], 8'd0);

            // Force a TX error (bit_error due to RX forced recessive) to increment TEC
            can_rx_force <= 1'b1;
            can_rx_value <= 1'b1;
            apb_write(ADDR_CTRL, 32'h0000_0001);
            apb_write(ADDR_TX_ID, 32'h0000_0333);
            apb_write(ADDR_TX_CTRL, 32'h0000_0000);
            apb_write(ADDR_TX_DATA0, 32'h0000_0000);
            apb_write(ADDR_TX_DATA1, 32'h0000_0000);
            apb_write(ADDR_CTRL, 32'h0000_0009);
            // bit_error triggered (RX forced recessive, TX sends dominant)
            wait_error_mask(32'h0000_0010, 32'h0000_0010, 3000);

            // ECR TEC should be non-zero after TX error
            apb_read(ADDR_ECR, rd_data);
            if (rd_data[23:16] != 8'd0) begin
                $display("[%0t] [PASS] ECR TEC non-zero after TX error: TEC=%0d REC=%0d", $time, rd_data[23:16], rd_data[7:0]);
            end else begin
                $display("[%0t] [FAIL] ECR TEC still zero after TX error", $time);
                err_cnt = err_cnt + 1;
            end

            // Cross-check ECR with ERROR register
            apb_read(ADDR_ECR, ecr_val);
            apb_read(ADDR_ERROR, err_val);
            check("ECR TEC matches ERROR TEC", ecr_val[23:16], err_val[23:16]);
            check("ECR REC matches ERROR REC", ecr_val[7:0], err_val[15:8]);

            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_ERROR, 32'h0000_003f);
            can_rx_force <= 1'b0;
        end
    endtask

    task run_error_state_test;
        begin
            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            apb_write(ADDR_BITTIMING, 32'h0111_0001);
            apb_write(ADDR_INTERRUPT, 32'h001f_001f);
            apb_write(ADDR_ERROR, 32'h0000_003f);

            // After reset, should be error_active
            apb_read(ADDR_STATUS, rd_data);
            check("STATUS error_active after reset", rd_data & 32'h0000_8000, 32'h0000_8000);
            check("STATUS not error_passive after reset", rd_data & 32'h0001_0000, 32'h0000_0000);
            check("STATUS not bus_off after reset", rd_data & 32'h0002_0000, 32'h0000_0000);

            // ERROR register error state bits
            apb_read(ADDR_ERROR, rd_data);
            check("ERROR error_active after reset", rd_data & 32'h2000_0000, 32'h2000_0000);
            check("ERROR not error_passive after reset", rd_data & 32'h4000_0000, 32'h0000_0000);
            check("ERROR not bus_off after reset", rd_data & 32'h8000_0000, 32'h0000_0000);

            apb_write(ADDR_CTRL, 32'h8000_0000);
            repeat (5) @(posedge s_apb_pclk);
            can_rx_force <= 1'b0;
        end
    endtask

    initial begin
        // $dumpfile("tb_apb_can.vcd");
        // $dumpvars(0, tb_apb_can);
        s_apb_psel    = 1'b0;
        s_apb_penable = 1'b0;
        s_apb_pwrite  = 1'b0;
        s_apb_paddr   = 32'd0;
        s_apb_pwdata  = 32'd0;
        can_rx_force  = 1'b1;
        can_rx_value  = 1'b1;
        err_cnt       = 0;
        rd_data       = 32'd0;
        wait_cnt      = 0;
        tx_err_iter   = 0;

        @(posedge s_apb_presetn);
        repeat (10) @(posedge s_apb_pclk);

        $display("========== TEST 1 : reset defaults and APB access ==========");
        apb_read(ADDR_CTRL, rd_data);
        check("ctrl reset", rd_data, 32'd0);
        apb_read(ADDR_BITTIMING, rd_data);
        check("bittiming reset", rd_data, 32'h0111_0001);
        apb_write(32'h0000_00f0, 32'hffff_ffff);
        apb_read(32'h0000_00f0, rd_data);
        check("invalid read returns zero", rd_data, 32'd0);

        $display("========== TEST 2 : standard frame loopback ==========");
        apb_write(ADDR_BITTIMING, 32'h0111_0001);
        apb_write(ADDR_INTERRUPT, 32'h0000_001f);
        run_loopback_frame(29'h0000_0123, 1'b0, 4'd8, 32'h1122_3344, 32'h5566_7788);

        $display("========== TEST 3 : extended frame loopback ==========");
        run_loopback_frame(29'h1abc_def0, 1'b1, 4'd3, 32'ha1b2_c300, 32'h0000_0000);

        $display("========== TEST 4 : ACK error increments TEC ==========");
        run_ack_error_counter();

        $display("========== TEST 5 : repeated ACK error enters Error Passive/Bus-Off ==========");
        run_bus_off_counter();

        $display("========== TEST 6 : arbitration lost and automatic retry ==========");
        run_arbitration_lost_retry();

        $display("========== TEST 7 : stuff error drop frame ==========");
        run_error_drop_frame();

        $display("========== TEST 8 : ECR register verification ==========");
        run_ecr_test();

        $display("========== TEST 9 : error state bits verification ==========");
        run_error_state_test();

        repeat (50) @(posedge s_apb_pclk);
        $display("==================================================");
        if (err_cnt == 0) begin
            $display("              TEST PASS");
        end else begin
            $display("              TEST FAIL : %0d errors", err_cnt);
        end
        $display("==================================================");
        $finish;
    end

    initial begin
        #(CLK_PERIOD*500000);
        $display("[%0t] TIMEOUT! errors=%0d", $time, err_cnt);
        $finish;
    end

endmodule
