`timescale 1ns / 1ps
module sha256_tb;

    reg clk = 0, rst = 1, start = 0, first = 0;
    reg [511:0] block = 0;
    wire busy, digest_valid;
    wire [255:0] digest;

    sha256_core dut (.clk(clk), .rst(rst), .start(start), .first(first),
                     .block(block), .busy(busy), .digest_valid(digest_valid),
                     .digest(digest));

    always #5 clk = ~clk;

    integer errors = 0;

    task send_block(input [511:0] b, input is_first);
        begin
            @(posedge clk);
            block <= b; first <= is_first; start <= 1;
            @(posedge clk);
            start <= 0;
            wait (digest_valid == 1);
            @(posedge clk);
        end
    endtask

    task check(input [255:0] expected, input [255:0] got);
        begin
            if (got === expected) $display("PASS  %h", got);
            else begin
                $display("FAIL  got      %h", got);
                $display("      expected %h", expected);
                errors = errors + 1;
            end
        end
    endtask

    // Vector 1: "abc" (one padded block)
    localparam [511:0] ABC_BLK = {32'h61626380, 416'd0, 64'h0000000000000018};
    localparam [255:0] ABC_DIG =
        256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

    // Vector 2: empty string (one padded block)
    localparam [511:0] EMPTY_BLK = {32'h80000000, 480'd0};
    localparam [255:0] EMPTY_DIG =
        256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;

    // Vector 3: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" (56 bytes -> two blocks)
    localparam [511:0] TWO_BLK1 = {
        32'h61626364, 32'h62636465, 32'h63646566, 32'h64656667,
        32'h65666768, 32'h66676869, 32'h6768696a, 32'h68696a6b,
        32'h696a6b6c, 32'h6a6b6c6d, 32'h6b6c6d6e, 32'h6c6d6e6f,
        32'h6d6e6f70, 32'h6e6f7071, 32'h80000000, 32'h00000000 };
    localparam [511:0] TWO_BLK2 = {480'd0, 32'h000001c0};
    localparam [255:0] TWO_DIG =
        256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;

    initial begin
        $display("Starting SHA-256 testbench...");
        #20 rst = 0;
        #10;

        send_block(ABC_BLK, 1);
        check(ABC_DIG, digest);

        send_block(EMPTY_BLK, 1);
        check(EMPTY_DIG, digest);

        send_block(TWO_BLK1, 1);
        send_block(TWO_BLK2, 0);
        check(TWO_DIG, digest);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

    initial begin
        #200000 $display("ERROR: timeout");
        $finish;
    end

endmodule