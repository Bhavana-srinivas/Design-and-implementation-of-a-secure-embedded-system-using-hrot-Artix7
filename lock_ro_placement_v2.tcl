# Run in the Vivado Tcl console with the IMPLEMENTED design open (open_run impl_1).
# Writes two files into the current folder (cd there first):
#   ro_puf_locs.xdc   - LOC/BEL of every oscillator LUT (add this first)
#   ro_puf_routes.xdc - fixed routes of the oscillator nets (add only if locs alone are not enough)
set fh [open "ro_puf_locs.xdc" w]
puts $fh "# generated placement lock for the ring oscillators"
set n 0
foreach c [get_cells -hierarchical -filter {(NAME =~ *osc_a_inst* || NAME =~ *osc_b_inst*) && REF_NAME =~ LUT*}] {
    set loc [get_property LOC $c]
    set bel [lindex [split [get_property BEL $c] "."] end]
    if {$loc eq "" || $bel eq ""} continue
    puts $fh "set_property LOC $loc \[get_cells {$c}\]"
    puts $fh "set_property BEL $bel \[get_cells {$c}\]"
    incr n
}
close $fh
set fr [open "ro_puf_routes.xdc" w]
puts $fr "# generated fixed routes for the ring oscillator nets"
set m 0
foreach net [get_nets -hierarchical -filter {NAME =~ *chain*}] {
    set r [string trim [get_property ROUTE $net]]
    if {$r eq ""} continue
    if {[string index $r 0] ne "\{"} { set r "\{ $r \}" }
    puts $fr "set_property FIXED_ROUTE $r \[get_nets {$net}\]"
    incr m
}
close $fr
puts "wrote $n LUT locks (expect 640) and $m net routes to [pwd]"
