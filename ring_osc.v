`timescale 1ns / 1ps
module ring_osc #(
    parameter STAGES = 5,
    parameter real SIM_DELAY = 1.0
)(
    input  wire enable,
    output wire osc_out
);
    (* keep = "true", dont_touch = "true" *) wire [STAGES-1:0] chain;

`ifdef SIMULATION
    assign #SIM_DELAY chain[0] = ~(chain[STAGES-1] & enable);
    genvar k;
    generate
        for (k = 1; k < STAGES; k = k + 1) begin : inv_chain
            assign #SIM_DELAY chain[k] = ~chain[k-1];
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