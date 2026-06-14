`timescale 1ns / 1ps


module MEM_WB_Reg (
    input  clk,
    input  rst,

    // ── Đầu vào (từ MEM stage) 
    input  [31:0] MEM_mem_read_data,
    input  [31:0] MEM_alu_result,
    input  [31:0] MEM_pc4,
    input  [31:0] MEM_imm,
    input  [4:0]  MEM_rd,
    input         MEM_RegWrite,
    input  [1:0]  MEM_ResultSrc,

    // ── Đầu ra (sang WB stage) 
    output reg [31:0] WB_mem_read_data,
    output reg [31:0] WB_alu_result,
    output reg [31:0] WB_pc4,
    output reg [31:0] WB_imm,
    output reg [4:0]  WB_rd,
    output reg        WB_RegWrite,
    output reg [1:0]  WB_ResultSrc
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            WB_mem_read_data <= 32'b0;
            WB_alu_result    <= 32'b0;
            WB_pc4           <= 32'b0;
            WB_imm           <= 32'b0;
            WB_rd            <= 5'b0;
            WB_RegWrite      <= 1'b0;
            WB_ResultSrc     <= 2'b0;
        end else begin
            WB_mem_read_data <= MEM_mem_read_data;
            WB_alu_result    <= MEM_alu_result;
            WB_pc4           <= MEM_pc4;
            WB_imm           <= MEM_imm;
            WB_rd            <= MEM_rd;
            WB_RegWrite      <= MEM_RegWrite;
            WB_ResultSrc     <= MEM_ResultSrc;
        end
    end

endmodule