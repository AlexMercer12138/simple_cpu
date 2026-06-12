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
//  Module      : MERC32_top
//  Description : MERC32 CPU top-level wrapper with selectable bus interface.
//                Six interfaces are mutually exclusive. Selection priority
//                (high to low) when multiple macros are defined:
//                  IF_AXI_LITE > IF_APB > IF_WBC > IF_AVALON > IF_DRP > IF_LB
//                All ports are fixed to 32-bit; external logic should truncate
//                as needed.
//  Wechat      : zxw895674551
//  Email       : alexmercer@outlook.com
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================
// `define IF_AXI_LITE
`define IF_APB
// `define IF_WBC
// `define IF_AVALON
// `define IF_DRP

module MERC32_top (
    input                               clk,
    input                               rst_n,

    input                               interrupt,

    output                              prog_load,
    output  [15:0]                      prog_addr,
    input   [31:0]                      prog_data

`ifdef IF_AXI_LITE
    ,
    output                              m_axi_awvalid,
    input                               m_axi_awready,
    output  [31:0]                      m_axi_awaddr,
    output                              m_axi_wvalid,
    input                               m_axi_wready,
    output  [31:0]                      m_axi_wdata,
    output  [3:0]                       m_axi_wstrb,
    input                               m_axi_bvalid,
    output                              m_axi_bready,
    input   [1:0]                       m_axi_bresp,
    output                              m_axi_arvalid,
    input                               m_axi_arready,
    output  [31:0]                      m_axi_araddr,
    input                               m_axi_rvalid,
    output                              m_axi_rready,
    input   [31:0]                      m_axi_rdata,
    input   [1:0]                       m_axi_rresp
`elsif IF_APB
    ,
    output                              m_apb_psel,
    output                              m_apb_penable,
    output  [31:0]                      m_apb_paddr,
    output                              m_apb_pwrite,
    output  [31:0]                      m_apb_pwdata,
    input   [31:0]                      m_apb_prdata,
    input                               m_apb_pready
`elsif IF_WBC
    ,
    output                              m_wb_cyc_o,
    output                              m_wb_stb_o,
    output                              m_wb_we_o,
    output  [31:0]                      m_wb_adr_o,
    output  [31:0]                      m_wb_dat_o,
    output  [3:0]                       m_wb_sel_o,
    input                               m_wb_ack_i,
    input   [31:0]                      m_wb_dat_i
`elsif IF_AVALON
    ,
    output  [31:0]                      m_av_address,
    output                              m_av_read,
    output                              m_av_write,
    output  [31:0]                      m_av_writedata,
    output  [3:0]                       m_av_byteenable,
    input                               m_av_waitrequest,
    input   [31:0]                      m_av_readdata,
    input                               m_av_readdatavalid
`elsif IF_DRP
    ,
    output  [31:0]                      drp_addr,
    output                              drp_en,
    output                              drp_we,
    input                               drp_rdy,
    output  [31:0]                      drp_in,
    input   [31:0]                      drp_out
`else
    ,
    output                              lb_rden,
    output                              lb_wren,
    output  [31:0]                      lb_addr,
    output  [31:0]                      lb_wdata,
    input                               lb_wrack,
    input   [31:0]                      lb_rdata,
    input                               lb_valid
`endif
);

    //----------------------------------------------------------------------------
    // Internal Local Bus signals (CPU side)
    //----------------------------------------------------------------------------
    wire                                cpu_lb_rden;
    wire                                cpu_lb_wren;
    wire    [31:0]                      cpu_lb_addr;
    wire    [31:0]                      cpu_lb_wdata;
    wire                                cpu_lb_wrack;
    wire    [31:0]                      cpu_lb_rdata;
    wire                                cpu_lb_valid;

    //----------------------------------------------------------------------------
    // merc32_core instantiation
    //----------------------------------------------------------------------------
    merc32_core u_merc32_core (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .interrupt                      (interrupt      ),

        .prog_load                      (prog_load      ),
        .prog_addr                      (prog_addr      ),
        .prog_data                      (prog_data      ),

        .lb_rden                        (cpu_lb_rden    ),
        .lb_wren                        (cpu_lb_wren    ),
        .lb_addr                        (cpu_lb_addr    ),
        .lb_wdata                       (cpu_lb_wdata   ),
        .lb_wrack                       (cpu_lb_wrack   ),
        .lb_rdata                       (cpu_lb_rdata   ),
        .lb_valid                       (cpu_lb_valid   )
    );

    //----------------------------------------------------------------------------
    // Bus interface selection (mutually exclusive, priority based)
    //----------------------------------------------------------------------------
`ifdef IF_AXI_LITE
    lb2axi_lite #(
        .LB_DATA_WIDTH                  (32             ),
        .LB_ADDR_WIDTH                  (32             ),
        .AXI_DATA_WIDTH                 (32             ),
        .AXI_ADDR_WIDTH                 (32             ))
    u_lb2axi_lite (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .lb_rden                        (cpu_lb_rden    ),
        .lb_wren                        (cpu_lb_wren    ),
        .lb_wdata                       (cpu_lb_wdata   ),
        .lb_addr                        (cpu_lb_addr    ),
        .lb_rdata                       (cpu_lb_rdata   ),
        .lb_valid                       (cpu_lb_valid   ),
        .lb_wrack                       (cpu_lb_wrack   ),

        .m_axi_awvalid                  (m_axi_awvalid  ),
        .m_axi_awready                  (m_axi_awready  ),
        .m_axi_awaddr                   (m_axi_awaddr   ),
        .m_axi_wvalid                   (m_axi_wvalid   ),
        .m_axi_wready                   (m_axi_wready   ),
        .m_axi_wdata                    (m_axi_wdata    ),
        .m_axi_wstrb                    (m_axi_wstrb    ),
        .m_axi_bvalid                   (m_axi_bvalid   ),
        .m_axi_bready                   (m_axi_bready   ),
        .m_axi_bresp                    (m_axi_bresp    ),
        .m_axi_arvalid                  (m_axi_arvalid  ),
        .m_axi_arready                  (m_axi_arready  ),
        .m_axi_araddr                   (m_axi_araddr   ),
        .m_axi_rvalid                   (m_axi_rvalid   ),
        .m_axi_rready                   (m_axi_rready   ),
        .m_axi_rdata                    (m_axi_rdata    ),
        .m_axi_rresp                    (m_axi_rresp    ));
