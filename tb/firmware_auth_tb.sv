
`timescale 1ns/1ps

module firmware_auth_tb;

    logic clk = 0;
    logic rst = 1;
    logic start = 0;
    logic firmware_select = 0;

    logic [7:0] mem_A [0:255];
    logic [7:0] mem_B [0:255];

    logic [2047:0] firmware_A, firmware_B;
    logic [255:0] trusted_hash_A;

    wire [255:0] calculated_hash;

    wire done;
    wire auth_valid;
    wire auth_pass;
    wire busy;

    integer i;

    always #5 clk = ~clk;

    // Main Firmware Authentication Module
    firmware_auth_top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .firmware_select(firmware_select),
        .firmware_A(firmware_A),
        .firmware_B(firmware_B),
        .trusted_hash_A(trusted_hash_A),
        .calculated_hash(calculated_hash),
        .done(done),
        .auth_valid(auth_valid),
        .auth_pass(auth_pass),
        .busy(busy)
    );

    // Reference SHA-256 engine for Firmware A enrollment
    logic enroll_start = 0;

    wire [255:0] enroll_digest;
    wire enroll_busy;
    wire enroll_done;

    sha256_256byte enrollment_sha (
        .clk(clk),
        .rst(rst),
        .start(enroll_start),
        .message(firmware_A),
        .digest(enroll_digest),
        .busy(enroll_busy),
        .done(enroll_done)
    );

    // Task to test selected firmware
    task automatic run_selected(
        input logic select_b,
        input integer test_number
    );

        begin

            @(negedge clk);

            firmware_select = select_b;
            start = 1;

            @(negedge clk);

            start = 0;

            wait(done === 1'b1);

            #1;

            $display("");
            $display("==================================================");
            $display("TEST %0d: Firmware %s",
                     test_number, select_b ? "B" : "A");

            $display("Calculated SHA-256: %064h",
                     calculated_hash);

            $display("Trusted SHA-256:    %064h",
                     trusted_hash_A);

            $display("AUTH_VALID: %b", auth_valid);
            $display("AUTH_PASS : %b", auth_pass);
            $display("DONE      : %b", done);

            if ((auth_valid === 1'b1) &&
                (auth_pass === 1'b1)) begin

                $display("RESULT: AUTHENTIC (PASS)");

            end
            else if ((auth_valid === 1'b1) &&
                     (auth_pass === 1'b0)) begin

                $display("RESULT: UNAUTHORISED (FAIL)");

            end
            else begin

                $display("RESULT: INVALID / UNKNOWN AUTHENTICATION");

            end

            $display("==================================================");

            @(negedge clk);

        end

    endtask

    // Main Simulation
    initial begin

        firmware_A = '0;
        firmware_B = '0;
        trusted_hash_A = '0;

        // Load firmware memory files
        $readmemh("firmware_A.mem", mem_A);
        $readmemh("firmware_B.mem", mem_B);

        // Convert memory bytes into 2048-bit firmware vectors
        for (i = 0; i < 256; i = i + 1) begin

            firmware_A[i*8 +: 8] = mem_A[i];
            firmware_B[i*8 +: 8] = mem_B[i];

        end

        // Reset sequence
        repeat (3) @(negedge clk);

        rst = 0;

        // Firmware A Enrollment
        @(negedge clk);

        enroll_start = 1;

        @(negedge clk);

        enroll_start = 0;

        wait(enroll_done === 1'b1);

        // Store Firmware A digest as trusted reference
        trusted_hash_A = enroll_digest;

        #1;

        $display("");
        $display("==================================================");
        $display("FIRMWARE ENROLLMENT COMPLETE");
        $display("Only Firmware A is trusted.");
        $display("Trusted SHA-256(A): %064h", trusted_hash_A);
        $display("==================================================");

        // Test 1: Original Firmware A
        run_selected(1'b0, 1);

        // Test 2: Modified Firmware B
        run_selected(1'b1, 2);

        // Test 3: Original Firmware A again
        run_selected(1'b0, 3);

        // Test 4: Modified Firmware B again
        run_selected(1'b1, 4);

        $display("");
        $display("==================================================");
        $display("SIMULATION COMPLETED");
        $display("==================================================");

        $finish;

    end

endmodule
