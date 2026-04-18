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

    reg clk = 0, rst_n = 0;

    // Clock generation: 50MHz (period = 20ns)
    initial begin
        forever begin
            #10 clk = ~clk;
        end
    end

    // Reset generation
    initial begin
        #100 rst_n = 1;
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

    // Internal signals for monitoring
    wire        prog_step;
    wire [31:0] prog_data_internal;
    wire [7:0]  prog_addr_internal;

    // Instruction trace: print instruction when prog_step is enabled
    always @(posedge clk) begin
        if (rst_n && prog_step) begin
            $display("[%0t] PC=%0d (0x%02X), Instruction=0x%08X", 
                     $time, prog_addr_internal, prog_addr_internal, prog_data_internal);
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

    // Access internal signals for monitoring
    assign prog_step = cpu_inst.prog_step;
    assign prog_addr_internal = cpu_inst.prog_addr;
    assign prog_data_internal = prog_data;

    // Instantiate Program Memory (ROM)
    instr_test rom_inst (
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

    // Test sequence
    initial begin
        $display("========================================");
        $display("Simple CPU Testbench Started");
        $display("========================================");
        
        // Wait for reset release
        @(posedge rst_n);
        $display("[%0t] Reset released, CPU starting...", $time);
        
        // Run for some cycles
        repeat(100) @(posedge clk);
        
        $display("========================================");
        $display("Simulation finished");
        $display("========================================");
        $finish;
    end

    // Dump waveforms for waveform viewer
    initial begin
        $dumpfile("simple_cpu_tb.vcd");
        $dumpvars(0, simple_cpu_tb);
    end

endmodule
