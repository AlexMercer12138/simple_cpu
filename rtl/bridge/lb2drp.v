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
//  Module      : lb2drp
//  Description : Local bus to DRP (Dynamic Reconfiguration Port) bridge
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
lb2drp #(
    .LB_DATA_WIDTH              (32             ),
    .LB_ADDR_WIDTH              (32             ),
    .APB_DATA_WIDTH             (32             ),
    .APB_ADDR_WIDTH             (8              ))
u_lb2drp (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .lb_rden                    (lb_rden        ),
    .lb_wren                    (lb_wren        ),
    .lb_wdata                   (lb_wdata       ),
    .lb_addr                    (lb_addr        ),
    .lb_rdata                   (lb_rdata       ),
    .lb_valid                   (lb_valid       ),
    .lb_wack                    (lb_wack        ),

    .drp_addr                   (drp_addr       ),
    .drp_en                     (drp_en         ),
    .drp_we                     (drp_we         ),
    .drp_rdy                    (drp_rdy        ),
    .drp_in                     (drp_in         ),
    .drp_out                    (drp_out        ));
*/

//================================================================================
//  Module Definition
//================================================================================
module lb2drp #(
    parameter LB_DATA_WIDTH             = 32,
    parameter LB_ADDR_WIDTH             = 32,
    parameter DRP_DATA_WIDTH            = 16,
    parameter DRP_ADDR_WIDTH            = 7
)(
    input                               clk,
    input                               rst_n,

    input                               lb_rden,
    input                               lb_wren,
    input   [LB_DATA_WIDTH-1:0]         lb_wdata,
    input   [LB_ADDR_WIDTH-1:0]         lb_addr,
    output  reg [LB_DATA_WIDTH-1:0]     lb_rdata,
    output  reg                         lb_valid,
    output  reg                         lb_wrack,

    output  reg [DRP_ADDR_WIDTH-1:0]    drp_addr,
    output  reg                         drp_en,
    output  reg                         drp_we,
    input                               drp_rdy,
    output  reg [DRP_DATA_WIDTH-1:0]    drp_in,
    input   [DRP_DATA_WIDTH-1:0]        drp_out
);

    localparam MIN_DATA_WIDTH = LB_DATA_WIDTH > DRP_DATA_WIDTH ? DRP_DATA_WIDTH : LB_DATA_WIDTH;
    localparam MIN_ADDR_WIDTH = LB_ADDR_WIDTH > DRP_ADDR_WIDTH ? DRP_ADDR_WIDTH : LB_ADDR_WIDTH;

    reg     [1:0]                       drp_enseq;
    reg                                 drp_wflag;
    reg                                 drp_start;
    reg                                 drp_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lb_rdata <= {LB_DATA_WIDTH{1'b0}};
            lb_valid <= 1'b0;
            lb_wack <= 1'b0;
            drp_enseq <= 2'b0;
            drp_start <= 1'b0;
            drp_wflag <= 1'b0;
            drp_en <= 1'b0;
            drp_we <= 1'b0;
            drp_in <= {DRP_DATA_WIDTH{1'b0}};
            drp_addr <= {DRP_ADDR_WIDTH{1'b0}};
            drp_busy <= 1'b0;
        end else begin
            lb_rdata <= drp_out[MIN_DATA_WIDTH-1:0];
            lb_valid <= drp_rdy;
            lb_wrack <= drp_rdy;
            drp_enseq <= {drp_enseq[0], lb_rden | lb_wren};
            drp_start <= ~drp_busy & drp_enseq == 2'b01;
            drp_wflag <= drp_start & drp_wflag ? 1'b0 : lb_wren ? 1'b1 : drp_wflag;
            drp_en <= drp_start;
            drp_we <= drp_start & drp_wflag;
            drp_in <= lb_wdata[MIN_DATA_WIDTH-1:0];
            drp_addr <= lb_addr[MIN_ADDR_WIDTH-1:0];
            drp_busy <= drp_start ? 1'b1 : drp_rdy ? 1'b0 : drp_busy;
        end
    end

endmodule
