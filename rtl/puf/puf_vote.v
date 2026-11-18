// Majority voting: M = 7 PUF measurements, per-bit ones-counters, voted bit = 1 if ones > 3.5 (i.e. >= 4).
// FSM: IDLE -> PAUSE (4 clocks, puf_en low) -> MEASURE (wait puf_valid) -> ... after 7 rounds -> done.
`timescale 1ns/1ps
module puf_vote #(parameter N = 64, parameter M = 7) (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,          // rising edge starts a voting run
    input  wire [N-1:0] puf_bits,
    input  wire         puf_valid,
    output reg          puf_en,
    output reg  [N-1:0] voted,
    output reg          done
);
    localparam IDLE = 2'd0, PAUSE = 2'd1, MEASURE = 2'd2;
    reg [1:0] st;
    reg       start_d;
    reg [2:0] pause_cnt;
    reg [3:0] round;
    reg [2:0] ones [0:N-1];
    integer j;

    always @(posedge clk) begin
        done    <= 1'b0;
        start_d <= start;
        if (rst) begin
            st <= IDLE; puf_en <= 1'b0; voted <= {N{1'b0}}; round <= 4'd0; pause_cnt <= 3'd0;
            for (j = 0; j < N; j = j + 1) ones[j] <= 3'd0;
        end else case (st)
            IDLE: begin
                puf_en <= 1'b0;
                if (start && !start_d) begin
                    for (j = 0; j < N; j = j + 1) ones[j] <= 3'd0;
                    round <= 4'd0; pause_cnt <= 3'd0; st <= PAUSE;
                end
            end
            PAUSE: begin
                puf_en <= 1'b0;
                if (pause_cnt == 3'd3) begin puf_en <= 1'b1; st <= MEASURE; end
                else pause_cnt <= pause_cnt + 3'd1;
            end
            MEASURE: if (puf_valid) begin
                puf_en <= 1'b0;
                for (j = 0; j < N; j = j + 1) if (puf_bits[j]) ones[j] <= ones[j] + 3'd1;
                round <= round + 4'd1;
                if (round == M - 1) st <= 2'd3;   // final accumulate takes effect next cycle
                else begin pause_cnt <= 3'd0; st <= PAUSE; end
            end
            2'd3: begin                            // all 7 rounds accumulated: majority decision
                for (j = 0; j < N; j = j + 1) voted[j] <= (ones[j] >= 3'd4);
                done <= 1'b1; st <= IDLE;
            end
        endcase
    end
endmodule
