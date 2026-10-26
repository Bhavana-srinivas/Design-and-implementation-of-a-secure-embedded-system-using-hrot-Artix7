`timescale 1ns/1ps

module ro_puf_tb;

    reg clk;
    reg rst;
    reg enable;
    wire [15:0] puf_bits;
    wire puf_valid;

    ro_puf #(
        .NUM_PAIRS(16),
        .COUNTER_WIDTH(16)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .puf_bits(puf_bits),
        .puf_valid(puf_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("Starting RO-PUF testbench...");
        rst = 1;
        enable = 0;
        #20;
        rst = 0;
        #10;

        enable = 1;
        wait (puf_valid == 1);
        #10;
        $display("PUF bits generated: %b", puf_bits);
        $display("puf_valid: %b", puf_valid);

        enable = 0;
        #20;
        enable = 1;
        wait (puf_valid == 1);
        #10;
        $display("PUF bits (2nd run): %b", puf_bits);

        $finish;
    end

    initial begin
        #500000;
        $display("ERROR: Simulation timeout - puf_valid never asserted");
        $finish;
    end

endmodule