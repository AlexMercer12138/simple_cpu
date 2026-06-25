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
//  Module      : lb2axi_lite
//  Description : Local bus to AXI-Lite bridge adapter
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================

//================================================================================
//  Instantiation Template
//================================================================================
/*
lb2axi_lite #(
    .LB_DATA_WIDTH              (32             ),
    .LB_ADDR_WIDTH              (32             ),
    .AXI_DATA_WIDTH             (32             ),
    .AXI_ADDR_WIDTH             (8              ))
u_lb2axi_lite (
    .clk                        (clk            ),
    .rst_n                      (rst_n          ),

    .lb_rden                    (lb_rden        ),
    .lb_wren                    (lb_wren        ),
    .lb_wdata                   (lb_wdata       ),
    .lb_addr                    (lb_addr        ),
    .lb_rdata                   (lb_rdata       ),
    .lb_valid                   (lb_valid       ),
    .lb_wrack                   (lb_wrack       ),

    .m_axi_awvalid              (m_axi_awvalid  ),
    .m_axi_awready              (m_axi_awready  ),
    .m_axi_awaddr               (m_axi_awaddr   ),
    .m_axi_wvalid               (m_axi_wvalid   ),
    .m_axi_wready               (m_axi_wready   ),
    .m_axi_wdata                (m_axi_wdata    ),
    .m_axi_wstrb                (m_axi_wstrb    ),
    .m_axi_bvalid               (m_axi_bvalid   ),
    .m_axi_bready               (m_axi_bready   ),
    .m_axi_bresp                (m_axi_bresp    ),
    .m_axi_arvalid              (m_axi_arvalid  ),
    .m_axi_arready              (m_axi_arready  ),
    .m_axi_araddr               (m_axi_araddr   ),
    .m_axi_rvalid               (m_axi_rvalid   ),
    .m_axi_rready               (m_axi_rready   ),
    .m_axi_rdata                (m_axi_rdata    ),
    .m_axi_rresp                (m_axi_rresp    ));
*/

//================================================================================
//  Module Definition
//================================================================================

module lb2axi_lite #(
    parameter LB_DATA_WIDTH             = 32,
    parameter LB_ADDR_WIDTH             = 32,
    parameter AXI_DATA_WIDTH            = 32,
    parameter AXI_ADDR_WIDTH            = 8
)(
    input                               clk,
    input                               rst_n,

    input                               lb_rden,
    input                               lb_wren,
    input   [LB_DATA_WIDTH-1:0]         lb_wdata,
    input   [LB_ADDR_WIDTH-1:0]         lb_addr,
    output  [LB_DATA_WIDTH-1:0]         lb_rdata,
    output                              lb_valid,
    output                              lb_wrack,

    output                              m_axi_awvalid,
    input                               m_axi_awready,
    output  [AXI_ADDR_WIDTH-1:0]        m_axi_awaddr,

    output                              m_axi_wvalid,
    input                               m_axi_wready,
    output  [AXI_DATA_WIDTH-1:0]        m_axi_wdata,
    output  [(AXI_DATA_WIDTH/8)-1:0]    m_axi_wstrb,

    input                               m_axi_bvalid,
    output                              m_axi_bready,
    input   [1:0]                       m_axi_bresp,

    output                              m_axi_arvalid,
    input                               m_axi_arready,
    output  [AXI_ADDR_WIDTH-1:0]        m_axi_araddr,

    input                               m_axi_rvalid,
    output                              m_axi_rready,
    input   [AXI_DATA_WIDTH-1:0]        m_axi_rdata,
    input   [1:0]                       m_axi_rresp
);

    localparam MIN_DATA_WIDTH = LB_DATA_WIDTH > AXI_DATA_WIDTH ? AXI_DATA_WIDTH : LB_DATA_WIDTH;
    localparam MIN_ADDR_WIDTH = LB_ADDR_WIDTH > AXI_ADDR_WIDTH ? AXI_ADDR_WIDTH : LB_ADDR_WIDTH;
    localparam ADDR_LSB = (AXI_DATA_WIDTH / 32) + 1;

    reg                                 axi_awvalid;
    reg     [AXI_ADDR_WIDTH-1:0]        axi_awaddr;
    reg                                 axi_wvalid;
    reg     [AXI_DATA_WIDTH-1:0]        axi_wdata;
    reg     [(AXI_DATA_WIDTH/8)-1:0]    axi_wstrb;
    reg                                 axi_arvalid;
    reg     [AXI_ADDR_WIDTH-1:0]        axi_araddr;
    reg                                 axi_bready;
    reg                                 axi_rready;

    reg                                 wr_ack;
    reg                                 rd_valid;
    reg     [LB_DATA_WIDTH-1:0]         rd_data;

    assign m_axi_awvalid = axi_awvalid;
    assign m_axi_awaddr = axi_awaddr;
    assign m_axi_wvalid = axi_wvalid;
    assign m_axi_wdata = axi_wdata;
    assign m_axi_arvalid = axi_arvalid;
    assign m_axi_araddr = axi_araddr;
    assign m_axi_wstrb = axi_wstrb;
    assign m_axi_bready = axi_bready;
    assign m_axi_rready = axi_rready;

    assign lb_rdata = rd_data;
    assign lb_valid = rd_valid;
    assign lb_wrack = wr_ack;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awvalid <= 1'b0;
            axi_bready <= 1'b0;
            axi_wvalid <= 1'b0;
            axi_awaddr <= {AXI_ADDR_WIDTH{1'b0}};
            axi_wdata <= {AXI_DATA_WIDTH{1'b0}};
            axi_wstrb <= {(AXI_DATA_WIDTH/8){1'b0}};
        end else begin
            axi_awvalid <= m_axi_awvalid & m_axi_awready ? 1'b0 : lb_wren ? 1'b1 : axi_awvalid;
            axi_bready <= m_axi_bvalid & m_axi_bready ? 1'b0 : lb_wren ? 1'b1 : axi_bready;
            axi_wvalid <= m_axi_wvalid & m_axi_wready ? 1'b0 : lb_wren ? 1'b1 : axi_wvalid;
            axi_awaddr <= lb_addr[MIN_ADDR_WIDTH-1:0];
            axi_wdata <= lb_wdata[MIN_DATA_WIDTH-1:0];
            axi_wstrb <= {(AXI_DATA_WIDTH/8){1'b1}} << (lb_addr[ADDR_LSB-1:0]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arvalid <= 1'b0;
            axi_rready <= 1'b0;
            axi_araddr <= {AXI_ADDR_WIDTH{1'b0}};
        end else begin
            axi_arvalid <= m_axi_arvalid & m_axi_arready ? 1'b0 : lb_rden ? 1'b1 : axi_arvalid;
            axi_rready <= m_axi_rvalid & m_axi_rready ? 1'b0 : lb_rden ? 1'b1 : axi_rready;
            axi_araddr <= lb_addr[MIN_ADDR_WIDTH-1:0];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ack <= 1'b0;
            rd_valid <= 1'b0;
            rd_data <= {LB_DATA_WIDTH{1'b0}};
        end else begin
            wr_ack <= m_axi_bvalid & m_axi_bready;
            rd_valid <= m_axi_rvalid & m_axi_rready;
            rd_data <= m_axi_rvalid & m_axi_rready ? m_axi_rdata[MIN_DATA_WIDTH-1:0] : rd_data;
        end
    end

endmodule
