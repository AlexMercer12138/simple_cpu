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
//  Module      : can_fifo
//  Description : Small CAN frame FIFO
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

module can_fifo #(
    parameter FIFO_DEPTH = 4
)(
    input   wire            clk,
    input   wire            rst_n,

    input   wire            wr_en,
    input   wire    [28:0]  wr_id,
    input   wire            wr_ide,
    input   wire            wr_rtr,
    input   wire    [3:0]   wr_dlc,
    input   wire    [63:0]  wr_data,

    input   wire            rd_en,
    output  wire            rd_valid,
    output  wire    [28:0]  rd_id,
    output  wire            rd_ide,
    output  wire            rd_rtr,
    output  wire    [3:0]   rd_dlc,
    output  wire    [63:0]  rd_data,

    output  wire            full,
    output  wire            empty,
    output  reg     [2:0]   count
);

    reg     [1:0]           wr_ptr;
    reg     [1:0]           rd_ptr;
    reg     [28:0]          id_mem   [0:3];
    reg                     ide_mem  [0:3];
    reg                     rtr_mem  [0:3];
    reg     [3:0]           dlc_mem  [0:3];
    reg     [63:0]          data_mem [0:3];
    integer                 i;

    wire                    do_write;
    wire                    do_read;

    assign full     = count == FIFO_DEPTH[2:0];
    assign empty    = count == 3'd0;
    assign rd_valid = ~empty;
    assign rd_id    = id_mem[rd_ptr];
    assign rd_ide   = ide_mem[rd_ptr];
    assign rd_rtr   = rtr_mem[rd_ptr];
    assign rd_dlc   = dlc_mem[rd_ptr];
    assign rd_data  = data_mem[rd_ptr];
    assign do_write = wr_en & ~full;
    assign do_read  = rd_en & ~empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 2'd0;
        end else if (do_write) begin
            wr_ptr <= wr_ptr + 2'd1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= 2'd0;
        end else if (do_read) begin
            rd_ptr <= rd_ptr + 2'd1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 3'd0;
        end else begin
            case ({do_write, do_read})
                2'b10: count <= count + 3'd1;
                2'b01: count <= count - 3'd1;
                default: count <= count;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) begin
                id_mem[i]   <= 29'd0;
                ide_mem[i]  <= 1'b0;
                rtr_mem[i]  <= 1'b0;
                dlc_mem[i]  <= 4'd0;
                data_mem[i] <= 64'd0;
            end
        end else if (do_write) begin
            id_mem[wr_ptr]   <= wr_id;
            ide_mem[wr_ptr]  <= wr_ide;
            rtr_mem[wr_ptr]  <= wr_rtr;
            dlc_mem[wr_ptr]  <= wr_dlc;
            data_mem[wr_ptr] <= wr_data;
        end
    end

endmodule
