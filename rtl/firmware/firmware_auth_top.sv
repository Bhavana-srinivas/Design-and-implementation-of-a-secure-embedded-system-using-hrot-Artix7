`timescale 1ns/1ps

module firmware_auth_top (

    // Clock and reset
    input  logic          clk,
    input  logic          rst,

    // Authentication control
    input  logic          start,
    input  logic          firmware_select,

    // Firmware memory inputs (256 bytes each)
    input  logic [2047:0] firmware_A,
    input  logic [2047:0] firmware_B,

    // Trusted hash enrolled from Firmware A
    input  logic [255:0] trusted_hash_A,

    // Authentication outputs
    output logic [255:0] calculated_hash,
    output logic         done,
    output logic         auth_valid,
    output wire          auth_pass,
    output wire          busy

);

    // Internal signals
    wire [2047:0] selected_firmware;
    wire [255:0] digest;

    wire sha_busy;
    wire sha_done;


    // ------------------------------------------
    // 1. FIRMWARE SELECTION
    // ------------------------------------------

    firmware_selector u_selector (

        .firmware_select  (firmware_select),
        .firmware_A       (firmware_A),
        .firmware_B       (firmware_B),
        .selected_firmware(selected_firmware)

    );


    // ------------------------------------------
    // 2. SHA-256 HASH CALCULATION
    // ------------------------------------------

    sha256_256byte u_sha256 (

        .clk     (clk),
        .rst     (rst),
        .start   (start),

        .message (selected_firmware),

        .digest  (digest),
        .busy    (sha_busy),
        .done    (sha_done)

    );


    // ------------------------------------------
    // 3. FIRMWARE HASH COMPARISON
    // ------------------------------------------

    hash_compare u_compare (

        .auth_valid      (auth_valid),
        .calculated_hash (calculated_hash),
        .trusted_hash    (trusted_hash_A),
        .auth_pass       (auth_pass)

    );


    // ------------------------------------------
    // 4. AUTHENTICATION CONTROL
    // ------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            calculated_hash <= 256'b0;
            done            <= 1'b0;
            auth_valid      <= 1'b0;

        end

        else begin

            // Completion pulse
            done <= sha_done;

            // Invalidate previous result on new request
            if (start) begin
                auth_valid <= 1'b0;
            end

            // Store calculated hash after SHA-256 completion
            if (sha_done) begin

                calculated_hash <= digest;
                auth_valid      <= 1'b1;

            end

        end

    end


    // ------------------------------------------
    // 5. BUSY STATUS
    // ------------------------------------------

    assign busy = sha_busy;


endmodule