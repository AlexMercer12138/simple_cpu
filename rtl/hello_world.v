// Simple CPU Program Memory Initialization
module hello_world(
    input wire [7:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h00000110;
        1 : prog_data = 32'h44000210;
        2 : prog_data = 32'h02FB0310;
        3 : prog_data = 32'h00080410;
        4 : prog_data = 32'h00100510;
        5 : prog_data = 32'h00010910;
        6 : prog_data = 32'h00090A10;
        7 : prog_data = 32'h00000B10;
        8 : prog_data = 32'h00000C10;
        9 : prog_data = 32'h00052226;
        10 : prog_data = 32'h00053326;
        11 : prog_data = 32'h00000810;
        12 : prog_data = 32'h001E181C;
        13 : prog_data = 32'h00010810;
        14 : prog_data = 32'h0020181C;
        15 : prog_data = 32'h00020810;
        16 : prog_data = 32'h0022181C;
        17 : prog_data = 32'h00030810;
        18 : prog_data = 32'h0024181C;
        19 : prog_data = 32'h00040810;
        20 : prog_data = 32'h0026181C;
        21 : prog_data = 32'h00050810;
        22 : prog_data = 32'h0028181C;
        23 : prog_data = 32'h00060810;
        24 : prog_data = 32'h002A181C;
        25 : prog_data = 32'h00070810;
        26 : prog_data = 32'h002C181C;
        27 : prog_data = 32'h00080810;
        28 : prog_data = 32'h002E181C;
        29 : prog_data = 32'h00300C1B;
        30 : prog_data = 32'h00680610;
        31 : prog_data = 32'h00310C1B;
        32 : prog_data = 32'h00650610;
        33 : prog_data = 32'h00310C1B;
        34 : prog_data = 32'h006C0610;
        35 : prog_data = 32'h00310C1B;
        36 : prog_data = 32'h006C0610;
        37 : prog_data = 32'h00310C1B;
        38 : prog_data = 32'h006F0610;
        39 : prog_data = 32'h00310C1B;
        40 : prog_data = 32'h00770610;
        41 : prog_data = 32'h00310C1B;
        42 : prog_data = 32'h006F0610;
        43 : prog_data = 32'h00310C1B;
        44 : prog_data = 32'h00720610;
        45 : prog_data = 32'h00310C1B;
        46 : prog_data = 32'h006C0610;
        47 : prog_data = 32'h00310C1B;
        48 : prog_data = 32'h00640610;
        49 : prog_data = 32'h00047726;
        50 : prog_data = 32'h00067721;
        51 : prog_data = 32'h00000B10;
        52 : prog_data = 32'h00361A1C;
        53 : prog_data = 32'h00380C1B;
        54 : prog_data = 32'h00000110;
        55 : prog_data = 32'h003A0C1B;
        56 : prog_data = 32'h00091121;
        57 : prog_data = 32'h003A0C1B;
        58 : prog_data = 32'h00002729;
        59 : prog_data = 32'h0009BB21;
        60 : prog_data = 32'h003BB31E;
        61 : prog_data = 32'h000B0C1B;
        default: prog_data = 0;
    endcase
end
endmodule