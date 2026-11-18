`timescale 1ns/1ps
// Simulation-level demonstration of the full two-stage workflow.
// Chip 0 = genuine (enrolled) device, chip 1 = a different device. Each is tried with Firmware A and B.
module hrot_system_tb;
    localparam [15:0] ENROLLED_RESP = 16'ha59c;   // response of genuine simulated chip (SEED=1), challenge 3

    logic clk = 0, rst = 1;
    logic [1:0] start = 2'b00;
    logic firmware_select = 0;
    logic [7:0] mem_A [0:255];
    logic [7:0] mem_B [0:255];
    logic [2047:0] firmware_A, firmware_B;
    logic [255:0] trusted_hash_A;
    integer i, errors = 0;
    always #41.667 clk = ~clk;

    // Reference SHA-256 instance to enrol the trusted hash of Firmware A (same method as firmware_auth_tb)
    logic enroll_start = 0;
    wire [255:0] enroll_digest; wire enroll_busy, enroll_done;
    sha256_256byte enrollment_sha (.clk(clk), .rst(rst), .start(enroll_start), .message(firmware_A),
                                   .digest(enroll_digest), .busy(enroll_busy), .done(enroll_done));

    wire        puf_done [0:1], puf_pass [0:1], fw_started [0:1], fw_done [0:1];
    wire        auth_valid [0:1], auth_pass [0:1], boot_allow [0:1], blocked [0:1];
    wire [15:0] puf_response [0:1];
    wire [7:0]  hd [0:1];
    wire [255:0] calculated_hash [0:1];

    genvar g;
    generate for (g = 0; g < 2; g = g + 1) begin : chip
        hrot_system_top #(.MEAS_CYC(128), .SEED(g + 1), .CHALLENGE(16'h0003), .ENROLLED(ENROLLED_RESP), .HD_MAX(2)) dut (
            .clk(clk), .rst(rst), .start(start[g]), .firmware_select(firmware_select),
            .firmware_A(firmware_A), .firmware_B(firmware_B), .trusted_hash_A(trusted_hash_A),
            .puf_done(puf_done[g]), .puf_pass(puf_pass[g]), .puf_response(puf_response[g]), .hd(hd[g]),
            .fw_started(fw_started[g]), .calculated_hash(calculated_hash[g]), .fw_done(fw_done[g]),
            .auth_valid(auth_valid[g]), .auth_pass(auth_pass[g]), .boot_allow(boot_allow[g]), .blocked(blocked[g]));
    end endgenerate

    task automatic scenario(input integer c, input logic sel_b, input logic exp_boot, input logic exp_fw_started, input integer n);
        begin
            @(negedge clk); rst = 1; firmware_select = sel_b;
            repeat (3) @(negedge clk); rst = 0; repeat (3) @(negedge clk);
            start[c] = 1; repeat (3) @(negedge clk); start[c] = 0;
            wait (boot_allow[c] === 1'b1 || blocked[c] === 1'b1);
            repeat (5) @(negedge clk);
            $display("");
            $display("==================================================");
            $display("TEST %0d: %s device, Firmware %s", n, c ? "DIFFERENT" : "GENUINE", sel_b ? "B" : "A");
            $display("PUF response : %h   (enrolled %h)", puf_response[c], ENROLLED_RESP);
            $display("Hamming dist : %0d   (threshold 2)", hd[c]);
            $display("PUF auth     : %s", puf_pass[c] ? "PASS" : "FAIL");
            $display("Firmware stage started : %b", fw_started[c]);
            if (fw_started[c]) begin
                $display("Calculated SHA-256 : %064h", calculated_hash[c]);
                $display("Trusted SHA-256    : %064h", trusted_hash_A);
                $display("Firmware auth: %s", (auth_valid[c] && auth_pass[c]) ? "AUTHENTIC (PASS)" : "UNAUTHORISED (FAIL)");
            end
            $display("FINAL: boot_allow=%b blocked=%b", boot_allow[c], blocked[c]);
            if (boot_allow[c] !== exp_boot || fw_started[c] !== exp_fw_started) begin
                $display("CHECK FAILED"); errors = errors + 1;
            end else $display("CHECK PASSED");
            $display("==================================================");
        end
    endtask

    initial begin
        firmware_A = '0; firmware_B = '0; trusted_hash_A = '0;
        $readmemh("firmware_A.mem", mem_A);
        $readmemh("firmware_B.mem", mem_B);
        for (i = 0; i < 256; i = i + 1) begin firmware_A[i*8 +: 8] = mem_A[i]; firmware_B[i*8 +: 8] = mem_B[i]; end
        repeat (3) @(negedge clk); rst = 0;
        @(negedge clk); enroll_start = 1; @(negedge clk); enroll_start = 0;
        wait (enroll_done === 1'b1);
        trusted_hash_A = enroll_digest; #1;
        $display("FIRMWARE ENROLLMENT COMPLETE. Trusted SHA-256(A): %064h", trusted_hash_A);

        scenario(0, 1'b0, 1'b1, 1'b1, 1);   // genuine device + A  -> boot
        scenario(0, 1'b1, 1'b0, 1'b1, 2);   // genuine device + B  -> firmware rejected
        scenario(1, 1'b0, 1'b0, 1'b0, 3);   // different device + A -> PUF fail, firmware never starts
        scenario(1, 1'b1, 1'b0, 1'b0, 4);   // different device + B -> PUF fail, firmware never starts

        $display("");
        if (errors == 0) $display("SIMULATION COMPLETED: ALL CHECKS PASSED"); else $display("SIMULATION COMPLETED: %0d CHECK(S) FAILED", errors);
        $finish;
    end
endmodule
