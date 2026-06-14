`timescale 1ns / 1ps



module ALU(
    input [31:0] A,
    input [31:0] B,
    input [3:0] ALU_op,

    output reg [31:0] ALU_Out,
    output Zero
);

    always @(*) begin
        case(ALU_op)

            4'b0000: ALU_Out = A + B;              // ADD
            4'b0001: ALU_Out = A - B;              // SUB
            4'b0010: ALU_Out = A & B;              // AND
            4'b0011: ALU_Out = A | B;              // OR
            4'b0100: ALU_Out = A ^ B;              // XOR
            4'b0101: ALU_Out = A << B[4:0];        // SLL
            4'b0110: ALU_Out = A >> B[4:0];        // SRL
            4'b0111: ALU_Out = $signed(A) >>> B[4:0]; // SRA
            4'b1000: ALU_Out = ($signed(A) < $signed(B)) ? 1 : 0; // SLT
            4'b1001: ALU_Out = (A < B) ? 1 : 0; // SLTU
            
            default: ALU_Out = 32'b0;

        endcase
    end

    assign Zero = (ALU_Out == 0);

endmodule