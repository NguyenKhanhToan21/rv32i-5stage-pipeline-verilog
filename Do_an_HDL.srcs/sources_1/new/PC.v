`timescale 1ns / 1ps


module PC(
    input        clk,
    input        rst,
    input        enable,
    input  [31:0] pc_next,
    output reg [31:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;        // reset về 0 (non-blocking)
        else if (enable)
            pc <= pc_next;      // cập nhật PC
        // else: giữ nguyên (stall)
    end

endmodule