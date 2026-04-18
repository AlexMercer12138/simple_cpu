// Simple CPU Program Memory Initialization
module instr_test(
    input wire [7:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h00000000;
        1 : prog_data = 32'h00001010;
        2 : prog_data = 32'h000FF020;
        3 : prog_data = 32'h00002131;
        4 : prog_data = 32'h00001242;
        5 : prog_data = 32'h00002153;
        6 : prog_data = 32'h00002164;
        7 : prog_data = 32'h00002175;
        8 : prog_data = 32'h00001286;
        9 : prog_data = 32'h00001297;
        10 : prog_data = 32'h0000A308;
        11 : prog_data = 32'h000040B9;
        12 : prog_data = 32'h0000D0CA;
        13 : prog_data = 32'h0000F0F0;
        14 : prog_data = 32'h0000F0DB;
        15 : prog_data = 32'h000110F0;
        16 : prog_data = 32'h0000F11C;
        17 : prog_data = 32'h000130F0;
        18 : prog_data = 32'h0000F12D;
        19 : prog_data = 32'h000150F0;
        20 : prog_data = 32'h0000F12E;
        21 : prog_data = 32'h000170F0;
        22 : prog_data = 32'h0000F21F;
        23 : prog_data = 32'h000170DA;
        default: prog_data = 0;
    endcase
end
endmodule