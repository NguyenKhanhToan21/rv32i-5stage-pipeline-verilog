`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2026 03:53:15 PM
// Design Name: 
// Module Name: RF_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module RF_tb;
    reg clk,rst, RegWrite;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;    
    reg [31:0] write_data;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    
    RF uut(
        .clk(clk),
        .rst(rst),
        .RegWrite(RegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
        );
     always         
        #5 clk = ~clk;
     initial begin 
        clk = 0;
        rst = 1;
        RegWrite = 0;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        write_data =0;
        #10 rst = 0;
        #10 // case 1: viet thanh ghi 1 = 10
            RegWrite = 1;
            rd = 5'd1;
            write_data = 32'd10; 
        #10 // Doc thanh ghi 1 (sau khi posegde clk = 25), doc la combinational
            RegWrite = 0;
            rs1 = 5'd1;
        #10 // case 2: viet thanh ghi 2 = 20 
            RegWrite = 1;
            rd = 5'd2;
            write_data = 32'd20;
        #10 // Doc thanh ghi 2 
            RegWrite = 0;
            rs2 = 5'd2;
            rs1 = 5'd1;
       #10;
            RegWrite = 1;
            rd = 5'd0;
            write_data = 32'd999;
            
            #10;
            RegWrite = 0;
            rs1 = 5'd0;
        #20
        $finish;
        end
endmodule
