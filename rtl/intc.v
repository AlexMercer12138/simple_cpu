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
//  Module      : intc
//  Description : Simple interrupt controller with configurable trigger mode.
//                TRIG_MODE (string) selects how the interrupt input is detected:
//                  "rise" - Rising  edge triggered
//                  "fall" - Falling edge triggered
//                  "high" - High    level triggered
//                  "low"  - Low     level triggered
//                When the trigger condition is met, irq_en is asserted high
//                and held until irq_ack is asserted high.
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
intc #(
    .TRIG_MODE                  ("rise"         ))
u_intc (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .interrupt                  (interrupt      ),
    .irq_ack                    (irq_ack        ),
    .irq_en                     (irq_en         ));
*/

//================================================================================
//  Module Definition
//================================================================================
module intc #(
    parameter TRIG_MODE                 = "rise"
)(
    input                               clk,
    input                               rst_n,

    input                               interrupt,
    input                               irq_ack,
    output  reg                         irq_en
);

    reg                                 intr_sync_d0;
    reg                                 intr_sync_d1;
    reg                                 intr_sync_d2;

    wire                                trig_rise;
    wire                                trig_fall;
    wire                                trig_high;
    wire                                trig_low;
    wire                                trig_hit;

    always @(posedge clk) begin
        if (!rst_n) begin
            intr_sync_d0 <= 1'b0;
            intr_sync_d1 <= 1'b0;
            intr_sync_d2 <= 1'b0;
        end else begin
            intr_sync_d0 <= interrupt;
            intr_sync_d1 <= intr_sync_d0;
            intr_sync_d2 <= intr_sync_d1;
        end
    end

    assign trig_rise =  intr_sync_d1 & ~intr_sync_d2;
    assign trig_fall = ~intr_sync_d1 &  intr_sync_d2;
    assign trig_high =  intr_sync_d1;
    assign trig_low  = ~intr_sync_d1;

    assign trig_hit  = (TRIG_MODE == "rise") ? trig_rise :
                       (TRIG_MODE == "fall") ? trig_fall :
                       (TRIG_MODE == "high") ? trig_high :
                       (TRIG_MODE == "low")  ? trig_low  : 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            irq_en <= 1'b0;
        end else if (irq_ack) begin
            irq_en <= 1'b0;
        end else if (trig_hit) begin
            irq_en <= 1'b1;
        end
    end

endmodule
