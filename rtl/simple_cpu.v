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
//  Module      : Simple CPU
//  Description : Lightweight 32-bit RISC CPU Core
//  Wechat      : zxw895674551
//  Email       : alexmercer@outlook.com
//--------------------------------------------------------------------------------
//  Copyright (c) 2025 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//================================================================================


module simple_cpu(
    input                               clk,
    input                               rst_n,

    output  reg [7:0]                   prog_addr,
    input       [31:0]                  prog_data,

    output  reg                         m_axi_awvalid,
    input                               m_axi_awready,
    output  reg [31:0]                  m_axi_awaddr,

    output  reg                         m_axi_wvalid,
    input                               m_axi_wready,
    output  reg [31:0]                  m_axi_wdata,
    output  reg [3:0]                   m_axi_wstrb,

    input                               m_axi_bvalid,
    output  reg                         m_axi_bready,
    input       [1:0]                   m_axi_bresp,

    output  reg                         m_axi_arvalid,
    input                               m_axi_arready,
    output  reg [31:0]                  m_axi_araddr,

    input                               m_axi_rvalid,
    output  reg                         m_axi_rready,
    input       [1:0]                   m_axi_rresp,
    input       [31:0]                  m_axi_rdata
    );

    localparam  SET                     = 4'b0000;
    localparam  ADD                     = 4'b0001;
    localparam  SUB                     = 4'b0010;
    localparam  AND                     = 4'b0011;
    localparam  OR                      = 4'b0100;
    localparam  XOR                     = 4'b0101;
    localparam  SLL                     = 4'b0110;
    localparam  SRL                     = 4'b0111;
    localparam  MWR                     = 4'b1000;
    localparam  MRD                     = 4'b1001;
    localparam  JAL                     = 4'b1010;
    localparam  JALR                    = 4'b1011;
    localparam  BEQ                     = 4'b1100;
    localparam  BNE                     = 4'b1101;
    localparam  BLT                     = 4'b1110;
    localparam  BGE                     = 4'b1111;

    reg                                 prog_load;
    reg                                 prog_exec;
    reg                                 prog_busy;
    reg     [7:0]                       prog_next;
    reg                                 prog_step;

    reg     [31:0]                      regi_int    [0:15];

    wire    [19:0]                      immediate;
    wire    [3:0]                       reg_src_1;
    wire    [3:0]                       reg_src_2;
    wire    [3:0]                       reg_dest;
    wire    [3:0]                       opcode;

    assign  immediate = prog_data[31:12];
    assign  reg_src_1 = prog_data[15:12];
    assign  reg_src_2 = prog_data[11:8];
    assign  reg_dest = prog_data[7:4];
    assign  opcode = prog_data[3:0];

    always @(posedge clk) begin
        if(!rst_n) begin
            prog_addr <= 0;
            prog_load <= 0;
            prog_exec <= 0;
            prog_busy <= 0;
        end else begin
            prog_addr <= prog_step ? prog_next : prog_addr;
            prog_load <= ~prog_busy | prog_step;
            prog_exec <= prog_load;
            prog_busy <= 1'b1;
        end
    end

    always @(posedge clk) begin : main
        integer i;
        if(!rst_n) begin
            prog_next <= 0;
            prog_step <= 0;
            for (i = 0;i < 16;i = i + 1) begin
                regi_int[i] <= 0;
            end
        end else if(prog_busy) begin
            case(opcode)
                SET:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? immediate : regi_int[reg_dest];
                end
                ADD:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] + regi_int[reg_src_1] : regi_int[reg_dest];
                end
                SUB:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] - regi_int[reg_src_1] : regi_int[reg_dest];
                end
                AND:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] & regi_int[reg_src_1] : regi_int[reg_dest];
                end
                OR:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] | regi_int[reg_src_1] : regi_int[reg_dest];
                end
                XOR:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] ^ regi_int[reg_src_1] : regi_int[reg_dest];
                end
                SLL:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] << regi_int[reg_src_1] : regi_int[reg_dest];
                end
                SRL:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    regi_int[reg_dest] <= prog_exec ? regi_int[reg_src_2] >> regi_int[reg_src_1] : regi_int[reg_dest];
                end
                MWR:begin
                    prog_step <= m_axi_bvalid & m_axi_bready;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    m_axi_awvalid <= prog_exec ? 1 : m_axi_awvalid & m_axi_awready ? 0 : m_axi_awvalid;
                    m_axi_wvalid <= prog_exec ? 1 : m_axi_wvalid & m_axi_wready ? 0 : m_axi_wvalid;
                    m_axi_bready <= prog_exec ? 1 : m_axi_bvalid & m_axi_bready ? 0 : m_axi_bready;
                    m_axi_awaddr <= prog_exec ? regi_int[reg_src_1] : m_axi_awaddr;
                    m_axi_wdata <= prog_exec ? regi_int[reg_src_2] : m_axi_wdata;
                    m_axi_wstrb <= prog_exec ? 4'b1111 : m_axi_wstrb;
                end
                MRD:begin
                    prog_step <= m_axi_rvalid & m_axi_rready;
                    prog_next <= prog_exec ? prog_addr + 1 : prog_next;
                    m_axi_arvalid <= prog_exec ? 1 : m_axi_arvalid & m_axi_arready ? 0 : m_axi_arvalid;
                    m_axi_rready <= prog_exec ? 1 : m_axi_rvalid & m_axi_rready ? 0 : m_axi_rready;
                    m_axi_araddr <= prog_exec ? regi_int[reg_src_1] : m_axi_araddr;
                    regi_int[reg_dest] <= m_axi_rvalid & m_axi_rready ? m_axi_rdata : regi_int[reg_dest];
                end
                JAL:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? immediate : prog_next;
                    regi_int[reg_dest] <= prog_exec ? prog_addr + 1 : regi_int[reg_dest];
                end
                JALR:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? regi_int[reg_src_1] : prog_next;
                    regi_int[reg_dest] <= prog_exec ? prog_addr + 1 : regi_int[reg_dest];
                end
                BEQ:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? (regi_int[reg_src_2] == regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                end
                BNE:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? (regi_int[reg_src_2] != regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                end
                BLT:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? (regi_int[reg_src_2] < regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                end
                BGE:begin
                    prog_step <= prog_exec;
                    prog_next <= prog_exec ? (regi_int[reg_src_2] >= regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                end
            endcase
        end
    end

endmodule