`elsif IF_APB
    lb2apb #(
        .LB_DATA_WIDTH                  (32             ),
        .LB_ADDR_WIDTH                  (32             ),
        .APB_DATA_WIDTH                 (32             ),
        .APB_ADDR_WIDTH                 (32             ))
    u_lb2apb (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .lb_rden                        (cpu_lb_rden    ),
        .lb_wren                        (cpu_lb_wren    ),
        .lb_wdata                       (cpu_lb_wdata   ),
        .lb_addr                        (cpu_lb_addr    ),
        .lb_rdata                       (cpu_lb_rdata   ),
        .lb_valid                       (cpu_lb_valid   ),
        .lb_wrack                       (cpu_lb_wrack   ),

        .m_apb_psel                     (m_apb_psel     ),
        .m_apb_penable                  (m_apb_penable  ),
        .m_apb_paddr                    (m_apb_paddr    ),
        .m_apb_pwrite                   (m_apb_pwrite   ),
        .m_apb_pwdata                   (m_apb_pwdata   ),
        .m_apb_prdata                   (m_apb_prdata   ),
        .m_apb_pready                   (m_apb_pready   ));
`elsif IF_WBC
    lb2wbc #(
        .LB_DATA_WIDTH                  (32             ),
        .LB_ADDR_WIDTH                  (32             ),
        .WB_DATA_WIDTH                  (32             ),
        .WB_ADDR_WIDTH                  (32             ))
    u_lb2wbc (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .lb_rden                        (cpu_lb_rden    ),
        .lb_wren                        (cpu_lb_wren    ),
        .lb_wdata                       (cpu_lb_wdata   ),
        .lb_addr                        (cpu_lb_addr    ),
        .lb_rdata                       (cpu_lb_rdata   ),
        .lb_valid                       (cpu_lb_valid   ),
        .lb_wrack                       (cpu_lb_wrack   ),

        .m_wb_cyc_o                     (m_wb_cyc_o     ),
        .m_wb_stb_o                     (m_wb_stb_o     ),
        .m_wb_we_o                      (m_wb_we_o      ),
        .m_wb_adr_o                     (m_wb_adr_o     ),
        .m_wb_dat_o                     (m_wb_dat_o     ),
        .m_wb_sel_o                     (m_wb_sel_o     ),
        .m_wb_ack_i                     (m_wb_ack_i     ),
        .m_wb_dat_i                     (m_wb_dat_i     ));
