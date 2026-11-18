// One oscillator + divide-by-8 + gated event counter (counter lives in the divided-oscillator clock domain).
`timescale 1ns/1ps
module ro_meas #(parameter ID = 0, parameter SEED = 1, parameter CW = 20) (
    input  wire          en,
    input  wire          gate,
    input  wire          clr,
    output reg  [CW-1:0] cnt
);
    wire osc;
    ring_osc #(.ID(ID), .SEED(SEED)) u_ro (.en(en), .out(osc));

    reg [2:0] div = 3'd0;
    always @(posedge osc) div <= div + 3'd1;
    wire dclk = div[2];

    reg [1:0] g = 2'b00, c = 2'b11;
    initial cnt = {CW{1'b0}};
    always @(posedge dclk) begin
        g <= {g[0], gate};
        c <= {c[0], clr};
        if (c[1])      cnt <= {CW{1'b0}};
        else if (g[1]) cnt <= cnt + 1'b1;
    end
endmodule
