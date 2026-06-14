`timescale 1ns / 1ps


module ALU_Control(
    input  [1:0] ALUOp,      // từ Control Unit
    input  [2:0] funct3,     // từ Decoder
    input        funct7_5,   // instruction[30], phân biệt ADD/SUB, SRL/SRA
    input        isRtype,
    output reg [3:0] ALU_op  // sang ALU
);

always @(*) begin
    case (ALUOp)

        // LOAD / STORE: luôn ADD để tính địa chỉ
        2'b00: ALU_op = 4'b0000;

        // BRANCH: luôn SUB để so sánh (Branch_Comp tự xử lý logic nhảy)
        2'b01: ALU_op = 4'b0001;

        // R-type và I-type arithmetic: decode theo funct3 + funct7[5]
        2'b10: begin
            case (funct3)
                // ADD (R) / ADDI (I) / SUB (R)
                // funct7[5]=1 và là R-type → SUB; còn lại → ADD
                3'b000: ALU_op = (funct7_5 && isRtype) ? 4'b0001 : 4'b0000;

                // SLL / SLLI
                3'b001: ALU_op = 4'b0101;

                // SLT / SLTI
                3'b010: ALU_op = 4'b1000;

                // SLTU / SLTIU
                3'b011: ALU_op = 4'b1001;

                // XOR / XORI
                3'b100: ALU_op = 4'b0100;

                // SRL / SRLI (funct7[5]=0) hoặc SRA / SRAI (funct7[5]=1)
                3'b101: ALU_op = (funct7_5) ? 4'b0111 : 4'b0110;

                // OR / ORI
                3'b110: ALU_op = 4'b0011;

                // AND / ANDI
                3'b111: ALU_op = 4'b0010;

                default: ALU_op = 4'b0000;
            endcase
        end

        // AUIPC: ALUOp=2'b11 (xem Control_Unit), cần ADD
        2'b11: ALU_op = 4'b0000;

        default: ALU_op = 4'b0000;
    endcase
end

endmodule