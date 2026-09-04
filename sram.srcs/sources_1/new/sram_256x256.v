module sram_256x256 #(
    parameter DEPTH = 256,
    parameter WIDTH = 256,
    parameter ARRAY_WIDTH = 32,
    parameter ARRAY_DEPTH = 16,
    parameter WORD_SIZE = 8,
    parameter ADDR_WIDTH = $clog2(DEPTH*WIDTH/WORD_SIZE)
) (
    input CSB,
    input OEB,
    input WEB,
    input [ADDR_WIDTH-1:0] A,
    input [WORD_SIZE-1:0] I,
    output [WORD_SIZE-1:0] O
);
    
    localparam TOTAL_BANKS = ARRAY_WIDTH * ARRAY_DEPTH;
    
    wire [TOTAL_BANKS-1:0] chip_select;
    wire [WORD_SIZE-1:0] out_data [TOTAL_BANKS-1:0];
    
    assign chip_select = 1'b1 << A[ADDR_WIDTH-1:4];
    
    genvar i, j;
    generate
        for(i = 0; i < ARRAY_WIDTH; i = i + 1) begin : row
            for(j = 0; j < ARRAY_DEPTH; j = j +1) begin : col
                localparam idx = (i * ARRAY_DEPTH) + j;
                
                sram_16x4 b1 (
                    .CE(chip_select[idx]),    
                    .OEB(OEB),
                    .CSB(CSB), 
                    .WEB(WEB),
                    .A(A[3:0]),
                    .I(I[7:4]),
                    .O(out_data[idx][7:4])
                );
                
                sram_16x4 b2(
                    .CE(chip_select[idx]),
                    .OEB(OEB),
                    .CSB(CSB),
                    .WEB(WEB),
                    .A(A[3:0]),
                    .I(I[3:0]),
                    .O(out_data[idx][3:0])
                );
            end
        end
    endgenerate
    
    assign O = out_data[A[ADDR_WIDTH-1:4]];

endmodule