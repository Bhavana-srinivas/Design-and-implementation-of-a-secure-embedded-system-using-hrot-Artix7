`timescale 1ns / 1ps
// Ring-oscillator PUF, now with NUM_PAIRS = 64 by default.
// puf_bits[i] = 1 when oscillator A_i counted more edges than B_i in the gate window.
// A measurement starts on a rising edge of `enable` (puf_valid drops, then rises when done).
// puf_valid stays high until enable falls or a new measurement starts.
module ro_puf #(
    parameter NUM_PAIRS     = 64,
    parameter COUNTER_WIDTH = 16,
    parameter MEAS_CYC      = 10000     // gate window in clk cycles (use a small value in simulation)
)(
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  [NUM_PAIRS-1:0] puf_bits,
    output reg  puf_valid
);

    wire [NUM_PAIRS-1:0] osc_a;
    wire [NUM_PAIRS-1:0] osc_b;
    wire [NUM_PAIRS-1:0] a_gt_b;

    reg gate;
    reg clr;
    wire cclr = clr | rst;

    genvar i;
    generate
    for (i = 0; i < NUM_PAIRS; i = i + 1) begin : ro_gen
        // SIM_DELAY mismatch models process variation in simulation only (ignored in synthesis)
        ring_osc #(.STAGES(5), .SIM_DELAY(1.5)) osc_a_inst (
            .enable(enable), .osc_out(osc_a[i]));
        ring_osc #(.STAGES(5),
            .SIM_DELAY(1.5 + 0.008*(((i*i*7 + i*13 + 5)%31)-15) + 0.003)) osc_b_inst (
            .enable(enable), .osc_out(osc_b[i]));

        // divide each oscillator by 8 so the counters can keep up
        reg [2:0] da, db;
        always @(posedge osc_a[i] or posedge cclr)
            if (cclr) da <= 0; else da <= da + 1;
        always @(posedge osc_b[i] or posedge cclr)
            if (cclr) db <= 0; else db <= db + 1;

        reg [COUNTER_WIDTH-1:0] ca, cb;
        always @(posedge da[2] or posedge cclr)
            if (cclr) ca <= 0; else if (gate) ca <= ca + 1;
        always @(posedge db[2] or posedge cclr)
            if (cclr) cb <= 0; else if (gate) cb <= cb + 1;

        assign a_gt_b[i] = (ca > cb);
    end
    endgenerate

    reg [COUNTER_WIDTH-1:0] meas_counter;
    reg measuring, settle, enable_prev;
    wire enable_rising = enable && !enable_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            meas_counter <= 0; measuring <= 0; settle <= 0;
            gate <= 0; clr <= 0; puf_valid <= 0;
            enable_prev <= 0; puf_bits <= 0;
        end else begin
            enable_prev <= enable;

            if (enable_rising && !measuring) begin
                measuring <= 1; meas_counter <= 0;
                clr <= 1; gate <= 0; settle <= 0; puf_valid <= 0;
            end else if (measuring) begin
                if (clr) begin
                    clr <= 0; gate <= 1;
                end else if (meas_counter < MEAS_CYC) begin
                    meas_counter <= meas_counter + 1;
                end else begin
                    gate <= 0; measuring <= 0; settle <= 1;
                end
            end else if (settle) begin
                puf_bits  <= a_gt_b;
                puf_valid <= 1;
                settle    <= 0;
            end else if (!enable) begin
                puf_valid <= 0;
            end
        end
    end
endmodule