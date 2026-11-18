// Stage 1: puf_vote (7 x RO-PUF) -> puf_crp (LFSR challenge) -> hamming_compare vs enrolled response.
`timescale 1ns/1ps
module puf_auth_top #(
    parameter MEAS_CYC = 10000, parameter SEED = 1,
    parameter [15:0] CHALLENGE = 16'h0003,
    parameter [15:0] ENROLLED  = 16'h0000,
    parameter integer HD_MAX   = 2
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg         done,
    output reg         pass,
    output wire [63:0] raw_bits,
    output wire [63:0] voted,
    output wire [15:0] response,
    output wire [7:0]  hd
);
    wire puf_en, puf_valid, vote_done;
    ro_puf #(.MEAS_CYC(MEAS_CYC), .SEED(SEED)) u_puf (
        .clk(clk), .rst(rst), .enable(puf_en), .puf_bits(raw_bits), .puf_valid(puf_valid));
    puf_vote u_vote (.clk(clk), .rst(rst), .start(start), .puf_bits(raw_bits), .puf_valid(puf_valid),
                     .puf_en(puf_en), .voted(voted), .done(vote_done));
    puf_crp u_crp (.challenge(CHALLENGE), .voted(voted), .response(response));
    wire h_pass;
    hamming_compare #(.W(16), .THRESH(HD_MAX)) u_ham (.fresh(response), .enrolled(ENROLLED), .hd(hd), .pass(h_pass));

    reg vd;
    always @(posedge clk) begin
        done <= 1'b0; vd <= vote_done;
        if (rst) begin pass <= 1'b0; vd <= 1'b0; end
        else begin
            if (start) pass <= 1'b0;
            if (vd) begin pass <= h_pass; done <= 1'b1; end   // one clock after vote_done, response is settled
        end
    end
endmodule
