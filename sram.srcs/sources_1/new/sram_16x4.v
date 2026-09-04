`timescale 1ns/1ps

module sram_16x4 #(
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH),
    parameter DATA_WIDTH = $clog2(DEPTH)
)(

    input           CE, // Chip Enable
    input           OEB, // Output Enable Bar
    input           CSB, // Chip Enable Bar
    input           WEB, // Write Enable Bar

    input  [ADDR_WIDTH-1:0]    A,
    input  [DATA_WIDTH-1:0]    I,
    output reg [DATA_WIDTH-1:0]    O
);

    reg [DATA_WIDTH-1:0]mem[DEPTH-1:0];

    always @(!CSB & CE)
        if(!WEB)begin
            mem[A] <= I;
        end else if (!OEB)begin
            O <= mem[A];
        end

endmodule