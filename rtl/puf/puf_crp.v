// LFSR challenge-response: 16-bit LFSR (taps 16,15,13,4), seeded by the challenge (0 -> 16'h0001).
// For each of the 16 response bits the LFSR advances 6 times; the low 6 bits index the 64-bit voted PUF vector.
`timescale 1ns/1ps
module puf_crp (
    input  wire [15:0] challenge,
    input  wire [63:0] voted,
    output reg  [15:0] response
);
    reg [15:0] l;
    integer i, s;
    always @* begin
        l = (challenge == 16'h0000) ? 16'h0001 : challenge;
        for (i = 0; i < 16; i = i + 1) begin
            for (s = 0; s < 6; s = s + 1)
                l = {l[14:0], l[15] ^ l[14] ^ l[12] ^ l[3]};
            response[i] = voted[l[5:0]];
        end
    end
endmodule
