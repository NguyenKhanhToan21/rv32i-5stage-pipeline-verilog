`timescale 1ns / 1ps


module ID_EX_Reg (
    input  clk,
    input  rst,

    // Flush
    input  ID_EX_flush,   // 1 = flush → NOP bubble

    // ── Đầu vào (từ ID stage) 
    // Data
    input  [31:0] ID_read_data1,
    input  [31:0] ID_read_data2,
    input  [31:0] ID_imm,
    input  [31:0] ID_pc,
    input  [31:0] ID_pc4,
    // Register addresses
    input  [4:0]  ID_rs1,
    input  [4:0]  ID_rs2,
    input  [4:0]  ID_rd,
    // Decode fields
    input  [2:0]  ID_funct3,
    input         ID_funct7_5,
    input         ID_isRtype,
    // Control signals
    input         ID_RegWrite,
    input         ID_MemRead,
    input         ID_MemWrite,
    input         ID_ALUSrc,
    input           ID_ALUSrcA,
    input  [1:0]  ID_ALUOp,
    input  [1:0]  ID_ResultSrc,
    input  [1:0]  ID_PCSrc,
    input         ID_Branch,

    // ── Đầu ra (sang EX stage) 
    output reg [31:0] EX_read_data1,
    output reg [31:0] EX_read_data2,
    output reg [31:0] EX_imm,
    output reg [31:0] EX_pc,
    output reg [31:0] EX_pc4,
    output reg [4:0]  EX_rs1,
    output reg [4:0]  EX_rs2,
    output reg [4:0]  EX_rd,
    output reg [2:0]  EX_funct3,
    output reg        EX_funct7_5,
    output reg        EX_isRtype,
    output reg        EX_RegWrite,
    output reg        EX_MemRead,
    output reg        EX_MemWrite,
    output reg        EX_ALUSrc,
    output reg   EX_ALUSrcA,
    output reg [1:0]  EX_ALUOp,
    output reg [1:0]  EX_ResultSrc,
    output reg [1:0]  EX_PCSrc,
    output reg        EX_Branch
);

    always @(posedge clk or posedge rst) begin
        if (rst | ID_EX_flush) begin
            // Flush: control signals = 0 → NOP bubble
            EX_read_data1 <= 32'b0;
            EX_read_data2 <= 32'b0;
            EX_imm        <= 32'b0;
            EX_pc         <= 32'b0;
            EX_pc4        <= 32'b0;
            EX_rs1        <= 5'b0;
            EX_rs2        <= 5'b0;
            EX_rd         <= 5'b0;
            EX_funct3     <= 3'b0;
            EX_funct7_5   <= 1'b0;
            EX_isRtype    <= 1'b0;
            EX_RegWrite   <= 1'b0;
            EX_MemRead    <= 1'b0;
            EX_MemWrite   <= 1'b0;
            EX_ALUSrc     <= 1'b0;
            EX_ALUSrcA    <= 1'b0;
            EX_ALUOp      <= 2'b0;
            EX_ResultSrc  <= 2'b0;
            EX_PCSrc      <= 2'b0;
            EX_Branch     <= 1'b0;
        end else begin
            EX_read_data1 <= ID_read_data1;
            EX_read_data2 <= ID_read_data2;
            EX_imm        <= ID_imm;
            EX_pc         <= ID_pc;
            EX_pc4        <= ID_pc4;
            EX_rs1        <= ID_rs1;
            EX_rs2        <= ID_rs2;
            EX_rd         <= ID_rd;
            EX_funct3     <= ID_funct3;
            EX_funct7_5   <= ID_funct7_5;
            EX_isRtype    <= ID_isRtype;
            EX_RegWrite   <= ID_RegWrite;
            EX_MemRead    <= ID_MemRead;
            EX_MemWrite   <= ID_MemWrite;
            EX_ALUSrc     <= ID_ALUSrc;
            EX_ALUSrcA    <= ID_ALUSrcA;
            EX_ALUOp      <= ID_ALUOp;
            EX_ResultSrc  <= ID_ResultSrc;
            EX_PCSrc      <= ID_PCSrc;
            EX_Branch     <= ID_Branch;
        end
    end

endmodule