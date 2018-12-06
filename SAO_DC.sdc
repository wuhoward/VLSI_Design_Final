# operating conditions and boundary conditions #
read_file -format verilog SAO.v

set cycle  6         ;#clock period defined by designer

create_clock -period $cycle [get_ports  clk]
set_dont_touch_network      [all_clocks]
set_fix_hold                [all_clocks]
set_clock_uncertainty  0.1  [all_clocks]
set_clock_latency      0.5  [all_clocks]
set_ideal_network           [get_ports clk]

#Don't touch the basic env setting as below
set_input_delay  1     -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 1     -clock clk [all_outputs] 
set_load         1     [all_outputs]
set_drive        1     [all_inputs]

set_operating_conditions -max_library slow -max slow
set_wire_load_model -name tsmc13_wl10 -library slow                        

set_max_fanout 6 [all_inputs]

compile_ultra
write_file -format ddc -hier -output SAO.ddc
write_file -format verilog -hier -output SAO_syn.v
write_sdf -version 2.1 -context verilog SAO_pr.sdf
write_sdc SAO_pr.sdc

report_timing > Timing.txt
report_area > Area.txt
report_power > Power.txt

exit           
