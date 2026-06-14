`timescale 1ns / 1ps


module D_MEM(
    input         clk,
    input         MemWrite,
    input         MemRead,
    input  [2:0]  funct3,
    input  [31:0] addr,
    input  [31:0] write_data,
    output reg [31:0] read_data
);

    reg [31:0] mem [0:255];

    // ĐỌC - Combinational

    wire [31:0] rword;
    wire [1:0]  boff;

    assign rword = mem[addr[9:2]];
    assign boff  = addr[1:0];

    always @(*) begin
        read_data = 32'b0;
        if (MemRead) begin
            case (funct3)
                3'b000: begin   // LB - sign-extend
                    case (boff)
                        2'b00: read_data = {{24{rword[7]}},  rword[7:0]};
                        2'b01: read_data = {{24{rword[15]}}, rword[15:8]};
                        2'b10: read_data = {{24{rword[23]}}, rword[23:16]};
                        2'b11: read_data = {{24{rword[31]}}, rword[31:24]};
                    endcase
                end
                3'b001: begin   // LH - sign-extend
                    case (boff[1])
                        1'b0: read_data = {{16{rword[15]}}, rword[15:0]};
                        1'b1: read_data = {{16{rword[31]}}, rword[31:16]};
                    endcase
                end
                3'b010: read_data = rword;  // LW
                3'b100: begin   // LBU - zero-extend
                    case (boff)
                        2'b00: read_data = {24'b0, rword[7:0]};
                        2'b01: read_data = {24'b0, rword[15:8]};
                        2'b10: read_data = {24'b0, rword[23:16]};
                        2'b11: read_data = {24'b0, rword[31:24]};
                    endcase
                end
                3'b101: begin   // LHU - zero-extend
                    case (boff[1])
                        1'b0: read_data = {16'b0, rword[15:0]};
                        1'b1: read_data = {16'b0, rword[31:16]};
                    endcase
                end
                default: read_data = 32'b0;
            endcase
        end
    end

    
    // GHI - Synchronous    
    reg [31:0] wword;

    always @(posedge clk) begin
        if (MemWrite) begin
            wword = mem[addr[9:2]];     // đọc word hiện tại
            case (funct3)
                3'b000: begin           // SB - ghi 1 byte
                    case (boff)
                        2'b00: wword[7:0]   = write_data[7:0];
                        2'b01: wword[15:8]  = write_data[7:0];
                        2'b10: wword[23:16] = write_data[7:0];
                        2'b11: wword[31:24] = write_data[7:0];
                    endcase
                end
                3'b001: begin           // SH - ghi halfword
                    case (boff[1])
                        1'b0: wword[15:0]  = write_data[15:0];
                        1'b1: wword[31:16] = write_data[15:0];
                    endcase
                end
                3'b010: wword = write_data; // SW - ghi word
                default: ;
            endcase
            mem[addr[9:2]] <= wword;    // ghi lại vào memory (non-blocking)
        end
    end

endmodule