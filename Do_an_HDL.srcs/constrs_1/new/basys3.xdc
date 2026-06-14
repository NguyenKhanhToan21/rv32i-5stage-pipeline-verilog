## Clock 100MHz (W5)
create_clock -period 10.000 -name clk [get_ports clk] 
#T-pipeline
#create_clock -period 200.000 -name clk [get_ports clk] #T-non_pipeline
set_property PACKAGE_PIN W5  [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
## Reset - nút BTNC (U18)
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

set_property PACKAGE_PIN U14 [get_ports {debug_wb[0]}]
set_property PACKAGE_PIN V14 [get_ports {debug_wb[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_wb[*]}]
set_input_delay -clock clk 0.000 [get_ports rst]

set_output_delay -clock clk 0.000 [get_ports {debug_wb[*]}]