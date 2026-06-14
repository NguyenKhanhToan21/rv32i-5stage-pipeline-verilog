`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_CPU
// Description: Testbench kiểm tra toàn bộ tập lệnh RV32I
//              Nhóm: R-type, I-type, S/L-type, U-type, B-type, J-type
//
// Cách dùng:
//   1. Đặt instruction.txt cùng thư mục project (hoặc nơi Vivado chạy simulation)
//   2. Add tất cả file .v vào project: CPU.v, Datapath.v, Control_Unit.v,
//      ALU_Control.v, ALU.v, Branch_Comp.v, RF.v, IMM_GEN.v, Decoder.v,
//      I_MEM.v, D_MEM.v, PC.v
//   3. Set tb_CPU làm top simulation module
//   4. Run Simulation → xem kết quả trong Tcl Console
//
// Kết quả: PASS/FAIL từng test case in ra console
//////////////////////////////////////////////////////////////////////////////////

module tb_CPU;

    // ── Clock & Reset ──────────────────────────────────────────
    reg clk, rst;
    localparam CLK_PERIOD = 10; // 10ns = 100MHz

    always #(CLK_PERIOD/2) clk = ~clk;

    // ── DUT ────────────────────────────────────────────────────
    CPU dut (
        .clk(clk),
        .rst(rst)
    );

    // ── Truy cập nội bộ qua hierarchical reference ─────────────
    // Register File
    wire [31:0] x1  = dut.dp.rf_inst.regs[1];
    wire [31:0] x2  = dut.dp.rf_inst.regs[2];
    wire [31:0] x3  = dut.dp.rf_inst.regs[3];
    wire [31:0] x4  = dut.dp.rf_inst.regs[4];
    wire [31:0] x5  = dut.dp.rf_inst.regs[5];
    wire [31:0] x6  = dut.dp.rf_inst.regs[6];
    wire [31:0] x7  = dut.dp.rf_inst.regs[7];
    wire [31:0] x8  = dut.dp.rf_inst.regs[8];
    wire [31:0] x9  = dut.dp.rf_inst.regs[9];
    wire [31:0] x10 = dut.dp.rf_inst.regs[10];
    wire [31:0] x11 = dut.dp.rf_inst.regs[11];
    wire [31:0] x12 = dut.dp.rf_inst.regs[12];
    wire [31:0] x13 = dut.dp.rf_inst.regs[13];
    wire [31:0] x14 = dut.dp.rf_inst.regs[14];
    wire [31:0] x15 = dut.dp.rf_inst.regs[15];
    wire [31:0] x16 = dut.dp.rf_inst.regs[16];
    wire [31:0] x17 = dut.dp.rf_inst.regs[17];
    wire [31:0] x18 = dut.dp.rf_inst.regs[18];
    wire [31:0] x19 = dut.dp.rf_inst.regs[19];
    wire [31:0] x20 = dut.dp.rf_inst.regs[20];
    wire [31:0] x21 = dut.dp.rf_inst.regs[21];
    wire [31:0] x22 = dut.dp.rf_inst.regs[22];
    wire [31:0] x23 = dut.dp.rf_inst.regs[23];
    wire [31:0] x24 = dut.dp.rf_inst.regs[24];
    wire [31:0] x25 = dut.dp.rf_inst.regs[25];
    wire [31:0] x26 = dut.dp.rf_inst.regs[26];
    wire [31:0] x27 = dut.dp.rf_inst.regs[27];
    wire [31:0] x28 = dut.dp.rf_inst.regs[28];
    wire [31:0] x29 = dut.dp.rf_inst.regs[29];

    // PC
    wire [31:0] pc_now = dut.dp.pc_inst.pc;

    // Data Memory (kiểm tra SW/LW)
    wire [31:0] dmem_100 = dut.dp.dmem_inst.mem[25]; // addr=100 → word index=25

    // ── Biến đếm PASS/FAIL ─────────────────────────────────────
    integer pass_cnt, fail_cnt;

    // ── Task kiểm tra ──────────────────────────────────────────
    task check;
        input [127:0] name;   // tên test (dùng string tối đa 16 ký tự)
        input [31:0]  got;
        input [31:0]  expected;
        begin
            if (got === expected) begin
                $display("  [PASS] %-20s got=0x%08X (%0d)", name, got, $signed(got));
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  [FAIL] %-20s got=0x%08X (%0d)  expected=0x%08X (%0d)",
                          name, got, $signed(got), expected, $signed(expected));
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task section;
        input [255:0] title;
        begin
            $display("\n========================================");
            $display("  %s", title);
            $display("========================================");
        end
    endtask

    // ── Chạy N chu kỳ ──────────────────────────────────────────
    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            #1; // ổn định combo sau clk
        end
    endtask

    // ── Main simulation ────────────────────────────────────────
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        clk = 0;
        rst = 1;

        $display("");
        $display("##############################################");
        $display("#   RISC-V RV32I CPU Testbench               #");
        $display("##############################################");

        // Reset 2 chu kỳ
        repeat(2) @(posedge clk);
        rst = 0;
        #1;

        // ══════════════════════════════════════════════
        // NHÓM 1: R-type (11 lệnh, PC=0x00→0x28)
        // Mỗi lệnh 1 chu kỳ → chạy 11 chu kỳ
        // ══════════════════════════════════════════════
        run_cycles(11);
        section("R-TYPE: ADD SUB AND OR XOR SLL SRL SLT SLTU");
        //                           expected
        check("ADD  x3=x1+x2",  x3,  32'd30);
        check("SUB  x4=x2-x1",  x4,  32'd10);
        check("AND  x5=x1&x2",  x5,  32'd0);            // 10&20=0b01010&0b10100=0
        check("OR   x6=x1|x2",  x6,  32'd30);           // 10|20=0b11110=30
        check("XOR  x7=x1^x2",  x7,  32'd30);           // 10^20=0b11110=30
        check("SLL  x8=x1<<x2", x8,  32'd10<<20);       // 10<<20
        check("SRL  x9=x8>>x1", x9,  (32'd10<<20)>>10); // x8>>10
        check("SLT  x10",       x10, 32'd1);             // 10<20 signed
        check("SLTU x11",       x11, 32'd1);             // 10<20 unsigned

        // ══════════════════════════════════════════════
        // NHÓM 2: I-type arithmetic (8 lệnh thêm, PC=0x2C→0x48)
        // Đã chạy 11 chu kỳ, chạy thêm 8
        // ══════════════════════════════════════════════
        run_cycles(8);
        section("I-TYPE: ADDI SLTI XORI ORI ANDI SLLI SRLI SRAI");
        check("ADDI x12=5",     x12, 32'd5);
        check("SLTI x13=1",     x13, 32'd1);    // 5<10
        check("XORI x14=5^3",   x14, 32'd6);    // 5^3=6
        check("ORI  x15=5|2",   x15, 32'd7);    // 5|2=7
        check("ANDI x16=5&6",   x16, 32'd4);    // 5&6=4
        check("SLLI x17=5<<2",  x17, 32'd20);   // 5<<2=20
        check("SRLI x18=20>>1", x18, 32'd10);   // 20>>1=10
        check("SRAI x19=20>>>1",x19, 32'd10);   // 20>>>1=10 (positive)

        // ══════════════════════════════════════════════
        // NHÓM 3: S-type / L-type (4 lệnh: ADDI, ADDI, SW, LW)
        // ══════════════════════════════════════════════
        run_cycles(4);
        section("S/L-TYPE: SW + LW");
        check("ADDI x20=100",   x20,     32'd100);
        check("ADDI x21=55",    x21,     32'd55);
        check("SW mem[100]=55", dmem_100,32'd55);
        check("LW  x22=55",     x22,     32'd55);

        // ══════════════════════════════════════════════
        // NHÓM 4: U-type (LUI, AUIPC)
        // ══════════════════════════════════════════════
        run_cycles(2);
        section("U-TYPE: LUI + AUIPC");
        check("LUI  x23",       x23, 32'h12345000);
        // AUIPC: PC tại lệnh AUIPC = 0x60, imm=0x1000 → x24=0x1060
        check("AUIPC x24",      x24, 32'h00001060);

        // ══════════════════════════════════════════════
        // NHÓM 5: B-type (10 lệnh: 5 branch + 5 lệnh sau)
        // BEQ true  → skip ADDI(99)         = 2 chu kỳ
        // BNE true  → skip ADDI(88)         = 2 chu kỳ
        // BLT true  → skip ADDI(77)         = 2 chu kỳ
        // BGE true  → skip ADDI(66)         = 2 chu kỳ
        // BEQ false → KHÔNG skip ADDI(42)   = 2 chu kỳ
        // ══════════════════════════════════════════════
        run_cycles(10);
        section("B-TYPE: BEQ BNE BLT BGE (taken/not-taken)");
        // x25 chỉ nên = 42 (từ BEQ false), các giá trị 99/88/77/66 đều bị skip
        check("BEQ taken(skip 99)", x25, 32'd42); // x25 cuối = 42, không phải 99/88/77/66
        // Thêm kiểm tra gián tiếp: nếu bất kỳ branch taken-sai, x25 sẽ ≠ 42
        // Kiểm tra x25 ≠ 99 (BEQ lẽ ra skip)
        begin
            if (x25 !== 32'd99 && x25 !== 32'd88 && x25 !== 32'd77 && x25 !== 32'd66)
                $display("  [PASS] Branch taken: không ghi 99/88/77/66 vào x25");
            else begin
                $display("  [FAIL] Branch taken: x25=0x%08X (1 branch sai direction)", x25);
                fail_cnt = fail_cnt + 1;
            end
        end

        // ══════════════════════════════════════════════
        // NHÓM 6: J-type (JAL + JALR)
        // JAL  → x26=PC+4=0x90, nhảy qua ADDI(11) đến PC=0x94
        // JALR → x28=PC+4=0x98, nhảy về x26=0x90 → ADDI(11) bị skip
        //         rồi PC=0x94 → JALR lại → ... loop ngắn?
        // Để tránh vòng lặp, nhìn vào x26, x27, x28, x29 sau 4 chu kỳ
        // ══════════════════════════════════════════════
        run_cycles(4);
        section("J-TYPE: JAL + JALR");
        // JAL tại PC=0x8C: x26 = 0x8C+4 = 0x90
        check("JAL  x26=PC+4",   x26, 32'h00000090);
        // x27 phải = 0 (ADDI x27,x0,11 bị JAL skip)
        check("JAL  skip x27=0", x27, 32'd0);
        // JALR tại PC=0x94: x28 = 0x94+4 = 0x98
        check("JALR x28=PC+4",   x28, 32'h00000098);
        // x29 = 55 (landing pad sau JALR tại PC=0x98)
        check("JALR land x29=55",x29, 32'd55);

        // ══════════════════════════════════════════════
        // Tổng kết
        // ══════════════════════════════════════════════
        $display("");
        $display("##############################################");
        $display("#  KẾT QUẢ: %0d PASS  |  %0d FAIL            #",
                  pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("#  ✓ TẤT CẢ TEST ĐỀU PASS                    #");
        else
            $display("#  ✗ CÓ %0d TEST THẤT BẠI, kiểm tra lại!     #", fail_cnt);
        $display("##############################################");
        $display("");

        $finish;
    end

    // ── Monitor: in ra PC và lệnh mỗi chu kỳ (dùng khi debug) ─
    // Bỏ comment dòng dưới để xem từng lệnh chạy:
    // initial $monitor("t=%0t PC=0x%03X instr=0x%08X", $time, pc_now, dut.dp.instruction);

    // ── Timeout ────────────────────────────────────────────────
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation quá thời gian!");
        $finish;
    end

endmodule