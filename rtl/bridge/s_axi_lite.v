`timescale 1 ns / 1 ps

module s_axi_lite #
(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Width of S_AXI data bus
    parameter integer AXI_DATA_WIDTH            = 32,
    // Width of S_AXI address bus
    parameter integer AXI_ADDR_WIDTH            = 6
)
(
    // Users to add ports here
    output  wire [31:0]                         monitor,

    // User ports ends
    // Do not modify the ports beyond this line

    // axi lite interface
    input   wire                                S_AXI_ACLK,
    input   wire                                S_AXI_ARESETN,
    input   wire [AXI_ADDR_WIDTH-1 : 0]         S_AXI_AWADDR,
    input   wire [2 : 0]                        S_AXI_AWPROT,
    input   wire                                S_AXI_AWVALID,
    output  wire                                S_AXI_AWREADY,
    input   wire [AXI_DATA_WIDTH-1 : 0]         S_AXI_WDATA,
    input   wire [(AXI_DATA_WIDTH/8)-1 : 0]     S_AXI_WSTRB,
    input   wire                                S_AXI_WVALID,
    output  wire                                S_AXI_WREADY,
    output  wire [1 : 0]                        S_AXI_BRESP,
    output  wire                                S_AXI_BVALID,
    input   wire                                S_AXI_BREADY,
    input   wire [AXI_ADDR_WIDTH-1 : 0]         S_AXI_ARADDR,
    input   wire [2 : 0]                        S_AXI_ARPROT,
    input   wire                                S_AXI_ARVALID,
    output  wire                                S_AXI_ARREADY,
    output  wire [AXI_DATA_WIDTH-1 : 0]         S_AXI_RDATA,
    output  wire [1 : 0]                        S_AXI_RRESP,
    output  wire                                S_AXI_RVALID,
    input   wire                                S_AXI_RREADY
);

    // AXI4LITE signals
    reg [AXI_ADDR_WIDTH-1 : 0] 	                axi_awaddr;
    reg                                         axi_awready;
    reg                                         axi_wready;
    reg [1 : 0]                                 axi_bresp;
    reg  	                                    axi_bvalid;
    reg [AXI_ADDR_WIDTH-1 : 0]                  axi_araddr;
    reg                                         axi_arready;
    reg [AXI_DATA_WIDTH-1 : 0]                  axi_rdata;
    reg [1 : 0]                                 axi_rresp;
    reg                                         axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam ADDR_LSB = (AXI_DATA_WIDTH/32) + 1;
    localparam OPT_ADDR_WIDTH = AXI_ADDR_WIDTH - ADDR_LSB;
    localparam SLVREG_NUM = 2**OPT_ADDR_WIDTH;
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    reg [31:0]                                  slv_index;
    reg [AXI_DATA_WIDTH-1:0]	                slv_reg [0:SLVREG_NUM-1];
    reg [31:0]                                  byte_index;
    reg                                         aw_en;

    wire [OPT_ADDR_WIDTH-1:0]                   wr_addr;
    wire [OPT_ADDR_WIDTH-1:0]                   rd_addr;
    wire                                        slv_reg_rden;
    wire                                        slv_reg_wren;

    assign wr_addr                              = axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB];
    assign rd_addr                              = axi_araddr[AXI_ADDR_WIDTH-1:ADDR_LSB];
    assign slv_reg_wren                         = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    assign slv_reg_rden                         = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    // I/O Connections assignments
    assign S_AXI_AWREADY                        = axi_awready;
    assign S_AXI_WREADY                         = axi_wready;
    assign S_AXI_BRESP                          = axi_bresp;
    assign S_AXI_BVALID                         = axi_bvalid;
    assign S_AXI_ARREADY                        = axi_arready;
    assign S_AXI_RDATA                          = axi_rdata;
    assign S_AXI_RRESP                          = axi_rresp;
    assign S_AXI_RVALID                         = axi_rvalid;

    // Implement axi_awready generation
    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end else begin    
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end 
    end       

    // Implement axi_awaddr latching
    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awaddr <= S_AXI_AWADDR;
            end
        end
    end

    // Implement axi_wready generation
    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_wready <= 1'b0;
        end else begin    
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end 
    end       

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            for (slv_index = 0;slv_index < SLVREG_NUM;slv_index = slv_index + 1) begin
                slv_reg[slv_index] <= 0;
            end
        end else if(slv_reg_wren) begin
            for ( byte_index = 0; byte_index <= (AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    slv_reg[wr_addr][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            end
        end
    end    

    // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_bvalid  <= 0;
            axi_bresp   <= 2'b0;
        end else begin    
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;
            end else begin
                if (S_AXI_BREADY && axi_bvalid) begin
                    axi_bvalid <= 1'b0; 
                end
            end
        end
    end

    // Implement axi_arready generation
    // axi_arready is asserted for one S_AXI_ACLK clock cycle when
    // S_AXI_ARVALID is asserted. axi_awready is 
    // de-asserted when reset (active low) is asserted. 
    // The read address is also latched when S_AXI_ARVALID is 
    // asserted. axi_araddr is reset to zero on reset assertion.
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 32'b0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Implement axi_arvalid generation
    // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
    // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
    // data are available on the axi_rdata bus at this instance. The 
    // assertion of axi_rvalid marks the validity of read data on the 
    // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
    // is deasserted on reset (active low). axi_rresp and axi_rdata are 
    // cleared to zero on reset (active low).  
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rvalid <= 0;
            axi_rresp  <= 0;
        end else begin    
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0;
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    // Output register or memory read data
    always @( posedge S_AXI_ACLK )begin
        if ( S_AXI_ARESETN == 1'b0 )begin
            axi_rdata  <= 0;
        end else if(slv_reg_rden) begin
            axi_rdata <= slv_reg[rd_addr];
        end
    end

    // Add user logic here
    assign  monitor = slv_reg[0];
    // User logic ends

    endmodule
