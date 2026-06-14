`timescale 1ns / 1ps


module I_MEM(
    input        clk,
    input        we,                  // write enable (dùng khi nạp code)
    input  [31:0] PC,
    input  [31:0] write_data,
    input  [7:0]  write_addr,
    output [31:0] instruction
);

    reg [31:0] mem [0:255];

    // Đọc lệnh bất đồng bộ (combinational) theo PC
    assign instruction = mem[PC[9:2]];

    // Ghi lệnh đồng bộ (dùng khi nạp chương trình qua testbench)
    always @(posedge clk) begin
        if (we)
            mem[write_addr] <= write_data;
    end


/*initial begin
    mem[0]  = 32'h00500093;
    mem[1]  = 32'h00A00113;
    mem[2]  = 32'h002081B3;
    mem[3]  = 32'h00302023;
    mem[4]  = 32'h00002183;
    mem[5]  = 32'hFE3190E3;
    mem[6]  = 32'h00000013; // nop
    mem[7]  = 32'h00000013; // nop
end */ //pipeline 
initial begin
    mem[0]  = 32'h00500093; // addi x1, x0, 5      x1 = 5
    mem[1]  = 32'h00A00113; // addi x2, x0, 10     x2 = 10
    mem[2]  = 32'h00000013; // nop
    mem[3]  = 32'h00000013; // nop
    mem[4]  = 32'h002081B3; // add  x3, x1, x2     x3 = 15
    mem[5]  = 32'h00000013; // nop
    mem[6]  = 32'h00000013; // nop
    mem[7]  = 32'h00302023; // sw   x3, 0(x0)      mem[0] = 15
    mem[8]  = 32'h00000013; // nop
    mem[9]  = 32'h00000013; // nop
    mem[10] = 32'h00002183; // lw   x3, 0(x0)      x3 = mem[0] = 15
    mem[11] = 32'h00000013; // nop
    mem[12] = 32'h00000013; // nop
    mem[13] = 32'h00000013; // nop
end
// non-pipeline
endmodule