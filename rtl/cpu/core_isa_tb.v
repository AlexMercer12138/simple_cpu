`timescale 1ns / 1ps

module merc32_isa_tb();

    localparam  OP_IMMEDIATE            = 4'b0001;
    localparam  OP_REGISTER             = 4'b0010;

    localparam  FUNC_SET                = 4'b0000;
    localparam  FUNC_ADD                = 4'b0001;
    localparam  FUNC_SUB                = 4'b0010;
    localparam  FUNC_AND                = 4'b0011;
    localparam  FUNC_OR                 = 4'b0100;
    localparam  FUNC_XOR                = 4'b0101;
    localparam  FUNC_SLL                = 4'b0110;
    localparam  FUNC_SRL                = 4'b0111;
    localparam  FUNC_SRA                = 4'b1000;
    localparam  FUNC_MWR                = 4'b1001;
    localparam  FUNC_MRD                = 4'b1010;
    localparam  FUNC_JAL                = 4'b1011;
    localparam  FUNC_BEQ                = 4'b1100;
    localparam  FUNC_BNE                = 4'b1101;
    localparam  FUNC_BLT                = 4'b1110;
    localparam  FUNC_BGE                = 4'b1111;

    reg clk = 0, rst_n = 0;
    integer i;

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
    wire [15:0] prog_addr;
    wire [31:0] prog_data;

    wire        lb_rden;
    wire        lb_wren;
    wire [31:0] lb_addr;
    wire [31:0] lb_wdata;
    reg         lb_wrack = 0;
    reg [31:0]  lb_rdata = 0;
    reg         lb_valid = 0;
    reg [31:0]  lb_ram  [0:255];

    initial begin
        for (i = 0;i < 256;i = i + 1) begin
            lb_ram[i] = 0;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            lb_wrack <= 0;
            lb_valid <= 0;
            lb_rdata <= 0;
        end else begin
            lb_ram[lb_addr] <= lb_wren ? lb_wdata : lb_ram[lb_addr];
            lb_wrack <= lb_wren;
            lb_valid <= lb_rden;
            lb_rdata <= lb_rden ? lb_ram[lb_addr] : lb_rdata;
        end
    end

    // Funct to ASCII string function (returns mnemonic with suffix)
    function [47:0] Opcode_ascii(
        input [3:0] opcode,
        input [3:0] funct
    );
        case (funct)
            FUNC_SET: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "SETI" : "SETR";
            FUNC_ADD: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "ADDI" : "ADDR";
            FUNC_SUB: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "SUBI" : "SUBR";
            FUNC_AND: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "ANDI" : "ANDR";
            FUNC_OR:  Opcode_ascii = (opcode == OP_IMMEDIATE) ? "ORI " : "ORR ";
            FUNC_XOR: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "XORI" : "XORR";
            FUNC_SLL: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "SLLI" : "SLLR";
            FUNC_SRL: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "SRLI" : "SRLR";
            FUNC_SRA: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "SRAI" : "SRAR";
            FUNC_MWR: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "MWRI" : "MWRR";
            FUNC_MRD: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "MRDI" : "MRDR";
            FUNC_JAL: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "JALI" : "JALR";
            FUNC_BEQ: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "BEQI" : "BEQR";
            FUNC_BNE: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "BNEI" : "BNER";
            FUNC_BLT: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "BLTI" : "BLTR";
            FUNC_BGE: Opcode_ascii = (opcode == OP_IMMEDIATE) ? "BGEI" : "BGER";
            default:  Opcode_ascii = "????";
        endcase
    endfunction

    // Instruction trace: print formatted instruction when prog_step is enabled
    // New instruction format:
    // [31:16] immediate/src_1, [15:12] src_2, [11:8] dest, [7:4] opcode, [3:0] funct
        // Instruction trace: print formatted instruction when prog_step is enabled
    // New instruction format:
    // [31:16] immediate/src_1, [15:12] src_2, [11:8] dest, [7:4] opcode, [3:0] funct
    always @(posedge clk) begin
        if (cpu_inst.prog_step) begin
            case({prog_data[7:4], prog_data[3:0]})
                // OP_IMMEDIATE: I-Type uses immediate [31:16]
                {OP_IMMEDIATE, FUNC_SET}: begin
                    $display("[%0d] : %s R%0d, %0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], $signed(prog_data[31:16]));
                end
                
                {OP_IMMEDIATE, FUNC_ADD},
                {OP_IMMEDIATE, FUNC_SUB},
                {OP_IMMEDIATE, FUNC_AND},
                {OP_IMMEDIATE, FUNC_OR},
                {OP_IMMEDIATE, FUNC_XOR}: begin
                    $display("[%0d] : %s R%0d, R%0d, %0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], $signed(prog_data[31:16]));
                end
                
                {OP_IMMEDIATE, FUNC_SLL},
                {OP_IMMEDIATE, FUNC_SRL},
                {OP_IMMEDIATE, FUNC_SRA}: begin
                    $display("[%0d] : %s R%0d, R%0d, %0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], prog_data[31:16]);
                end
                
                {OP_IMMEDIATE, FUNC_MWR}: begin
                    $display("[%0d] : %s [R%0d + %0d], R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[15:12], $signed(prog_data[31:16]), prog_data[11:8]);
                end
                
                {OP_IMMEDIATE, FUNC_MRD}: begin
                    $display("[%0d] : %s R%0d, [R%0d + %0d]", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], $signed(prog_data[31:16]));
                end
                
                {OP_IMMEDIATE, FUNC_JAL}: begin
                    $display("[%0d] : %s %0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[31:16], prog_data[11:8]);
                end
                
                {OP_IMMEDIATE, FUNC_BEQ},
                {OP_IMMEDIATE, FUNC_BNE},
                {OP_IMMEDIATE, FUNC_BLT},
                {OP_IMMEDIATE, FUNC_BGE}: begin
                    $display("[%0d] : %s %0d, R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[31:16], prog_data[15:12], prog_data[11:8]);
                end
                
                // OP_REGISTER: R-Type uses src_1 [19:16]
                {OP_REGISTER, FUNC_SET}: begin
                    $display("[%0d] : %s R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[19:16]);
                end
                
                {OP_REGISTER, FUNC_ADD},
                {OP_REGISTER, FUNC_SUB},
                {OP_REGISTER, FUNC_AND},
                {OP_REGISTER, FUNC_OR},
                {OP_REGISTER, FUNC_XOR}: begin
                    $display("[%0d] : %s R%0d, R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], prog_data[19:16]);
                end
                
                {OP_REGISTER, FUNC_SLL},
                {OP_REGISTER, FUNC_SRL},
                {OP_REGISTER, FUNC_SRA}: begin
                    $display("[%0d] : %s R%0d, R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], prog_data[19:16]);
                end
                
                {OP_REGISTER, FUNC_MWR}: begin
                    $display("[%0d] : %s [R%0d + R%0d], R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[15:12], prog_data[19:16], prog_data[11:8]);
                end
                
                {OP_REGISTER, FUNC_MRD}: begin
                    $display("[%0d] : %s R%0d, [R%0d + R%0d]", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[11:8], prog_data[15:12], prog_data[19:16]);
                end
                
                {OP_REGISTER, FUNC_JAL}: begin
                    $display("[%0d] : %s R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[19:16], prog_data[11:8]);
                end
                
                {OP_REGISTER, FUNC_BEQ},
                {OP_REGISTER, FUNC_BNE},
                {OP_REGISTER, FUNC_BLT},
                {OP_REGISTER, FUNC_BGE}: begin
                    $display("[%0d] : %s R%0d, R%0d, R%0d", 
                             prog_addr, Opcode_ascii(prog_data[7:4], prog_data[3:0]), 
                             prog_data[19:16], prog_data[15:12], prog_data[11:8]);
                end

                default:begin
                    $display("Unknown opcode!");
                end
            endcase
        end
    end

    // Instantiate MERC32
    merc32_core cpu_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // Program memory interface
        .prog_load      (prog_load),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),

        .lb_rden        (lb_rden),
        .lb_wren        (lb_wren),
        .lb_addr        (lb_addr),
        .lb_wdata       (lb_wdata),
        .lb_wrack       (lb_wrack),
        .lb_rdata       (lb_rdata),
        .lb_valid       (lb_valid)
    );

    // Instantiate Program Memory (ROM)
    inst_test rom_inst (
        .prog_addr      (prog_addr),
        .prog_data      (prog_data)
    );

    initial begin
        wait(prog_load && (prog_addr == 88)) $finish;
    end

    initial begin
        $dumpfile("merc32_isa_tb.vcd");
        $dumpvars(0, merc32_isa_tb);
    end

    initial begin
        #10000 $finish;
    end

endmodule
