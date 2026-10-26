`timescale 1ns / 1ps
// Noise-injection test for puf_vote.
// A fake PUF returns TRUE_BITS with some bits flipped each round. Bit j is flipped in
// round r when ((j + r) % 7) < FLIPS, so every bit flips in exactly FLIPS of 7 rounds.
//   FLIPS = 3 -> every bit is a minority flip -> majority vote must recover TRUE_BITS
//   FLIPS = 4 -> every bit flips in a majority of rounds -> vote is wrong (shows the limit)
module fake_puf #(parameter N = 64, parameter FLIPS = 3) (
    input  wire         clk, rst, enable,
    output reg  [N-1:0] puf_bits,
    output reg          puf_valid
);
    localparam [N-1:0] TRUE_BITS = 64'hA5C3_0F1E_9B47_D2E8;
    reg        prev;
    reg [3:0]  wait_cnt;
    reg        busy;
    integer    r, j;
    reg [N-1:0] noise;
    initial r = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin prev<=0; puf_valid<=0; busy<=0; wait_cnt<=0; puf_bits<=0; end
        else begin
            prev <= enable;
            if (enable && !prev) begin busy<=1; wait_cnt<=0; puf_valid<=0; end
            else if (busy) begin
                if (wait_cnt == 8) begin
                    for (j = 0; j < N; j = j + 1) noise[j] = (((j + r) % 7) < FLIPS);
                    puf_bits  <= TRUE_BITS ^ noise;
                    puf_valid <= 1; busy <= 0; r = r + 1;
                end else wait_cnt <= wait_cnt + 1;
            end else if (!enable) puf_valid <= 0;
        end
    end
endmodule

module puf_vote_tb;
    localparam N = 64;
    localparam [N-1:0] TRUE_BITS = 64'hA5C3_0F1E_9B47_D2E8;
    reg clk = 0, rst = 1, start = 0;
    always #5 clk = ~clk;

    wire [N-1:0] bits3, bits4, v3, v4;
    wire valid3, valid4, en3, en4, done3, done4;

    fake_puf #(.N(N), .FLIPS(3)) p3 (.clk(clk), .rst(rst), .enable(en3), .puf_bits(bits3), .puf_valid(valid3));
    puf_vote #(.N(N), .M(7)) v3i (.clk(clk), .rst(rst), .start(start), .puf_bits(bits3),
                                  .puf_valid(valid3), .en(en3), .voted(v3), .done(done3));
    fake_puf #(.N(N), .FLIPS(4)) p4 (.clk(clk), .rst(rst), .enable(en4), .puf_bits(bits4), .puf_valid(valid4));
    puf_vote #(.N(N), .M(7)) v4i (.clk(clk), .rst(rst), .start(start), .puf_bits(bits4),
                                  .puf_valid(valid4), .en(en4), .voted(v4), .done(done4));

    function integer popcount;
        input [N-1:0] x; integer k;
        begin popcount = 0; for (k = 0; k < N; k = k + 1) popcount = popcount + x[k]; end
    endfunction

    integer errors = 0;
    reg [N-1:0] first_raw;

    initial begin
        #50 rst = 0; #50;
        @(posedge clk); start <= 1; @(posedge clk); start <= 0;
        // capture one raw measurement for comparison
        wait (valid3); first_raw = bits3;
        wait (done3 && done4);
        @(posedge clk);
        $display("Single raw measurement : %0d / 64 bits wrong", popcount(first_raw ^ TRUE_BITS));
        $display("FLIPS=3 voted (M=7)    : %0d / 64 bits wrong", popcount(v3 ^ TRUE_BITS));
        $display("FLIPS=4 voted (M=7)    : %0d / 64 bits wrong (expected: all wrong)", popcount(v4 ^ TRUE_BITS));
        if (v3 !== TRUE_BITS) begin $display("FAIL: vote did not recover true bits"); errors = errors + 1; end
        else $display("PASS: majority vote removed the injected noise");
        if (popcount(v4 ^ TRUE_BITS) != 64) begin $display("FAIL: FLIPS=4 case should be fully wrong"); errors = errors + 1; end
        else $display("PASS: vote fails when noise exceeds M/2 (documented limit)");
        // done must drop when a new vote starts
        @(posedge clk); start <= 1; @(posedge clk); start <= 0; @(posedge clk); @(posedge clk);
        if (done3 !== 1'b0) begin $display("FAIL: done did not drop on restart"); errors = errors + 1; end
        else $display("PASS: done drops on restart");
        if (errors == 0) $display("ALL VOTER TESTS PASSED"); else $display("%0d VOTER TEST(S) FAILED", errors);
        $finish;
    end
    initial begin #200000 $display("TIMEOUT"); $finish; end
endmodule