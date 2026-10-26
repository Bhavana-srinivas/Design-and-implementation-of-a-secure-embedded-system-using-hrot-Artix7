`timescale 1ns / 1ps
module reject_tb;
    reg clk = 0, rst = 1, enable = 0;
    wire [15:0] puf_bits;
    wire puf_valid;

    localparam [15:0] REF   = 16'b0110011011001101; // enrolled value
    localparam [15:0] REF_2 = 16'b0110011011001110; // 2 bits flipped
    localparam [15:0] REF_3 = 16'b0110011011001010; // 3 bits flipped
    localparam [15:0] REF_6 = 16'b0110011011110010; // 6 bits flipped

    wire auth0, auth2, auth3, auth6;
    wire [4:0] hd0, hd2, hd3, hd6;

    ro_puf #(.NUM_PAIRS(16), .COUNTER_WIDTH(16)) puf (
        .clk(clk), .rst(rst), .enable(enable),
        .puf_bits(puf_bits), .puf_valid(puf_valid));

    hamming_compare #(.WIDTH(16), .THRESHOLD(2)) c0 (.clk(clk), .rst(rst),
        .fresh_response(puf_bits), .stored_reference(REF),   .valid(puf_valid),
        .authenticated(auth0), .hamming_distance(hd0));
    hamming_compare #(.WIDTH(16), .THRESHOLD(2)) c2 (.clk(clk), .rst(rst),
        .fresh_response(puf_bits), .stored_reference(REF_2), .valid(puf_valid),
        .authenticated(auth2), .hamming_distance(hd2));
    hamming_compare #(.WIDTH(16), .THRESHOLD(2)) c3 (.clk(clk), .rst(rst),
        .fresh_response(puf_bits), .stored_reference(REF_3), .valid(puf_valid),
        .authenticated(auth3), .hamming_distance(hd3));
    hamming_compare #(.WIDTH(16), .THRESHOLD(2)) c6 (.clk(clk), .rst(rst),
        .fresh_response(puf_bits), .stored_reference(REF_6), .valid(puf_valid),
        .authenticated(auth6), .hamming_distance(hd6));

    always #5 clk = ~clk;

    initial begin
        #20 rst = 0;
        #10 enable = 1;
        wait (puf_valid == 1);
        #30;
        $display("puf_bits = %b", puf_bits);
        $display("exact : hd=%0d auth=%b (expect 0,1) %s", hd0, auth0, (hd0==0 && auth0==1) ? "PASS" : "FAIL");
        $display("2 flip: hd=%0d auth=%b (expect 2,1) %s", hd2, auth2, (hd2==2 && auth2==1) ? "PASS" : "FAIL");
        $display("3 flip: hd=%0d auth=%b (expect 3,0) %s", hd3, auth3, (hd3==3 && auth3==0) ? "PASS" : "FAIL");
        $display("6 flip: hd=%0d auth=%b (expect 6,0) %s", hd6, auth6, (hd6==6 && auth6==0) ? "PASS" : "FAIL");
        $finish;
    end

    initial begin
        #500000 $display("ERROR: timeout");
        $finish;
    end
endmodule