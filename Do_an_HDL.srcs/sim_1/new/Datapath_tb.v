`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:37:58 PM
// Design Name: 
// Module Name: Datapath_tb
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

module tb_Datapath();

    // Khai báo các tín hiệu
    reg clk;
    reg rst;
    
    // Các thanh ghi để điều khiển Datapath từ Testbench
    reg Branch;
    reg MemRead;
    reg MemtoReg;
    reg MemWrite;
    reg ALUSrc;
    reg RegWrite;
    reg [3:0] ALU_op_ctrl;

    // Gọi module Datapath
    Datapath dut (
        .clk(clk),
        .rst(rst),
        .Branch(Branch),
        .MemRead(MemRead),
        .MemtoReg(MemtoReg),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .ALU_op_ctrl(ALU_op_ctrl)
    );

    // Tạo xung clock chu kỳ 10ns
    always #5 clk = ~clk;

    // Kịch bản điều khiển (Đồng bộ với 3 lệnh nạp trong I_MEM)
    initial begin
        // Khởi tạo
        clk = 0; 
        rst = 1;
        
        // Tắt hết mọi tín hiệu điều khiển
        Branch = 0; MemRead = 0; MemtoReg = 0; 
        MemWrite = 0; ALUSrc = 0; RegWrite = 0; 
        ALU_op_ctrl = 4'b0000;
        
        #20; // Đợi reset xong
        rst = 0; 

        // --------------------------------------------------------
        // CHU KỲ 1: Lệnh "addi x1, x0, 5" (Time: 20ns -> 30ns)
        // --------------------------------------------------------
        // - Lấy dữ liệu B từ Imm Gen (ALUSrc = 1)
        // - ALU thực hiện Cộng (ALU_op_ctrl = 0000)
        // - Ghi kết quả ALU vào RF (MemtoReg = 0, RegWrite = 1)
        ALUSrc = 1; 
        ALU_op_ctrl = 4'b0000; 
        MemtoReg = 0; 
        RegWrite = 1;
        #10; 

        // --------------------------------------------------------
        // CHU KỲ 2: Lệnh "addi x2, x1, 10" (Time: 30ns -> 40ns)
        // --------------------------------------------------------
        // Tín hiệu giống hệt lệnh trên (vì cùng là addi)
        ALUSrc = 1; 
        ALU_op_ctrl = 4'b0000; 
        MemtoReg = 0; 
        RegWrite = 1;
        #10;

        // --------------------------------------------------------
        // CHU KỲ 3: Lệnh "add x3, x1, x2" (Time: 40ns -> 50ns)
        // --------------------------------------------------------
        // - Lấy dữ liệu B từ Register File (ALUSrc = 0)
        // - ALU thực hiện Cộng (ALU_op_ctrl = 0000)
        // - Ghi kết quả ALU vào RF (MemtoReg = 0, RegWrite = 1)
        ALUSrc = 0; 
        ALU_op_ctrl = 4'b0000; 
        MemtoReg = 0; 
        RegWrite = 1;
        #10;

        // --------------------------------------------------------
        // KẾT THÚC: Tắt ghi để bảo vệ thanh ghi
        // --------------------------------------------------------
        RegWrite = 0;
        #20;
        
        $finish;
    end

endmodule