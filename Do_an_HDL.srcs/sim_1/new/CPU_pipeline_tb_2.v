`timescale 1ns / 1ps

module CPU_Pipeline_tb;

    // =========================================================
    // DUT
    // =========================================================
    reg clk, rst;

    CPU_Pipeline dut (
        .clk(clk),
        .rst(rst)
    );

    // Clock 10 ns
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
    // Task: chạy N cycle
    // =========================================================
    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            #1; // settling time
        end
    endtask

    // =========================================================
    // Task: kiểm tra register
    // =========================================================
    task check_reg;
        input [4:0]    reg_idx;
        input [31:0]   expected;
        input [8*10:1] label;
        begin
            test_num = test_num + 1;
            if (rf(reg_idx) === expected) begin
                $display("  [PASS] %-10s x%0d = 0x%08h (%0d)",
                    label, reg_idx, rf(reg_idx), $signed(rf(reg_idx)));
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] %-10s x%0d = 0x%08h (%0d)  -- expected 0x%08h (%0d)",
                    label, reg_idx, rf(reg_idx), $signed(rf(reg_idx)),
                    expected, $signed(expected));
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // =========================================================
    // Task: kiểm tra D_MEM (word index)
    // =========================================================
    task check_dmem;
        input [7:0]    widx;
        input [31:0]   expected;
        input [8*10:1] label;
        begin
            test_num = test_num + 1;
            if (dut.dp.dmem_inst.mem[widx] === expected) begin
                $display("  [PASS] %-10s mem[%0d] = 0x%08h",
                    label, widx, dut.dp.dmem_inst.mem[widx]);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] %-10s mem[%0d] = 0x%08h  -- expected 0x%08h",
                    label, widx, dut.dp.dmem_inst.mem[widx], expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // =========================================================
    // Macro-task: bắt đầu nhóm test mới
    //   rst=1 → xóa I_MEM & D_MEM → (caller nạp lệnh) → rst=0
    // Được gọi rồi caller nạp lệnh, sau đó gọi start_cpu
    // =========================================================
    task begin_group;
        integer i;
        begin
            rst = 1;
            @(posedge clk); #1;
            for (i = 0; i < 256; i = i + 1) begin
                dut.dp.imem_inst.mem[i] = 32'h00000013; // NOP
                dut.dp.dmem_inst.mem[i] = 32'h00000000;
            end
            // Caller nạp lệnh ngay sau task này (rst vẫn=1)
        end
    endtask

    task start_cpu;
        begin
            @(posedge clk); // 1 cycle đệm sau khi nạp xong
            rst = 0;
            @(posedge clk); // cycle đầu tiên CPU chạy
        end
    endtask

    // =========================================================
    // Encoding functions
    // =========================================================

    // R-type (opcode 0110011)
    function [31:0] R;
        input [4:0] rd, rs1, rs2;
        input [2:0] funct3;
        input [6:0] funct7;
        R = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // I-type arithmetic (opcode 0010011)
    function [31:0] Ialu;
        input [4:0]  rd, rs1;
        input [11:0] imm;
        input [2:0]  funct3;
        Ialu = {imm, rs1, funct3, rd, 7'b0010011};
    endfunction

    // ADDI shorthand
    function [31:0] ADDI;
        input [4:0]  rd, rs1;
        input [11:0] imm;
        ADDI = {imm, rs1, 3'b000, rd, 7'b0010011};
    endfunction

    // I-type shift (SLLI/SRLI/SRAI)
    function [31:0] Ishamt;
        input [4:0] rd, rs1, shamt;
        input [2:0] funct3;
        input       arith; // 1=SRA/SRAI
        Ishamt = {1'b0, arith, 5'b00000, shamt, rs1, funct3, rd, 7'b0010011};
    endfunction

    // I-type LOAD (opcode 0000011)
    function [31:0] LOAD;
        input [4:0]  rd, rs1;
        input [11:0] imm;
        input [2:0]  funct3;
        LOAD = {imm, rs1, funct3, rd, 7'b0000011};
    endfunction

    // I-type JALR (opcode 1100111)
    function [31:0] JALR;
        input [4:0]  rd, rs1;
        input [11:0] imm;
        JALR = {imm, rs1, 3'b000, rd, 7'b1100111};
    endfunction

    // S-type STORE (opcode 0100011)
    function [31:0] STORE;
        input [4:0]  rs1, rs2;
        input [11:0] imm;
        input [2:0]  funct3;
        STORE = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
    endfunction

    // B-type BRANCH (opcode 1100011)
    // imm13 = byte offset (bit[0] luôn 0, spec dùng imm[12:1])
    function [31:0] BRANCH;
        input [4:0]  rs1, rs2;
        input [12:0] imm13;
        input [2:0]  funct3;
        BRANCH = {imm13[12], imm13[10:5], rs2, rs1, funct3,
                  imm13[4:1], imm13[11], 7'b1100011};
    endfunction

    // U-type LUI (opcode 0110111)
    function [31:0] LUI;
        input [4:0]  rd;
        input [19:0] imm20;
        LUI = {imm20, rd, 7'b0110111};
    endfunction

    // U-type AUIPC (opcode 0010111)
    function [31:0] AUIPC;
        input [4:0]  rd;
        input [19:0] imm20;
        AUIPC = {imm20, rd, 7'b0010111};
    endfunction

    // J-type JAL (opcode 1101111)
    function [31:0] JAL;
        input [4:0]  rd;
        input [20:0] imm21; // byte offset, bit[0]=0
        JAL = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, 7'b1101111};
    endfunction

    parameter NOP = 32'h00000013;

    // =========================================================
    // MAIN TEST
    // =========================================================
    initial begin
        pass_cnt = 0; fail_cnt = 0; test_num = 0;
        rst = 1; #20;

        $display("");
        $display("╔══════════════════════════════════════════════════════╗");
        $display("║    RISC-V Pipeline CPU - Full RV32I Testbench v2    ║");
        $display("╚══════════════════════════════════════════════════════╝");

        // ═════════════════════════════════════════════════════════
        // NHÓM 1 - R-type (10 lệnh)
        // Giá trị: x1=15, x2=-5, x3=3
        //   x10=ADD(x1,x3)  = 18
        //   x11=SUB(x1,x3)  = 12
        //   x12=SLL(x1,x3)  = 15<<3=120
        //   x13=SLT(x2,x1)  = (-5<15)=1
        //   x14=SLTU(x2,x1) = (0xFFFFFFFB<15u)=0
        //   x15=XOR(x1,x3)  = 15^3=12
        //   x16=SRL(x1,x3)  = 15>>3=1
        //   x17=SRA(x2,x3)  = -5>>>3=-1
        //   x18=OR(x1,x3)   = 15|3=15
        //   x19=AND(x1,x3)  = 15&3=3
        // ═════════════════════════════════════════════════════════
        $display(""); $display(" Nhom 1: R-type ");
        begin_group;
        dut.dp.imem_inst.mem[0]  = ADDI(1, 0, 12'd15);
        dut.dp.imem_inst.mem[1]  = ADDI(2, 0, 12'hFFB);         // -5
        dut.dp.imem_inst.mem[2]  = ADDI(3, 0, 12'd3);
        dut.dp.imem_inst.mem[3]  = R(10, 1, 3, 3'b000, 7'h00); // ADD
        dut.dp.imem_inst.mem[4]  = R(11, 1, 3, 3'b000, 7'h20); // SUB
        dut.dp.imem_inst.mem[5]  = R(12, 1, 3, 3'b001, 7'h00); // SLL
        dut.dp.imem_inst.mem[6]  = R(13, 2, 1, 3'b010, 7'h00); // SLT
        dut.dp.imem_inst.mem[7]  = R(14, 2, 1, 3'b011, 7'h00); // SLTU
        dut.dp.imem_inst.mem[8]  = R(15, 1, 3, 3'b100, 7'h00); // XOR
        dut.dp.imem_inst.mem[9]  = R(16, 1, 3, 3'b101, 7'h00); // SRL
        dut.dp.imem_inst.mem[10] = R(17, 2, 3, 3'b101, 7'h20); // SRA
        dut.dp.imem_inst.mem[11] = R(18, 1, 3, 3'b110, 7'h00); // OR
        dut.dp.imem_inst.mem[12] = R(19, 1, 3, 3'b111, 7'h00); // AND
        start_cpu;
        // Lệnh cuối ở [12]: WB = 12+4=16 cycle, margin=+4 → 20
        run_cycles(20);

        check_reg(10, 32'd18,        "ADD");
        check_reg(11, 32'd12,        "SUB");
        check_reg(12, 32'd120,       "SLL");
        check_reg(13, 32'd1,         "SLT");
        check_reg(14, 32'd0,         "SLTU");
        check_reg(15, 32'd12,        "XOR");
        check_reg(16, 32'd1,         "SRL");
        check_reg(17, 32'hFFFFFFFF,  "SRA");
        check_reg(18, 32'd15,        "OR");
        check_reg(19, 32'd3,         "AND");

        // ═════════════════════════════════════════════════════════
        // NHÓM 2 - I-type ALU Immediate (9 lệnh)
        // x1=20, x2=-3
        //   x10=ADDI(x1,5)    =25
        //   x11=SLTI(x2,0)    =(-3<0)=1
        //   x12=SLTIU(x2,1)   =(0xFFFFFFFD<1u)=0
        //   x13=XORI(x1,15)   =20^15=27
        //   x14=ORI(x1,7)     =20|7=23
        //   x15=ANDI(x1,15)   =20&15=4
        //   x16=SLLI(x1,2)    =20<<2=80
        //   x17=SRLI(x1,2)    =20>>2=5
        //   x18=SRAI(x2,1)    =-3>>>1=-2
        // ═════════════════════════════════════════════════════════
        $display(""); $display(" Nhom 2: I-type ALU Immediate");
        begin_group;
        dut.dp.imem_inst.mem[0]  = ADDI(1, 0, 12'd20);
        dut.dp.imem_inst.mem[1]  = ADDI(2, 0, 12'hFFD);           // -3
        dut.dp.imem_inst.mem[2]  = Ialu(10,1, 12'd5,    3'b000);  // ADDI  +5
        dut.dp.imem_inst.mem[3]  = Ialu(11,2, 12'd0,    3'b010);  // SLTI  <0
        dut.dp.imem_inst.mem[4]  = Ialu(12,2, 12'd1,    3'b011);  // SLTIU <1
        dut.dp.imem_inst.mem[5]  = Ialu(13,1, 12'h00F,  3'b100);  // XORI  ^15
        dut.dp.imem_inst.mem[6]  = Ialu(14,1, 12'h007,  3'b110);  // ORI   |7
        dut.dp.imem_inst.mem[7]  = Ialu(15,1, 12'h00F,  3'b111);  // ANDI  &15
        dut.dp.imem_inst.mem[8]  = Ishamt(16,1,5'd2,3'b001,1'b0); // SLLI  <<2
        dut.dp.imem_inst.mem[9]  = Ishamt(17,1,5'd2,3'b101,1'b0); // SRLI  >>2
        dut.dp.imem_inst.mem[10] = Ishamt(18,2,5'd1,3'b101,1'b1); // SRAI  >>>1
        start_cpu;
        run_cycles(18); // [10]+4+margin

        check_reg(10, 32'd25,        "ADDI");
        check_reg(11, 32'd1,         "SLTI");
        check_reg(12, 32'd0,         "SLTIU");
        check_reg(13, 32'd27,        "XORI");
        check_reg(14, 32'd23,        "ORI");
        check_reg(15, 32'd4,         "ANDI");
        check_reg(16, 32'd80,        "SLLI");
        check_reg(17, 32'd5,         "SRLI");
        check_reg(18, 32'hFFFFFFFE,  "SRAI");

        // ═════════════════════════════════════════════════════════
        // NHÓM 3 - Load Instructions (5 kiểu: LW LH LB LBU LHU)
        // D_MEM: mem[0]=0xDEADBEEF, mem[1]=0x00008080
        //   x10=LW  0(x0)   =0xDEADBEEF
        //   x11=LH  0(x0)   =sext(0xBEEF)=0xFFFFBEEF
        //   x12=LH  2(x0)   =sext(0xDEAD)=0xFFFFDEAD
        //   x13=LB  0(x0)   =sext(0xEF)=0xFFFFFFEF
        //   x14=LBU 0(x0)   =0x000000EF
        //   x15=LHU 0(x0)   =0x0000BEEF
        //   x16=LB  4(x0)   =sext(0x80)=0xFFFFFF80
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 3: Load Instructions ");
        begin_group;
        dut.dp.dmem_inst.mem[0] = 32'hDEADBEEF;
        dut.dp.dmem_inst.mem[1] = 32'h00008080;
        dut.dp.imem_inst.mem[0] = LOAD(10,0,12'd0,3'b010); // LW  x10
        dut.dp.imem_inst.mem[1] = LOAD(11,0,12'd0,3'b001); // LH  x11
        dut.dp.imem_inst.mem[2] = LOAD(12,0,12'd2,3'b001); // LH  x12 +2
        dut.dp.imem_inst.mem[3] = LOAD(13,0,12'd0,3'b000); // LB  x13
        dut.dp.imem_inst.mem[4] = LOAD(14,0,12'd0,3'b100); // LBU x14
        dut.dp.imem_inst.mem[5] = LOAD(15,0,12'd0,3'b101); // LHU x15
        dut.dp.imem_inst.mem[6] = LOAD(16,0,12'd4,3'b000); // LB  x16 +4
        start_cpu;
        run_cycles(14);

        check_reg(10, 32'hDEADBEEF,  "LW");
        check_reg(11, 32'hFFFFBEEF,  "LH");
        check_reg(12, 32'hFFFFDEAD,  "LH+2");
        check_reg(13, 32'hFFFFFFEF,  "LB");
        check_reg(14, 32'h000000EF,  "LBU");
        check_reg(15, 32'h0000BEEF,  "LHU");
        check_reg(16, 32'hFFFFFF80,  "LB+4");

        // ═════════════════════════════════════════════════════════
        // NHÓM 4 - Store Instructions (SW SH SB)
        // x1=0x12345678 (bằng LUI+ADDI)
        //   SW x1,0(x0) → mem[0]=0x12345678
        //   SH x1,4(x0) → mem[1]=0x00005678
        //   SB x1,8(x0) → mem[2]=0x00000078
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 4: Store Instructions");
        begin_group;
        dut.dp.imem_inst.mem[0] = LUI(1, 20'h12345);            // LUI  x1
        dut.dp.imem_inst.mem[1] = ADDI(1,1,12'h678);            // ADDI x1,x1,0x678
        dut.dp.imem_inst.mem[2] = STORE(0,1,12'd0, 3'b010);     // SW
        dut.dp.imem_inst.mem[3] = STORE(0,1,12'd4, 3'b001);     // SH
        dut.dp.imem_inst.mem[4] = STORE(0,1,12'd8, 3'b000);     // SB
        start_cpu;
        // SW ở [2] ghi D_MEM tại MEM stage = cycle 2+3=5
        // SB ở [4] ghi D_MEM tại cycle 4+3=7; margin+5=12
        run_cycles(14);

        check_dmem(0, 32'h12345678,  "SW");
        check_dmem(1, 32'h00005678,  "SH");
        check_dmem(2, 32'h00000078,  "SB");

        // ═════════════════════════════════════════════════════════
        // NHÓM 5 - Branch Instructions (BEQ BNE BLT BGE BLTU BGEU)
        // Setup: x1=5, x2=5, x3=3
        // Mỗi branch taken (+8) → nhảy qua lệnh "bẫy" → thực thi "marker"
        // Expected: x10..x15 = 1
        //
        // Layout (word index):
        //  [0..3] setup x1,x2,x3,x4
        //  [4]  BEQ  x1,x2,+8   → [6]
        //  [5]  BAIT x10
        //  [6]  x10=1
        //  [7]  BNE  x1,x3,+8   → [9]
        //  [8]  BAIT x11
        //  [9]  x11=1
        //  [10] BLT  x3,x1,+8   → [12]
        //  [11] BAIT x12
        //  [12] x12=1
        //  [13] BGE  x1,x2,+8   → [15]
        //  [14] BAIT x13
        //  [15] x13=1
        //  [16] BLTU x3,x1,+8   → [18]
        //  [17] BAIT x14
        //  [18] x14=1
        //  [19] BGEU x1,x3,+8   → [21]
        //  [20] BAIT x15
        //  [21] x15=1
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 5: Branch Instructions");
        begin_group;
        dut.dp.imem_inst.mem[0]  = ADDI(1,0,12'd5);
        dut.dp.imem_inst.mem[1]  = ADDI(2,0,12'd5);
        dut.dp.imem_inst.mem[2]  = ADDI(3,0,12'd3);
        dut.dp.imem_inst.mem[3]  = NOP;
        // BEQ x1,x2,+8
        dut.dp.imem_inst.mem[4]  = BRANCH(1,2,13'd8, 3'b000);
        dut.dp.imem_inst.mem[5]  = Ialu(10,0,12'hDEA,3'b000); // bẫy
        dut.dp.imem_inst.mem[6]  = ADDI(10,0,12'd1);
        // BNE x1,x3,+8
        dut.dp.imem_inst.mem[7]  = BRANCH(1,3,13'd8, 3'b001);
        dut.dp.imem_inst.mem[8]  = Ialu(11,0,12'hDEA,3'b000);
        dut.dp.imem_inst.mem[9]  = ADDI(11,0,12'd1);
        // BLT x3,x1,+8
        dut.dp.imem_inst.mem[10] = BRANCH(3,1,13'd8, 3'b100);
        dut.dp.imem_inst.mem[11] = Ialu(12,0,12'hDEA,3'b000);
        dut.dp.imem_inst.mem[12] = ADDI(12,0,12'd1);
        // BGE x1,x2,+8  (5>=5 → taken)
        dut.dp.imem_inst.mem[13] = BRANCH(1,2,13'd8, 3'b101);
        dut.dp.imem_inst.mem[14] = Ialu(13,0,12'hDEA,3'b000);
        dut.dp.imem_inst.mem[15] = ADDI(13,0,12'd1);
        // BLTU x3,x1,+8
        dut.dp.imem_inst.mem[16] = BRANCH(3,1,13'd8, 3'b110);
        dut.dp.imem_inst.mem[17] = Ialu(14,0,12'hDEA,3'b000);
        dut.dp.imem_inst.mem[18] = ADDI(14,0,12'd1);
        // BGEU x1,x3,+8
        dut.dp.imem_inst.mem[19] = BRANCH(1,3,13'd8, 3'b111);
        dut.dp.imem_inst.mem[20] = Ialu(15,0,12'hDEA,3'b000);
        dut.dp.imem_inst.mem[21] = ADDI(15,0,12'd1);
        start_cpu;
        // 6 branch × 2 penalty + ~22 lệnh thực + drain5 + margin5 = 45
        run_cycles(45);

        check_reg(10, 32'd1,  "BEQ");
        check_reg(11, 32'd1,  "BNE");
        check_reg(12, 32'd1,  "BLT");
        check_reg(13, 32'd1,  "BGE");
        check_reg(14, 32'd1,  "BLTU");
        check_reg(15, 32'd1,  "BGEU");

        // ═════════════════════════════════════════════════════════
        // NHÓM 6 - Jump (JAL + JALR)
        // JAL:
        //   [0] 0x00 JAL x1,+12  → x1=0x04, PC→0x0C
        //   [1] 0x04 BAIT x10
        //   [2] 0x08 BAIT x10
        //   [3] 0x0C x10=1       ← marker
        // JALR:
        //   [4] 0x10 ADDI x2,x0,0x20  → x2=32
        //   [5] 0x14 JALR x3,x2,0     → x3=0x18, PC→0x20
        //   [6] 0x18 BAIT x11
        //   [7] 0x1C BAIT x11
        //   [8] 0x20 x11=1        ← marker
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 6: Jump Instructions");
        begin_group;
        dut.dp.imem_inst.mem[0] = JAL(1, 21'd12);
        dut.dp.imem_inst.mem[1] = Ialu(10,0,12'hBAD,3'b000); // bẫy
        dut.dp.imem_inst.mem[2] = Ialu(10,0,12'hBAD,3'b000); // bẫy
        dut.dp.imem_inst.mem[3] = ADDI(10,0,12'd1);          // marker JAL
        dut.dp.imem_inst.mem[4] = ADDI(2,0,12'h020);         // x2=0x20
        dut.dp.imem_inst.mem[5] = JALR(3,2,12'd0);           // JALR
        dut.dp.imem_inst.mem[6] = Ialu(11,0,12'hBAD,3'b000); // bẫy
        dut.dp.imem_inst.mem[7] = Ialu(11,0,12'hBAD,3'b000); // bẫy
        dut.dp.imem_inst.mem[8] = ADDI(11,0,12'd1);          // marker JALR
        start_cpu;
        run_cycles(25);

        check_reg(1,  32'h00000004,  "JAL-rd");
        check_reg(10, 32'd1,         "JAL-PC");
        check_reg(3,  32'h00000018,  "JALR-rd");
        check_reg(11, 32'd1,         "JALR-PC");

        // ═════════════════════════════════════════════════════════
        // NHÓM 7 - Upper Immediate (LUI + AUIPC)
        //   [0] 0x00 LUI   x10,0xABCDE → x10=0xABCDE000
        //   [1] 0x04 AUIPC x11,0x00001 → x11=0x04+0x1000=0x00001004
        //   [2] 0x08 LUI   x12,0xFFFFF → x12=0xFFFFF000
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 7: Upper Immediate");
        begin_group;
        dut.dp.imem_inst.mem[0] = LUI(10,   20'hABCDE);
        dut.dp.imem_inst.mem[1] = AUIPC(11, 20'h00001);
        dut.dp.imem_inst.mem[2] = LUI(12,   20'hFFFFF);
        start_cpu;
        run_cycles(12);

        check_reg(10, 32'hABCDE000,  "LUI");
        check_reg(11, 32'h00001004,  "AUIPC");
        check_reg(12, 32'hFFFFF000,  "LUI-neg");

        // ═════════════════════════════════════════════════════════
        // NHÓM 8 (bonus) - Forwarding & Load-Use Stall
        //   [0] ADDI x1,x0,10
        //   [1] ADD  x2,x1,x1  → EX/MEM forward x1 → x2=20
        //   [2] ADD  x3,x2,x1  → EX/MEM fwd x2, MEM/WB fwd x1 → x3=30
        //   [3] SW   x1,0(x0)  → mem[0]=10
        //   [4] LW   x4,0(x0)  → x4=10
        //   [5] ADD  x5,x4,x1  → load-use stall, x5=20
        // ═════════════════════════════════════════════════════════
        $display(""); $display("Nhom 8 (bonus): Forwarding & Load-Use Stall");
        begin_group;
        dut.dp.imem_inst.mem[0] = ADDI(1,0,12'd10);
        dut.dp.imem_inst.mem[1] = R(2,1,1,3'b000,7'h00);     // ADD x2,x1,x1
        dut.dp.imem_inst.mem[2] = R(3,2,1,3'b000,7'h00);     // ADD x3,x2,x1
        dut.dp.imem_inst.mem[3] = STORE(0,1,12'd0,3'b010);   // SW  x1,0(x0)
        dut.dp.imem_inst.mem[4] = LOAD(4,0,12'd0,3'b010);    // LW  x4,0(x0)
        dut.dp.imem_inst.mem[5] = R(5,4,1,3'b000,7'h00);     // ADD x5,x4,x1
        start_cpu;
        run_cycles(16);

        check_reg(1, 32'd10,  "FWD-x1");
        check_reg(2, 32'd20,  "FWD-x2");
        check_reg(3, 32'd30,  "FWD-x3");
        check_reg(4, 32'd10,  "LU-LW");
        check_reg(5, 32'd20,  "LU-ADD");

        // ═════════════════════════════════════════════════════════
        // TỔNG KẾT
        // ═════════════════════════════════════════════════════════

        $display("Ket qua tong hop:");
        $display("  Tests        : %0d", test_num);
        $display("  PASS         : %0d", pass_cnt);
        $display("  FAIL         : %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("OK  Tat ca PASS!");
        else
            $display(" !!  Con loi, xem chi tiet o tren.                 ");


        $finish;
    end

    // =========================================================
    // Safety timeout
    // =========================================================
    initial begin
        #200000;
        $display("[TIMEOUT] Simulation khong ket thuc sau 200us.");
        $finish;
    end

    // =========================================================
    // VCD dump
    // =========================================================
    initial begin
        $dumpfile("cpu_full.vcd");
        $dumpvars(0, CPU_Pipeline_tb);
    end

endmodule
