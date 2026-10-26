`timescale 1ns / 1ps
// UART receiver, 8N1, LSB first. Samples each bit at its midpoint.
// `valid` pulses for one clock when `data` holds a received byte.
// CLKS_PER_BIT = clock frequency / baud rate (100 MHz / 115200 = 868).
module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]  state;
    reg        rx_s1, rx_s2;      // two-flop synchronizer (rx is asynchronous)
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_s1   <= 1'b1;
            rx_s2   <= 1'b1;
            state   <= IDLE;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            rx_s1 <= rx;
            rx_s2 <= rx_s1;
            valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (!rx_s2) begin       // falling edge: start bit begins
                        state <= START;
                        cnt   <= 16'd0;
                    end
                end

                START: begin                // wait to the middle of the start bit
                    if (cnt == (CLKS_PER_BIT - 1) / 2) begin
                        if (!rx_s2) begin   // still low: genuine start bit
                            cnt     <= 16'd0;
                            bit_idx <= 3'd0;
                            state   <= DATA;
                        end else begin      // glitch, ignore
                            state <= IDLE;
                        end
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                DATA: begin                 // one full bit later = middle of data bit
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        shreg <= {rx_s2, shreg[7:1]};
                        if (bit_idx == 3'd7) state <= STOP;
                        else                 bit_idx <= bit_idx + 3'd1;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                STOP: begin                 // middle of the stop bit
                    if (cnt == CLKS_PER_BIT - 1) begin
                        data  <= shreg;
                        valid <= 1'b1;
                        state <= IDLE;
                        cnt   <= 16'd0;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end

endmodule