`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/18 18:30:12
// Design Name: 
// Module Name: simple_cpu_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Simple CPU Testbench with instruction trace
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module simple_cpu_tb();

    localparam  SET  = 4'b0000;
    localparam  ADD  = 4'b0001;
    localparam  SUB  = 4'b0010;
    localparam  AND  = 4'b0011;
    localparam  OR   = 4'b0100;
    localparam  XOR  = 4'b0101;
    localparam  SLL  = 4'b0110;
    localparam  SRL  = 4'b0111;
    localparam  MWR  = 4'b1000;
    localparam  MRD  = 4'b1001;
    localparam  JAL  = 4'b1010;
    localparam  JALR = 4'b1011;
    localparam  BEQ  = 4'b1100;
    localparam  BNE  = 4'b1101;
    localparam  BLT  = 4'b1110;
    localparam  BGE  = 4'b1111;

    reg clk = 0, rst_n = 0;

    // Clock generation: 50MHz (period = 20ns)
    initial begin
        forever begin
            #10 clk = ~clk;
        end
    end

    // Reset generation
    initial begin
        #2000 rst_n = 1;
    end

    // Signals for CPU connection
    wire [7:0]  prog_addr;
    wire [31:0] prog_data;
    
    // AXI4-Lite interface signals (CPU master -> Slave)
    wire        m_axi_awvalid;
    wire        m_axi_awready;
    wire [31:0] m_axi_awaddr;
    wire        m_axi_wvalid;
    wire        m_axi_wready;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_bvalid;
    wire        m_axi_bready;
    wire [1:0]  m_axi_bresp;
    wire        m_axi_arvalid;
    wire        m_axi_arready;
    wire [31:0] m_axi_araddr;
    wire        m_axi_rvalid;
    wire        m_axi_rready;
    wire [1:0]  m_axi_rresp;
    wire [31:0] m_axi_rdata;

    // Opcode to ASCII string function
    function [31:0] Opcode_ascii(
        input [3:0] opcode
    );
        case (opcode)
            SET : Opcode_ascii = "SET ";
            ADD : Opcode_ascii = "ADD ";
            SUB : Opcode_ascii = "SUB ";
            AND : Opcode_ascii = "AND ";
            OR  : Opcode_ascii = "OR  ";
            XOR : Opcode_ascii = "XOR ";
            SLL : Opcode_ascii = "SLL ";
            SRL : Opcode_ascii = "SRL ";
            MWR : Opcode_ascii = "MWR ";
            MRD : Opcode_ascii = "MRD ";
            JAL : Opcode_ascii = "JAL ";
            JALR: Opcode_ascii = "JALR";
            BEQ : Opcode_ascii = "BEQ ";
            BNE : Opcode_ascii = "BNE ";
            BLT : Opcode_ascii = "BLT ";
            BGE : Opcode_ascii = "BGE ";
            default: Opcode_ascii = "????";
        endcase
    endfunction

    // Instruction trace: print formatted instruction when prog_step is enabled
    always @(posedge clk) begin
        if (cpu_inst.prog_step) begin
            case (prog_data[3:0])
                // I-type: SET, JAL - Rd, Imm
                SET, JAL: begin
                    $display("[%0d] : %s R%0d, #%0d", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[7:4], prog_data[31:12]);
                end
                
                // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL - Rd, Rs2, Rs1
                ADD, SUB, AND, OR, XOR, SLL, SRL: begin
                    $display("[%0d] : %s R%0d, R%0d R%0d", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[7:4], prog_data[11:8], prog_data[15:12]);
                end
                
                // M-type: MWR - [Rs1], Rs2
                MWR: begin
                    $display("[%0d] : %s [R%0d], R%0d", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[15:12], prog_data[11:8]);
                end
                
                // M-type: MRD - Rd, [Rs1]
                MRD: begin
                    $display("[%0d] : %s R%0d, [R%0d]", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[7:4], prog_data[15:12]);
                end
                
                // J-type: JALR - Rd, Rs1
                JALR: begin
                    $display("[%0d] : %s R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[7:4], prog_data[15:12]);
                end
                
                // B-type: BEQ, BNE, BLT, BGE - Rs1, Rs2, Rd (branch if Rs2 op Rd, jump to Rs1)
                BEQ, BNE, BLT, BGE: begin
                    $display("[%0d] : %s R%0d, R%0d R%0d", 
                             prog_addr, Opcode_ascii(prog_data[3:0]), prog_data[15:12], prog_data[11:8], prog_data[7:4]);
                end
                
                default: begin
                    $display("[%0d] : UNKNOWN OPCODE (0x%08X)", prog_addr, prog_data);
                end
            endcase
        end
    end

    // Instantiate Simple CPU
    simple_cpu cpu_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // Program memory interface
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),
        
        // AXI4-Lite Master Interface (Write Address)
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awaddr   (m_axi_awaddr),
        
        // AXI4-Lite Master Interface (Write Data)
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        
        // AXI4-Lite Master Interface (Write Response)
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp),
        
        // AXI4-Lite Master Interface (Read Address)
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_araddr   (m_axi_araddr),
        
        // AXI4-Lite Master Interface (Read Data)
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rdata    (m_axi_rdata)
    );

    // Instantiate Program Memory (ROM)
    // instr_test rom_inst (
    //     .prog_addr      (prog_addr),
    //     .prog_data      (prog_data)
    // );

    hello_world rom_inst (
        .prog_addr      (prog_addr),
        .prog_data      (prog_data)
    );

    // Instantiate AXI4-Lite Slave (for data memory)
    s_axi_lite #(
        .AXI_DATA_WIDTH (32),
        .AXI_ADDR_WIDTH (6)
    ) s_axi_inst (
        .S_AXI_ACLK     (clk),
        .S_AXI_ARESETN  (rst_n),
        
        // Write Address Channel
        .S_AXI_AWADDR   (m_axi_awaddr[5:0]),
        .S_AXI_AWPROT   (3'b000),
        .S_AXI_AWVALID  (m_axi_awvalid),
        .S_AXI_AWREADY  (m_axi_awready),
        
        // Write Data Channel
        .S_AXI_WDATA    (m_axi_wdata),
        .S_AXI_WSTRB    (m_axi_wstrb),
        .S_AXI_WVALID   (m_axi_wvalid),
        .S_AXI_WREADY   (m_axi_wready),
        
        // Write Response Channel
        .S_AXI_BRESP    (m_axi_bresp),
        .S_AXI_BVALID   (m_axi_bvalid),
        .S_AXI_BREADY   (m_axi_bready),
        
        // Read Address Channel
        .S_AXI_ARADDR   (m_axi_araddr[5:0]),
        .S_AXI_ARPROT   (3'b000),
        .S_AXI_ARVALID  (m_axi_arvalid),
        .S_AXI_ARREADY  (m_axi_arready),
        
        // Read Data Channel
        .S_AXI_RDATA    (m_axi_rdata),
        .S_AXI_RRESP    (m_axi_rresp),
        .S_AXI_RVALID   (m_axi_rvalid),
        .S_AXI_RREADY   (m_axi_rready)
    );

endmodule
