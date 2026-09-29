
`timescale 1ns / 1ps

module hrot_top (
    input  wire        clk,        // Basys 3 onboard 100MHz clock
    input  wire        btnC,       // Center button - used as reset
    input  wire        sw0,        // Switch 0 - enable PUF measurement
    output wire [15:0] led         // 16 LEDs - display puf_bits
);

    wire puf_valid;
    wire [15:0] puf_bits;

    ro_puf #(
        .NUM_PAIRS(16),
        .COUNTER_WIDTH(16)
    ) ro_puf_inst (
        .clk(clk),
        .rst(btnC),
        .enable(sw0),
        .puf_bits(puf_bits),
        .puf_valid(puf_valid)
    );

    // Only display puf_bits once measurement is valid; show all-zero while measuring
    assign led = puf_valid ? puf_bits : 16'b0;

endmodule