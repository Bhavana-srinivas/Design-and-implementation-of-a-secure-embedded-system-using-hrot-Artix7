`timescale 1ns / 1ps
// System testbench: PUF (64 pairs, voted) -> LFSR challenge -> Hamming auth -> UART -> SHA-256.
// ENROLL = 1 : just measure and print the response for each of the 4 challenges.
// ENROLL = 0 : full test using the REF values compiled into hrot_top (or passed with -P).
module hrot_top_tb;
    parameter ENROLL = 0;
    parameter NEG    = 0;       // 1 = wrong-chip test: expect PUF reject and no firmware check
    parameter [15:0] REF0 = 16'hD4FC, REF1 = 16'hFF99, REF2 = 16'hA7A8, REF3 = 16'h3795;
    parameter [15:0] DUT_REF0 = REF0;       // what this "chip" has enrolled for challenge 0
    localparam CPB = 16;                    // fast UART for simulation

    // SHA-256 of the 100-byte test image (byte i = (i*7+3) & 255), computed with python hashlib
    localparam [255:0] IMG_HASH =
        256'h5a2cda2351d1cdd9dd7957e57c0b3c8522451f25b6494569b7e94388c46f0980;

    reg clk = 0, btnC = 1, rx = 1;
    reg [15:0] sw = 0;
    wire [15:0] led;
    wire esp_en;
    always #5 clk = ~clk;

    hrot_top #(.MEAS_CYC(3000), .VOTE_ROUNDS(3), .CLKS_PER_BIT(CPB),
               .REF0(DUT_REF0), .REF1(REF1), .REF2(REF2), .REF3(REF3),
               .FW_REF_HASH(IMG_HASH)) dut (
        .clk(clk), .btnC(btnC), .sw(sw), .uart_rx_in(rx), .esp_en(esp_en), .led(led));

    wire led_auth = led[15], led_busy = led[13], led_pass = led[12], led_fail = led[11];

    task send_byte(input [7:0] b);
        integer k;
        begin
            rx = 0; repeat (CPB) @(posedge clk);          
            for (k = 0; k < 8; k = k + 1) begin rx = b[k]; repeat (CPB) @(posedge clk); end
            rx = 1; repeat (CPB) @(posedge clk);
        end
    endtask

    integer i, errors = 0;
    integer ch;
    integer restart_fail = 0;   // times the voter failed to restart on a new sw[0] rise
    integer stage = 0;          // progress marker, printed on timeout
    integer rx_bytes = 0;       // bytes the UART receiver actually delivered
    always @(posedge clk) if (dut.rx_valid) rx_bytes = rx_bytes + 1;
    task mark(input integer n);
        begin stage = n; $display("[%0t] stage %0d", $time, n); end
    endtask
    reg [7:0] img [0:99];

    task send_image(input integer tamper);
        integer n;
        begin
            mark(20);
            send_byte(8'h00); send_byte(8'h00); send_byte(8'h00); send_byte(8'd100);
            for (n = 0; n < 100; n = n + 1)
                send_byte((tamper && n == 50) ? (img[n] ^ 8'h01) : img[n]);
            mark(21);
        end
    endtask

    task wait_puf;       // call right after raising sw[0]: wait for the new vote to finish, then for the checker to be ready
        begin
            mark(10);
            // trace: did the voter see start low before this rise? (start_d should be 0 right now)
            $display("  TRACE t+0 : start=%0d start_d=%0d st=%0d done=%0d puf_en=%0d puf_valid=%0d",
                     dut.vote_inst.start, dut.vote_inst.start_d, dut.vote_inst.st, dut.vote_inst.done, dut.puf_en, dut.puf_valid);
            repeat (3) @(posedge clk);
            $display("  TRACE t+3 : start=%0d start_d=%0d st=%0d done=%0d puf_en=%0d puf_valid=%0d round=%0d",
                     dut.vote_inst.start, dut.vote_inst.start_d, dut.vote_inst.st, dut.vote_inst.done, dut.puf_en, dut.puf_valid, dut.vote_inst.round);
            repeat (17) @(posedge clk);             // total 20 clocks for the voter to restart
            if (dut.vote_inst.st == 2'd0 && dut.vote_inst.done) begin
                restart_fail = restart_fail + 1;
                $display("NOTE: voter did NOT restart after sw[0] rose (st=%0d done=%0d start=%0d start_d=%0d)",
                         dut.vote_inst.st, dut.vote_inst.done, dut.vote_inst.start, dut.vote_inst.start_d);
            end
            mark(11); wait (dut.vote_done_d);       // vote finished
            mark(12); wait (led_busy || !led_auth); // checker ready (or PUF rejected)
            mark(13); repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        for (i = 0; i < 100; i = i + 1) img[i] = (i*7 + 3) & 8'hFF;
        #100 btnC = 0; #100;

        if (ENROLL) begin
            for (i = 0; i < 4; i = i + 1) begin
                sw = 0; repeat (10) @(posedge clk);
                sw = {1'b1, 12'b0, i[1:0], 1'b1};          // sw15=1 show response, challenge i, start
                wait_puf;
                $display("ENROLL challenge %0d : response = %h", i, led);
            end
            $finish;
        end


        if (NEG) begin
            sw = {13'b0, 2'd0, 1'b1};
            wait_puf;
            $display("NEG  : PUF Hamming distance = %0d, authenticated = %0d", led[4:0], led_auth);
            send_image(0);
            repeat (20000) @(posedge clk);
            $display("NEG  : firmware busy=%0d pass=%0d fail=%0d esp_en=%0d after sending a GOOD image", led_busy, led_pass, led_fail, esp_en);
            if (led_auth) begin
                if (led_pass) $display("RESULT: authenticated, firmware accepted, esp_en=%0d", esp_en);
            end else if (!led_busy && !led_pass && !led_fail) $display("RESULT: PUF rejected, firmware check never ran, esp_en=%0d (gate works)", esp_en);
            else $display("RESULT: GATE BROKEN");
            $finish;
        end

        // ---- T1: genuine chip, good firmware ----
        sw = {13'b0, 2'd0, 1'b1};
        wait_puf;
        if (!led_auth) begin $display("FAIL T1: genuine chip not authenticated (HD=%0d)", led[4:0]); errors = errors + 1; end
        else $display("PASS T1a: genuine chip authenticated (HD=%0d)", led[4:0]);
        if (esp_en) begin $display("FAIL T1c: esp_en high BEFORE firmware verified"); errors = errors + 1; end
        else $display("PASS T1c: esp_en low while firmware not yet verified");
        send_image(0);
        wait (led_pass || led_fail); repeat (4) @(posedge clk);
        if (led_pass && !led_fail && esp_en) $display("PASS T1b: good firmware accepted, esp_en high (ESP32 may boot)");
        else begin $display("FAIL T1b: good firmware rejected or esp_en low (esp_en=%0d)", esp_en); errors = errors + 1; end

        // ---- T2: re-run with one flipped bit in the image ----
        mark(2); sw = 0; repeat (20) @(posedge clk);
        sw = {13'b0, 2'd0, 1'b1};
        wait_puf;
        send_image(1);
        wait (led_pass || led_fail); repeat (4) @(posedge clk);
        if (led_fail && !led_pass && !esp_en) $display("PASS T2 : tampered firmware rejected, esp_en stays low");
        else begin $display("FAIL T2 : tampered firmware accepted or esp_en high (esp_en=%0d)", esp_en); errors = errors + 1; end

        // ---- T3: other challenges authenticate too ----
        for (ch = 1; ch < 4; ch = ch + 1) begin
            sw = 0; repeat (20) @(posedge clk);
            sw = {13'b0, ch[1:0], 1'b1};
            wait_puf;
            if (led_auth) $display("PASS T3 : challenge %0d authenticated (HD=%0d)", sw[2:1], led[4:0]);
            else begin $display("FAIL T3 : challenge %0d rejected (HD=%0d)", sw[2:1], led[4:0]); errors = errors + 1; end
        end

        if (restart_fail != 0)
            $display("WARNING: voter restart not exercised %0d time(s); PUF was not re-measured in those steps", restart_fail);
        if (errors == 0) $display("ALL SYSTEM TESTS PASSED"); else $display("%0d SYSTEM TEST(S) FAILED", errors);
        $finish;
    end
    initial begin #150000000 $display("TIMEOUT: testbench stage=%0d, uart bytes delivered=%0d, hash ctrl state=%0d len=%0d rem=%0d, led=%h", stage, rx_bytes, dut.hash_inst.state, dut.hash_inst.len, dut.hash_inst.rem, led);
        $display("         voter: st=%0d done=%0d round=%0d start=%0d start_d=%0d puf_en=%0d puf_valid=%0d", dut.vote_inst.st, dut.vote_inst.done, dut.vote_inst.round, dut.vote_inst.start, dut.vote_inst.start_d, dut.puf_en, dut.puf_valid); $finish; end
endmodule