// Simple CPU Program Memory Initialization
module intr_test(
    input wire [15:0] prog_addr,
    output reg [31:0] prog_data
);
always @(*) begin
    case (prog_addr)
        0 : prog_data = 32'h00010110;
        1 : prog_data = 32'h00050310;
        2 : prog_data = 32'h00103216;
        3 : prog_data = 32'h00014411;
        4 : prog_data = 32'h00030F1B;
        5 : prog_data = 32'hFFFE1113;
        6 : prog_data = 32'h00010510;
        7 : prog_data = 32'h00010510;
        8 : prog_data = 32'h00010510;
        9 : prog_data = 32'h00010510;
        10 : prog_data = 32'h00010510;
        11 : prog_data = 32'hFFFF2513;
        12 : prog_data = 32'h00011114;
        13 : prog_data = 32'h00050F2B;
        default: prog_data = 0;
    endcase
end
endmodule