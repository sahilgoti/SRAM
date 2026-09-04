`timescale 1ns/1ps

module tb_sram_256x256;

    // Parameters matching DUT
    parameter DEPTH      = 256;
    parameter WIDTH      = 256;
    parameter WORD_SIZE  = 8;
    parameter ADDR_WIDTH = $clog2(DEPTH * WIDTH / WORD_SIZE); // 13 bits (8192 words)

    // DUT Inputs (driven as regs in TB)
    reg                  CSB;
    reg                  OEB;
    reg                  WEB;
    reg [ADDR_WIDTH-1:0] A;
    reg [WORD_SIZE-1:0]  I;

    // DUT Output (monitored as wire in TB)
    wire [WORD_SIZE-1:0] O;

    // Testbench Variables
    integer i;
    integer err_count;
    reg [WORD_SIZE-1:0]  expected_data;

    // Instantiate Device Under Test (DUT)
    sram_256x256 #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH),
        .WORD_SIZE(WORD_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .CSB(CSB),
        .OEB(OEB),
        .WEB(WEB),
        .A(A),
        .I(I),
        .O(O)
    );

    // =========================================================================
    // Task: Write a byte into SRAM
    // =========================================================================
    task write_mem(input [ADDR_WIDTH-1:0] addr, input [WORD_SIZE-1:0] data);
    begin
        CSB = 1'b0;  // Select chip (active low)
        WEB = 1'b0;  // Write enable (active low)
        OEB = 1'b1;  // Disable output during write
        A   = addr;
        I   = data;
        #10;
        WEB = 1'b1;  // Deassert write
        #5;
    end
    endtask

    // =========================================================================
    // Task: Read and Verify a byte from SRAM
    // =========================================================================
    task read_and_verify(input [ADDR_WIDTH-1:0] addr, input [WORD_SIZE-1:0] exp_data);
    begin
        CSB = 1'b0;  // Select chip (active low)
        WEB = 1'b1;  // Read mode (write disabled)
        OEB = 1'b0;  // Enable output (active low)
        A   = addr;
        #10;
        
        // Verify output against expected data
        if (O !== exp_data) begin
            $display("[ERROR] Addr: 0x%04h | Expected: 0x%02h | Got: 0x%02h at time %0t", addr, exp_data, O, $time);
            err_count = err_count + 1;
        end else begin
            $display("[PASS]  Addr: 0x%04h | Data Read: 0x%02h at time %0t", addr, O, $time);
        end

        OEB = 1'b1;  // Disable output
        #5;
    end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        // Setup waveform dump
        $dumpfile("sram_256x256_tb.vcd");
        $dumpvars(0, tb_sram_256x256);

        // Initialize signals
        CSB       = 1'b1; // Disabled (active low)
        OEB       = 1'b1; // Disabled (active low)
        WEB       = 1'b1; // Disabled (active low)
        A         = 0;
        I         = 0;
        err_count = 0;

        #20;
        $display("=================================================");
        $display("Starting SRAM 256x256 Testbench Simulation");
        $display("Total Words: %0d | Addr Width: %0d | Word Size: %0d", (DEPTH*WIDTH/WORD_SIZE), ADDR_WIDTH, WORD_SIZE);
        $display("=================================================");

        // ----------------------------------------------------------------
        // TEST 1: Basic Write and Read back on selected addresses
        // ----------------------------------------------------------------
        $display("\n--- TEST 1: Basic Write and Read Back ---");
        write_mem(13'h0000, 8'hA5);
        write_mem(13'h0001, 8'h5A);
        write_mem(13'h000F, 8'h3C);
        write_mem(13'h0010, 8'hC3);
        write_mem(13'h00FF, 8'hFF);
        write_mem(13'h0100, 8'h11);
        write_mem(13'h1FFF, 8'hAA); // Last address (8191)

        read_and_verify(13'h0000, 8'hA5);
        read_and_verify(13'h0001, 8'h5A);
        read_and_verify(13'h000F, 8'h3C);
        read_and_verify(13'h0010, 8'hC3);
        read_and_verify(13'h00FF, 8'hFF);
        read_and_verify(13'h0100, 8'h11);
        read_and_verify(13'h1FFF, 8'hAA);

        #20;

        // ----------------------------------------------------------------
        // TEST 2: Sequential Write & Read for first 32 locations
        // ----------------------------------------------------------------
        $display("\n--- TEST 2: Sequential Write and Read (32 words) ---");
        for (i = 0; i < 32; i = i + 1) begin
            write_mem(i[ADDR_WIDTH-1:0], (i * 7 + 3) & 8'hFF);
        end

        for (i = 0; i < 32; i = i + 1) begin
            expected_data = (i * 7 + 3) & 8'hFF;
            read_and_verify(i[ADDR_WIDTH-1:0], expected_data);
        end

        #20;

        // ----------------------------------------------------------------
        // TEST 3: Overwrite test
        // ----------------------------------------------------------------
        $display("\n--- TEST 3: Overwrite Test ---");
        write_mem(13'h0005, 8'hDE);
        read_and_verify(13'h0005, 8'hDE);
        write_mem(13'h0005, 8'hAD);
        read_and_verify(13'h0005, 8'hAD);

        #20;

        // ----------------------------------------------------------------
        // TEST 4: Chip Select Bar (CSB = 1) Write Inhibit Test
        // ----------------------------------------------------------------
        $display("\n--- TEST 4: CSB Write Inhibit Test (CSB = 1) ---");
        CSB = 1'b1; // Disabled
        WEB = 1'b0; // Write enable active
        OEB = 1'b1;
        A   = 13'h0005;
        I   = 8'h99;   // Attempt writing 0x99 while CSB is disabled
        #10;
        WEB = 1'b1;
        #5;

        // Verify address 0x0005 still has the old value 0xAD, not 0x99
        read_and_verify(13'h0005, 8'hAD);

        #20;

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("\n=================================================");
        if (err_count == 0) begin
            $display("TEST PASSED: All operations verified with 0 errors.");
        end else begin
            $display("TEST FAILED: Completed with %0d error(s).", err_count);
        end
        $display("=================================================\n");

        #50;
        $finish;
    end

endmodule
