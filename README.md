# HRoT project: structured exactly like the report

rtl/firmware/  = YOUR ORIGINAL files, byte-for-byte unchanged:
  firmware_selector.v, hash_compare.v, sha256_256byte.sv (behavioural, simulation-only SHA-256), firmware_auth_top.sv
rtl/puf/       = Stage 1 written from the report text (your own PUF source files were not available):
  ring_osc.v (5-stage), ro_meas.v (divide-by-8 + gated counter, used inside ro_puf), ro_puf.v (64 pairs, MEAS_CYC, puf_bits/puf_valid),
  puf_vote.v (N=64, M=7, IDLE/PAUSE/MEASURE), puf_crp.v (16-bit LFSR, taps 16/15/13/4, zero seed -> 0001), hamming_compare.v (16 bit, threshold 2),
  puf_auth_top.v (chains vote -> crp -> hamming)
rtl/hrot_system_top.sv = simulation-level integration: firmware_auth_top starts only after PUF authentication passes.
tb/firmware_auth_tb.sv = YOUR ORIGINAL testbench (unchanged).  tb/hrot_system_tb.sv = integrated PUF + firmware demo (4 scenarios).
mem/firmware_A.mem, firmware_B.mem (your files).

## Vivado
Design Sources: rtl/firmware/*, rtl/puf/*, rtl/hrot_system_top.sv
Simulation Sources: tb/hrot_system_tb.sv (top) and tb/firmware_auth_tb.sv, plus mem/*.mem (needed in the sim folder for $readmemh)
Settings > Simulation > Verilog options: define SIM (ring-oscillator behavioural model). Run All.
Expected last line: SIMULATION COMPLETED: ALL CHECKS PASSED

## Tested (Icarus Verilog, -g2012 -DSIM)
firmware_auth_tb: A PASS, B FAIL, A PASS, B FAIL (as in the report)
hrot_system_tb: genuine+A boots | genuine+B firmware rejected | different device (A or B): PUF FAIL, firmware stage never starts

## Notes
- The PUF stage here is verified only against a behavioural oscillator model; the real board behaviour comes from your own PUF design.
- ENROLLED_RESP = a59c is the response of the modelled genuine chip (challenge 3).
- puf_crp: LFSR runs continuously over the 16 output bits (restarting from the seed per bit would give identical bits).
