`timescale 1ns/1ps
module firmware_selector (
    input  wire          firmware_select, // 0 = A, 1 = B
    input  wire [2047:0]  firmware_A,
    input  wire [2047:0]  firmware_B,
    output wire [2047:0]  selected_firmware
);
    assign selected_firmware = firmware_select ? firmware_B : firmware_A;
endmodule
