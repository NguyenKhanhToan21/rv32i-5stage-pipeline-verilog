`timescale 1ns / 1ps


module Datapath(
    input clk,
    input rst,

    // Control signals từ CONTROL_UNIT
    input        Branch,
    input        MemRead,
    input        MemtoReg,
    input        MemWrite,
    input        ALUSrc,
    input        RegWrite,
    input [1:0]  ALUSrcA,    // 00=rs1, 01=PC
    input [1:0]  ResultSrc,  // 00=ALU, 01=MEM, 10=PC+4, 11=imm
    input [1:0]  PCSrc,      // 00=PC+4(default), 01=PC+imm(JAL), 10=rs1+imm(JALR)
    input [1:0]  ALUOp,      // sang ALU_Control

    // Expose opcode để CPU top-level kết nối với Control Unit
    output [6:0] opcode_out,
    output [31:0] debug_wb
);
    // PC
    wire [31:0] pc_out, pc_next, pc_plus4;
    wire [31:0] branch_target, jalr_target;

    assign pc_plus4      = pc_out + 32'd4;
    assign branch_target = pc_out + imm_out;                     // JAL và BRANCH
    assign jalr_target   = (read_data1 + imm_out) & ~32'b1;      // JALR: clear bit 0

    // Quyết định PC tiếp theo
    // Branch: chỉ nhảy khi CẢ Branch=1 VÀ take_branch=1
    wire do_branch = Branch & take_branch;

    assign pc_next = (do_branch)          ? branch_target :  // BRANCH thỏa điều kiện
                     (PCSrc == 2'b10)     ? jalr_target   :  // JALR
                     (PCSrc == 2'b01)     ? branch_target :  // JAL
                     pc_plus4;                               // default

    PC pc_inst (
        .clk     (clk),
        .rst     (rst),
        .enable  (1'b1),
        .pc_next (pc_next),
        .pc      (pc_out)
    );

    
    // Instruction Memory
    
    wire [31:0] instruction;

    I_MEM imem_inst (
        .clk        (clk),
        .we         (1'b0),
        .PC         (pc_out),
        .write_data (32'b0),
        .write_addr (8'b0),
        .instruction(instruction)
    );

    
    // Decoder
    
    wire [6:0] opcode;
    assign opcode_out = opcode;   // kết nối ra CPU top-level → Control Unit
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] shamt;

    DECODER decoder_inst (
        .instruction(instruction),
        .opcode     (opcode),
        .rd         (rd),
        .funct3     (funct3),
        .rs1        (rs1),
        .rs2        (rs2),
        .funct7     (funct7),
        .shamt      (shamt)
    );

    
    // Immediate Generator
    
    wire [31:0] imm_out;

    IMM_GEN imm_gen_inst (
        .instruction(instruction),
        .imm        (imm_out)
    );

    
    // Register File
    
    wire [31:0] read_data1, read_data2, write_data_rf;

    RF rf_inst (
        .clk        (clk),
        .rst        (rst),
        .RegWrite   (RegWrite),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (write_data_rf),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    
    // ALU_Control: decode ALUOp + funct3 + funct7[5] → ALU_op
    
    wire [3:0] alu_op_wire;

    // isRtype = 1 khi opcode là R-type (0110011)
    wire isRtype_w = (opcode == 7'b0110011);

    ALU_Control alu_ctrl_inst (
        .ALUOp   (ALUOp),
        .funct3  (funct3),
        .funct7_5(funct7[5]),
        .isRtype (isRtype_w),
        .ALU_op  (alu_op_wire)
    );

    
    // ALU Input A MUX: rs1 hoặc PC (cho AUIPC)
    
    wire [31:0] alu_in_a;

    assign alu_in_a = (ALUSrcA == 2'b01) ? pc_out : read_data1;

    
    // ALU Input B MUX: rs2 hoặc imm
    
    wire [31:0] alu_in_b;

    assign alu_in_b = ALUSrc ? imm_out : read_data2;

    
    // ALU
    
    wire [31:0] alu_result;
    wire        alu_zero;

    ALU alu_inst (
        .A      (alu_in_a),
        .B      (alu_in_b),
        .ALU_op (alu_op_wire),
        .ALU_Out(alu_result),
        .Zero   (alu_zero)
    );

    
    // Branch Comparator: quyết định có nhảy không
    
    wire take_branch;

    BRANCH_COMP branch_comp_inst (
        .rs1       (read_data1),
        .rs2       (read_data2),
        .funct3    (funct3),
        .take_branch(take_branch)
    );

    
    // Data Memory
    
    wire [31:0] mem_read_data;

    D_MEM dmem_inst (
        .clk       (clk),
        .MemWrite  (MemWrite),
        .MemRead   (MemRead),
        .funct3    (funct3),      // thêm để phân biệt LB/LH/LW/LBU/LHU, SB/SH/SW
        .addr      (alu_result),
        .write_data(read_data2),
        .read_data (mem_read_data)
    );

    
    // Write-back MUX (4-way)
    //   00 = ALU result      (R-type, I-type, AUIPC)
    //   01 = Memory data     (LOAD)
    //   10 = PC + 4          (JAL, JALR → lưu return address)
    //   11 = imm             (LUI)
    
    assign write_data_rf =
        (ResultSrc == 2'b00) ? alu_result    :
        (ResultSrc == 2'b01) ? mem_read_data :
        (ResultSrc == 2'b10) ? pc_plus4      :
                               imm_out;      // 2'b11 = LUI
    assign debug_wb  = write_data_rf;

endmodule