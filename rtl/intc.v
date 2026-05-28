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
//                trig_mode selects how the interrupt input is detected.
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
intc    u_intc (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .interrupt                  (interrupt      ),
    .trig_en                    (trig_en        ),
    .trig_mode                  (trig_mode      ),
    .intr_trig                  (intr_trig      ));
*/

//================================================================================
//  Module Definition
//================================================================================
module intc(
    input                               clk,
    input                               rst_n,

    input                               interrupt,

    input                               trig_en,
    input   [1:0]                       trig_mode,

    output  reg                         intr_trig
);

    localparam  RISE                    = 2'b00;
    localparam  FALL                    = 2'b01;
    localparam  HIGH                    = 2'b10;
    localparam  LOW                     = 2'b11;

    reg                                 intr_ff0;
    reg                                 intr_ff1;
    reg                                 intr_ff2;

    wire                                trig_rise;
    wire                                trig_fall;
    wire                                trig_high;
    wire                                trig_low;
    wire                                trig_hit;

    assign trig_rise =  intr_ff1 & ~intr_ff2;
    assign trig_fall = ~intr_ff1 &  intr_ff2;
    assign trig_high =  intr_ff1;
    assign trig_low  = ~intr_ff1;

    assign trig_hit  = (trig_mode == RISE) ? trig_rise :
                       (trig_mode == FALL) ? trig_fall :
                       (trig_mode == HIGH) ? trig_high :
                       (trig_mode == LOW)  ? trig_low  : 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            intr_ff0 <= 1'b0;
            intr_ff1 <= 1'b0;
            intr_ff2 <= 1'b0;
        end else begin
            intr_ff0 <= interrupt;
            intr_ff1 <= intr_ff0;
            intr_ff2 <= intr_ff1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            intr_trig <= 1'b0;
        end else begin
            intr_trig <= trig_hit & trig_en;
        end
    end

endmodule
