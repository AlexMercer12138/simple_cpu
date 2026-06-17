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
        7 : prog_data = 32'h00460410;
        8 : prog_data = 32'h00104216;
        9 : prog_data = 32'h00010110;
        10 : prog_data = 32'h00FF0510;
        11 : prog_data = 32'h00105516;
        12 : prog_data = 32'h0014341A;
        13 : prog_data = 32'h00094417;
        14 : prog_data = 32'h00010710;
        15 : prog_data = 32'h0007402B;
        16 : prog_data = 32'h000C001C;
        17 : prog_data = 32'h48650410;
        18 : prog_data = 32'h00104416;
        19 : prog_data = 32'h6C6C4411;
        20 : prog_data = 32'h00103419;
        21 : prog_data = 32'h00700410;
        22 : prog_data = 32'h00003429;
        23 : prog_data = 32'h0014341A;
        24 : prog_data = 32'h00094417;
        25 : prog_data = 32'h00010710;
        26 : prog_data = 32'h0007402B;
        27 : prog_data = 32'h0017001C;
        28 : prog_data = 32'h6F200410;
        29 : prog_data = 32'h00104416;
        30 : prog_data = 32'h776F4411;
        31 : prog_data = 32'h00103419;
        32 : prog_data = 32'h00700410;
        33 : prog_data = 32'h00003429;
        34 : prog_data = 32'h0014341A;
        35 : prog_data = 32'h00094417;
        36 : prog_data = 32'h00010710;
        37 : prog_data = 32'h0007402B;
        38 : prog_data = 32'h0022001C;
        39 : prog_data = 32'h726C0410;
        40 : prog_data = 32'h00104416;
        41 : prog_data = 32'h64214411;
        42 : prog_data = 32'h00103419;
        43 : prog_data = 32'h00700410;
        44 : prog_data = 32'h00003429;
        45 : prog_data = 32'h0014341A;
        46 : prog_data = 32'h00094417;
        47 : prog_data = 32'h00010710;
        48 : prog_data = 32'h0007402B;
        49 : prog_data = 32'h002D001C;
        50 : prog_data = 32'h000A0410;
        51 : prog_data = 32'h00184416;
        52 : prog_data = 32'h00103419;
        53 : prog_data = 32'h00100410;
        54 : prog_data = 32'h00003429;
        55 : prog_data = 32'h0014341A;
        56 : prog_data = 32'h00094417;
        57 : prog_data = 32'h00010710;
        58 : prog_data = 32'h0007402B;
        59 : prog_data = 32'h0037001C;
        60 : prog_data = 32'h000D0410;
        61 : prog_data = 32'h00184416;
        62 : prog_data = 32'h00103419;
        63 : prog_data = 32'h00100410;
        64 : prog_data = 32'h00003429;
        65 : prog_data = 32'h00016611;
        66 : prog_data = 32'h0005602B;
        67 : prog_data = 32'h0041011C;
        68 : prog_data = 32'h00000610;
        69 : prog_data = 32'h000C0E1D;
        70 : prog_data = 32'hFFFE1113;
        71 : prog_data = 32'h00010810;
        72 : prog_data = 32'h00003829;
        73 : prog_data = 32'h0008381A;
        74 : prog_data = 32'h00188817;
        75 : prog_data = 32'h0014341A;
        76 : prog_data = 32'h00094417;
        77 : prog_data = 32'h00010710;
        78 : prog_data = 32'h0007402B;
        79 : prog_data = 32'h004B001C;
        80 : prog_data = 32'h00188816;
        81 : prog_data = 32'h00103819;
        82 : prog_data = 32'h00100810;
        83 : prog_data = 32'h00003829;
        84 : prog_data = 32'h00011114;
        85 : prog_data = 32'hFFFF2D13;
        86 : prog_data = 32'h000D0E2D;
        default: prog_data = 0;
    endcase
end
endmodule