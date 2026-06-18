// Simple CPU Program Memory Initialization
module uart_test(
    input wire [15:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h10000310;
        1 : prog_data = 32'h00103316;
        2 : prog_data = 32'hE1000410;
        3 : prog_data = 32'h00014416;
        4 : prog_data = 32'h00043419;
        5 : prog_data = 32'h00010410;
        6 : prog_data = 32'h00183419;
        7 : prog_data = 32'h00410410;
        8 : prog_data = 32'h00104216;
        9 : prog_data = 32'h00010110;
        10 : prog_data = 32'h00FF0510;
        11 : prog_data = 32'h00105516;
        12 : prog_data = 32'h0014341A;
        13 : prog_data = 32'h00094417;
        14 : prog_data = 32'h0001401B;
        15 : prog_data = 32'hFFFDF01C;
        16 : prog_data = 32'h48650410;
        17 : prog_data = 32'h00104416;
        18 : prog_data = 32'h6C6C4411;
        19 : prog_data = 32'h00103419;
        20 : prog_data = 32'h00700410;
        21 : prog_data = 32'h00003429;
        22 : prog_data = 32'h0014341A;
        23 : prog_data = 32'h00094417;
        24 : prog_data = 32'h0001401B;
        25 : prog_data = 32'hFFFDF01C;
        26 : prog_data = 32'h6F200410;
        27 : prog_data = 32'h00104416;
        28 : prog_data = 32'h776F4411;
        29 : prog_data = 32'h00103419;
        30 : prog_data = 32'h00700410;
        31 : prog_data = 32'h00003429;
        32 : prog_data = 32'h0014341A;
        33 : prog_data = 32'h00094417;
        34 : prog_data = 32'h0001401B;
        35 : prog_data = 32'hFFFDF01C;
        36 : prog_data = 32'h726C0410;
        37 : prog_data = 32'h00104416;
        38 : prog_data = 32'h64214411;
        39 : prog_data = 32'h00103419;
        40 : prog_data = 32'h00700410;
        41 : prog_data = 32'h00003429;
        42 : prog_data = 32'h0014341A;
        43 : prog_data = 32'h00094417;
        44 : prog_data = 32'h0001401B;
        45 : prog_data = 32'hFFFDF01C;
        46 : prog_data = 32'h000A0410;
        47 : prog_data = 32'h00184416;
        48 : prog_data = 32'h00103419;
        49 : prog_data = 32'h00100410;
        50 : prog_data = 32'h00003429;
        51 : prog_data = 32'h0014341A;
        52 : prog_data = 32'h00094417;
        53 : prog_data = 32'h0001401B;
        54 : prog_data = 32'hFFFDF01C;
        55 : prog_data = 32'h000D0410;
        56 : prog_data = 32'h00184416;
        57 : prog_data = 32'h00103419;
        58 : prog_data = 32'h00100410;
        59 : prog_data = 32'h00003429;
        60 : prog_data = 32'h00016611;
        61 : prog_data = 32'h0005602B;
        62 : prog_data = 32'h003C011C;
        63 : prog_data = 32'h00000610;
        64 : prog_data = 32'h000C0E1D;
        65 : prog_data = 32'hFFFE1113;
        66 : prog_data = 32'h00010810;
        67 : prog_data = 32'h00003829;
        68 : prog_data = 32'h0008381A;
        69 : prog_data = 32'h00188817;
        70 : prog_data = 32'h0014341A;
        71 : prog_data = 32'h00094417;
        72 : prog_data = 32'h0001401B;
        73 : prog_data = 32'hFFFDF01C;
        74 : prog_data = 32'h00008411;
        75 : prog_data = 32'h00184416;
        76 : prog_data = 32'h00103419;
        77 : prog_data = 32'h00100410;
        78 : prog_data = 32'h00003429;
        79 : prog_data = 32'h00011114;
        80 : prog_data = 32'hFFFF2D13;
        81 : prog_data = 32'h000D0E2D;
        default: prog_data = 0;
    endcase
end
endmodule