`timescale 1ns/1ps
// Simulation-oriented SHA-256 engine for exactly 256-byte firmware images.
// This is a behavioral reference model for Vivado XSim, not synthesizable RTL.
module sha256_256byte (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [2047:0] message,
    output logic [255:0] digest,
    output logic         busy,
    output logic         done
);
    function automatic logic [31:0] rotr(input logic [31:0] x, input integer n);
        rotr = (x >> n) | (x << (32-n));
    endfunction

    task automatic calculate_sha256(
        input  logic [2047:0] msg,
        output logic [255:0] result
    );
        logic [31:0] K [0:63];
        logic [31:0] H [0:7];
        logic [31:0] W [0:63];
        logic [31:0] a,b,c,d,e,f,g,h;
        logic [31:0] t1,t2,s0,s1,ch,maj;
        logic [7:0]  block_byte;
        integer i, j, block_no, byte_index;

        begin
            K[ 0]=32'h428a2f98; K[ 1]=32'h71374491; K[ 2]=32'hb5c0fbcf; K[ 3]=32'he9b5dba5;
            K[ 4]=32'h3956c25b; K[ 5]=32'h59f111f1; K[ 6]=32'h923f82a4; K[ 7]=32'hab1c5ed5;
            K[ 8]=32'hd807aa98; K[ 9]=32'h12835b01; K[10]=32'h243185be; K[11]=32'h550c7dc3;
            K[12]=32'h72be5d74; K[13]=32'h80deb1fe; K[14]=32'h9bdc06a7; K[15]=32'hc19bf174;
            K[16]=32'he49b69c1; K[17]=32'hefbe4786; K[18]=32'h0fc19dc6; K[19]=32'h240ca1cc;
            K[20]=32'h2de92c6f; K[21]=32'h4a7484aa; K[22]=32'h5cb0a9dc; K[23]=32'h76f988da;
            K[24]=32'h983e5152; K[25]=32'ha831c66d; K[26]=32'hb00327c8; K[27]=32'hbf597fc7;
            K[28]=32'hc6e00bf3; K[29]=32'hd5a79147; K[30]=32'h06ca6351; K[31]=32'h14292967;
            K[32]=32'h27b70a85; K[33]=32'h2e1b2138; K[34]=32'h4d2c6dfc; K[35]=32'h53380d13;
            K[36]=32'h650a7354; K[37]=32'h766a0abb; K[38]=32'h81c2c92e; K[39]=32'h92722c85;
            K[40]=32'ha2bfe8a1; K[41]=32'ha81a664b; K[42]=32'hc24b8b70; K[43]=32'hc76c51a3;
            K[44]=32'hd192e819; K[45]=32'hd6990624; K[46]=32'hf40e3585; K[47]=32'h106aa070;
            K[48]=32'h19a4c116; K[49]=32'h1e376c08; K[50]=32'h2748774c; K[51]=32'h34b0bcb5;
            K[52]=32'h391c0cb3; K[53]=32'h4ed8aa4a; K[54]=32'h5b9cca4f; K[55]=32'h682e6ff3;
            K[56]=32'h748f82ee; K[57]=32'h78a5636f; K[58]=32'h84c87814; K[59]=32'h8cc70208;
            K[60]=32'h90befffa; K[61]=32'ha4506ceb; K[62]=32'hbef9a3f7; K[63]=32'hc67178f2;

            H[0]=32'h6a09e667; H[1]=32'hbb67ae85; H[2]=32'h3c6ef372; H[3]=32'ha54ff53a;
            H[4]=32'h510e527f; H[5]=32'h9b05688c; H[6]=32'h1f83d9ab; H[7]=32'h5be0cd19;

            // 256 bytes = four data blocks plus one padding/length block.
            for (block_no=0; block_no<5; block_no=block_no+1) begin
                for (i=0; i<16; i=i+1) begin
                    W[i]=32'b0;
                    for (j=0; j<4; j=j+1) begin
                        byte_index = block_no*64 + i*4 + j;
                        if (byte_index < 256)
                            block_byte = msg[byte_index*8 +: 8];
                        else if (byte_index == 256)
                            block_byte = 8'h80;
                        else if (byte_index >= 312 && byte_index < 320)
                            block_byte = 8'h00; // length bytes are inserted below
                        else
                            block_byte = 8'h00;
                        W[i] = {W[i][23:0], block_byte};
                    end
                end

                // The 64-bit message length (256*8 = 2048 bits) is at bytes 312..319.
                if (block_no == 4) begin
                    W[14] = 32'h00000000;
                    W[15] = 32'h00000800;
                end

                for (i=16; i<64; i=i+1) begin
                    s0 = rotr(W[i-15],7) ^ rotr(W[i-15],18) ^ (W[i-15] >> 3);
                    s1 = rotr(W[i-2],17) ^ rotr(W[i-2],19) ^ (W[i-2] >> 10);
                    W[i] = W[i-16] + s0 + W[i-7] + s1;
                end

                a=H[0]; b=H[1]; c=H[2]; d=H[3];
                e=H[4]; f=H[5]; g=H[6]; h=H[7];

                for (i=0; i<64; i=i+1) begin
                    s1 = rotr(e,6) ^ rotr(e,11) ^ rotr(e,25);
                    ch = (e & f) ^ ((~e) & g);
                    t1 = h + s1 + ch + K[i] + W[i];
                    s0 = rotr(a,2) ^ rotr(a,13) ^ rotr(a,22);
                    maj = (a & b) ^ (a & c) ^ (b & c);
                    t2 = s0 + maj;
                    h=g; g=f; f=e; e=d+t1;
                    d=c; c=b; b=a; a=t1+t2;
                end

                H[0]=H[0]+a; H[1]=H[1]+b; H[2]=H[2]+c; H[3]=H[3]+d;
                H[4]=H[4]+e; H[5]=H[5]+f; H[6]=H[6]+g; H[7]=H[7]+h;
            end

            result = {H[0],H[1],H[2],H[3],H[4],H[5],H[6],H[7]};
        end
    endtask

    logic [255:0] digest_temp;
    always_ff @(posedge clk) begin
        if (rst) begin
            digest <= 256'b0;
            busy   <= 1'b0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                calculate_sha256(message, digest_temp);
                digest <= digest_temp;
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end
endmodule
