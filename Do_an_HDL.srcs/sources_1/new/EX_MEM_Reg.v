`timescale 1ns / 1ps


module EX_MEM_Reg (
    input  clk,
    input  rst,

    // ── Đầu vào (từ EX stage)  
    input  [31:0] EX_alu_result,
    input  [31:0] EX_write_data,
    input  [31:0] EX_pc4,
    input  [31:0] EX_imm,
    input  [4:0]  EX_rd,
    input  [2:0]  EX_funct3,
    input         EX_RegWrite,
    input         EX_MemRead,
    input         EX_MemWrite,
    input  [1:0]  EX_ResultSrc,
    input         EX_Branch,
    input         EX_take_branch,
    input  [31:0] EX_branch_target,

    // ── Đầu ra (sang MEM stage) 
    output reg [31:0] MEM_alu_result,
    output reg [31:0] MEM_write_data,
    output reg [31:0] MEM_pc4,
    output reg [31:0] MEM_imm,
    output reg [4:0]  MEM_rd,
    output reg [2:0]  MEM_funct3,
    output reg        MEM_RegWrite,
    output reg        MEM_MemRead,
    output reg        MEM_MemWrite,
    output reg [1:0]  MEM_ResultSrc,
    output reg        MEM_Branch,
    output reg        MEM_take_branch,
    output reg [31:0] MEM_branch_target,

    // 
    output reg [31:0] MEM_result_fwd
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_alu_result    <= 32'b0;
            MEM_write_data    <= 32'b0;
            MEM_pc4           <= 32'b0;
            MEM_imm           <= 32'b0;
            MEM_rd            <= 5'b0;
            MEM_funct3        <= 3'b0;
            MEM_RegWrite      <= 1'b0;
            MEM_MemRead       <= 1'b0;
            MEM_MemWrite      <= 1'b0;
            MEM_ResultSrc     <= 2'b0;
            MEM_Branch        <= 1'b0;
            MEM_take_branch   <= 1'b0;
            MEM_branch_target <= 32'b0;
            MEM_result_fwd    <= 32'b0;
        end else begin
            MEM_alu_result    <= EX_alu_result;
            MEM_write_data    <= EX_write_data;
            MEM_pc4           <= EX_pc4;
            MEM_imm           <= EX_imm;
            MEM_rd            <= EX_rd;
            MEM_funct3        <= EX_funct3;
            MEM_RegWrite      <= EX_RegWrite;
            MEM_MemRead       <= EX_MemRead;
            MEM_MemWrite      <= EX_MemWrite;
            MEM_ResultSrc     <= EX_ResultSrc;
            MEM_Branch        <= EX_Branch;
            MEM_take_branch   <= EX_take_branch;
            MEM_branch_target <= EX_branch_target;

            
            case (EX_ResultSrc)
                2'b11:   MEM_result_fwd <= EX_imm;          // LUI
                2'b10:   MEM_result_fwd <= EX_pc4;          // JAL/JALR
                default: MEM_result_fwd <= EX_alu_result;   // normal ALU
            endcase
        end
    end

endmodule