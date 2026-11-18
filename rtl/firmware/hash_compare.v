
`timescale 1ns/1ps

module hash_compare (
    input  wire         auth_valid,
    input  wire [255:0] calculated_hash,
    input  wire [255:0] trusted_hash,
    output wire         auth_pass
);

    // Authentication is valid only after hash calculation completes.
    assign auth_pass = auth_valid &&
                       (calculated_hash == trusted_hash);

endmodule
