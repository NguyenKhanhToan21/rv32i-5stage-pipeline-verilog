`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Pipeline_Regs
// Description: 4 thanh ghi pipeline cho RISC-V 5-stage
//              IF/ID  →  ID/EX  →  EX/MEM  →  MEM/WB
//
// Flush logic:
//   - IF_ID_flush  : xóa khi branch taken (điền NOP = 0)
//   - ID_EX_flush  : xóa khi branch taken HOẶC load-use hazard
//
// Stall logic:
//   - IF_ID_write=0 : giữ nguyên IF/ID (khi load-use hazard)
//   - PC_write=0    : giữ nguyên PC    (xử lý ở Datapath)
//////////////////////////////////////////////////////////////////////////////////

module Pipeline_Regs (
    input clk,
    input rst,

    // ── Stall / Flush controls ──────────────────────────────────────────
    input        PC_write,       // 0 = stall PC
    input        IF_ID_write,    // 0 = stall IF/ID register
    input        IF_ID_flush,    // 1 = flush IF/ID (branch taken)
    input        ID_EX_flush,    // 1 = flush ID/EX (branch taken hoặc load-use)

    // ══════════════════════════════════════════════════════════════════
    // IF/ID  ─  đầu vào
    // ══════════════════════════════════════════════════════════════════
    input [31:0] IF_pc,
    input [31:0] IF_pc4,
    input [31:0] IF_instr,

    // IF/ID  ─  đầu ra
    output reg [31:0] ID_pc,
    output reg [31:0] ID_pc4,
    output reg [31:0] ID_instr,

    // ══════════════════════════════════════════════════════════════════
    // ID/EX  ─  đầu vào (tất cả control signals + data)
    // ══════════════════════════════════════════════════════════════════
    // Data
    input [31:0] ID_read_data1,
    input [31:0] ID_read_data2,
    input [31:0] ID_imm,
    input [31:0] ID_pc_in,
    input [31:0] ID_pc4_in,
    // Register addresses (dùng cho forwarding và WB)
    input [4:0]  ID_rs1,
    input [4:0]  ID_rs2,
    input [4:0]  ID_rd,
    // Decode fields
    input [2:0]  ID_funct3,
    input        ID_funct7_5,
    input        ID_isRtype,
    // Control signals
    input        ID_RegWrite,
    input        ID_MemRead,
    input        ID_MemWrite,
    input        ID_ALUSrc,
    input [1:0]  ID_ALUSrcA,
    input [1:0]  ID_ALUOp,
    input [1:0]  ID_ResultSrc,
    input [1:0]  ID_PCSrc,
    input        ID_Branch,

    // ID/EX  ─  đầu ra
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
    output reg [1:0]  EX_ALUSrcA,
    output reg [1:0]  EX_ALUOp,
    output reg [1:0]  EX_ResultSrc,
    output reg [1:0]  EX_PCSrc,
    output reg        EX_Branch,

    // ══════════════════════════════════════════════════════════════════
    // EX/MEM  ─  đầu vào
    // ══════════════════════════════════════════════════════════════════
    input [31:0] EX_alu_result,
    input [31:0] EX_write_data,   // rs2 data (sau forwarding) → ghi vào DMEM
    input [31:0] EX_pc4_in,
    input [31:0] EX_imm_in,
    input [4:0]  EX_rd_in,
    input [2:0]  EX_funct3_in,
    input        EX_RegWrite_in,
    input        EX_MemRead_in,
    input        EX_MemWrite_in,
    input [1:0]  EX_ResultSrc_in,
    input        EX_Branch_in,
    input        EX_take_branch_in,
    input [31:0] EX_branch_target_in,

    // EX/MEM  ─  đầu ra
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

    // ══════════════════════════════════════════════════════════════════
    // MEM/WB  ─  đầu vào
    // ══════════════════════════════════════════════════════════════════
    input [31:0] MEM_mem_read_data,
    input [31:0] MEM_alu_result_in,
    input [31:0] MEM_pc4_in,
    input [31:0] MEM_imm_in,
    input [4:0]  MEM_rd_in,
    input        MEM_RegWrite_in,
    input [1:0]  MEM_ResultSrc_in,

    // MEM/WB  ─  đầu ra
    output reg [31:0] WB_mem_read_data,
    output reg [31:0] WB_alu_result,
    output reg [31:0] WB_pc4,
    output reg [31:0] WB_imm,
    output reg [4:0]  WB_rd,
    output reg        WB_RegWrite,
    output reg [1:0]  WB_ResultSrc
);

    // ──────────────────────────────────────────────────────────────────
    // IF/ID register
    // ──────────────────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst || IF_ID_flush) begin
            ID_pc    <= 32'b0;
            ID_pc4   <= 32'b0;
            ID_instr <= 32'b0;  // NOP = 0x00000000
        end else if (IF_ID_write) begin
            ID_pc    <= IF_pc;
            ID_pc4   <= IF_pc4;
            ID_instr <= IF_instr;
        end
        // else: giữ nguyên (stall)
    end

    // ──────────────────────────────────────────────────────────────────
    // ID/EX register
    // ──────────────────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst || ID_EX_flush) begin
            // Flush: tất cả control signals = 0 → NOP bubble
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
            EX_ALUSrcA    <= 2'b0;
            EX_ALUOp      <= 2'b0;
            EX_ResultSrc  <= 2'b0;
            EX_PCSrc      <= 2'b0;
            EX_Branch     <= 1'b0;
        end else begin
            EX_read_data1 <= ID_read_data1;
            EX_read_data2 <= ID_read_data2;
            EX_imm        <= ID_imm;
            EX_pc         <= ID_pc_in;
            EX_pc4        <= ID_pc4_in;
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

    // ──────────────────────────────────────────────────────────────────
    // EX/MEM register
    // ──────────────────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_alu_result   <= 32'b0;
            MEM_write_data   <= 32'b0;
            MEM_pc4          <= 32'b0;
            MEM_imm          <= 32'b0;
            MEM_rd           <= 5'b0;
            MEM_funct3       <= 3'b0;
            MEM_RegWrite     <= 1'b0;
            MEM_MemRead      <= 1'b0;
            MEM_MemWrite     <= 1'b0;
            MEM_ResultSrc    <= 2'b0;
            MEM_Branch       <= 1'b0;
            MEM_take_branch  <= 1'b0;
            MEM_branch_target<= 32'b0;
        end else begin
            MEM_alu_result   <= EX_alu_result;
            MEM_write_data   <= EX_write_data;
            MEM_pc4          <= EX_pc4_in;
            MEM_imm          <= EX_imm_in;
            MEM_rd           <= EX_rd_in;
            MEM_funct3       <= EX_funct3_in;
            MEM_RegWrite     <= EX_RegWrite_in;
            MEM_MemRead      <= EX_MemRead_in;
            MEM_MemWrite     <= EX_MemWrite_in;
            MEM_ResultSrc    <= EX_ResultSrc_in;
            MEM_Branch       <= EX_Branch_in;
            MEM_take_branch  <= EX_take_branch_in;
            MEM_branch_target<= EX_branch_target_in;
        end
    end

    // ──────────────────────────────────────────────────────────────────
    // MEM/WB register
    // ──────────────────────────────────────────────────────────────────
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
            WB_alu_result    <= MEM_alu_result_in;
            WB_pc4           <= MEM_pc4_in;
            WB_imm           <= MEM_imm_in;
            WB_rd            <= MEM_rd_in;
            WB_RegWrite      <= MEM_RegWrite_in;
            WB_ResultSrc     <= MEM_ResultSrc_in;
        end
    end

endmodule
