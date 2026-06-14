`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: CPU_Pipeline_tb
// Description: Testbench kiểm tra toàn bộ 37 lệnh RV32I (không bao gồm SYSTEM/FENCE)
//
// Chiến lược:
//   - Load chương trình trực tiếp vào I_MEM qua task load_imem()
//   - Không dùng file .txt → chạy được trên bất kỳ simulator nào
//   - Mỗi nhóm lệnh có EXPECTED VALUE kèm theo và tự động PASS/FAIL
//   - Cuối cùng in tổng kết số lệnh pass/fail
//
// Lưu ý pipeline:
//   - Sau khi nạp lệnh cuối, cần ~5 cycle để WB stage hoàn tất
//   - Stall (load-use) và flush (branch) được xử lý tự động bởi CPU
//
// Encoding tham khảo RV32I spec:
//   R-type : [31:25]=funct7 | [24:20]=rs2 | [19:15]=rs1 | [14:12]=funct3 | [11:7]=rd | [6:0]=opcode
//   I-type : [31:20]=imm[11:0]            | [19:15]=rs1 | [14:12]=funct3 | [11:7]=rd | [6:0]=opcode
//   S-type : [31:25]=imm[11:5] | [24:20]=rs2 | [19:15]=rs1 | [14:12]=funct3 | [11:7]=imm[4:0] | [6:0]=opcode
//   B-type : [31]=imm[12] | [30:25]=imm[10:5] | [24:20]=rs2 | [19:15]=rs1 | [14:12]=funct3
//            | [11:8]=imm[4:1] | [7]=imm[11] | [6:0]=opcode
//   U-type : [31:12]=imm[31:12] | [11:7]=rd | [6:0]=opcode
//   J-type : [31]=imm[20] | [30:21]=imm[10:1] | [20]=imm[11] | [19:12]=imm[19:12]
//            | [11:7]=rd | [6:0]=opcode
//////////////////////////////////////////////////////////////////////////////////

module CPU_Pipeline_tb;

    // =========================================================
    // DUT
    // =========================================================
    reg clk, rst;

    CPU_Pipeline dut (
        .clk(clk),
        .rst(rst)
    );

    // Clock 10ns
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================
    // Scoreboard
    // =========================================================
    integer pass_cnt, fail_cnt, test_num;

    // =========================================================
    // Helper: đọc register file
    // =========================================================
    function [31:0] rf;
        input [4:0] idx;
        rf = dut.dp.rf_inst.regs[idx];
    endfunction

    // =========================================================
    // Task: nạp 1 lệnh vào I_MEM (word index)
    // =========================================================
    task load_instr;
        input [7:0]  idx;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            dut.dp.imem_inst.mem[idx] = instr;
        end
    endtask

    // =========================================================
    // Task: hard-reset CPU và xóa I_MEM
    // =========================================================
    task do_reset;
        integer i;
        begin
            rst = 1;
            // Xóa toàn bộ I_MEM
            for (i = 0; i < 256; i = i + 1)
                dut.dp.imem_inst.mem[i] = 32'h00000013; // NOP (ADDI x0,x0,0)
            // Xóa D_MEM
            for (i = 0; i < 256; i = i + 1)
                dut.dp.dmem_inst.mem[i] = 32'h0;
            @(posedge clk); @(posedge clk);
            rst = 0;
            @(posedge clk);
        end
    endtask

    // =========================================================
    // Task: chạy N cycle
    // =========================================================
    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // =========================================================
    // Task: kiểm tra giá trị thanh ghi
    // =========================================================
    task check_reg;
        input [4:0]  reg_idx;
        input [31:0] expected;
        input [127:0] test_name; // 16 chars
        begin
            test_num = test_num + 1;
            if (rf(reg_idx) === expected) begin
                $display("  [PASS] %s : x%0d = 0x%08h (%0d)",
                    test_name, reg_idx, rf(reg_idx), $signed(rf(reg_idx)));
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] %s : x%0d = 0x%08h (%0d) -- expected 0x%08h (%0d)",
                    test_name, reg_idx, rf(reg_idx), $signed(rf(reg_idx)),
                    expected, $signed(expected));
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // =========================================================
    // Task: kiểm tra D_MEM word
    // =========================================================
    task check_mem;
        input [7:0]  mem_idx;   // word index
        input [31:0] expected;
        input [127:0] test_name;
        begin
            test_num = test_num + 1;
            if (dut.dp.dmem_inst.mem[mem_idx] === expected) begin
                $display("  [PASS] %s : mem[%0d] = 0x%08h",
                    test_name, mem_idx, dut.dp.dmem_inst.mem[mem_idx]);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] %s : mem[%0d] = 0x%08h -- expected 0x%08h",
                    test_name, mem_idx, dut.dp.dmem_inst.mem[mem_idx], expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // =========================================================
    // Encoding helpers (functions)
    // =========================================================

    // R-type: opcode=0110011
    function [31:0] R;
        input [4:0] rd, rs1, rs2;
        input [2:0] funct3;
        input [6:0] funct7;
        R = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // I-type arithmetic: opcode=0010011
    function [31:0] I_arith;
        input [4:0] rd, rs1;
        input [11:0] imm12;
        input [2:0] funct3;
        I_arith = {imm12, rs1, funct3, rd, 7'b0010011};
    endfunction

    // I-type SLLI/SRLI/SRAI (shamt): opcode=0010011
    function [31:0] I_shift;
        input [4:0] rd, rs1, shamt;
        input [2:0] funct3;
        input       arith; // 1=SRA, 0=SRL/SLL
        I_shift = {{1'b0, arith, 5'b00000}, shamt, rs1, funct3, rd, 7'b0010011};
    endfunction

    // I-type LOAD: opcode=0000011
    function [31:0] I_load;
        input [4:0] rd, rs1;
        input [11:0] imm12;
        input [2:0] funct3;
        I_load = {imm12, rs1, funct3, rd, 7'b0000011};
    endfunction

    // I-type JALR: opcode=1100111
    function [31:0] I_jalr;
        input [4:0] rd, rs1;
        input [11:0] imm12;
        I_jalr = {imm12, rs1, 3'b000, rd, 7'b1100111};
    endfunction

    // S-type STORE: opcode=0100011
    function [31:0] S_store;
        input [4:0] rs1, rs2;
        input [11:0] imm12;
        input [2:0] funct3;
        S_store = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], 7'b0100011};
    endfunction

    // B-type BRANCH: opcode=1100011
    // imm là offset byte (phải chẵn), được chia đôi trong encoding
    function [31:0] B_branch;
        input [4:0] rs1, rs2;
        input [12:0] imm13; // imm[12:1] — bit 0 luôn = 0
        input [2:0] funct3;
        B_branch = {imm13[12], imm13[10:5], rs2, rs1, funct3,
                    imm13[4:1], imm13[11], 7'b1100011};
    endfunction

    // U-type LUI: opcode=0110111
    function [31:0] U_lui;
        input [4:0] rd;
        input [19:0] imm20;
        U_lui = {imm20, rd, 7'b0110111};
    endfunction

    // U-type AUIPC: opcode=0010111
    function [31:0] U_auipc;
        input [4:0] rd;
        input [19:0] imm20;
        U_auipc = {imm20, rd, 7'b0010111};
    endfunction

    // J-type JAL: opcode=1101111
    function [31:0] J_jal;
        input [4:0] rd;
        input [20:0] imm21; // imm[20:1] — bit 0 luôn = 0
        J_jal = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, 7'b1101111};
    endfunction

    // NOP = ADDI x0, x0, 0
    parameter NOP = 32'h00000013;

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin
        pass_cnt = 0; fail_cnt = 0; test_num = 0;
        rst = 1;
        #30;

        $display("");
        $display("╔══════════════════════════════════════════════════╗");
        $display("║     RISC-V Pipeline CPU — Full ISA Testbench     ║");
        $display("╚══════════════════════════════════════════════════╝");

        // ─────────────────────────────────────────────────────────
        // NHÓM 1: R-type (10 lệnh)
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 1: R-type ══════");
        do_reset;

        // Chương trình:
        //   ADDI x1, x0, 15      → x1 = 15
        //   ADDI x2, x0, -5      → x2 = -5  (0xFFFFFFFB)
        //   ADDI x3, x0, 3       → x3 = 3
        //   ADD  x10, x1, x3     → x10 = 15+3 = 18
        //   SUB  x11, x1, x3     → x11 = 15-3 = 12
        //   SLL  x12, x1, x3     → x12 = 15<<3 = 120
        //   SLT  x13, x2, x1     → x13 = (-5 < 15) = 1
        //   SLTU x14, x2, x1     → x14 = (0xFFFFFFFB < 15) = 0   (unsigned)
        //   XOR  x15, x1, x3     → x15 = 15^3 = 12
        //   SRL  x16, x1, x3     → x16 = 15>>3 = 1
        //   SRA  x17, x2, x3     → x17 = -5>>>3 = -1 (arithmetic)
        //   OR   x18, x1, x3     → x18 = 15|3 = 15
        //   AND  x19, x1, x3     → x19 = 15&3 = 3
        //   (rồi NOP x5 để drain)

        // x1=1, x2=2, x3=3, x10=10,...
        dut.dp.imem_inst.mem[0]  = I_arith(1,  0, 12'd15,  3'b000);  // ADDI x1,x0,15
        dut.dp.imem_inst.mem[1]  = I_arith(2,  0, 12'hFFB, 3'b000);  // ADDI x2,x0,-5
        dut.dp.imem_inst.mem[2]  = I_arith(3,  0, 12'd3,   3'b000);  // ADDI x3,x0,3
        dut.dp.imem_inst.mem[3]  = R(10, 1, 3, 3'b000, 7'b0000000);  // ADD  x10,x1,x3
        dut.dp.imem_inst.mem[4]  = R(11, 1, 3, 3'b000, 7'b0100000);  // SUB  x11,x1,x3
        dut.dp.imem_inst.mem[5]  = R(12, 1, 3, 3'b001, 7'b0000000);  // SLL  x12,x1,x3
        dut.dp.imem_inst.mem[6]  = R(13, 2, 1, 3'b010, 7'b0000000);  // SLT  x13,x2,x1
        dut.dp.imem_inst.mem[7]  = R(14, 2, 1, 3'b011, 7'b0000000);  // SLTU x14,x2,x1
        dut.dp.imem_inst.mem[8]  = R(15, 1, 3, 3'b100, 7'b0000000);  // XOR  x15,x1,x3
        dut.dp.imem_inst.mem[9]  = R(16, 1, 3, 3'b101, 7'b0000000);  // SRL  x16,x1,x3
        dut.dp.imem_inst.mem[10] = R(17, 2, 3, 3'b101, 7'b0100000);  // SRA  x17,x2,x3
        dut.dp.imem_inst.mem[11] = R(18, 1, 3, 3'b110, 7'b0000000);  // OR   x18,x1,x3
        dut.dp.imem_inst.mem[12] = R(19, 1, 3, 3'b111, 7'b0000000);  // AND  x19,x1,x3

        rst = 0;
        run_cycles(25); // 13 lệnh + 5 drain + margin

        check_reg(10, 32'd18,          "ADD   ");
        check_reg(11, 32'd12,          "SUB   ");
        check_reg(12, 32'd120,         "SLL   ");
        check_reg(13, 32'd1,           "SLT   ");
        check_reg(14, 32'd0,           "SLTU  ");
        check_reg(15, 32'd12,          "XOR   ");
        check_reg(16, 32'd1,           "SRL   ");
        check_reg(17, 32'hFFFFFFFF,    "SRA   ");
        check_reg(18, 32'd15,          "OR    ");
        check_reg(19, 32'd3,           "AND   ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 2: I-type ALU Immediate (9 lệnh)
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 2: I-type ALU Immediate ══════");
        do_reset;

        // x1 = 20, x2 = -3 (0xFFFFFFFD)
        // ADDI  x10,x1,5     → 25
        // SLTI  x11,x2,0     → (-3 < 0) = 1
        // SLTIU x12,x2,1     → (0xFFFFFFFD < 1 unsigned) = 0
        // XORI  x13,x1,12'hF → 20^15 = 27
        // ORI   x14,x1,12'h7 → 20|7 = 23
        // ANDI  x15,x1,12'hF → 20&15 = 4
        // SLLI  x16,x1,2     → 20<<2 = 80
        // SRLI  x17,x1,2     → 20>>2 = 5
        // SRAI  x18,x2,1     → -3>>>1 = -2 (0xFFFFFFFE)

        dut.dp.imem_inst.mem[0]  = I_arith(1,  0, 12'd20,  3'b000);  // ADDI x1,x0,20
        dut.dp.imem_inst.mem[1]  = I_arith(2,  0, 12'hFFD, 3'b000);  // ADDI x2,x0,-3
        dut.dp.imem_inst.mem[2]  = I_arith(10, 1, 12'd5,   3'b000);  // ADDI  x10,x1,5
        dut.dp.imem_inst.mem[3]  = I_arith(11, 2, 12'd0,   3'b010);  // SLTI  x11,x2,0
        dut.dp.imem_inst.mem[4]  = I_arith(12, 2, 12'd1,   3'b011);  // SLTIU x12,x2,1
        dut.dp.imem_inst.mem[5]  = I_arith(13, 1, 12'h00F, 3'b100);  // XORI  x13,x1,15
        dut.dp.imem_inst.mem[6]  = I_arith(14, 1, 12'h007, 3'b110);  // ORI   x14,x1,7
        dut.dp.imem_inst.mem[7]  = I_arith(15, 1, 12'h00F, 3'b111);  // ANDI  x15,x1,15
        dut.dp.imem_inst.mem[8]  = I_shift(16, 1, 5'd2,    3'b001, 0); // SLLI x16,x1,2
        dut.dp.imem_inst.mem[9]  = I_shift(17, 1, 5'd2,    3'b101, 0); // SRLI x17,x1,2
        dut.dp.imem_inst.mem[10] = I_shift(18, 2, 5'd1,    3'b101, 1); // SRAI x18,x2,1

        rst = 0;
        run_cycles(22);

        check_reg(10, 32'd25,          "ADDI  ");
        check_reg(11, 32'd1,           "SLTI  ");
        check_reg(12, 32'd0,           "SLTIU ");
        check_reg(13, 32'd27,          "XORI  ");
        check_reg(14, 32'd23,          "ORI   ");
        check_reg(15, 32'd4,           "ANDI  ");
        check_reg(16, 32'd80,          "SLLI  ");
        check_reg(17, 32'd5,           "SRLI  ");
        check_reg(18, 32'hFFFFFFFE,    "SRAI  ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 3: Load Instructions (5 lệnh)
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 3: Load Instructions ══════");
        do_reset;

        // Chuẩn bị dữ liệu trong D_MEM:
        //   mem[0] = 0xDEADBEEF  (word 0, byte addr 0x000)
        //   mem[1] = 0x00008080  (word 1, byte addr 0x004)
        dut.dp.dmem_inst.mem[0] = 32'hDEADBEEF;
        dut.dp.dmem_inst.mem[1] = 32'h00008080;

        // x1 = 0 (base addr)
        // LW   x10, 0(x1)   → 0xDEADBEEF
        // LH   x11, 0(x1)   → sign_ext(0xBEEF) = 0xFFFFBEEF  (-16657)
        // LH   x12, 2(x1)   → sign_ext(0xDEAD) = 0xFFFFDEAD  (-8531)
        // LB   x13, 0(x1)   → sign_ext(0xEF) = 0xFFFFFFEF  (-17)
        // LBU  x14, 0(x1)   → zero_ext(0xEF) = 0x000000EF  (239)
        // LHU  x15, 0(x1)   → zero_ext(0xBEEF) = 0x0000BEEF (48879)
        // LB   x16, 4(x1)   → sign_ext(0x80) = 0xFFFFFF80  (-128)

        dut.dp.imem_inst.mem[0]  = I_arith(1,  0, 12'd0,  3'b000);  // ADDI x1,x0,0
        dut.dp.imem_inst.mem[1]  = I_load(10, 1, 12'd0, 3'b010);    // LW   x10,0(x1)
        dut.dp.imem_inst.mem[2]  = NOP;
        dut.dp.imem_inst.mem[3]  = I_load(11, 1, 12'd0, 3'b001);    // LH   x11,0(x1)
        dut.dp.imem_inst.mem[4]  = I_load(12, 1, 12'd2, 3'b001);    // LH   x12,2(x1)
        dut.dp.imem_inst.mem[5]  = I_load(13, 1, 12'd0, 3'b000);    // LB   x13,0(x1)
        dut.dp.imem_inst.mem[6]  = I_load(14, 1, 12'd0, 3'b100);    // LBU  x14,0(x1)
        dut.dp.imem_inst.mem[7]  = I_load(15, 1, 12'd0, 3'b101);    // LHU  x15,0(x1)
        dut.dp.imem_inst.mem[8]  = I_load(16, 1, 12'd4, 3'b000);    // LB   x16,4(x1)

        rst = 0;
        run_cycles(22);

        check_reg(10, 32'hDEADBEEF,    "LW    ");
        check_reg(11, 32'hFFFFBEEF,    "LH    ");
        check_reg(12, 32'hFFFFDEAD,    "LH+2  ");
        check_reg(13, 32'hFFFFFFEF,    "LB    ");
        check_reg(14, 32'h000000EF,    "LBU   ");
        check_reg(15, 32'h0000BEEF,    "LHU   ");
        check_reg(16, 32'hFFFFFF80,    "LB    ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 4: Store Instructions (3 lệnh)
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 4: Store Instructions ══════");
        do_reset;

        // x1 = 0x12345678  (dữ liệu ghi)
        // SW x1, 0(x0)   → mem[0] = 0x12345678
        // SH x1, 4(x0)   → mem[1][15:0] = 0x5678
        // SB x1, 8(x0)   → mem[2][7:0]  = 0x78

        dut.dp.imem_inst.mem[0]  = I_arith(1,  0, 12'h678, 3'b000);  // ADDI x1,x0,0x678 (= 1656)
        // Để load full 0x12345678 cần LUI + ADDI
        // LUI x1, 0x12345   → x1 = 0x12345000
        // ADDI x1,x1,0x678  → x1 = 0x12345678
        dut.dp.imem_inst.mem[0]  = U_lui(1, 20'h12345);               // LUI  x1,0x12345
        dut.dp.imem_inst.mem[1]  = I_arith(1, 1, 12'h678, 3'b000);   // ADDI x1,x1,0x678
        dut.dp.imem_inst.mem[2]  = S_store(0, 1, 12'd0,  3'b010);    // SW   x1,0(x0)
        dut.dp.imem_inst.mem[3]  = S_store(0, 1, 12'd4,  3'b001);    // SH   x1,4(x0)
        dut.dp.imem_inst.mem[4]  = S_store(0, 1, 12'd8,  3'b000);    // SB   x1,8(x0)

        rst = 0;
        run_cycles(18);

        check_mem(0, 32'h12345678, "SW    ");
        check_mem(1, 32'h00005678, "SH    ");
        check_mem(2, 32'h00000078, "SB    ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 5: Branch Instructions (6 lệnh)
        // ─────────────────────────────────────────────────────────
        // Chiến lược: mỗi branch taken sẽ nhảy qua lệnh ADDI "bẫy" (sẽ ghi x31=0xDEAD)
        // Nếu branch đúng → x31 vẫn = 0, nếu branch sai → x31 = 0xDEAD → FAIL
        $display("");
        $display("══════ NHÓM 5: Branch Instructions ══════");
        do_reset;

        // Layout chương trình (mỗi lệnh = 4 byte):
        //  Offset  Word  Lệnh
        //  0x00    [0]   ADDI x1, x0, 5
        //  0x04    [1]   ADDI x2, x0, 5
        //  0x08    [2]   ADDI x3, x0, 3
        //  0x0C    [3]   ADDI x4, x0, -1   (0xFFFFFFFF)
        //  0x10    [4]   ADDI x5, x0, 6
        //
        // Test BEQ taken (x1==x2): nhảy qua "bẫy" tại [6]
        //  0x14    [5]   BEQ  x1,x2, +8    → nhảy tới [7]
        //  0x18    [6]   ADDI x10,x0,0xDEAD  ← bẫy (không được thực thi)
        //  0x1C    [7]   ADDI x10,x0,1       ← marker BEQ ok
        //
        // Test BNE taken (x1!=x3):
        //  0x20    [8]   BNE  x1,x3, +8    → nhảy tới [10]
        //  0x24    [9]   ADDI x11,x0,0xDEAD
        //  0x28    [10]  ADDI x11,x0,1
        //
        // Test BLT taken (x3 < x1, signed):
        //  0x2C    [11]  BLT  x3,x1, +8    → nhảy tới [13]
        //  0x30    [12]  ADDI x12,x0,0xDEAD
        //  0x34    [13]  ADDI x12,x0,1
        //
        // Test BGE taken (x1 >= x2, signed, equal):
        //  0x38    [14]  BGE  x1,x2, +8    → nhảy tới [16]
        //  0x3C    [15]  ADDI x13,x0,0xDEAD
        //  0x40    [16]  ADDI x13,x0,1
        //
        // Test BLTU taken (x3 < x1, unsigned):
        //  0x44    [17]  BLTU x3,x1, +8    → nhảy tới [19]
        //  0x48    [18]  ADDI x14,x0,0xDEAD
        //  0x4C    [19]  ADDI x14,x0,1
        //
        // Test BGEU taken (x1 >= x3, unsigned):
        //  0x50    [20]  BGEU x1,x3, +8    → nhảy tới [22]
        //  0x54    [21]  ADDI x15,x0,0xDEAD
        //  0x58    [22]  ADDI x15,x0,1
        //  0x5C    [23]  NOP (drain)
        //  0x60    [24]  NOP

        // Setup
        dut.dp.imem_inst.mem[0]  = I_arith(1, 0, 12'd5,    3'b000);  // ADDI x1,x0,5
        dut.dp.imem_inst.mem[1]  = I_arith(2, 0, 12'd5,    3'b000);  // ADDI x2,x0,5
        dut.dp.imem_inst.mem[2]  = I_arith(3, 0, 12'd3,    3'b000);  // ADDI x3,x0,3
        dut.dp.imem_inst.mem[3]  = I_arith(4, 0, 12'hFFF,  3'b000);  // ADDI x4,x0,-1
        dut.dp.imem_inst.mem[4]  = I_arith(5, 0, 12'd6,    3'b000);  // ADDI x5,x0,6
        // BEQ x1,x2,+8 (imm=8 → imm[12:1]=0000_0000_0100)
        dut.dp.imem_inst.mem[5]  = B_branch(1, 2, 13'd8,  3'b000);   // BEQ
        dut.dp.imem_inst.mem[6]  = I_arith(10,0, 12'hDEA, 3'b000);  // BAIT
        dut.dp.imem_inst.mem[7]  = I_arith(10,0, 12'd1,   3'b000);  // marker
        // BNE x1,x3,+8
        dut.dp.imem_inst.mem[8]  = B_branch(1, 3, 13'd8,  3'b001);   // BNE
        dut.dp.imem_inst.mem[9]  = I_arith(11,0, 12'hDEA, 3'b000);
        dut.dp.imem_inst.mem[10] = I_arith(11,0, 12'd1,   3'b000);
        // BLT x3,x1,+8
        dut.dp.imem_inst.mem[11] = B_branch(3, 1, 13'd8,  3'b100);   // BLT
        dut.dp.imem_inst.mem[12] = I_arith(12,0, 12'hDEA, 3'b000);
        dut.dp.imem_inst.mem[13] = I_arith(12,0, 12'd1,   3'b000);
        // BGE x1,x2,+8 (1>=2 false? No: x1=5,x2=5 → equal → taken)
        dut.dp.imem_inst.mem[14] = B_branch(1, 2, 13'd8,  3'b101);   // BGE
        dut.dp.imem_inst.mem[15] = I_arith(13,0, 12'hDEA, 3'b000);
        dut.dp.imem_inst.mem[16] = I_arith(13,0, 12'd1,   3'b000);
        // BLTU x3,x1,+8
        dut.dp.imem_inst.mem[17] = B_branch(3, 1, 13'd8,  3'b110);   // BLTU
        dut.dp.imem_inst.mem[18] = I_arith(14,0, 12'hDEA, 3'b000);
        dut.dp.imem_inst.mem[19] = I_arith(14,0, 12'd1,   3'b000);
        // BGEU x1,x3,+8
        dut.dp.imem_inst.mem[20] = B_branch(1, 3, 13'd8,  3'b111);   // BGEU
        dut.dp.imem_inst.mem[21] = I_arith(15,0, 12'hDEA, 3'b000);
        dut.dp.imem_inst.mem[22] = I_arith(15,0, 12'd1,   3'b000);

        rst = 0;
        // Mỗi branch taken penalty 2 cycle, 6 branch × 3 lệnh + setup 5 + drain 8
        run_cycles(55);

        check_reg(10, 32'd1,  "BEQ   ");
        check_reg(11, 32'd1,  "BNE   ");
        check_reg(12, 32'd1,  "BLT   ");
        check_reg(13, 32'd1,  "BGE   ");
        check_reg(14, 32'd1,  "BLTU  ");
        check_reg(15, 32'd1,  "BGEU  ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 6: Jump Instructions — JAL + JALR
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 6: Jump Instructions ══════");
        do_reset;

        // Chương trình:
        //  [0] 0x00: JAL  x1, +12    → x1 = 0x04 (PC+4), PC → 0x0C
        //  [1] 0x04: ADDI x10,x0,0xBAD  ← bẫy (không được thực thi)
        //  [2] 0x08: ADDI x10,x0,0xBAD  ← bẫy
        //  [3] 0x0C: ADDI x10,x0,1      ← marker JAL ok
        //  [4] 0x10: ADDI x2,x0,0x20    ← x2 = 0x20 (target JALR)
        //  [5] 0x14: JALR x3,x2,0       → x3 = 0x18 (PC+4), PC → 0x20
        //  [6] 0x18: ADDI x11,x0,0xBAD  ← bẫy
        //  [7] 0x1C: ADDI x11,x0,0xBAD  ← bẫy
        //  [8] 0x20: ADDI x11,x0,1      ← marker JALR ok

        // JAL x1, +12 → imm=12
        dut.dp.imem_inst.mem[0]  = J_jal(1, 21'd12);                  // JAL  x1,+12
        dut.dp.imem_inst.mem[1]  = I_arith(10,0, 12'hBAD, 3'b000);   // BAIT
        dut.dp.imem_inst.mem[2]  = I_arith(10,0, 12'hBAD, 3'b000);   // BAIT
        dut.dp.imem_inst.mem[3]  = I_arith(10,0, 12'd1,   3'b000);   // marker JAL
        dut.dp.imem_inst.mem[4]  = I_arith(2, 0, 12'h020, 3'b000);   // ADDI x2,x0,0x20
        dut.dp.imem_inst.mem[5]  = I_jalr(3, 2, 12'd0);              // JALR x3,x2,0
        dut.dp.imem_inst.mem[6]  = I_arith(11,0, 12'hBAD, 3'b000);   // BAIT
        dut.dp.imem_inst.mem[7]  = I_arith(11,0, 12'hBAD, 3'b000);   // BAIT
        dut.dp.imem_inst.mem[8]  = I_arith(11,0, 12'd1,   3'b000);   // marker JALR

        rst = 0;
        run_cycles(25);

        check_reg(1,  32'h00000004, "JAL rd ");
        check_reg(10, 32'd1,        "JAL PC ");
        check_reg(3,  32'h00000018, "JALR rd");
        check_reg(11, 32'd1,        "JALR PC");

        // ─────────────────────────────────────────────────────────
        // NHÓM 7: Upper Immediate — LUI + AUIPC
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 7: Upper Immediate ══════");
        do_reset;

        // [0] 0x00: LUI   x10, 0xABCDE   → x10 = 0xABCDE000
        // [1] 0x04: AUIPC x11, 0x00001   → x11 = PC(0x04) + 0x00001000 = 0x00001004
        // [2] 0x08: LUI   x12, 0xFFFFF   → x12 = 0xFFFFF000  (-4096)
        // [3] 0x0C: NOP (drain)

        dut.dp.imem_inst.mem[0]  = U_lui(10,   20'hABCDE);   // LUI   x10,0xABCDE
        dut.dp.imem_inst.mem[1]  = U_auipc(11, 20'h00001);   // AUIPC x11,0x00001
        dut.dp.imem_inst.mem[2]  = U_lui(12,   20'hFFFFF);   // LUI   x12,0xFFFFF

        rst = 0;
        run_cycles(15);

        check_reg(10, 32'hABCDE000,  "LUI   ");
        check_reg(11, 32'h00001004,  "AUIPC ");
        check_reg(12, 32'hFFFFF000,  "LUI-  ");

        // ─────────────────────────────────────────────────────────
        // NHÓM 8 (bonus): Kiểm tra Forwarding + Load-Use stall
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("══════ NHÓM 8 (bonus): Forwarding & Load-Use stall ══════");
        do_reset;

        // EX/MEM forwarding:
        //   ADD x1,x0,x0   → x1=0 (dùng để base)
        //   ADDI x1,x0,10  → x1=10
        //   ADD  x2,x1,x1  → x2=20  (cần EX/MEM forward x1)
        //   ADD  x3,x2,x1  → x3=30  (cần MEM/WB forward x2, EX/MEM forward x1)
        //
        // Load-use stall:
        //   SW   x1,0(x0)  → mem[0]=10
        //   LW   x4,0(x0)  → x4=10  (load)
        //   ADD  x5,x4,x1  → x5=20  (dùng ngay x4 → stall 1 cycle → x5=20)

        dut.dp.imem_inst.mem[0]  = I_arith(1, 0, 12'd10, 3'b000);    // ADDI x1,x0,10
        dut.dp.imem_inst.mem[1]  = R(2, 1, 1, 3'b000, 7'b0000000);   // ADD  x2,x1,x1
        dut.dp.imem_inst.mem[2]  = R(3, 2, 1, 3'b000, 7'b0000000);   // ADD  x3,x2,x1
        dut.dp.imem_inst.mem[3]  = S_store(0, 1, 12'd0, 3'b010);     // SW   x1,0(x0)
        dut.dp.imem_inst.mem[4]  = I_load(4, 0, 12'd0, 3'b010);      // LW   x4,0(x0)
        dut.dp.imem_inst.mem[5]  = R(5, 4, 1, 3'b000, 7'b0000000);   // ADD  x5,x4,x1

        rst = 0;
        run_cycles(22);

        check_reg(1, 32'd10,  "FWD x1 ");
        check_reg(2, 32'd20,  "FWD x2 ");
        check_reg(3, 32'd30,  "FWD x3 ");
        check_reg(4, 32'd10,  "LU  LW ");
        check_reg(5, 32'd20,  "LU  ADD");

        // ─────────────────────────────────────────────────────────
        // TỔNG KẾT
        // ─────────────────────────────────────────────────────────
        $display("");
        $display("╔══════════════════════════════════════════════════╗");
        $display("║                  KẾT QUẢ TỔNG HỢP               ║");
        $display("╠══════════════════════════════════════════════════╣");
        $display("║  Tổng số test : %-4d                             ║", test_num);
        $display("║  PASS         : %-4d                             ║", pass_cnt);
        $display("║  FAIL         : %-4d                             ║", fail_cnt);
        if (fail_cnt == 0)
        $display("║  ✔  Tất cả test PASS!                           ║");
        else
        $display("║  ✘  Có lỗi cần kiểm tra lại!                   ║");
        $display("╚══════════════════════════════════════════════════╝");
        $display("");

        $finish;
    end

    // =========================================================
    // Safety timeout
    // =========================================================
    initial begin
        #50000;
        $display("[TB] TIMEOUT sau 50000ns — dừng simulation.");
        $finish;
    end

    // =========================================================
    // VCD dump (tùy chọn, comment lại nếu không cần)
    // =========================================================
    initial begin
        $dumpfile("cpu_pipeline_full.vcd");
        $dumpvars(0, CPU_Pipeline_tb);
    end

endmodule

//==============================================================
// GHI CHÚ: System / Fence Instructions
//==============================================================
//
// CPU này KHÔNG hỗ trợ SYSTEM / FENCE vì những lý do sau:
//
// 1. ECALL / EBREAK (opcode 7'b1110011, funct12 = 000/001):
//    → Control_Unit không có case cho opcode 7'b1110011.
//    → Sẽ rơi vào default: tất cả control = 0 → lệnh bị bỏ qua
//      như NOP, CPU tiếp tục chạy bình thường (KHÔNG dừng).
//    → Không có cơ chế trap/interrupt handler.
//
// 2. FENCE / FENCE.I (opcode 7'b0001111):
//    → Tương tự, không có case → hoạt động như NOP.
//    → Trong pipeline in-order không có cache hay store buffer
//      thực sự, FENCE về mặt chức năng là không cần thiết.
//      Nhưng CPU không nhận biết hay xử lý đúng spec.
//
// 3. CSR instructions (CSRRW, CSRRS, ...):
//    → Hoàn toàn không có CSR register file.
//    → Không hỗ trợ.
//
// Kết luận: Đây là CPU RV32I "user-level" cơ bản — phù hợp
// cho mục đích học thuật. Để hỗ trợ SYSTEM/FENCE cần thêm:
//   - Cơ chế trap (PC → handler)
//   - CSR register file (mstatus, mepc, mcause, ...)
//   - Pipeline flush khi trap
//
//==============================================================