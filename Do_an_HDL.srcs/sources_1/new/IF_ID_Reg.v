`timescale 1ns / 1ps
module IF_ID_Reg (
    input  clk,
    input  rst,
    input  IF_ID_write,
    input  IF_ID_flush,
    input  [31:0] IF_pc,
    input  [31:0] IF_pc4,
    input  [31:0] IF_instr,
    output reg [31:0] ID_pc,
    output reg [31:0] ID_pc4,
    output reg [31:0] ID_instr
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ID_pc    <= 32'b0;
            ID_pc4   <= 32'b0;
            ID_instr <= 32'b0;
        end else if (IF_ID_flush) begin   // synchronous flush
            ID_pc    <= 32'b0;
            ID_pc4   <= 32'b0;
            ID_instr <= 32'b0;
        end else if (IF_ID_write) begin
            ID_pc    <= IF_pc;
            ID_pc4   <= IF_pc4;
            ID_instr <= IF_instr;
        end
    end
endmodule