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
//  Module      : can_rx
//  Description : CAN Classic receive path with de-stuffing and CRC check
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

module can_rx (
    input   wire            clk,
    input   wire            rst_n,

    input   wire            enable,
    input   wire            sample_tick,
    input   wire            can_rx,

    output  reg             frame_valid,
    output  reg     [28:0]  frame_id,
    output  reg             frame_ide,
    output  reg             frame_rtr,
    output  reg     [3:0]   frame_dlc,
    output  reg     [63:0]  frame_data,

    output  reg             crc_error,
    output  reg             stuff_error,
    output  reg             form_error
);

    localparam ST_IDLE      = 2'd0;
    localparam ST_DATA      = 2'd1;
    localparam ST_TAIL      = 2'd2;
    localparam ST_ERROR     = 2'd3;

    reg     [1:0]           state;
    reg     [127:0]         bit_store;
    reg     [7:0]           bit_cnt;
    reg     [7:0]           expected_total;
    reg     [7:0]           core_len;
    reg                     expected_known;
    reg                     ide_seen;
    reg     [3:0]           dlc_seen;
    reg                     last_bit;
    reg     [2:0]           same_cnt;
    reg     [3:0]           tail_cnt;
    reg                     form_error_work;

    wire    [3:0]           std_dlc_next;
    wire    [3:0]           ext_dlc_next;

    assign std_dlc_next = {bit_store[15], bit_store[16], bit_store[17], can_rx};
    assign ext_dlc_next = {bit_store[35], bit_store[36], bit_store[37], can_rx};

    function [14:0] crc15_next;
        input [14:0] crc_in;
        input        bit_in;
        reg          feedback;
        begin
            feedback   = bit_in ^ crc_in[14];
            crc15_next = {crc_in[13:0], 1'b0};
            if (feedback) begin
                crc15_next = crc15_next ^ 15'h4599;
            end
        end
    endfunction

    function [3:0] limit_dlc;
        input [3:0] dlc_in;
        begin
            limit_dlc = dlc_in > 4'd8 ? 4'd8 : dlc_in;
        end
    endfunction

    function [14:0] calc_crc_from_bits;
        input [127:0] bits;
        input [7:0]   len;
        integer       i;
        reg [14:0]    crc_tmp;
        begin
            crc_tmp = 15'd0;
            for (i = 0; i < 128; i = i + 1) begin
                if (i < len) begin
                    crc_tmp = crc15_next(crc_tmp, bits[i]);
                end
            end
            calc_crc_from_bits = crc_tmp;
        end
    endfunction

    function [14:0] read_crc_from_bits;
        input [127:0] bits;
        input [7:0]   len;
        integer       i;
        begin
            read_crc_from_bits = 15'd0;
            for (i = 0; i < 15; i = i + 1) begin
                read_crc_from_bits[14 - i] = bits[len + i];
            end
        end
    endfunction

    function frame_crc_ok;
        input [127:0] bits;
        input [7:0]   len;
        begin
            frame_crc_ok = calc_crc_from_bits(bits, len) == read_crc_from_bits(bits, len);
        end
    endfunction

    function [28:0] parse_id;
        input [127:0] bits;
        integer       i;
        begin
            parse_id = 29'd0;
            if (!bits[13]) begin
                for (i = 0; i < 11; i = i + 1) begin
                    parse_id[10 - i] = bits[1 + i];
                end
            end else begin
                for (i = 0; i < 11; i = i + 1) begin
                    parse_id[28 - i] = bits[1 + i];
                end
                for (i = 0; i < 18; i = i + 1) begin
                    parse_id[17 - i] = bits[14 + i];
                end
            end
        end
    endfunction

    function [3:0] parse_dlc;
        input [127:0] bits;
        begin
            if (!bits[13]) begin
                parse_dlc = limit_dlc({bits[15], bits[16], bits[17], bits[18]});
            end else begin
                parse_dlc = limit_dlc({bits[35], bits[36], bits[37], bits[38]});
            end
        end
    endfunction

    function parse_rtr;
        input [127:0] bits;
        begin
            parse_rtr = bits[13] ? bits[32] : bits[12];
        end
    endfunction

    function [63:0] parse_data;
        input [127:0] bits;
        input [3:0]   dlc_in;
        input         ide_in;
        integer       i;
        integer       start_index;
        begin
            parse_data = 64'd0;
            start_index = ide_in ? 39 : 19;
            for (i = 0; i < 64; i = i + 1) begin
                if (i < ({4'd0, dlc_in} << 3)) begin
                    parse_data[63 - i] = bits[start_index + i];
                end
            end
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state           <= ST_IDLE;
            bit_store       <= 128'd0;
            bit_cnt         <= 8'd0;
            expected_total  <= 8'd0;
            core_len        <= 8'd0;
            expected_known  <= 1'b0;
            ide_seen        <= 1'b0;
            dlc_seen        <= 4'd0;
            last_bit        <= 1'b1;
            same_cnt        <= 3'd0;
            tail_cnt        <= 4'd0;
            form_error_work <= 1'b0;
            frame_valid     <= 1'b0;
            frame_id        <= 29'd0;
            frame_ide       <= 1'b0;
            frame_rtr       <= 1'b0;
            frame_dlc       <= 4'd0;
            frame_data      <= 64'd0;
            crc_error       <= 1'b0;
            stuff_error     <= 1'b0;
            form_error      <= 1'b0;
        end else begin
            frame_valid <= 1'b0;
            crc_error   <= 1'b0;
            stuff_error <= 1'b0;
            form_error  <= 1'b0;

            if (!enable) begin
                state           <= ST_IDLE;
                bit_store       <= 128'd0;
                bit_cnt         <= 8'd0;
                expected_total  <= 8'd0;
                core_len        <= 8'd0;
                expected_known  <= 1'b0;
                ide_seen        <= 1'b0;
                dlc_seen        <= 4'd0;
                last_bit        <= 1'b1;
                same_cnt        <= 3'd0;
                tail_cnt        <= 4'd0;
                form_error_work <= 1'b0;
            end else if (sample_tick) begin
                case (state)
                    ST_IDLE: begin
                        if (!can_rx) begin
                            bit_store       <= 128'd0;
                            bit_store[0]    <= 1'b0;
                            bit_cnt         <= 8'd1;
                            expected_total  <= 8'd0;
                            core_len        <= 8'd0;
                            expected_known  <= 1'b0;
                            ide_seen        <= 1'b0;
                            dlc_seen        <= 4'd0;
                            last_bit        <= 1'b0;
                            same_cnt        <= 3'd1;
                            tail_cnt        <= 4'd0;
                            form_error_work <= 1'b0;
                            state           <= ST_DATA;
                        end
                    end

                    ST_DATA: begin
                        if ((same_cnt == 3'd5) && (can_rx == last_bit)) begin
                            stuff_error <= 1'b1;
                            state       <= ST_ERROR;
                        end else if ((same_cnt == 3'd5) && (can_rx != last_bit)) begin
                            last_bit <= can_rx;
                            same_cnt <= 3'd1;
                        end else begin
                            bit_store[bit_cnt] <= can_rx;
                            last_bit           <= can_rx;
                            same_cnt           <= can_rx == last_bit ? same_cnt + 3'd1 : 3'd1;

                            if (bit_cnt == 8'd13) begin
                                ide_seen <= can_rx;
                            end
                            if ((bit_cnt == 8'd18) && !ide_seen) begin
                                dlc_seen       <= limit_dlc(std_dlc_next);
                                core_len       <= 8'd19 + ({4'd0, limit_dlc(std_dlc_next)} << 3);
                                expected_total <= 8'd34 + ({4'd0, limit_dlc(std_dlc_next)} << 3);
                                expected_known <= 1'b1;
                            end
                            if ((bit_cnt == 8'd38) && ide_seen) begin
                                dlc_seen       <= limit_dlc(ext_dlc_next);
                                core_len       <= 8'd39 + ({4'd0, limit_dlc(ext_dlc_next)} << 3);
                                expected_total <= 8'd54 + ({4'd0, limit_dlc(ext_dlc_next)} << 3);
                                expected_known <= 1'b1;
                            end
                            if (expected_known && ((bit_cnt + 8'd1) == expected_total)) begin
                                tail_cnt <= 4'd0;
                                state    <= ST_TAIL;
                            end else if (bit_cnt == 8'd127) begin
                                form_error <= 1'b1;
                                state      <= ST_ERROR;
                            end else begin
                                bit_cnt <= bit_cnt + 8'd1;
                            end
                        end
                    end

                    ST_TAIL: begin
                        if (((tail_cnt == 4'd0) && !can_rx) || ((tail_cnt == 4'd2) && !can_rx) || ((tail_cnt >= 4'd3) && !can_rx)) begin
                            form_error_work <= 1'b1;
                        end

                        if (tail_cnt == 4'd9) begin
                            if (form_error_work || !can_rx) begin
                                form_error <= 1'b1;
                            end else if (!frame_crc_ok(bit_store, core_len)) begin
                                crc_error <= 1'b1;
                            end else begin
                                frame_valid <= 1'b1;
                                frame_id    <= parse_id(bit_store);
                                frame_ide   <= bit_store[13];
                                frame_rtr   <= parse_rtr(bit_store);
                                frame_dlc   <= parse_dlc(bit_store);
                                frame_data  <= parse_data(bit_store, parse_dlc(bit_store), bit_store[13]);
                            end
                            state <= ST_IDLE;
                        end else begin
                            tail_cnt <= tail_cnt + 4'd1;
                        end
                    end

                    ST_ERROR: begin
                        if (can_rx) begin
                            state <= ST_IDLE;
                        end
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
