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
//  Module      : lb2wishbone
//  Description : Local bus to Wishbone B4 classic bridge adapter
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
lb2wishbone #(
    .LB_DATA_WIDTH              (32             ),
    .LB_ADDR_WIDTH              (32             ),
    .WB_DATA_WIDTH              (32             ),
    .WB_ADDR_WIDTH              (8              ))
u_lb2wishbone (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .lb_rden                    (lb_rden        ),
    .lb_wren                    (lb_wren        ),
    .lb_wdata                   (lb_wdata       ),
    .lb_addr                    (lb_addr        ),
    .lb_rdata                   (lb_rdata       ),
    .lb_valid                   (lb_valid       ),
    .lb_wack                    (lb_wack        ),

    .m_wb_cyc_o                 (m_wb_cyc_o     ),
    .m_wb_stb_o                 (m_wb_stb_o     ),
    .m_wb_we_o                  (m_wb_we_o      ),
    .m_wb_adr_o                 (m_wb_adr_o     ),
    .m_wb_dat_o                 (m_wb_dat_o     ),
    .m_wb_sel_o                 (m_wb_sel_o     ),
    .m_wb_ack_i                 (m_wb_ack_i     ),
    .m_wb_dat_i                 (m_wb_dat_i     ));
*/

//================================================================================
//  Module Definition
//================================================================================
module lb2wbc #(
    parameter LB_DATA_WIDTH             = 32,
    parameter LB_ADDR_WIDTH             = 32,
    parameter WB_DATA_WIDTH             = 32,
    parameter WB_ADDR_WIDTH             = 8
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

    output  reg                         m_wb_cyc_o,
    output  reg                         m_wb_stb_o,
    output  reg                         m_wb_we_o,
    output  reg [WB_ADDR_WIDTH-1:0]     m_wb_adr_o,
    output  reg [WB_DATA_WIDTH-1:0]     m_wb_dat_o,
    output  reg [(WB_DATA_WIDTH/8)-1:0] m_wb_sel_o,
    input                               m_wb_ack_i,
    input   [WB_DATA_WIDTH-1:0]         m_wb_dat_i
);

    localparam MIN_DATA_WIDTH = LB_DATA_WIDTH > WB_DATA_WIDTH ? WB_DATA_WIDTH : LB_DATA_WIDTH;
    localparam MIN_ADDR_WIDTH = LB_ADDR_WIDTH > WB_ADDR_WIDTH ? WB_ADDR_WIDTH : LB_ADDR_WIDTH;
    localparam ADDR_LSB = (AXI_DATA_WIDTH / 32) + 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_wb_cyc_o <= 1'b0;
            m_wb_stb_o <= 1'b0;
            m_wb_we_o <= 1'b0;
            m_wb_adr_o <= {WB_ADDR_WIDTH{1'b0}};
            m_wb_dat_o <= {WB_DATA_WIDTH{1'b0}};
            m_wb_sel_o <= {(WB_DATA_WIDTH/8){1'b0}};
        end else begin
            m_wb_cyc_o <= lb_rden | lb_wren ? 1'b1 : m_wb_cyc_o & m_wb_stb_o & m_wb_ack_i ? 1'b0 : m_wb_cyc_o;
            m_wb_stb_o <= lb_rden | lb_wren ? 1'b1 : m_wb_cyc_o & m_wb_stb_o & m_wb_ack_i ? 1'b0 : m_wb_stb_o;
            m_wb_we_o <= lb_wren ? 1'b1 : lb_rden ? 1'b0 : m_wb_we_o;
            m_wb_adr_o <= lb_addr[MIN_ADDR_WIDTH-1:0];
            m_wb_dat_o <= lb_wdata[MIN_DATA_WIDTH-1:0];
            m_wb_sel_o <= {(WB_DATA_WIDTH/8){1'b1}} << (lb_addr[ADDR_LSB-1:0]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lb_rdata <= {LB_DATA_WIDTH{1'b0}};
            lb_valid <= 1'b0;
            lb_wrack <= 1'b0;
        end else begin
            lb_rdata <= m_wb_dat_i[MIN_DATA_WIDTH-1:0];
            lb_valid <= m_wb_cyc_o & m_wb_stb_o & m_wb_ack_i & ~m_wb_sel_o;
            lb_wrack <= m_wb_cyc_o & m_wb_stb_o & m_wb_ack_i & m_wb_sel_o;
        end
    end

endmodule
