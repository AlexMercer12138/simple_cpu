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
//  Module      : can_tx
//  Description : CAN Classic transmit path with bit stuffing and CRC-15
//--------------------------------------------------------------------------------
//  Copyright (c) 2026 Mercer. All rights reserved.
//  Licensed under the MIT License.
//--------------------------------------------------------------------------------
//  Version History:
//  v1.0 - Initial release
//  v1.1 - Add tx_ok tracking, remove ST_RETRY (retry moved to can_top)
//================================================================================

//================================================================================
//  Module Definition
//================================================================================

module can_tx (
    input   wire            clk,
    input   wire            rst_n,

    input   wire            enable,
    input   wire            loopback_mode,
    input   wire            listen_only,
    input   wire            start,
    input   wire    [28:0]  tx_id,
    input   wire            tx_ide,
    input   wire            tx_rtr,
    input   wire    [3:0]   tx_dlc,
    input   wire    [63:0]  tx_data,

    input   wire            bit_tick,
    input   wire            sample_tick,
    input   wire            bus_idle,
    input   wire            can_rx,

    output  reg             can_tx,
    output  reg             busy,
    output  reg             done,
    output  reg             ack_error,
    output  reg             bit_error,
    output  reg             arbitration_lost
);

    localparam ST_IDLE      = 3'd0;
    localparam ST_DATA      = 3'd1;
    localparam ST_CRC_DELIM = 3'd2;
    localparam ST_ACK       = 3'd3;
    localparam ST_ACK_DELIM = 3'd4;
    localparam ST_EOF       = 3'd5;
    localparam ST_IFS       = 3'd6;

    reg     [2:0]           state;
    reg     [7:0]           raw_index;
    reg     [7:0]           raw_len;
    reg     [14:0]          frame_crc;
    reg                     last_bit;
    reg     [2:0]           same_cnt;
    reg     [3:0]           eof_cnt;
    reg     [2:0]           ifs_cnt;
    reg                     ack_sampled;
    reg                     tx_ok;

    reg     [28:0]          id_latched;
    reg                     ide_latched;
    reg                     rtr_latched;
    reg     [3:0]           dlc_latched;
    reg     [63:0]          data_latched;

    wire    [3:0]           dlc_limited;
    wire    [7:0]           core_len_wire;
    wire    [14:0]          crc_wire;
    wire                    next_raw_bit;
    wire                    insert_stuff;
    wire                    arbitration_field;
    wire                    arbitration_loss_sample;
    wire                    bit_error_sample;

    assign dlc_limited   = tx_dlc > 4'd8 ? 4'd8 : tx_dlc;
    assign core_len_wire = tx_ide ? (8'd39 + ({4'd0, dlc_limited} << 3)) : (8'd19 + ({4'd0, dlc_limited} << 3));
    assign crc_wire      = calc_crc(tx_id, tx_ide, tx_rtr, dlc_limited, tx_data);
    assign next_raw_bit  = raw_bit(raw_index + 8'd1, id_latched, ide_latched, rtr_latched, dlc_latched, data_latched, frame_crc);
    assign insert_stuff  = same_cnt == 3'd5;
    assign arbitration_field = (state == ST_DATA) && ((raw_index < 8'd12) ||
                               (!ide_latched && (raw_index == 8'd12)) ||
                               (ide_latched && (raw_index <= 8'd32)));
    assign arbitration_loss_sample = sample_tick && busy && !loopback_mode && arbitration_field && can_tx && !can_rx;
    assign bit_error_sample = sample_tick && busy && !loopback_mode && (state == ST_DATA) && (can_rx != can_tx) &&
                              !arbitration_field && !insert_stuff;

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

    function [7:0] core_length;
        input       ide_in;
        input [3:0] dlc_in;
        begin
            core_length = ide_in ? (8'd39 + ({4'd0, limit_dlc(dlc_in)} << 3)) : (8'd19 + ({4'd0, limit_dlc(dlc_in)} << 3));
        end
    endfunction

    function raw_bit;
        input [7:0]  index;
        input [28:0] id_in;
        input        ide_in;
        input        rtr_in;
        input [3:0]  dlc_in;
        input [63:0] data_in;
        input [14:0] crc_in;
        integer      payload_index;
        integer      crc_index;
        reg [3:0]    dlc_eff;
        begin
            dlc_eff = limit_dlc(dlc_in);
            raw_bit = 1'b1;
            if (!ide_in) begin
                if (index == 8'd0) begin
                    raw_bit = 1'b0;
                end else if (index <= 8'd11) begin
                    raw_bit = id_in[11 - index];
                end else if (index == 8'd12) begin
                    raw_bit = rtr_in;
                end else if (index == 8'd13) begin
                    raw_bit = 1'b0;
                end else if (index == 8'd14) begin
                    raw_bit = 1'b0;
                end else if ((index >= 8'd15) && (index <= 8'd18)) begin
                    raw_bit = dlc_eff[18 - index];
                end else if ((index >= 8'd19) && (index < (8'd19 + ({4'd0, dlc_eff} << 3)))) begin
                    payload_index = index - 8'd19;
                    raw_bit = data_in[63 - payload_index];
                end else if ((index >= core_length(ide_in, dlc_eff)) && (index < (core_length(ide_in, dlc_eff) + 8'd15))) begin
                    crc_index = index - core_length(ide_in, dlc_eff);
                    raw_bit = crc_in[14 - crc_index];
                end
            end else begin
                if (index == 8'd0) begin
                    raw_bit = 1'b0;
                end else if (index <= 8'd11) begin
                    raw_bit = id_in[29 - index];
                end else if (index == 8'd12) begin
                    raw_bit = 1'b1;
                end else if (index == 8'd13) begin
                    raw_bit = 1'b1;
                end else if ((index >= 8'd14) && (index <= 8'd31)) begin
                    raw_bit = id_in[31 - index];
                end else if (index == 8'd32) begin
                    raw_bit = rtr_in;
                end else if (index == 8'd33) begin
                    raw_bit = 1'b0;
                end else if (index == 8'd34) begin
                    raw_bit = 1'b0;
                end else if ((index >= 8'd35) && (index <= 8'd38)) begin
                    raw_bit = dlc_eff[38 - index];
                end else if ((index >= 8'd39) && (index < (8'd39 + ({4'd0, dlc_eff} << 3)))) begin
                    payload_index = index - 8'd39;
                    raw_bit = data_in[63 - payload_index];
                end else if ((index >= core_length(ide_in, dlc_eff)) && (index < (core_length(ide_in, dlc_eff) + 8'd15))) begin
                    crc_index = index - core_length(ide_in, dlc_eff);
                    raw_bit = crc_in[14 - crc_index];
                end
            end
        end
    endfunction

    function [14:0] calc_crc;
        input [28:0] id_in;
        input        ide_in;
        input        rtr_in;
        input [3:0]  dlc_in;
        input [63:0] data_in;
        integer      i;
        reg [14:0]   crc_tmp;
        begin
            crc_tmp = 15'd0;
            for (i = 0; i < 128; i = i + 1) begin
                if (i < core_length(ide_in, dlc_in)) begin
                    crc_tmp = crc15_next(crc_tmp, raw_bit(i[7:0], id_in, ide_in, rtr_in, dlc_in, data_in, 15'd0));
                end
            end
            calc_crc = crc_tmp;
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            raw_index    <= 8'd0;
            raw_len      <= 8'd0;
            frame_crc    <= 15'd0;
            last_bit     <= 1'b1;
            same_cnt     <= 3'd0;
            eof_cnt      <= 4'd0;
            ifs_cnt      <= 3'd0;
            ack_sampled  <= 1'b0;
            id_latched   <= 29'd0;
            ide_latched  <= 1'b0;
            rtr_latched  <= 1'b0;
            dlc_latched  <= 4'd0;
            data_latched <= 64'd0;
            can_tx       <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
            ack_error    <= 1'b0;
            bit_error    <= 1'b0;
            arbitration_lost <= 1'b0;
            tx_ok        <= 1'b0;
        end else begin
            done             <= 1'b0;
            ack_error        <= 1'b0;
            bit_error        <= 1'b0;
            arbitration_lost <= 1'b0;

            if (!enable || listen_only) begin
                state       <= ST_IDLE;
                raw_index   <= 8'd0;
                raw_len     <= 8'd0;
                last_bit    <= 1'b1;
                same_cnt    <= 3'd0;
                eof_cnt     <= 4'd0;
                ifs_cnt     <= 3'd0;
                ack_sampled <= 1'b0;
                can_tx      <= 1'b1;
                busy        <= 1'b0;
                tx_ok       <= 1'b0;
            end else begin
                if (arbitration_loss_sample) begin
                    arbitration_lost <= 1'b1;
                    tx_ok            <= 1'b0;
                    can_tx           <= 1'b1;
                    busy             <= 1'b0;
                    state            <= ST_IDLE;
                end else if (bit_error_sample) begin
                    bit_error <= 1'b1;
                    tx_ok     <= 1'b0;
                    can_tx    <= 1'b1;
                    busy      <= 1'b0;
                    state     <= ST_IDLE;
                end else begin
                    case (state)
                    ST_IDLE: begin
                        can_tx      <= 1'b1;
                        busy        <= 1'b0;
                        ack_sampled <= 1'b0;
                        if (start) begin
                            id_latched   <= tx_id;
                            ide_latched  <= tx_ide;
                            rtr_latched  <= tx_rtr;
                            dlc_latched  <= dlc_limited;
                            data_latched <= tx_data;
                            frame_crc    <= crc_wire;
                            raw_len      <= core_len_wire + 8'd15;
                            raw_index    <= 8'd0;
                            last_bit     <= 1'b0;
                            same_cnt     <= 3'd1;
                            can_tx       <= 1'b0;
                            busy         <= 1'b1;
                            tx_ok        <= 1'b1;
                            state        <= ST_DATA;
                        end
                    end

                    ST_DATA: begin
                        busy <= 1'b1;
                        if (bit_tick) begin
                            if (raw_index == raw_len - 8'd1) begin
                                can_tx   <= 1'b1;
                                state    <= ST_CRC_DELIM;
                                last_bit <= 1'b1;
                                same_cnt <= 3'd1;
                            end else if (insert_stuff) begin
                                can_tx   <= ~last_bit;
                                last_bit <= ~last_bit;
                                same_cnt <= 3'd1;
                            end else begin
                                can_tx    <= next_raw_bit;
                                raw_index <= raw_index + 8'd1;
                                last_bit  <= next_raw_bit;
                                same_cnt  <= next_raw_bit == last_bit ? same_cnt + 3'd1 : 3'd1;
                            end
                        end
                    end

                    ST_CRC_DELIM: begin
                        busy   <= 1'b1;
                        can_tx <= 1'b1;
                        if (bit_tick) begin
                            state       <= ST_ACK;
                            ack_sampled <= 1'b0;
                        end
                    end

                    ST_ACK: begin
                        busy   <= 1'b1;
                        can_tx <= 1'b1;
                        if (sample_tick) begin
                            ack_sampled <= loopback_mode | ~can_rx;
                        end
                        if (bit_tick) begin
                            if (!ack_sampled && !loopback_mode) begin
                                ack_error <= 1'b1;
                                tx_ok     <= 1'b0;
                                can_tx    <= 1'b1;
                                busy      <= 1'b0;
                                state     <= ST_IDLE;
                            end else begin
                                state <= ST_ACK_DELIM;
                            end
                        end
                    end

                    ST_ACK_DELIM: begin
                        busy   <= 1'b1;
                        can_tx <= 1'b1;
                        if (bit_tick) begin
                            eof_cnt <= 4'd0;
                            state   <= ST_EOF;
                        end
                    end

                    ST_EOF: begin
                        busy   <= 1'b1;
                        can_tx <= 1'b1;
                        if (bit_tick) begin
                            if (eof_cnt == 4'd6) begin
                                eof_cnt <= 4'd0;
                                ifs_cnt <= 3'd0;
                                state   <= ST_IFS;
                            end else begin
                                eof_cnt <= eof_cnt + 4'd1;
                            end
                        end
                    end

                    ST_IFS: begin
                        busy   <= 1'b1;
                        can_tx <= 1'b1;
                        if (bit_tick) begin
                            if (ifs_cnt == 3'd2) begin
                                ifs_cnt <= 3'd0;
                                busy    <= 1'b0;
                                done    <= tx_ok;
                                state   <= ST_IDLE;
                            end else begin
                                ifs_cnt <= ifs_cnt + 3'd1;
                            end
                        end
                    end

                    default: begin
                        state  <= ST_IDLE;
                        can_tx <= 1'b1;
                        busy   <= 1'b0;
                    end
                endcase
                end
            end
        end
    end

endmodule
