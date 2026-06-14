`timescale 1ns / 1ps


module CONTROL_UNIT(
    input  [6:0] opcode,

    output reg        Branch,
    output reg        MemRead,
    output reg        MemtoReg,
    output reg        MemWrite,
    output reg        ALUSrc,
    output reg        RegWrite,

    output reg        ALUSrcA,
    output reg [1:0]  ResultSrc,
    output reg [1:0]  PCSrc,
    output reg [1:0]  ALUOp
);

always @(*) begin
    // ---- Giá trị mặc định (tránh latch) ----
    Branch    = 1'b0;
    MemRead   = 1'b0;
    MemWrite  = 1'b0;
    ALUSrc    = 1'b0;
    RegWrite  = 1'b0;
    MemtoReg  = 1'b0;
    ALUSrcA   = 1'b0;
    ResultSrc = 2'b00;
    PCSrc     = 2'b00;
    ALUOp     = 2'b00;

    case (opcode)

        // ---- R-type (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU) ----
        7'b0110011: begin
            RegWrite  = 1'b1;
            ALUOp     = 2'b10;   // decode theo funct3/funct7
        end

        // ---- I-type arithmetic (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI) ----
        7'b0010011: begin
            RegWrite  = 1'b1;
            ALUSrc    = 1'b1;    // operand B = imm
            ALUOp     = 2'b10;   // decode theo funct3/funct7
        end

        // ---- LOAD (LW, LH, LB, LHU, LBU) ----
        7'b0000011: begin
            RegWrite  = 1'b1;
            MemRead   = 1'b1;
            ALUSrc    = 1'b1;    // addr = rs1 + imm
            ResultSrc = 2'b01;   // write-back từ memory
            ALUOp     = 2'b00;   // ADD
        end

        // ---- STORE (SW, SH, SB) ----
        7'b0100011: begin
            MemWrite  = 1'b1;
            ALUSrc    = 1'b1;    // addr = rs1 + imm
            ALUOp     = 2'b00;   // ADD
        end

        // ---- BRANCH (BEQ, BNE, BLT, BGE, BLTU, BGEU) ----
        // QUAN TRỌNG: KHÔNG set PCSrc ở đây.
        // Datapath sẽ tự quyết định pc_next bằng:
        //   if (Branch & take_branch) → branch_target
        //   else                      → PC + 4
        7'b1100011: begin
            Branch    = 1'b1;
            ALUOp     = 2'b01;   // SUB (để tính BEQ/BNE nếu cần, Branch_Comp xử lý chính)
            // PCSrc = 2'b00 (default) - Datapath tự xử lý
        end

        // ---- JAL ----
        7'b1101111: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b10;   // rd = PC + 4
            PCSrc     = 2'b01;   // PC_next = PC + imm
        end

        // ---- JALR ----
        7'b1100111: begin
            RegWrite  = 1'b1;
            ALUSrc    = 1'b1;    // rs1 + imm (tính trong Datapath riêng)
            ResultSrc = 2'b10;   // rd = PC + 4
            PCSrc     = 2'b10;   // PC_next = (rs1 + imm) & ~1
            ALUOp     = 2'b00;   // ADD
        end

        // ---- LUI ----
        7'b0110111: begin
            RegWrite  = 1'b1;
            ResultSrc = 2'b11;   // rd = imm (upper immediate)
        end

        // ---- AUIPC ----
        7'b0010111: begin
            RegWrite  = 1'b1;
            ALUSrcA   = 1'b1;   // operand A = PC
            ALUSrc    = 1'b1;    // operand B = imm
            ALUOp     = 2'b00;   // ADD → rd = PC + imm
            ResultSrc = 2'b00;   // write-back từ ALU result
        end
        default: begin 
            end
    endcase
end

endmodule