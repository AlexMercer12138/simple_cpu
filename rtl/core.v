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


module merc32_core(
    input                               clk,
    input                               rst_n,

    input                               interrupt,

    output                              prog_load,
    output  reg [15:0]                  prog_addr,
    input       [31:0]                  prog_data,

    output  reg                         lb_rden,
    output  reg                         lb_wren,
    output  reg [31:0]                  lb_addr,
    output  reg [31:0]                  lb_wdata,
    input                               lb_wrack,
    input   [31:0]                      lb_rdata,
    input                               lb_valid
    );

    localparam  OP_IMMEDIATE            = 4'b0001;
    localparam  OP_REGISTER             = 4'b0010;

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
    localparam  FUNC_JAL                = 4'b1011;
    localparam  FUNC_BEQ                = 4'b1100;
    localparam  FUNC_BNE                = 4'b1101;
    localparam  FUNC_BLT                = 4'b1110;
    localparam  FUNC_BGE                = 4'b1111;

    localparam  ST_IDLE                 = 5'b00001;
    localparam  ST_LOAD                 = 5'b00010;
    localparam  ST_EXEC                 = 5'b00100;
    localparam  ST_STEP                 = 5'b01000;
    localparam  ST_INTR                 = 5'b10000;

    reg     [4:0]                       cpu_state;
    reg     [15:0]                      prog_next;

    reg                                 alu_vld;
    reg     [3:0]                       alu_ptr;
    reg     signed  [31:0]              alu_data;

    wire                                trig_en;
    wire    [1:0]                       trig_mode;
    reg                                 intr_flag;
    wire    [15:0]                      intr_addr;
    wire    [15:0]                      ret_addr;

    reg     signed  [31:0]              regi_int    [0:15];

    wire    [15:0]                      immediate;
    wire    [3:0]                       reg_src_1;
    wire    [3:0]                       reg_src_2;
    wire    [3:0]                       reg_dest;
    wire    [3:0]                       opcode;
    wire    [3:0]                       funct;

    wire                                prog_busy;
    wire                                prog_exec;
    wire                                prog_step;

    assign  immediate                   = prog_data[31:16];
    assign  reg_src_1                   = prog_data[19:16];
    assign  reg_src_2                   = prog_data[15:12];
    assign  reg_dest                    = prog_data[11:8];
    assign  opcode                      = prog_data[7:4];
    assign  funct                       = prog_data[3:0];

    assign  prog_busy = cpu_state != ST_IDLE;
    assign  prog_load = cpu_state == ST_LOAD;
    assign  prog_exec = cpu_state == ST_EXEC;
    assign  prog_step = 
        funct == FUNC_MWR ? lb_wrack : 
        funct == FUNC_MRD ? lb_valid : 
        cpu_state == ST_STEP;

    assign  trig_en                     = regi_int[1][0];
    assign  trig_mode                   = regi_int[1][2:1];
    assign  intr_addr                   = regi_int[2][31:16];
    assign  ret_addr                    = regi_int[2][15:0];

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
            prog_next <= 0;
        end else begin
            prog_addr <= prog_step ? (intr_flag ? intr_addr : prog_next) : prog_addr;
            case({opcode, funct})
                {OP_IMMEDIATE, FUNC_JAL}:prog_next <= prog_exec ? immediate : prog_next;
                {OP_IMMEDIATE, FUNC_BEQ}:prog_next <= prog_exec ? (regi_int[reg_src_2] == regi_int[reg_dest] ? immediate : prog_addr + 1) : prog_next;
                {OP_IMMEDIATE, FUNC_BNE}:prog_next <= prog_exec ? (regi_int[reg_src_2] != regi_int[reg_dest] ? immediate : prog_addr + 1) : prog_next;
                {OP_IMMEDIATE, FUNC_BLT}:prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) < $signed(regi_int[reg_dest]) ? immediate : prog_addr + 1) : prog_next;
                {OP_IMMEDIATE, FUNC_BGE}:prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) >= $signed(regi_int[reg_dest]) ? immediate : prog_addr + 1) : prog_next;
                {OP_REGISTER, FUNC_JAL}:prog_next <= prog_exec ? regi_int[reg_src_1] : prog_next;
                {OP_REGISTER, FUNC_BEQ}:prog_next <= prog_exec ? (regi_int[reg_src_2] == regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                {OP_REGISTER, FUNC_BNE}:prog_next <= prog_exec ? (regi_int[reg_src_2] != regi_int[reg_dest] ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                {OP_REGISTER, FUNC_BLT}:prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) < $signed(regi_int[reg_dest]) ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                {OP_REGISTER, FUNC_BGE}:prog_next <= prog_exec ? ($signed(regi_int[reg_src_2]) >= $signed(regi_int[reg_dest]) ? regi_int[reg_src_1] : prog_addr + 1) : prog_next;
                default:prog_next <= prog_exec ? prog_addr + 1 : prog_next;
            endcase
        end
    end

    always @(posedge clk) begin : main
        if(!rst_n) begin
            alu_vld <= 1'b0;
            alu_ptr <= 4'd0;
            alu_data <= 32'h0;
        end else if(prog_busy) begin
            alu_ptr <= reg_dest;
            case({opcode, funct})
                {OP_IMMEDIATE, FUNC_SET}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_ADD}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] + immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_SUB}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] - immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_AND}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] & immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_OR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] | immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_XOR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] ^ immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_SLL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] << immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_SRL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] >> immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_SRA}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] >>> immediate : alu_data;
                end
                {OP_IMMEDIATE, FUNC_MRD}:begin
                    alu_vld <= lb_valid;
                    alu_data <= lb_valid ? lb_rdata : alu_data;
                end
                {OP_IMMEDIATE, FUNC_JAL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? prog_addr + 1 : alu_data;
                end
                {OP_REGISTER, FUNC_SET}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_ADD}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] + regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_SUB}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] - regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_AND}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] & regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_OR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] | regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_XOR}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] ^ regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_SLL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] << regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_SRL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] >> regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_SRA}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? regi_int[reg_src_2] >>> regi_int[reg_src_1] : alu_data;
                end
                {OP_REGISTER, FUNC_MRD}:begin
                    alu_vld <= lb_valid;
                    alu_data <= lb_valid ? lb_rdata : alu_data;
                end
                {OP_REGISTER, FUNC_JAL}:begin
                    alu_vld <= prog_exec;
                    alu_data <= prog_exec ? prog_addr + 1 : alu_data;
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
                4'hf:regi_int[15] <= alu_data;
            endcase
        end else begin
            regi_int[00] <= 32'h0;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            intr_flag <= 1'b0;
        end else if(prog_step) begin
            intr_flag <= 1'b0;
        end else if(intr_trig) begin
            intr_flag <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            lb_wren <= 0;
            lb_rden <= 0;
            lb_addr <= 0;
            lb_wdata <= 0;
        end else begin
            lb_wren <= funct == FUNC_MWR && prog_exec;
            lb_rden <= funct == FUNC_MRD && prog_exec;
            lb_wdata <= funct == FUNC_MWR && prog_exec ? regi_int[reg_dest] : lb_wdata;
            lb_addr <= 
                opcode == OP_IMMEDIATE ? regi_int[reg_src_2] + immediate : 
                opcode == OP_REGISTER ?  regi_int[reg_src_2] + regi_int[reg_src_1] : lb_addr;
        end
    end

intc                        u_intc (
    .clk                    (clk            ),
    .rst_n                  (rst_n          ),
    .interrupt              (interrupt      ),
    .trig_en                (trig_en        ),
    .trig_mode              (trig_mode      ),
    .intr_trig              (intr_trig      ));

endmodule
