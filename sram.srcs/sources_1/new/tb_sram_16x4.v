`timescale 1ns/1ps

module tb_sram_16x4;

    // Parameters matching DUT
    parameter DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH); // 4
    parameter DATA_WIDTH = $clog2(DEPTH); // 4

    // DUT Inputs (driven as regs in TB)
    reg                  CE;
    reg                  OEB;
    reg                  CSB;
    reg                  WEB;
    reg [ADDR_WIDTH-1:0] A;
    reg [DATA_WIDTH-1:0] I;

    // DUT Output (monitored as wire in TB)
    wire [DATA_WIDTH-1:0] O;

    // Test tracking
    integer i;
    integer err_count;
    reg [DATA_WIDTH-1:0] expected_data;

    // Instantiate Device Under Test (DUT)
    sram_16x4 #(
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .CE(CE),
        .OEB(OEB),
        .CSB(CSB),
        .WEB(WEB),
        .A(A),
        .I(I),
        .O(O)
    );

    // Task: Write to SRAM
    task write_mem(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        CSB = 1'b0;  // Select chip (active low)
        WEB = 1'b0;  // Write enable (active low)
        OEB = 1'b1;  // Disable output during write
        A   = addr;
        I   = data;
        
        // Pulse CE high to trigger the always block (!CSB & CE)
        CE  = 1'b0;
        #5;
        CE  = 1'b1;
        #10;
        CE  = 1'b0;
        #5;
        
        WEB = 1'b1;  // Deassert write enable
    end
    endtask

    // Task: Read and Verify from SRAM
    task read_and_verify(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] exp_data);
    begin
        CSB = 1'b0;  // Select chip (active low)
        WEB = 1'b1;  // Read mode (Write disabled)
        OEB = 1'b0;  // Output enable (active low)
        A   = addr;
        
        // Pulse CE high to trigger the always block (!CSB & CE)
        CE  = 1'b0;
        #5;
        CE  = 1'b1;
        #10;
        
        // Verify output
        if (O !== exp_data) begin
            $display("[ERROR] Addr: 0x%0h | Expected: 0x%0h | Got: 0x%0h at time %0t", addr, exp_data, O, $time);
            err_count = err_count + 1;
        end else begin
            $display("[PASS]  Addr: 0x%0h | Data Read: 0x%0h at time %0t", addr, O, $time);
        end
        
        CE  = 1'b0;
        OEB = 1'b1;
        #5;
    end
    endtask

    // Main Test Sequence
    initial begin
        // Setup waveform dump
        $dumpfile("sram_16x4_tb.vcd");
        $dumpvars(0, tb_sram_16x4);

        // Initialize signals
        CE        = 1'b0;
        CSB       = 1'b1; // Inactive
        WEB       = 1'b1; // Inactive
        OEB       = 1'b1; // Inactive
        A         = 0;
        I         = 0;
        err_count = 0;

        #20;
        $display("=================================================");
        $display("Starting SRAM 16x4 Testbench Simulation");
        $display("=================================================");

        // ----------------------------------------------------------------
        // TEST 1: Write to all memory locations (Address 0 to 15)
        // ----------------------------------------------------------------
        $display("\n--- TEST 1: Writing data across all 16 addresses ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            // Data pattern: (i * 3 + 1) modulo 16
            write_mem(i[ADDR_WIDTH-1:0], (i * 3 + 1) & 4'hF);
        end

        #20;

        // ----------------------------------------------------------------
        // TEST 2: Read back and verify all memory locations
        // ----------------------------------------------------------------
        $display("\n--- TEST 2: Reading back and verifying all 16 addresses ---");
        for (i = 0; i < DEPTH; i = i + 1) begin
            expected_data = (i * 3 + 1) & 4'hF;
            read_and_verify(i[ADDR_WIDTH-1:0], expected_data);
        end

        #20;

        // ----------------------------------------------------------------
        // TEST 3: Overwrite specific addresses and verify
        // ----------------------------------------------------------------
        $display("\n--- TEST 3: Overwrite address 0x3 and 0xA ---");
        write_mem(4'h3, 4'hA);
        write_mem(4'hA, 4'h5);

        read_and_verify(4'h3, 4'hA);
        read_and_verify(4'hA, 4'h5);

        #20;

        // ----------------------------------------------------------------
        // TEST 4: Chip Disable (CSB = 1) - Write Inhibit Test
        // ----------------------------------------------------------------
        $display("\n--- TEST 4: Chip Select Bar (CSB = 1) Write Inhibit Test ---");
        CSB = 1'b1; // Chip disabled
        WEB = 1'b0; // Write enable active
        OEB = 1'b1;
        A   = 4'h3;
        I   = 4'hF; // Try to write 0xF into addr 0x3
        
        CE = 1'b0; #5;
        CE = 1'b1; #10;
        CE = 1'b0; #5;
        WEB = 1'b1;

        // Verify address 0x3 still holds the old value (0xA), not 0xF
        read_and_verify(4'h3, 4'hA);

        #20;

        // ----------------------------------------------------------------
        // Test Summary
        // ----------------------------------------------------------------
        $display("\n=================================================");
        if (err_count == 0) begin
            $display("TEST PASSED: All tests completed with 0 errors.");
        end else begin
            $display("TEST FAILED: Completed with %0d error(s).", err_count);
        end
        $display("=================================================\n");

        #50;
        $finish;
    end

endmodule
