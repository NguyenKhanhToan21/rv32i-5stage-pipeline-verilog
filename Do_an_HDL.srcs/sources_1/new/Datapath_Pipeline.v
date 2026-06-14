`timescale 1ns / 1ps


module Datapath_Pipeline (
    input clk,
    input rst,

    input        Branch,
    input        MemRead,
    input        MemWrite,
    input        ALUSrc,
    input        RegWrite,
    input        ALUSrcA,
    input [1:0]  ResultSrc,
    input [1:0]  PCSrc,
    input [1:0]  ALUOp,

    output [6:0]  opcode_out,
    output [31:0] debug_wb

);
reg [31:0] debug_pc_reg, debug_alu_reg, debug_wb_reg;

    
    // Hazard / Forwarding wires
    
    wire        PC_write, IF_ID_write, IF_ID_flush, ID_EX_flush;
    wire [1:0]  forwardA, forwardB;
    wire        forwardM;

    
    // IF Stage
    
     wire [31:0] pc_out, pc_next, pc_plus4;

    PC pc_inst (
        .clk     (clk),
        .rst     (rst),
        .enable  (PC_write),
        .pc_next (pc_next),
        .pc      (pc_out)
    );
    assign pc_plus4 = pc_out + 32'd4;

    wire [31:0] IF_instruction;
    I_MEM imem_inst (
        .clk        (clk),
        .we         (1'b0),
        .PC         (pc_out),
        .write_data (32'b0),
        .write_addr (8'b0),
        .instruction(IF_instruction)
    );

    
    // IF/ID Register
    
    wire [31:0] ID_pc, ID_pc4, ID_instr;

    IF_ID_Reg if_id_reg (
        .clk         (clk),
        .rst         (rst),
        .IF_ID_write (IF_ID_write),
        .IF_ID_flush (IF_ID_flush),
        .IF_pc       (pc_out),
        .IF_pc4      (pc_plus4),
        .IF_instr    (IF_instruction),
        .ID_pc       (ID_pc),
        .ID_pc4      (ID_pc4),
        .ID_instr    (ID_instr)
    );

    
    // ID Stage
    
    wire [6:0] ID_opcode;
    wire [4:0] ID_rd, ID_rs1_addr, ID_rs2_addr;
    wire [2:0] ID_funct3;
    wire [6:0] ID_funct7;
    wire [4:0] ID_shamt;

    DECODER decoder_inst (
        .instruction(ID_instr),
        .opcode     (ID_opcode),
        .rd         (ID_rd),
        .funct3     (ID_funct3),
        .rs1        (ID_rs1_addr),
        .rs2        (ID_rs2_addr),
        .funct7     (ID_funct7),
        .shamt      (ID_shamt)
    );
    assign opcode_out = ID_opcode;

    wire [31:0] ID_imm;
    IMM_GEN imm_gen_inst (
        .instruction(ID_instr),
        .imm        (ID_imm)
    );

    // WB write-back
    wire [31:0] WB_alu_result_wire, WB_mem_read_data_wire;
    wire [31:0] WB_pc4_wire, WB_imm_wire;
    wire [1:0]  WB_ResultSrc_wire;
    wire [4:0]  WB_rd_wire;
    wire        WB_RegWrite_wire;

    (* keep = "true" *) wire [31:0] WB_write_data =
        (WB_ResultSrc_wire == 2'b00) ? WB_alu_result_wire    :
        (WB_ResultSrc_wire == 2'b01) ? WB_mem_read_data_wire :
        (WB_ResultSrc_wire == 2'b10) ? WB_pc4_wire           :
                                       WB_imm_wire;

     wire [31:0] ID_read_data1, ID_read_data2;
    RF rf_inst (
        .clk        (clk),
        .rst        (rst),
        .RegWrite   (WB_RegWrite_wire),
        .rs1        (ID_rs1_addr),
        .rs2        (ID_rs2_addr),
        .rd         (WB_rd_wire),
        .write_data (WB_write_data),
        .read_data1 (ID_read_data1),
        .read_data2 (ID_read_data2)
    );

    wire ID_isRtype   = (ID_opcode == 7'b0110011);
    wire [31:0] ID_jal_target = ID_pc + ID_imm;

    
    // ID/EX Register
    
    wire [31:0] EX_read_data1_reg, EX_read_data2_reg;
    wire [31:0] EX_imm, EX_pc, EX_pc4_reg;
    wire [4:0]  EX_rs1, EX_rs2, EX_rd;
    wire [2:0]  EX_funct3;
    wire        EX_funct7_5, EX_isRtype;
    wire        EX_RegWrite, EX_MemRead, EX_MemWrite, EX_ALUSrc, EX_Branch;
    wire [1:0]  EX_ALUOp, EX_ResultSrc, EX_PCSrc;
    wire        EX_ALUSrcA;

    ID_EX_Reg id_ex_reg (
        .clk           (clk),
        .rst           (rst),
        .ID_EX_flush   (ID_EX_flush),
        .ID_read_data1 (ID_read_data1),
        .ID_read_data2 (ID_read_data2),
        .ID_imm        (ID_imm),
        .ID_pc         (ID_pc),
        .ID_pc4        (ID_pc4),
        .ID_rs1        (ID_rs1_addr),
        .ID_rs2        (ID_rs2_addr),
        .ID_rd         (ID_rd),
        .ID_funct3     (ID_funct3),
        .ID_funct7_5   (ID_funct7[5]),
        .ID_isRtype    (ID_isRtype),
        .ID_RegWrite   (RegWrite),
        .ID_MemRead    (MemRead),
        .ID_MemWrite   (MemWrite),
        .ID_ALUSrc     (ALUSrc),
        .ID_ALUSrcA    (ALUSrcA),
        .ID_ALUOp      (ALUOp),
        .ID_ResultSrc  (ResultSrc),
        .ID_PCSrc      (PCSrc),
        .ID_Branch     (Branch),
        .EX_read_data1 (EX_read_data1_reg),
        .EX_read_data2 (EX_read_data2_reg),
        .EX_imm        (EX_imm),
        .EX_pc         (EX_pc),
        .EX_pc4        (EX_pc4_reg),
        .EX_rs1        (EX_rs1),
        .EX_rs2        (EX_rs2),
        .EX_rd         (EX_rd),
        .EX_funct3     (EX_funct3),
        .EX_funct7_5   (EX_funct7_5),
        .EX_isRtype    (EX_isRtype),
        .EX_RegWrite   (EX_RegWrite),
        .EX_MemRead    (EX_MemRead),
        .EX_MemWrite   (EX_MemWrite),
        .EX_ALUSrc     (EX_ALUSrc),
        .EX_ALUSrcA    (EX_ALUSrcA),
        .EX_ALUOp      (EX_ALUOp),
        .EX_ResultSrc  (EX_ResultSrc),
        .EX_PCSrc      (EX_PCSrc),
        .EX_Branch     (EX_Branch)
    );

    
    // EX Stage
    
    wire [31:0] MEM_alu_result_wire;
    wire        MEM_RegWrite_wire;
    wire [4:0]  MEM_rd_wire;
    wire [31:0] MEM_result_fwd_wire;  // FF output từ EX_MEM_Reg



    // Forwarded rs1 (không override bởi PC/imm)
    wire [31:0] fwd_rs1 =
        (forwardA == 2'b10) ? MEM_result_fwd_wire :
        (forwardA == 2'b01) ? WB_write_data       :
                              EX_read_data1_reg;

    // Forwarded rs2 (không override bởi imm)
    wire [31:0] fwd_rs2 =
        (forwardB == 2'b10) ? MEM_result_fwd_wire :
        (forwardB == 2'b01) ? WB_write_data       :
                              EX_read_data2_reg;

    // ALU input A: AUIPC dùng PC, còn lại dùng forwarded rs1
    wire [31:0] alu_in_a = EX_ALUSrcA ? EX_pc : fwd_rs1;

    // ALU input B: I-type dùng imm, còn lại dùng forwarded rs2
    wire [31:0] alu_in_b = EX_ALUSrc  ? EX_imm : fwd_rs2;

    // Store write data: forwardM chọn WB, còn lại là fwd_rs2
    wire [31:0] EX_store_data = forwardM ? WB_write_data : fwd_rs2;

    wire [3:0] alu_op_wire;
    ALU_Control alu_ctrl_inst (
        .ALUOp   (EX_ALUOp),
        .funct3  (EX_funct3),
        .funct7_5(EX_funct7_5),
        .isRtype (EX_isRtype),
        .ALU_op  (alu_op_wire)
    );

    wire [31:0] EX_alu_result;
    wire        EX_alu_zero;
    ALU alu_inst (
        .A      (alu_in_a),
        .B      (alu_in_b),
        .ALU_op (alu_op_wire),
        .ALU_Out(EX_alu_result),
        .Zero   (EX_alu_zero)
    );

    // Branch comparator dùng fwd_rs1/fwd_rs2 trực tiếp (không tính lại)
    wire EX_take_branch;
    BRANCH_COMP branch_comp_inst (
        .rs1        (fwd_rs1),
        .rs2        (fwd_rs2),
        .funct3     (EX_funct3),
        .take_branch(EX_take_branch)
    );

    wire [31:0] EX_branch_target = EX_pc + EX_imm;
    wire [31:0] EX_jalr_target   = (fwd_rs1 + EX_imm) & ~32'b1;

    
    // EX/MEM Register
    
    wire [31:0] MEM_write_data_wire, MEM_pc4_wire, MEM_imm_wire;
    wire [2:0]  MEM_funct3_wire;
    wire        MEM_MemRead_wire, MEM_MemWrite_wire;
    wire [1:0]  MEM_ResultSrc_wire;
    wire        MEM_Branch_nc, MEM_take_branch_nc;
    wire [31:0] MEM_branch_target_nc;

    EX_MEM_Reg ex_mem_reg (
        .clk              (clk),
        .rst              (rst),
        .EX_alu_result    (EX_alu_result),
        .EX_write_data    (EX_store_data),
        .EX_pc4           (EX_pc4_reg),
        .EX_imm           (EX_imm),
        .EX_rd            (EX_rd),
        .EX_funct3        (EX_funct3),
        .EX_RegWrite      (EX_RegWrite),
        .EX_MemRead       (EX_MemRead),
        .EX_MemWrite      (EX_MemWrite),
        .EX_ResultSrc     (EX_ResultSrc),
        .EX_Branch        (EX_Branch),
        .EX_take_branch   (EX_take_branch),
        .EX_branch_target (EX_branch_target),
        .MEM_alu_result   (MEM_alu_result_wire),
        .MEM_write_data   (MEM_write_data_wire),
        .MEM_pc4          (MEM_pc4_wire),
        .MEM_imm          (MEM_imm_wire),
        .MEM_rd           (MEM_rd_wire),
        .MEM_funct3       (MEM_funct3_wire),
        .MEM_RegWrite     (MEM_RegWrite_wire),
        .MEM_MemRead      (MEM_MemRead_wire),
        .MEM_MemWrite     (MEM_MemWrite_wire),
        .MEM_ResultSrc    (MEM_ResultSrc_wire),
        .MEM_Branch       (MEM_Branch_nc),
        .MEM_take_branch  (MEM_take_branch_nc),
        .MEM_branch_target(MEM_branch_target_nc),
        .MEM_result_fwd   (MEM_result_fwd_wire)
    );

    
    // MEM Stage 
    
    wire [31:0] MEM_mem_read_data;

    D_MEM dmem_inst (
        .clk       (clk),
        .MemWrite  (MEM_MemWrite_wire),
        .MemRead   (MEM_MemRead_wire),
        .funct3    (MEM_funct3_wire),
        .addr      (MEM_alu_result_wire),
        .write_data(MEM_write_data_wire),
        .read_data (MEM_mem_read_data)
    );

    
    // PC next logic
    
    wire do_branch = EX_Branch & EX_take_branch;
    wire do_jalr   = (EX_PCSrc == 2'b10);
    wire do_jal    = (PCSrc    == 2'b01);

    assign pc_next =
        do_branch ? EX_branch_target :
        do_jalr   ? EX_jalr_target   :
        do_jal    ? ID_jal_target    :
        pc_plus4;

    
    // Hazard Detection
    
    Hazard_Detection hazard_unit (
        .EX_MemRead    (EX_MemRead),
        .EX_rd         (EX_rd),
        .ID_rs1        (ID_rs1_addr),
        .ID_rs2        (ID_rs2_addr),
        .ID_PCSrc      (PCSrc),
        .EX_Branch     (EX_Branch),
        .EX_take_branch(EX_take_branch),
        .EX_PCSrc      (EX_PCSrc),
        .PC_write      (PC_write),
        .IF_ID_write   (IF_ID_write),
        .IF_ID_flush   (IF_ID_flush),
        .ID_EX_flush   (ID_EX_flush)
    );

    
    // Forwarding Unit
    
    Forwarding_Unit fwd_unit (
        .EX_rs1      (EX_rs1),
        .EX_rs2      (EX_rs2),
        .MEM_RegWrite(MEM_RegWrite_wire),
        .MEM_rd      (MEM_rd_wire),
        .WB_RegWrite (WB_RegWrite_wire),
        .WB_rd       (WB_rd_wire),
        .forwardA    (forwardA),
        .forwardB    (forwardB),
        .forwardM    (forwardM)
    );

    
    // MEM/WB Register
    
    MEM_WB_Reg mem_wb_reg (
        .clk              (clk),
        .rst              (rst),
        .MEM_mem_read_data(MEM_mem_read_data),
        .MEM_alu_result   (MEM_alu_result_wire),
        .MEM_pc4          (MEM_pc4_wire),
        .MEM_imm          (MEM_imm_wire),
        .MEM_rd           (MEM_rd_wire),
        .MEM_RegWrite     (MEM_RegWrite_wire),
        .MEM_ResultSrc    (MEM_ResultSrc_wire),
        .WB_mem_read_data (WB_mem_read_data_wire),
        .WB_alu_result    (WB_alu_result_wire),
        .WB_pc4           (WB_pc4_wire),
        .WB_imm           (WB_imm_wire),
        .WB_rd            (WB_rd_wire),
        .WB_RegWrite      (WB_RegWrite_wire),
        .WB_ResultSrc     (WB_ResultSrc_wire)
    );
   

always @(posedge clk) begin
    debug_wb_reg  <= WB_write_data;
end

assign debug_wb  = debug_wb_reg;

endmodule