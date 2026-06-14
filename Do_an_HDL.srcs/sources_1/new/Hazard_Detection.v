`timescale 1ns / 1ps


module Hazard_Detection (
    // ── Load-Use inputs (từ ID/EX và IF/ID) ──
    input        EX_MemRead,   // ID/EX.MemRead
    input [4:0]  EX_rd,        // ID/EX.rd
    input [4:0]  ID_rs1,       // IF/ID decoded rs1
    input [4:0]  ID_rs2,       // IF/ID decoded rs2

    // ── Control hazard inputs từ ID stage (JAL) ──
    input [1:0]  ID_PCSrc,         // PCSrc từ ctrl unit decode tại ID (JAL=01)

    // ── Control hazard inputs từ EX stage (Branch/JALR) ──
    input        EX_Branch,        // ID/EX.Branch
    input        EX_take_branch,   // từ BRANCH_COMP tại EX
    input [1:0]  EX_PCSrc,         // ID/EX.PCSrc (JALR=10)

    // ── Outputs ──
    output PC_write,       // 0 = stall PC
    output IF_ID_write,    // 0 = stall IF/ID register
    output IF_ID_flush,    // 1 = flush IF/ID (điền NOP)
    output ID_EX_flush     // 1 = flush ID/EX (bubble)
);

    // Load-use hazard: phải stall + bubble
    wire load_use_hazard = EX_MemRead &&
                           ((EX_rd == ID_rs1) || (EX_rd == ID_rs2)) &&
                           (EX_rd != 5'b0);

    // Branch/JALR resolved tại EX: flush 2 instructions đã fetch sai
    wire do_flush_ex = (EX_Branch & EX_take_branch) | (EX_PCSrc == 2'b10);

    // JAL resolved tại ID: chỉ flush IF/ID (1 instruction đã fetch sai)
    wire do_flush_id = (ID_PCSrc == 2'b01);

    // PC: dừng khi stall, chạy bình thường khi flush
    assign PC_write    = ~load_use_hazard;

    // IF/ID: dừng khi stall, flush khi branch/jump
    assign IF_ID_write = ~load_use_hazard;
    assign IF_ID_flush = (do_flush_ex | do_flush_id) & ~load_use_hazard;

    // ID/EX: bubble khi stall (load-use) hoặc flush EX-stage (branch/JALR)
    assign ID_EX_flush = load_use_hazard | do_flush_ex;

endmodule