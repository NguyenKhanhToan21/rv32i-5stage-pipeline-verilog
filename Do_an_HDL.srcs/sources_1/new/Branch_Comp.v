module BRANCH_COMP(
    input [31:0] rs1,
    input [31:0] rs2,
    input [2:0] funct3,

    output reg take_branch
);

always @(*) begin
    case(funct3)

    3'b000: take_branch = (rs1 == rs2);                      // BEQ
    3'b001: take_branch = (rs1 != rs2);                      // BNE
    3'b100: take_branch = ($signed(rs1) < $signed(rs2));     // BLT
    3'b101: take_branch = ($signed(rs1) >= $signed(rs2));    // BGE
    3'b110: take_branch = (rs1 < rs2);                       // BLTU
    3'b111: take_branch = (rs1 >= rs2);                      // BGEU

    default: take_branch = 0;

    endcase
end

endmodule