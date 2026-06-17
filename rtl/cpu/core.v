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
//  Module      : MERC32
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


module merc32_core #(
    // ILB/DLB address widths are word-address widths. The maximum supported
    // value is 16 because the MERC32 PC and local address fields are 16 bits.
    parameter   ILB_ADDR_WIDTH          = 16,
    parameter   DLB_ADDR_WIDTH          = 16
) (
    input                               clk,
    input                               rst_n,

    input                               interrupt,

    output                              dlb_en,
    output                              dlb_we,
    output      [DLB_ADDR_WIDTH-1:0]    dlb_addr,
    output      [31:0]                  dlb_wdata,
    input       [31:0]                  dlb_rdata,

    output                              ilb_en,
    output                              ilb_we,
    output      [ILB_ADDR_WIDTH-1:0]    ilb_addr,
    output      [31:0]                  ilb_wdata,
    input       [31:0]                  ilb_rdata,

    output                              plb_rden,
    output                              plb_wren,
    output      [31:0]                  plb_addr,
    output      [31:0]                  plb_wdata,
    input                               plb_wrack,
    input   [31:0]                      plb_rdata,
    input                               plb_valid
    );

    localparam  OP_IMM                  = 4'b0001;
    localparam  OP_REG                  = 4'b0010;

    localparam  FUNC_SET                = 4'b0000;
    localparam  FUNC_ADD                = 4'b0001;
    localparam  FUNC_SUB                = 4'b0010;
    localparam  FUNC_AND                = 4'b0011;
    localparam  FUNC_OR                 = 4'b0100;
    localparam  FUNC_XOR                = 4'b0101;
    localparam  FUNC_SLL                = 4'b0110;
    localparam  FUNC_SRL                = 4'b0111;
    localparam  FUNC_SRA                = 4'b1000;
    localparam  FUNC_MWR                = 4'b1001;
    localparam  FUNC_MRD                = 4'b1010;
    localparam  FUNC_CMP                = 4'b1011;
    localparam  FUNC_BRC                = 4'b1100;
    localparam  FUNC_JAL                = 4'b1101;

    localparam  ST_IDLE                 = 5'b00001;
    localparam  ST_LOAD                 = 5'b00010;
    localparam  ST_EXEC                 = 5'b00100;
    localparam  ST_STEP                 = 5'b01000;
    localparam  ST_INTR                 = 5'b10000;

    localparam  CMP_EQ                  = 4'd0;
    localparam  CMP_NE                  = 4'd1;
    localparam  CMP_SGE                 = 4'd2;
    localparam  CMP_SLT                 = 4'd3;
    localparam  CMP_SGT                 = 4'd4;
    localparam  CMP_SLE                 = 4'd5;
    localparam  CMP_UGE                 = 4'd6;
    localparam  CMP_ULT                 = 4'd7;
    localparam  CMP_UGT                 = 4'd8;
    localparam  CMP_ULE                 = 4'd9;

    localparam  TRIG_RISE               = 2'b00;
    localparam  TRIG_FALL               = 2'b01;
    localparam  TRIG_HIGH               = 2'b10;
    localparam  TRIG_LOW                = 2'b11;

    reg     [4:0]                       cpu_state;
    reg     [15:0]                      prog_addr;
    reg     [15:0]                      prog_next;

    reg                                 alu_vld;
    reg     [3:0]                       alu_ptr;
    reg     signed  [31:0]              alu_data;

    reg                                 uge;
    reg                                 ugt;
    reg                                 sge;
    reg                                 sgt;
    reg                                 eq;

    wire                                trig_en;
    wire    [1:0]                       trig_mode;
    wire                                trig_hit;
    wire    [15:0]                      intr_addr;
    wire    [15:0]                      ret_addr;

    reg                                 intr_ff0;
    reg                                 intr_ff1;
    reg                                 intr_ff2;
    reg                                 intr_flag;

    reg     signed  [31:0]              regi_int    [0:15];

    wire    [15:0]                      imm;
    wire    [3:0]                       rs1;
    wire    [3:0]                       rs2;
    wire    [3:0]                       rd;
    wire    [3:0]                       opc;
    wire    [3:0]                       fun;

    wire                                prog_exec;
    wire                                prog_step;
    wire                                inst_mwr;
    wire                                inst_mrd;
    reg                                 lb_req;
    reg                                 lb_wren;
    reg     [31:0]                      lb_addr;
    reg     [31:0]                      lb_wdata;
    wire    [31:0]                      lb_rdata;
    wire                                lb_rack;

    wire                                data_addr_hit;
    wire                                peri_addr_hit;
    wire                                miss_addr_hit;
    wire                                peri_done;

    reg                                 data_pending;
    reg                                 miss_pending;

    assign  imm = ilb_rdata[31:16];
    assign  rs1 = ilb_rdata[19:16];
    assign  rs2 = ilb_rdata[15:12];
    assign  rd  = ilb_rdata[11:8];
    assign  opc = ilb_rdata[7:4];
    assign  fun = ilb_rdata[3:0];
    
    assign  ilb_en    = cpu_state == ST_LOAD;
    assign  ilb_we    = 1'b0;
    assign  ilb_addr  = prog_addr;
    assign  ilb_wdata = 32'h0;

    assign  prog_exec = cpu_state == ST_EXEC;
    assign  inst_mwr  = ({opc, fun} == {OP_IMM, FUNC_MWR} || {opc, fun} == {OP_REG, FUNC_MWR});
    assign  inst_mrd  = ({opc, fun} == {OP_IMM, FUNC_MRD} || {opc, fun} == {OP_REG, FUNC_MRD});
    assign  prog_step = (inst_mwr || inst_mrd) ? lb_rack : cpu_state == ST_STEP;

    assign  data_addr_hit = (lb_addr >= 32'h0010_0000) && (lb_addr < (32'h0010_0000 + (32'd1 << (DLB_ADDR_WIDTH + 2))));
    assign  peri_addr_hit = lb_addr >= 32'h1000_0000;
    assign  miss_addr_hit = ~data_addr_hit & ~peri_addr_hit;
    assign  peri_done     = plb_valid | plb_wrack;

    assign  dlb_en        = lb_req & data_addr_hit;
    assign  dlb_we        = lb_req & data_addr_hit & lb_wren;
    assign  dlb_addr      = lb_addr[DLB_ADDR_WIDTH+1:2];
    assign  dlb_wdata     = lb_wdata;

    assign  plb_rden      = lb_req & peri_addr_hit & ~lb_wren;
    assign  plb_wren      = lb_req & peri_addr_hit & lb_wren;
    assign  plb_addr      = lb_addr;
    assign  plb_wdata     = lb_wdata;

    assign  lb_rack       = data_pending | miss_pending | peri_done;
    assign  lb_rdata      = data_pending ? dlb_rdata : plb_valid ? plb_rdata : 32'hdece;

    assign  trig_en   = regi_int[1][0];
    assign  trig_mode = regi_int[1][2:1];
    assign  intr_addr = regi_int[2][31:16];
    assign  ret_addr  = regi_int[2][15:0];
    assign  trig_hit  = 
        (trig_mode == TRIG_RISE) ?  intr_ff1 & ~intr_ff2 :
        (trig_mode == TRIG_FALL) ? ~intr_ff1 &  intr_ff2 :
        (trig_mode == TRIG_HIGH) ?  intr_ff2 :
        (trig_mode == TRIG_LOW)  ? ~intr_ff2 : 1'b0;

    always @(posedge clk) begin
        if(!rst_n) begin
            cpu_state <= ST_IDLE;
        end else begin
            case(cpu_state)
                ST_IDLE:cpu_state <= ST_LOAD;
                ST_LOAD:cpu_state <= ST_EXEC;
                ST_EXEC:cpu_state <= ST_STEP;
                ST_STEP:cpu_state <= prog_step ? (intr_flag ? ST_INTR : ST_LOAD) : ST_STEP;
                ST_INTR:cpu_state <= ST_LOAD;
                default:cpu_state <= ST_IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            prog_addr <= 0;
        end else if(prog_step) begin
            prog_addr <= intr_flag ? intr_addr : prog_next;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            prog_next <= 0;
        end else if(prog_exec) begin
            case({opc, fun})
                {OP_IMM, FUNC_BRC}:begin
                    case(rd)
                        CMP_EQ:prog_next <= eq ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_NE:prog_next <= ~eq ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_SGE:prog_next <= sge ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_SLT:prog_next <= ~sge ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_SGT:prog_next <= sgt ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_SLE:prog_next <= ~sgt ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_UGE:prog_next <= uge ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_ULT:prog_next <= ~uge ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_UGT:prog_next <= ugt ? regi_int[rs2] + imm : prog_addr + 1;
                        CMP_ULE:prog_next <= ~ugt ? regi_int[rs2] + imm : prog_addr + 1;
                        default:prog_next <= prog_addr + 1;
                    endcase
                end
                {OP_IMM, FUNC_JAL}:prog_next <= regi_int[rs2] + imm;
                {OP_REG, FUNC_BRC}:begin
                    case(rd)
                        CMP_EQ:prog_next <= eq ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_NE:prog_next <= ~eq ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_SGE:prog_next <= sge ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_SLT:prog_next <= ~sge ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_SGT:prog_next <= sgt ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_SLE:prog_next <= ~sgt ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_UGE:prog_next <= uge ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_ULT:prog_next <= ~uge ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_UGT:prog_next <= ugt ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        CMP_ULE:prog_next <= ~ugt ? regi_int[rs2] + regi_int[rs1] : prog_addr + 1;
                        default:prog_next <= prog_addr + 1;
                    endcase
                end
                {OP_REG, FUNC_JAL}:prog_next <= regi_int[rs2] + regi_int[rs1];
                default:prog_next <= prog_addr + 1;
            endcase
        end
    end

    always @(posedge clk) begin : main
        if(!rst_n) begin
            alu_vld <= 1'b0;
            alu_ptr <= 4'd0;
            alu_data <= 32'h0;
        end else begin
            alu_ptr <= rd;
            case({opc, fun})
                {OP_IMM, FUNC_SET}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? imm : alu_data;
                end
                {OP_IMM, FUNC_ADD}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] + imm : alu_data;
                end
                {OP_IMM, FUNC_SUB}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] - imm : alu_data;
                end
                {OP_IMM, FUNC_AND}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] & imm : alu_data;
                end
                {OP_IMM, FUNC_OR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] | imm : alu_data;
                end
                {OP_IMM, FUNC_XOR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] ^ imm : alu_data;
                end
                {OP_IMM, FUNC_SLL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] << imm : alu_data;
                end
                {OP_IMM, FUNC_SRL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] >> imm : alu_data;
                end
                {OP_IMM, FUNC_SRA}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] >>> imm : alu_data;
                end
                {OP_IMM, FUNC_MRD}:begin
                    alu_vld <= lb_rack;
                    alu_data <= lb_rack ? lb_rdata : alu_data;
                end
                {OP_IMM, FUNC_JAL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? prog_addr + 1 : alu_data;
                end
                {OP_REG, FUNC_SET}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_ADD}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] + regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_SUB}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] - regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_AND}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] & regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_OR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] | regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_XOR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] ^ regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_SLL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] << regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_SRL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] >> regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_SRA}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[rs2] >>> regi_int[rs1] : alu_data;
                end
                {OP_REG, FUNC_MRD}:begin
                    alu_vld <= lb_rack;
                    alu_data <= lb_rack ? lb_rdata : alu_data;
                end
                {OP_REG, FUNC_JAL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? prog_addr + 1 : alu_data;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            ugt <= 0;
            uge <= 0;
            sgt <= 0;
            sge <= 0;
            eq <= 0;
        end else if(prog_exec) begin
            case({opc, fun})
                {OP_IMM, FUNC_CMP}:begin
                    ugt <= $unsigned(regi_int[rs2]) > $unsigned(imm);
                    uge <= $unsigned(regi_int[rs2]) >= $unsigned(imm);
                    sgt <= $signed(regi_int[rs2]) > $signed(imm);
                    sge <= $signed(regi_int[rs2]) >= $signed(imm);
                    eq <= regi_int[rs2] == imm;
                end
                {OP_REG, FUNC_CMP}:begin
                    ugt <= $unsigned(regi_int[rs2]) > $unsigned(regi_int[rs1]);
                    uge <= $unsigned(regi_int[rs2]) >= $unsigned(regi_int[rs1]);
                    sgt <= $signed(regi_int[rs2]) > $signed(regi_int[rs1]);
                    sge <= $signed(regi_int[rs2]) >= $signed(regi_int[rs1]);
                    eq <= regi_int[rs2] == regi_int[rs1];
                end
            endcase
        end
    end

    always @(posedge clk) begin:register_files
        integer i;
        if(!rst_n) begin
            for (i = 0;i < 16;i = i + 1) begin
                regi_int[i] <= 0;
            end
        end else if(alu_vld) begin
            case (alu_ptr)
                4'h0:regi_int[00] <= regi_int[00];
                4'h1:regi_int[01] <= alu_data;
                4'h2:regi_int[02] <= {alu_data[31:16],prog_next};
                4'h3:regi_int[03] <= alu_data;
                4'h4:regi_int[04] <= alu_data;
                4'h5:regi_int[05] <= alu_data;
                4'h6:regi_int[06] <= alu_data;
                4'h7:regi_int[07] <= alu_data;
                4'h8:regi_int[08] <= alu_data;
                4'h9:regi_int[09] <= alu_data;
                4'ha:regi_int[10] <= alu_data;
                4'hb:regi_int[11] <= alu_data;
                4'hc:regi_int[12] <= alu_data;
                4'hd:regi_int[13] <= alu_data;
                4'he:regi_int[14] <= alu_data;
                4'hf:regi_int[15] <= regi_int[15];
            endcase
        end else begin
            regi_int[00] <= 32'h0;
            regi_int[15] <= {uge, ugt, sge, sgt, eq, 11'b0, prog_addr};
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            intr_ff0 <= 1'b0;
            intr_ff1 <= 1'b0;
            intr_ff2 <= 1'b0;
            intr_flag <= 1'b0;
        end else begin
            intr_ff0 <= interrupt;
            intr_ff1 <= intr_ff0;
            intr_ff2 <= intr_ff1;
            intr_flag <= trig_hit & trig_en ? 1'b1 : prog_step ? 1'b0 : intr_flag;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            lb_req <= 1'b0;
            lb_wren <= 1'b0;
            lb_addr <= 32'h0;
            lb_wdata <= 32'h0;
        end else begin
            lb_req <= (inst_mwr || inst_mrd) && prog_exec;
            lb_wren <= inst_mwr && prog_exec;
            lb_wdata <= regi_int[rd];
            lb_addr <=
                opc == OP_IMM ? regi_int[rs2] + imm :
                opc == OP_REG ? regi_int[rs2] + regi_int[rs1] :
                32'h0;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            data_pending <= 1'b0;
            miss_pending <= 1'b0;
        end else begin
            data_pending <= lb_req & data_addr_hit;
            miss_pending <= lb_req & miss_addr_hit;
        end
    end

endmodule
