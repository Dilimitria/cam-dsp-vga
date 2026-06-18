## Generated SDC file "timings.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Tue Jun 16 19:19:51 2026"

##
## DEVICE  "EP4CE115F29C7"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {clk_fpga} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_50}]
create_clock -name {cam_pix_clk} -period 96.000 -waveform { 0.000 48.000 } [get_ports {cam_pix_clk}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {PLL_CAM_inst|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {PLL_CAM_inst|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 12 -divide_by 25 -master_clock {clk_fpga} [get_pins {PLL_CAM_inst|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {PLL_CAM_inst|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {PLL_CAM_inst|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 48 -divide_by 25 -master_clock {clk_fpga} [get_pins {PLL_CAM_inst|altpll_component|auto_generated|pll1|clk[1]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 


#**************************************************************
# Set False Path
#**************************************************************
# set_false_path -from {frame_ready} -to {frame_ready_sync1}
# set_false_path -from {frame_clear} -to {frame_clear_sync1}

#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

