`timescale 1ns / 1ps



module RF (
    input clk, rst,
    input RegWrite,

    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,

    input [31:0] write_data,

    output [31:0] read_data1,
    output [31:0] read_data2
);

    reg [31:0] regs [0:31];
    integer i;

    assign read_data1 = (rs1 == 0)                             ? 32'b0      :
                        (RegWrite && rd != 0 && rd == rs1)     ? write_data  :
                                                                  regs[rs1];
    assign read_data2 = (rs2 == 0)                             ? 32'b0      :
                        (RegWrite && rd != 0 && rd == rs2)     ? write_data  :
                                                                  regs[rs2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (RegWrite && rd != 0)
                regs[rd] <= write_data;
        end
    end

endmodule