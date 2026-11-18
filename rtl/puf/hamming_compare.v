// Hamming distance between fresh and enrolled response; PASS if HD <= THRESH.
`timescale 1ns/1ps
module hamming_compare #(parameter W = 16, parameter THRESH = 2) (
    input  wire [W-1:0] fresh,
    input  wire [W-1:0] enrolled,
    output reg  [7:0]   hd,
    output wire         pass
);
    wire [W-1:0] x = fresh ^ enrolled;
    integer i;
    always @* begin hd = 0; for (i = 0; i < W; i = i + 1) hd = hd + x[i]; end
    assign pass = (hd <= THRESH);
endmodule
