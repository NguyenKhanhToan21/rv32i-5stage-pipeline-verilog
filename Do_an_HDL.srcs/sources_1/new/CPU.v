`timescale 1ns / 1ps


module CPU(
    input clk,
    input rst,
    output [31:0] debug_wb     // thêm
);

    // ---- Wire từ Datapath expose ra để Control Unit đọc opcode ----
    wire [6:0] opcode_w;

    // ---- Control signals ----
    wire        Branch_w, MemRead_w, MemtoReg_w, MemWrite_w;
    wire        ALUSrc_w, RegWrite_w;
    wire [1:0]  ALUSrcA_w, ResultSrc_w, PCSrc_w, ALUOp_w;

    // ---- Control Unit ----
    CONTROL_UNIT ctrl (
        .opcode    (opcode_w),
        .Branch    (Branch_w),
        .MemRead   (MemRead_w),
        .MemtoReg  (MemtoReg_w),
        .MemWrite  (MemWrite_w),
        .ALUSrc    (ALUSrc_w),
        .RegWrite  (RegWrite_w),
        .ALUSrcA   (ALUSrcA_w),
        .ResultSrc (ResultSrc_w),
        .PCSrc     (PCSrc_w),
        .ALUOp     (ALUOp_w)
    );

    // ---- Datapath ----
    Datapath dp (
        .clk       (clk),
        .rst       (rst),
        .Branch    (Branch_w),
        .MemRead   (MemRead_w),
        .MemtoReg  (MemtoReg_w),
        .MemWrite  (MemWrite_w),
        .ALUSrc    (ALUSrc_w),
        .RegWrite  (RegWrite_w),
        .ALUSrcA   (ALUSrcA_w),
        .ResultSrc (ResultSrc_w),
        .PCSrc     (PCSrc_w),
        .ALUOp     (ALUOp_w),
        .opcode_out(opcode_w),
        .debug_wb  (debug_wb)    // thêm
    );

endmodule