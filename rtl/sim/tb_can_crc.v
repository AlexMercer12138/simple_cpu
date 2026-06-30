`timescale 1ns / 1ps
//================================================================================
//  Module      : tb_can_crc
//  Description : Testbench for can_crc and CAN CRC-15 reference path
//  Author      : Mercer
//================================================================================

module tb_can_crc();

    localparam CLK_PERIOD = 10;

    reg             clk = 1'b0;
    reg             rst_n = 1'b0;
    reg             clear;
    reg             enable;
    reg             data_bit;
    wire    [14:0]  crc_value;
    wire    [14:0]  crc_next_value;

    integer         err_cnt;
    integer         i;
    reg     [14:0]  ref_crc;
    reg     [18:0]  std_frame_bits;

    can_crc u_can_crc (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .clear          (clear          ),
        .enable         (enable         ),
        .data_bit       (data_bit       ),
        .crc_value      (crc_value      ),
        .crc_next_value (crc_next_value ));

    always #(CLK_PERIOD/2) clk = ~clk;

    initial #(CLK_PERIOD*5) rst_n = 1'b1;

    function [14:0] crc15_next;
        input [14:0] crc_in;
        input        bit_in;
        reg          feedback;
        begin
            feedback   = bit_in ^ crc_in[14];
            crc15_next = {crc_in[13:0], 1'b0};
            if (feedback) begin
                crc15_next = crc15_next ^ 15'h4599;
            end
        end
    endfunction

    task push_bit(input bit_in);
        begin
            @(negedge clk);
            data_bit = bit_in;
            enable   = 1'b1;
            ref_crc  = crc15_next(ref_crc, bit_in);
            @(negedge clk);
            enable   = 1'b0;
            data_bit = 1'b0;
        end
    endtask

    task check(input [255:0] tag, input [14:0] act, input [14:0] exp);
        begin
            if (act !== exp) begin
                $display("[%0t] [FAIL] %0s: expect 0x%04h, got 0x%04h", $time, tag, exp, act);
                err_cnt = err_cnt + 1;
            end else begin
                $display("[%0t] [PASS] %0s: 0x%04h", $time, tag, act);
            end
        end
    endtask

    initial begin
        // $dumpfile("tb_can_crc.vcd");
        // $dumpvars(0, tb_can_crc);
        clear          = 1'b0;
        enable         = 1'b0;
        data_bit       = 1'b0;
        err_cnt        = 0;
        ref_crc        = 15'd0;
        std_frame_bits = 19'b0_00100100011_0_0_0_0010;

        @(posedge rst_n);
        @(posedge clk);
        clear <= 1'b1;
        @(posedge clk);
        clear <= 1'b0;
        @(posedge clk);
        ref_crc <= 15'd0;

        for (i = 18; i >= 0; i = i - 1) begin
            push_bit(std_frame_bits[i]);
        end

        check("standard frame SOF/ID/control/DLC CRC", crc_value, ref_crc);
        check("known reference CRC for ID 0x123 DLC 2", crc_value, 15'h26f3);

        if (err_cnt == 0) begin
            $display("TEST PASS");
        end else begin
            $display("TEST FAIL : %0d errors", err_cnt);
        end
        $finish;
    end

    initial begin
        #(CLK_PERIOD*1000);
        $display("[%0t] TIMEOUT! errors=%0d", $time, err_cnt);
        $finish;
    end

endmodule
