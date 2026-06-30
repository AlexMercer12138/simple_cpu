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
//  Module      : can_bit_timing
//  Description : CAN bit timing tick generator
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================

//================================================================================
//  Module Definition
//================================================================================

module can_bit_timing (
    input   wire            clk,
    input   wire            rst_n,

    input   wire            enable,
    input   wire    [9:0]   brp,
    input   wire    [1:0]   sjw,
    input   wire    [3:0]   tseg1,
    input   wire    [3:0]   tseg2,
    input   wire            can_rx,

    output  reg             tq_tick,
    output  reg             sample_tick,
    output  reg             bit_tick,
    output  reg             sync_tick,
    output  reg             bus_idle
);

    reg     [9:0]           brp_cnt;
    reg     [5:0]           tq_cnt;
    reg                     rx_ff0;
    reg                     rx_ff1;
    reg                     rx_ff2;
    reg     [3:0]           idle_cnt;

    wire    [5:0]           brp_div;
    wire    [5:0]           tseg1_eff;
    wire    [5:0]           tseg2_eff;
    wire    [5:0]           bit_tq_total;
    wire    [5:0]           sample_tq;
    wire                    dominant_edge;
    wire    [5:0]           sjw_eff;

    assign brp_div       = brp == 10'd0 ? 6'd1 : brp[5:0];
    assign tseg1_eff     = tseg1 == 4'd0 ? 6'd1 : {2'd0, tseg1};
    assign tseg2_eff     = tseg2 == 4'd0 ? 6'd1 : {2'd0, tseg2};
    assign bit_tq_total  = 6'd1 + tseg1_eff + tseg2_eff;
    assign sample_tq     = 6'd1 + tseg1_eff;
    assign dominant_edge = rx_ff2 & ~rx_ff1;
    assign sjw_eff       = sjw == 2'd0 ? 6'd1 : {4'd0, sjw};

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_ff0 <= 1'b1;
            rx_ff1 <= 1'b1;
            rx_ff2 <= 1'b1;
        end else begin
            rx_ff0 <= can_rx;
            rx_ff1 <= rx_ff0;
            rx_ff2 <= rx_ff1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            brp_cnt     <= 10'd0;
            tq_cnt      <= 6'd0;
            tq_tick     <= 1'b0;
            sample_tick <= 1'b0;
            bit_tick    <= 1'b0;
            sync_tick   <= 1'b0;
        end else if (!enable) begin
            brp_cnt     <= 10'd0;
            tq_cnt      <= 6'd0;
            tq_tick     <= 1'b0;
            sample_tick <= 1'b0;
            bit_tick    <= 1'b0;
            sync_tick   <= 1'b0;
        end else begin
            tq_tick     <= 1'b0;
            sample_tick <= 1'b0;
            bit_tick    <= 1'b0;
            sync_tick   <= 1'b0;

            if (dominant_edge && (tq_cnt < sjw_eff)) begin
                brp_cnt   <= 10'd0;
                tq_cnt    <= 6'd0;
                sync_tick <= 1'b1;
            end else if (brp_cnt == {4'd0, brp_div} - 10'd1) begin
                brp_cnt <= 10'd0;
                tq_tick <= 1'b1;

                if (tq_cnt == bit_tq_total - 6'd1) begin
                    tq_cnt   <= 6'd0;
                    bit_tick <= 1'b1;
                end else begin
                    tq_cnt <= tq_cnt + 6'd1;
                end

                if (tq_cnt == sample_tq - 6'd1) begin
                    sample_tick <= 1'b1;
                end
            end else begin
                brp_cnt <= brp_cnt + 10'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            idle_cnt <= 4'd0;
            bus_idle <= 1'b1;
        end else if (!enable) begin
            idle_cnt <= 4'd0;
            bus_idle <= 1'b1;
        end else if (bit_tick) begin
            if (rx_ff1) begin
                idle_cnt <= idle_cnt == 4'd15 ? idle_cnt : idle_cnt + 4'd1;
            end else begin
                idle_cnt <= 4'd0;
            end
            bus_idle <= idle_cnt >= 4'd10;
        end
    end

endmodule
