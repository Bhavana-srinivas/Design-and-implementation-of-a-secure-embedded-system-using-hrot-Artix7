`timescale 1ns/1ps
// Simulation-level integration of the two stages (as in the report):
//   Stage 1: RO-PUF -> majority voting -> LFSR challenge-response -> Hamming comparison  (puf_auth_top)
//   Stage 2: firmware selection -> SHA-256 -> trusted hash comparison                    (firmware_auth_top, unchanged)
// Firmware authentication is triggered only after PUF authentication passes.
module hrot_system_top #(
    parameter MEAS_CYC = 10000,
    parameter SEED     = 1,                 // simulation only: which modelled chip this is
    parameter [15:0] CHALLENGE = 16'h0003,
    parameter [15:0] ENROLLED  = 16'h0000,
    parameter integer HD_MAX   = 2
) (
    input  logic          clk,
    input  logic          rst,
    input  logic          start,
    input  logic          firmware_select,
    input  logic [2047:0] firmware_A,
    input  logic [2047:0] firmware_B,
    input  logic [255:0]  trusted_hash_A,

    output logic          puf_done,
    output logic          puf_pass,
    output logic [15:0]   puf_response,
    output logic [7:0]    hd,
    output logic          fw_started,       // 1 if firmware verification was ever triggered
    output logic [255:0]  calculated_hash,
    output logic          fw_done,
    output logic          auth_valid,
    output logic          auth_pass,
    output logic          boot_allow,       // PUF PASS and firmware PASS
    output logic          blocked           // PUF FAIL or firmware FAIL (sticky until reset)
);
    logic [63:0] raw_bits, voted;

    puf_auth_top #(.MEAS_CYC(MEAS_CYC), .SEED(SEED), .CHALLENGE(CHALLENGE),
                   .ENROLLED(ENROLLED), .HD_MAX(HD_MAX)) u_puf (
        .clk(clk), .rst(rst), .start(start), .done(puf_done), .pass(puf_pass),
        .raw_bits(raw_bits), .voted(voted), .response(puf_response), .hd(hd));

    // Gate: firmware stage starts only when the PUF stage finished AND passed.
    wire fw_start = puf_done & puf_pass;
    wire fw_busy;

    firmware_auth_top u_fw (
        .clk(clk), .rst(rst), .start(fw_start), .firmware_select(firmware_select),
        .firmware_A(firmware_A), .firmware_B(firmware_B), .trusted_hash_A(trusted_hash_A),
        .calculated_hash(calculated_hash), .done(fw_done), .auth_valid(auth_valid),
        .auth_pass(auth_pass), .busy(fw_busy));

    always_ff @(posedge clk) begin
        if (rst) begin
            fw_started <= 1'b0; boot_allow <= 1'b0; blocked <= 1'b0;
        end else begin
            if (fw_start) fw_started <= 1'b1;
            if (puf_done && !puf_pass) blocked <= 1'b1;                 // device rejected, firmware never starts
            if (fw_done) begin
                if (auth_valid && auth_pass) boot_allow <= 1'b1;
                else                         blocked    <= 1'b1;        // firmware rejected
            end
        end
    end
endmodule
