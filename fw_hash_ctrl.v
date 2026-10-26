`timescale 1ns / 1ps
// Firmware hash checker.
//
// Protocol on the byte stream (from uart_rx):
//   4 bytes  : firmware length in bytes, big-endian
//   N bytes  : firmware image
// The controller packs the bytes into 64-byte blocks, applies SHA-256 padding
// (0x80, zeros, 64-bit bit-length), runs sha256_core, then compares the digest
// with ref_hash. `done` goes high when finished; `match` is valid when done=1.
//
// `enable` gates everything: while low, the controller and the SHA core are held
// idle/reset. Raise it (e.g. when the PUF has authenticated) to start a check.
// Bytes that arrive while the controller is idle are ignored, so the sender
// should only start after enable is high (e.g. ESP32 held in reset until then).
module fw_hash_ctrl (
    input  wire         clk,
    input  wire         rst,
    input  wire         enable,
    input  wire         rx_valid,
    input  wire [7:0]   rx_data,
    input  wire [255:0] ref_hash,
    output reg          done,
    output reg          match,
    output wire         busy
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_LEN   = 3'd1,
                     S_DATA  = 3'd2,
                     S_FINAL = 3'd3,
                     S_START = 3'd4,
                     S_WAIT  = 3'd5,
                     S_CMP   = 3'd6,
                     S_DONE  = 3'd7;

    reg [2:0]   state;
    reg [31:0]  len;            // firmware length in bytes
    reg [31:0]  rem;            // bytes still to receive
    reg [2:0]   len_cnt;
    reg [5:0]   idx;            // byte position inside the current block
    reg [511:0] blk;
    reg         first_blk, last_blk, need_len;

    wire         core_busy, core_valid;
    wire [255:0] digest;
    wire         core_start = (state == S_START);
    wire         core_rst   = rst | ~enable;

    sha256_core core (
        .clk(clk), .rst(core_rst),
        .start(core_start), .first(first_blk), .block(blk),
        .busy(core_busy), .digest_valid(core_valid), .digest(digest)
    );

    wire [63:0] bit_len = {29'd0, len, 3'b000};

    assign busy = (state != S_IDLE) && (state != S_DONE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            len       <= 32'd0;
            rem       <= 32'd0;
            len_cnt   <= 3'd0;
            idx       <= 6'd0;
            blk       <= 512'd0;
            first_blk <= 1'b1;
            last_blk  <= 1'b0;
            need_len  <= 1'b0;
            done      <= 1'b0;
            match     <= 1'b0;
        end else if (!enable) begin
            state <= S_IDLE;
            done  <= 1'b0;
            match <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    len     <= 32'd0;
                    len_cnt <= 3'd0;
                    state   <= S_LEN;
                end

                // receive the 4-byte big-endian length
                S_LEN: if (rx_valid) begin
                    len <= {len[23:0], rx_data};
                    if (len_cnt == 3'd3) begin
                        rem       <= {len[23:0], rx_data};
                        idx       <= 6'd0;
                        blk       <= 512'd0;
                        first_blk <= 1'b1;
                        last_blk  <= 1'b0;
                        need_len  <= 1'b0;
                        state     <= ({len[23:0], rx_data} == 32'd0) ? S_FINAL : S_DATA;
                    end else begin
                        len_cnt <= len_cnt + 3'd1;
                    end
                end

                // receive firmware bytes into the block buffer
                S_DATA: if (rx_valid) begin
                    blk[511 - 8*idx -: 8] <= rx_data;
                    rem <= rem - 32'd1;
                    if (idx == 6'd63) begin
                        state <= S_START;           // block full, hash it
                    end else begin
                        idx <= idx + 6'd1;
                        if (rem == 32'd1) state <= S_FINAL;   // that was the last byte
                    end
                end

                // append 0x80, and the length if it fits in this block
                S_FINAL: begin
                    blk[511 - 8*idx -: 8] <= 8'h80;
                    if (idx <= 6'd55) begin
                        blk[63:0] <= bit_len;
                        last_blk  <= 1'b1;
                    end else begin
                        need_len <= 1'b1;           // length goes in one more block
                    end
                    state <= S_START;
                end

                // one-cycle start pulse to the core (core_start is state == S_START)
                S_START: begin
                    first_blk <= 1'b0;
                    state     <= S_WAIT;
                end

                S_WAIT: if (core_valid) begin
                    if (last_blk) begin
                        state <= S_CMP;
                    end else if (need_len) begin
                        blk      <= {448'd0, bit_len};
                        last_blk <= 1'b1;
                        need_len <= 1'b0;
                        state    <= S_START;
                    end else begin
                        blk   <= 512'd0;
                        idx   <= 6'd0;
                        state <= (rem == 32'd0) ? S_FINAL : S_DATA;
                    end
                end

                S_CMP: begin
                    match <= (digest == ref_hash);
                    done  <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    // hold result until enable drops
                end
            endcase
        end
    end

endmodule