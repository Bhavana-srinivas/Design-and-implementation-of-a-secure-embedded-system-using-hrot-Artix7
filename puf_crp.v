`timescale 1ns / 1ps
// Challenge -> response selector.
// The 16-bit challenge seeds a maximal-length 16-bit LFSR (taps 16,15,13,4).
// For each response bit k, the LFSR is advanced 6 steps and its low 6 bits pick
// one of the 64 PUF bits (so N must be 64). Output is purely combinational.
// Note: the same index can be drawn twice for one challenge; that is accepted here.
module puf_crp #(
    parameter N = 64,
    parameter R = 16
)(
    input  wire [15:0]  seed,       // the challenge
    input  wire [N-1:0] puf_bits,   // stable (voted) PUF bits
    output reg  [R-1:0] response
);
    integer k, s;
    reg [15:0] l;

    always @(*) begin
        l = (seed == 16'd0) ? 16'h0001 : seed;   // all-zero is the LFSR lock-up state
        for (k = 0; k < R; k = k + 1) begin
            for (s = 0; s < 6; s = s + 1)
                l = {l[14:0], l[15] ^ l[14] ^ l[12] ^ l[3]};
            response[k] = puf_bits[l[5:0]];
        end
    end
endmodule