`timescale 1ns / 1ps
module ro_puf #(
    parameter NUM_PAIRS = 16,
    parameter COUNTER_WIDTH = 16
)(
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  [NUM_PAIRS-1:0] puf_bits,
    output reg  puf_valid
);

    // Ring oscillator pairs: each pair = 2 oscillators of 5 inverters
    wire [NUM_PAIRS-1:0] osc_a;
    wire [NUM_PAIRS-1:0] osc_b;

    genvar i;
    generate
    for (i = 0; i < NUM_PAIRS; i = i + 1) begin : ro_gen
        ring_osc #(.STAGES(5), .SIM_DELAY(1.0 + (i * 0.07))) osc_a_inst (
            .enable(enable),
            .osc_out(osc_a[i])
        );
        ring_osc #(.STAGES(5), .SIM_DELAY(1.13 + (i * 0.11))) osc_b_inst (
            .enable(enable),
            .osc_out(osc_b[i])
        );
    end
    endgenerate

    // Counters to measure frequency over MEAS_CYC clock cycles
    reg [COUNTER_WIDTH-1:0] count_a [0:NUM_PAIRS-1];
    reg [COUNTER_WIDTH-1:0] count_b [0:NUM_PAIRS-1];
    reg [COUNTER_WIDTH-1:0] meas_counter;
    reg measuring;

    localparam MEAS_CYC = 16'd10000; // tune this on real hardware

    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            meas_counter <= 0;
            measuring <= 0;
            puf_valid <= 0;
            for (j = 0; j < NUM_PAIRS; j = j + 1) begin
                count_a[j] <= 0;
                count_b[j] <= 0;
            end
        end else if (enable && !measuring) begin
            measuring <= 1;
            meas_counter <= 0;
            for (j = 0; j < NUM_PAIRS; j = j + 1) begin
                count_a[j] <= 0;
                count_b[j] <= 0;
            end
            puf_valid <= 0;
        end else if (measuring) begin
            if (meas_counter < MEAS_CYC) begin
                meas_counter <= meas_counter + 1;
                for (j = 0; j < NUM_PAIRS; j = j + 1) begin
                    if (osc_a[j]) count_a[j] <= count_a[j] + 1;
                    if (osc_b[j]) count_b[j] <= count_b[j] + 1;
                end
            end else begin
                measuring <= 0;
                puf_valid <= 1;
                for (j = 0; j < NUM_PAIRS; j = j + 1) begin
                    puf_bits[j] <= (count_a[j] > count_b[j]) ? 1'b1 : 1'b0;
                end
            end
        end
    end

endmodule