`timescale 1ns / 1ps
module ring_osc #(
    parameter STAGES = 5
)(
    input  wire enable,
    output wire osc_out
);
    wire [STAGES-1:0] chain;

`ifdef SIMULATION
    // Artificial delay for simulation only - NOT for synthesis
    assign #1 chain[0] = ~(chain[STAGES-1] & enable);
    genvar k;
    generate
        for (k = 1; k < STAGES; k = k + 1) begin : inv_chain
            assign #1 chain[k] = ~chain[k-1];
        end
    endgenerate
`else
    assign chain[0] = ~(chain[STAGES-1] & enable);
    genvar k;
    generate
        for (k = 1; k < STAGES; k = k + 1) begin : inv_chain
            assign chain[k] = ~chain[k-1];
        end
    endgenerate
`endif

    assign osc_out = chain[STAGES-1];

endmodule