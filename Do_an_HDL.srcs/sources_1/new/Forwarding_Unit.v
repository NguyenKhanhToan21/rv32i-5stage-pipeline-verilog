`timescale 1ns / 1ps

module Forwarding_Unit (
    // Registers của instruction đang ở EX stage
    input [4:0] EX_rs1,
    input [4:0] EX_rs2,

    // EX/MEM pipeline register
    input        MEM_RegWrite,
    input [4:0]  MEM_rd,

    // MEM/WB pipeline register
    input        WB_RegWrite,
    input [4:0]  WB_rd,

    // Outputs: chọn nguồn forwarding
    output reg [1:0] forwardA,
    output reg [1:0] forwardB,
    output reg       forwardM    // forward vào STORE write_data
);

    always @(*) begin
        // ── forwardA
        // Ưu tiên EX/MEM trước (gần hơn → mới hơn)
        if (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs1))
            forwardA = 2'b10;  // EX/MEM → EX
        else if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == EX_rs1))
            forwardA = 2'b01;  // MEM/WB → EX
        else
            forwardA = 2'b00;  // register file

        // ── forwardB 
        if (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs2))
            forwardB = 2'b10;  // EX/MEM → EX
        else if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == EX_rs2))
            forwardB = 2'b01;  // MEM/WB → EX
        else
            forwardB = 2'b00;  // register file

        // ── forwardM: forward cho STORE write data (rs2 của STORE) ───
        // STORE dùng rs2 làm write_data; nếu WB stage đang ghi vào rd == rs2 của STORE
        if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == EX_rs2) &&
            !(MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs2)))
            forwardM = 1'b1;  // dùng WB write_back làm store data
        else
            forwardM = 1'b0;
    end

endmodule
