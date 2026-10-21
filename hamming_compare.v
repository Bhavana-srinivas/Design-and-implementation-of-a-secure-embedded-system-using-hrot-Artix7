`timescale 1ns / 1ps
module hamming_compare #(
    parameter WIDTH = 16,
    parameter THRESHOLD = 2
)(
    input  wire              clk,
    input  wire              rst,
    input  wire [WIDTH-1:0]  fresh_response,
    input  wire [WIDTH-1:0]  stored_reference,
    input  wire              valid,
    output reg                authenticated,
    output reg  [4:0]         hamming_distance
);

    wire [WIDTH-1:0] diff;
    integer i;
    reg [4:0] count;

    assign diff = fresh_response ^ stored_reference;

    always @(*) begin
        count = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (diff[i]) count = count + 1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hamming_distance <= 0;
            authenticated    <= 0;
        end else if (valid) begin
            hamming_distance <= count;
            authenticated    <= (count <= THRESHOLD);
        end
    end

endmodule