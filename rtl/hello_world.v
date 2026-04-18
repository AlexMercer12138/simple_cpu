// Simple CPU Program Memory Initialization
module hello_world(
    input wire [7:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h00000010;
        1 : prog_data = 32'h04400020;
        2 : prog_data = 32'h2FAEE030;
        3 : prog_data = 32'h00008040;
        4 : prog_data = 32'h00010050;
        5 : prog_data = 32'h00001090;
        6 : prog_data = 32'h000090A0;
        7 : prog_data = 32'h000000B0;
        8 : prog_data = 32'h00005226;
        9 : prog_data = 32'h00004336;
        10 : prog_data = 32'h00000080;
        11 : prog_data = 32'h000260D0;
        12 : prog_data = 32'h0000D18C;
        13 : prog_data = 32'h00001080;
        14 : prog_data = 32'h000280D0;
        15 : prog_data = 32'h0000D18C;
        16 : prog_data = 32'h00002080;
        17 : prog_data = 32'h0002A0D0;
        18 : prog_data = 32'h0000D18C;
        19 : prog_data = 32'h00003080;
        20 : prog_data = 32'h0002C0D0;
        21 : prog_data = 32'h0000D18C;
        22 : prog_data = 32'h00004080;
        23 : prog_data = 32'h0002E0D0;
        24 : prog_data = 32'h0000D18C;
        25 : prog_data = 32'h00005080;
        26 : prog_data = 32'h000300D0;
        27 : prog_data = 32'h0000D18C;
        28 : prog_data = 32'h00006080;
        29 : prog_data = 32'h000320D0;
        30 : prog_data = 32'h0000D18C;
        31 : prog_data = 32'h00007080;
        32 : prog_data = 32'h000340D0;
        33 : prog_data = 32'h0000D18C;
        34 : prog_data = 32'h00008080;
        35 : prog_data = 32'h000360D0;
        36 : prog_data = 32'h0000D18C;
        37 : prog_data = 32'h000380FA;
        38 : prog_data = 32'h00068060;
        39 : prog_data = 32'h000390FA;
        40 : prog_data = 32'h00065060;
        41 : prog_data = 32'h000390FA;
        42 : prog_data = 32'h0006C060;
        43 : prog_data = 32'h000390FA;
        44 : prog_data = 32'h0006C060;
        45 : prog_data = 32'h000390FA;
        46 : prog_data = 32'h0006F060;
        47 : prog_data = 32'h000390FA;
        48 : prog_data = 32'h00077060;
        49 : prog_data = 32'h000390FA;
        50 : prog_data = 32'h0006F060;
        51 : prog_data = 32'h000390FA;
        52 : prog_data = 32'h00072060;
        53 : prog_data = 32'h000390FA;
        54 : prog_data = 32'h0006C060;
        55 : prog_data = 32'h000390FA;
        56 : prog_data = 32'h00064060;
        57 : prog_data = 32'h00004776;
        58 : prog_data = 32'h00006771;
        59 : prog_data = 32'h000000B0;
        60 : prog_data = 32'h0003F0D0;
        61 : prog_data = 32'h0000D1AC;
        62 : prog_data = 32'h000410FA;
        63 : prog_data = 32'h00000010;
        64 : prog_data = 32'h000430FA;
        65 : prog_data = 32'h00009111;
        66 : prog_data = 32'h000430FA;
        67 : prog_data = 32'h00002708;
        68 : prog_data = 32'h00009BB1;
        69 : prog_data = 32'h000440D0;
        70 : prog_data = 32'h0000DB3E;
        71 : prog_data = 32'h0000A0FA;
        default: prog_data = 0;
    endcase
end
endmodule