`elsif IF_AVALON
    lb2avalon #(
        .LB_DATA_WIDTH                  (32                 ),
        .LB_ADDR_WIDTH                  (32                 ),
        .AV_DATA_WIDTH                  (32                 ),
        .AV_ADDR_WIDTH                  (32                 ))
    u_lb2avalon (
        .clk                            (clk                ),
        .rst_n                          (rst_n              ),

        .lb_rden                        (cpu_lb_rden        ),
        .lb_wren                        (cpu_lb_wren        ),
        .lb_wdata                       (cpu_lb_wdata       ),
        .lb_addr                        (cpu_lb_addr        ),
        .lb_rdata                       (cpu_lb_rdata       ),
        .lb_valid                       (cpu_lb_valid       ),
        .lb_wrack                       (cpu_lb_wrack       ),

        .m_av_address                   (m_av_address       ),
        .m_av_read                      (m_av_read          ),
        .m_av_write                     (m_av_write         ),
        .m_av_writedata                 (m_av_writedata     ),
        .m_av_byteenable                (m_av_byteenable    ),
        .m_av_waitrequest               (m_av_waitrequest   ),
        .m_av_readdata                  (m_av_readdata      ),
        .m_av_readdatavalid             (m_av_readdatavalid ));
`elsif IF_DRP
    lb2drp #(
        .LB_DATA_WIDTH                  (32             ),
        .LB_ADDR_WIDTH                  (32             ),
        .DRP_DATA_WIDTH                 (32             ),
        .DRP_ADDR_WIDTH                 (32             ))
    u_lb2drp (
        .clk                            (clk            ),
        .rst_n                          (rst_n          ),

        .lb_rden                        (cpu_lb_rden    ),
        .lb_wren                        (cpu_lb_wren    ),
        .lb_wdata                       (cpu_lb_wdata   ),
        .lb_addr                        (cpu_lb_addr    ),
        .lb_rdata                       (cpu_lb_rdata   ),
        .lb_valid                       (cpu_lb_valid   ),
        .lb_wrack                       (cpu_lb_wrack   ),

        .drp_addr                       (drp_addr       ),
        .drp_en                         (drp_en         ),
        .drp_we                         (drp_we         ),
        .drp_rdy                        (drp_rdy        ),
        .drp_in                         (drp_in         ),
        .drp_out                        (drp_out        ));
`else
    assign lb_rden      = cpu_lb_rden;
    assign lb_wren      = cpu_lb_wren;
    assign lb_addr      = cpu_lb_addr;
    assign lb_wdata     = cpu_lb_wdata;
    assign cpu_lb_wrack = lb_wrack;
    assign cpu_lb_rdata = lb_rdata;
    assign cpu_lb_valid = lb_valid;
`endif

endmodule
