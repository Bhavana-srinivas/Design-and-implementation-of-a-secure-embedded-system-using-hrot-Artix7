## hrot_top pins - Cmod A7-35T on ALS-SDA-ARTIX7-03
## Cabling this file assumes (pin 1 to pin 1, 1:1 ribbons):
##   CN18 (SW1-8)   -> CN3
##   CN19 (SW9-16)  -> CN4   (unplug the CN11->CN4 button cable first)
##   CN20 (LR1-8)   -> CN12  (already plugged)
##   CN21 (LR9-16)  -> CN7
##   esp_en         -> CN10 pin 1 (T1), single wire to ESP32 EN, plus GND
## Header pin order from the lab package pin chart.

## Clock 12 MHz
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.667} [get_ports clk]

## USB-UART PC -> FPGA (Cmod manual, verify)
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports uart_rx_in]

## Reset: Cmod module button BTN0 (Cmod manual, verify)
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports btnC]

## Switches (inputs only; TS nets also feed the green LEDs)
## DIP1 via CN18 -> CN3 pins 1-8 (pins 1,2 = M3,L3 also on the analog header)
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
## DIP2 via CN19 -> CN4 pins 1-8
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN M1  IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## Red LEDs LR1-8 via CN20 -> CN12 pins 1-8
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
## Red LEDs LR9-16 via CN21 -> CN7 pins 1-8
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN N2 IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN R3 IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN T3 IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## ESP32 EN: CN10 pin 1. External 1k pull-down from EN to GND is REQUIRED (FPGA pin floats before configuration).
set_property -dict { PACKAGE_PIN T1 IOSTANDARD LVCMOS33 } [get_ports esp_en]

## Oscillator rules stay in ro_puf_rules.xdc
