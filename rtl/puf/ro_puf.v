// RO-PUF: 64 pairs (128 ring oscillators). puf_bits[i] = 1 if count(A[i]) > count(B[i]).
// Measurement window = MEAS_CYC system clocks. puf_valid stays high until `enable` is dropped.
`timescale 1ns/1ps
module ro_puf #(parameter MEAS_CYC = 10000, parameter SEED = 1, parameter CW = 20) (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    output reg  [63:0] puf_bits,
    output reg         puf_valid
);
    reg osc_en, gate, clr;
    wire [CW-1:0] cA [0:63];
    wire [CW-1:0] cB [0:63];

    genvar i;
    generate for (i = 0; i < 64; i = i + 1) begin : pairs
        ro_meas #(.ID(i),      .SEED(SEED), .CW(CW)) u_a (.en(osc_en), .gate(gate), .clr(clr), .cnt(cA[i]));
        ro_meas #(.ID(64 + i), .SEED(SEED), .CW(CW)) u_b (.en(osc_en), .gate(gate), .clr(clr), .cnt(cB[i]));
    end endgenerate

    localparam S_IDLE=0, S_CLR=1, S_COUNT=2, S_STOP=3, S_CMP=4, S_HOLD=5;
    reg [2:0]  st;
    reg [31:0] tmr;
    integer k;

    always @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE; osc_en <= 1'b0; gate <= 1'b0; clr <= 1'b1; puf_valid <= 1'b0;
            puf_bits <= 64'd0; tmr <= 32'd0;
        end else case (st)
            S_IDLE: begin
                puf_valid <= 1'b0; osc_en <= 1'b0; gate <= 1'b0; clr <= 1'b1; tmr <= 0;
                if (enable) begin osc_en <= 1'b1; st <= S_CLR; end
            end
            S_CLR: begin                      // oscillators run, counters held cleared
                tmr <= tmr + 1;
                if (tmr == 15) begin clr <= 1'b0; tmr <= 0; st <= S_COUNT; end
            end
            S_COUNT: begin
                gate <= 1'b1; tmr <= tmr + 1;
                if (tmr == MEAS_CYC - 1) begin gate <= 1'b0; tmr <= 0; st <= S_STOP; end
            end
            S_STOP: begin                     // let gate fall through the synchronisers
                tmr <= tmr + 1;
                if (tmr == 15) st <= S_CMP;
            end
            S_CMP: begin
                for (k = 0; k < 64; k = k + 1) puf_bits[k] <= (cA[k] > cB[k]);
                osc_en <= 1'b0; puf_valid <= 1'b1; st <= S_HOLD;
            end
            S_HOLD: if (!enable) begin puf_valid <= 1'b0; st <= S_IDLE; end
        endcase
    end
endmodule
