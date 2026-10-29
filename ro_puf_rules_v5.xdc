# ro_puf_rules_v5.xdc - ring-oscillator rules ONLY (plain XDC: no if/foreach/puts).
# Oscillator names from the code: ro_gen[i].osc_a_inst / osc_b_inst, net "chain".

# Oscillators are intentional combinational loops (DRC LUTLP-1).
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *chain*}]
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]

# Keep the oscillators so they are not optimized away.
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *osc_a_inst* || NAME =~ *osc_b_inst*}]

# Placement lock: add ro_puf_locs.xdc (made by lock_ro_placement.tcl) before enrollment.
