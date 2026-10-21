`timescale 1ns / 1ps
// Majority-vote wrapper around ro_puf.
// Runs M measurements (M odd, <= 15) and outputs the per-bit majority.
//   start : rising edge begins a new vote (done drops immediately)
//   en    : drive ro_puf.enable with this
//   done  : high when `voted` is valid; stays high until the next start
module puf_vote #(
    parameter N = 64,
    parameter M = 7
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [N-1:0] puf_bits,     // from ro_puf
    input  wire         puf_valid,    // from ro_puf
    output reg          en,           // to ro_puf.enable
    output reg  [N-1:0] voted,
    output reg          done
);

    localparam [1:0] S_IDLE = 2'd0, S_PAUSE = 2'd1, S_MEAS = 2'd2;

    reg [1:0] st;
    reg [3:0] cnt [0:N-1];
    reg [3:0] round;
    reg [2:0] pause;
    reg       start_d;
    integer   i;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            st <= S_IDLE; en <= 1'b0; done <= 1'b0; round <= 4'd0;
            pause <= 3'd0; voted <= {N{1'b0}}; start_d <= 1'b0;
            for (i = 0; i < N; i = i + 1) cnt[i] <= 4'd0;
        end else begin
            start_d <= start;
            case (st)
                S_IDLE: begin
                    en <= 1'b0;
                    if (start & ~start_d) begin   // rising edge, evaluated in-block (no separate wire)
                        done <= 1'b0; round <= 4'd0; pause <= 3'd0; st <= S_PAUSE;
                        for (i = 0; i < N; i = i + 1) cnt[i] <= 4'd0;
                    end
                end

                // hold enable low for 4 clocks so ro_puf sees a clean rising edge
                S_PAUSE: begin
                    en <= 1'b0;
                    if (pause == 3'd4) begin
                        en <= 1'b1; pause <= 3'd0; st <= S_MEAS;
                    end else pause <= pause + 3'd1;
                end

                S_MEAS: if (puf_valid) begin
                    for (i = 0; i < N; i = i + 1)
                        cnt[i] <= cnt[i] + {3'd0, puf_bits[i]};
                    round <= round + 4'd1;
                    if (round == M-1) begin
                        for (i = 0; i < N; i = i + 1)
                            voted[i] <= ((cnt[i] + {3'd0, puf_bits[i]}) > (M/2));
                        done <= 1'b1; en <= 1'b0; st <= S_IDLE;
                    end else begin
                        en <= 1'b0; st <= S_PAUSE;
                    end
                end

                default: st <= S_IDLE;
            endcase
        end
    end
endmodule