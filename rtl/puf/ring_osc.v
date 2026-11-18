// 5-stage ring oscillator: NAND (enable) + 4 inverters => odd inversion count, oscillates when en=1.
// -DSIM : behavioural model, half-period depends on ID and SEED (stands in for manufacturing variation).
`timescale 1ns/1ps
module ring_osc #(parameter ID = 0, parameter SEED = 1) (
    input  wire en,
    output wire out
);
`ifdef SIM
    localparam integer M    = (ID*ID*ID*37 + ID*ID*SEED*101 + ID*SEED*SEED*577 + ID*7919 + SEED*SEED*SEED*977 + SEED*104729) % 1009;
    localparam real    HALF = 1.0 + M * 0.0003;   // ns
    reg q = 1'b0;
    always begin
        wait (en);
        #(HALF);
        if (en) q = ~q;
    end
    always @(negedge en) q = 1'b0;
    assign out = q;
`else
    (* KEEP = "TRUE", DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *) wire [4:0] n;
    assign n[0] = ~(en & n[4]);
    assign n[1] = ~n[0];
    assign n[2] = ~n[1];
    assign n[3] = ~n[2];
    assign n[4] = ~n[3];
    assign out  = n[4];
`endif
endmodule
