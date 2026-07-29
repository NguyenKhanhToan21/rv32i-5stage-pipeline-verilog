# RV32I 5-Stage Pipeline CPU

Verilog HDL implementation of a RISC-V RV32I 32-bit processor 
with 5-stage pipeline and hazard handling.

> Course: CE213 – Digital System Design with HDL  
> University of Information Technology (UIT) – VNU-HCM

---

## Features
- Full RV32I base instruction set (R, I, S, B, U, J-type)
- Classic 5-stage pipeline: IF → ID → EX → MEM → WB
- Data hazard handling via **Forwarding Unit** (EX/MEM & MEM/WB)
- Load-Use hazard handling via **Stalling**
- Control hazard handling via **Pipeline Flushing**
  - JAL: 1-cycle penalty (resolved at ID stage)
  - Branch/JALR: 2-cycle penalty (resolved at EX stage)

---

## Pipeline Architecture
IF → ( ID → EX → MEM → WB )  Forwarding Unit, Hazard Detection Unit
        


---

## Hazard Handling Summary
| Hazard Type     | Method      | Penalty     |
|-----------------|-------------|-------------|
| Data (RAW)      | Forwarding  | 0 cycles    |
| Load-Use        | Stall       | 1 cycle     |
| Branch Taken    | Flush       | 2 cycles    |
| JAL             | Flush       | 1 cycle     |
| JALR            | Flush       | 2 cycles    |

---

## Simulation Results
All 8 test groups passed (self-checking testbench):
- R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- I-type ALU: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- Load: LW, LH, LHU, LB, LBU
- Store: SW, SH, SB
- Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
- Jump: JAL, JALR
- Upper Immediate: LUI, AUIPC
- Forwarding & Load-Use Stall

---

## Performance (Xilinx Artix-7, Vivado 2024.2)
| Metric        | Non-Pipeline | Pipeline     |
|---------------|--------------|--------------|
| Fmax          | ~9.22 MHz    | ~110.47 MHz  |
| Critical Path | ~108.5 ns    | ~9.05 ns     |
| Slice LUTs    | 424          | 502 (+18%)   |
| Flip-Flops    | 104          | 369 (+255%)  |

---

## Tools
- **Language:** Verilog HDL  
- **Simulator:** Xilinx Vivado XSIM 2024.2  
- **Target FPGA:** Artix-7 (Basys3)

---

## Team
| MSSV     | Họ tên              |
|----------|---------------------|
| 23521681 | Nguyễn Quốc Trung   |
| 23521608 | Nguyễn Khánh Toàn   |
| 23521633 | Trịnh Hùng Tráng    |

Instructor: Hồ Ngọc Diễm
