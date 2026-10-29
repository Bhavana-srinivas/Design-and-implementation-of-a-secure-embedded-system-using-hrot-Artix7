`timescale 1ns / 1ps
// Hardware root of trust, Basys 3.
//   Stage 1 (hardware check): 64-pair RO PUF -> majority vote -> LFSR challenge selects
//                              16 bits -> Hamming compare against the enrolled response.
//   Stage 2 (firmware check): only if stage 1 passed, hash the image arriving on UART RX
//                              and compare with FW_REF_HASH.
//
// Switches:  sw[0]    start / enable (set sw[2:1] first, then raise sw[0])
//            sw[2:1]  challenge select (0..3)
//            sw[15]   1 = show the raw 16-bit PUF response on the LEDs (for enrollment/uniqueness)
// LEDs (sw[15]=0):
//            led[15] PUF authenticated   led[14] PUF measurement done
//            led[13] hash checker busy   led[12] FIRMWARE PASS   led[11] FIRMWARE FAIL
//            led[4:0] Hamming distance of the PUF response
//            led[10]  ESP32 boot allowed (same as esp_en)
// Send the firmware over UART only after led[15] is lit.
//
// esp_en (wire to the ESP32 EN/reset pin): LOW at power-up, goes HIGH only when BOTH checks have
// passed (PUF authenticated AND firmware hash matched). It drops again as soon as sw[0] is lowered,
// the PUF is re-measured, or reset is pressed, so the ESP32 is held in reset in every other case.
module hrot_top #(
    // Defaults are for a 12 MHz clock (Cmod A7). For a 100 MHz board (Basys 3) use MEAS_CYC=10000, CLKS_PER_BIT=868.
    parameter MEAS_CYC     = 1200,    // PUF gate window in clk cycles (1200 / 12 MHz = 100 us)
    parameter VOTE_ROUNDS  = 7,       // odd, <= 15
    parameter CLKS_PER_BIT = 104,     // 12 MHz / 115200 baud = 104.2 (0.16 % error)
    parameter THRESHOLD    = 2,

    // Challenge-response table. Seeds are the challenges; REFs are the enrolled responses.
    // The REF values below come from SIMULATION. Re-enroll on your own board (sw[15]=1).
    parameter [15:0] SEED0 = 16'hACE1, SEED1 = 16'h1D2B, SEED2 = 16'h7F31, SEED3 = 16'hB00B,
   parameter [15:0] REF0  = 16'h4EFD, REF1  = 16'h6E34, REF2  = 16'hFE39, REF3  = 16'h7BFB,
    // SHA-256 of the approved firmware image (python3 fw_tools.py hash fw.bin)
    parameter [255:0] FW_REF_HASH =
        256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
)(
    input  wire        clk,
    input  wire        btnC,
    input  wire [15:0] sw,
    input  wire        uart_rx_in,
    output wire        esp_en,      // to ESP32 EN pin (high = allowed to boot)
    output wire [15:0] led
);

    wire rst = btnC;

    // The switches are asynchronous to clk: pass them through a 2-flop synchronizer.
    reg [15:0] sw_s1, sw_q;
    always @(posedge clk or posedge rst)
        if (rst) begin sw_s1 <= 16'd0; sw_q <= 16'd0; end
        else     begin sw_s1 <= sw;    sw_q <= sw_s1; end

    // ---------------- PUF measurement with voting ----------------
    wire [63:0] puf_bits;
    wire        puf_valid, puf_en;
    wire [63:0] voted;
    wire        vote_done;

    ro_puf #(.NUM_PAIRS(64), .COUNTER_WIDTH(16), .MEAS_CYC(MEAS_CYC)) ro_puf_inst (
        .clk(clk), .rst(rst), .enable(puf_en),
        .puf_bits(puf_bits), .puf_valid(puf_valid));

    puf_vote #(.N(64), .M(VOTE_ROUNDS)) vote_inst (
        .clk(clk), .rst(rst), .start(sw_q[0]),
        .puf_bits(puf_bits), .puf_valid(puf_valid),
        .en(puf_en), .voted(voted), .done(vote_done));

    // ---------------- challenge-response ----------------
    wire [1:0] sel = sw_q[2:1];
    wire [15:0] seed = (sel == 2'd0) ? SEED0 : (sel == 2'd1) ? SEED1 :
                       (sel == 2'd2) ? SEED2 : SEED3;
    wire [15:0] ref_resp = (sel == 2'd0) ? REF0 : (sel == 2'd1) ? REF1 :
                           (sel == 2'd2) ? REF2 : REF3;
    wire [15:0] response;

    puf_crp #(.N(64), .R(16)) crp_inst (.seed(seed), .puf_bits(voted), .response(response));

    wire        authenticated;
    wire [4:0]  hamming_distance;

    hamming_compare #(.WIDTH(16), .THRESHOLD(THRESHOLD)) compare_inst (
        .clk(clk), .rst(rst),
        .fresh_response(response), .stored_reference(ref_resp),
        .valid(vote_done),
        .authenticated(authenticated), .hamming_distance(hamming_distance));

    // authenticated is stale for one clock after vote_done rises; wait one clock
    reg vote_done_d;
    always @(posedge clk or posedge rst)
        if (rst) vote_done_d <= 1'b0; else vote_done_d <= vote_done;

    wire puf_ok = vote_done_d & authenticated & sw_q[0];

    // ---------------- firmware check (gated by PUF result) ----------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_inst (
        .clk(clk), .rst(rst), .rx(uart_rx_in), .data(rx_data), .valid(rx_valid));

    wire fw_done, fw_match, fw_busy;

    fw_hash_ctrl hash_inst (
        .clk(clk), .rst(rst), .enable(puf_ok),
        .rx_valid(rx_valid), .rx_data(rx_data), .ref_hash(FW_REF_HASH),
        .done(fw_done), .match(fw_match), .busy(fw_busy));

    // ---------------- boot permission ----------------
    // Registered so the ESP32 EN pin never glitches. High only if BOTH checks passed.
    reg esp_ok;
    always @(posedge clk or posedge rst)
        if (rst) esp_ok <= 1'b0;
        else     esp_ok <= puf_ok & fw_done & fw_match;
    assign esp_en = esp_ok;

    // ---------------- LEDs ----------------
    wire [15:0] status = {puf_ok, vote_done_d, fw_busy, fw_done & fw_match, fw_done & ~fw_match,
                          esp_ok, 5'b0, vote_done_d ? hamming_distance : 5'd0};
    assign led = sw_q[15] ? response : status;

endmodule