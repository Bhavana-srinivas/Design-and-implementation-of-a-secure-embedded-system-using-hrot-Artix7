`timescale 1ns / 1ps
// Bit-bangs a UART stream (4-byte length + firmware bytes) into uart_rx +
// fw_hash_ctrl and checks the match/mismatch result.
// Firmware pattern: byte i = (i*7 + 3) & 0xFF. Reference hashes are SHA-256 of that
// pattern, computed with Python hashlib.
module fw_hash_tb;

    localparam CPB = 16;                    // fast "baud" for simulation

    reg clk = 0, rst = 1, enable = 0, rx = 1;
    reg [255:0] ref_hash = 256'd0;
    wire [7:0] rx_data;
    wire rx_valid, done, match, busy;

    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx (
        .clk(clk), .rst(rst), .rx(rx), .data(rx_data), .valid(rx_valid));

    fw_hash_ctrl dut (
        .clk(clk), .rst(rst), .enable(enable),
        .rx_valid(rx_valid), .rx_data(rx_data),
        .ref_hash(ref_hash), .done(done), .match(match), .busy(busy));

    always #5 clk = ~clk;

    integer errors = 0;

    task send_byte(input [7:0] b);
        integer k;
        begin
            rx = 1'b0;                              // start bit
            repeat (CPB) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin     // data bits, LSB first
                rx = b[k];
                repeat (CPB) @(posedge clk);
            end
            rx = 1'b1;                              // stop bit
            repeat (CPB) @(posedge clk);
        end
    endtask

    // n bytes of firmware; tamper = index of a byte to flip a bit in (-1 = none)
    task run_test(input integer n, input integer tamper,
                  input [255:0] refh, input expect_match, input [8*24-1:0] name);
        integer i;
        reg [7:0] b;
        begin
            enable = 0;                             // drop enable: back to idle, core reset
            repeat (4) @(posedge clk);
            ref_hash = refh;
            enable = 1;
            repeat (4) @(posedge clk);

            send_byte(n >> 24);
            send_byte(n >> 16);
            send_byte(n >> 8);
            send_byte(n);
            for (i = 0; i < n; i = i + 1) begin
                b = (i * 7 + 3) & 8'hFF;
                if (i == tamper) b = b ^ 8'h01;
                send_byte(b);
            end

            wait (done == 1'b1);
            @(posedge clk);
            if (match === expect_match)
                $display("PASS  %0s  (len=%0d, match=%b)", name, n, match);
            else begin
                $display("FAIL  %0s  (len=%0d, match=%b, expected %b)", name, n, match, expect_match);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $display("Starting firmware hash checker testbench...");
        #30 rst = 0;

        run_test(0,   -1, 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855, 1, "empty");
        run_test(3,   -1, 256'h6ab0dba1f4f1dfbb37b4f9eeb092c09fca4900ad32bdcd147d8dde35d6c87c35, 1, "3 bytes");
        run_test(55,  -1, 256'he7313d333c272e639f790978283f9eb392e843d0f29b7016828bb1daa4aac70b, 1, "55 bytes (1 block)");
        run_test(56,  -1, 256'h4324d65f3c103567f5589c710bc08f8523f929a9272e3af36fc968e52abc6c27, 1, "56 bytes (len spills)");
        run_test(63,  -1, 256'h81c80242132f230c3bd41b3e63bbcff16107339549214a99614ff26664625055, 1, "63 bytes");
        run_test(64,  -1, 256'h39e3d7b6b5d075d37d053ad89b24b41bef4f3c29760c84447cab3f3be1882241, 1, "64 bytes (exact block)");
        run_test(100, -1, 256'h5a2cda2351d1cdd9dd7957e57c0b3c8522451f25b6494569b7e94388c46f0980, 1, "100 bytes");
        run_test(130, -1, 256'h4d5e47a2e8510a314576c238f6ff19d389d3ef3aaaca8b2e530263a5d15741da, 1, "130 bytes (3 blocks)");

        // tampered: one bit flipped in byte 50, reference is the ORIGINAL hash -> must reject
        run_test(100, 50, 256'h5a2cda2351d1cdd9dd7957e57c0b3c8522451f25b6494569b7e94388c46f0980, 0, "tampered byte 50");
        // tampered last byte
        run_test(100, 99, 256'h5a2cda2351d1cdd9dd7957e57c0b3c8522451f25b6494569b7e94388c46f0980, 0, "tampered last byte");
        // correct firmware but wrong reference -> must reject
        run_test(100, -1, 256'h4d5e47a2e8510a314576c238f6ff19d389d3ef3aaaca8b2e530263a5d15741da, 0, "wrong reference");
        // the tampered image's own hash -> matches (shows the hash really covers the data)
        run_test(100, 50, 256'hb7aa3746301d0c5bbdd98d0b6d2d09ed01b4a8eeb0c3c3cc03dd7d752d9bb50d, 1, "tampered vs its own hash");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

    initial begin
        #10000000 $display("ERROR: timeout");
        $finish;
    end

endmodule