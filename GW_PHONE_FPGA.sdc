create_clock -name i_clk -period 41.667 -waveform {0 20.833} [get_ports {i_clk}] -add
create_clock -name i_tv_pclk -period 16.667 -waveform {0 8.333} [get_ports {i_tv_pclk}] -add
create_clock -name i_sensor_pclk -period 166.667 -waveform {0 83.333} [get_ports {i_sensor_pclk}] -add
create_clock -name sdrc_clk -period 10.000 -waveform {0.625 5.625} [get_pins {sdram_pll_inst/rpll_inst/CLKOUT}] -add
create_clock -name sdram_clk -period 10.000 -waveform {0 5.000} [get_pins {sdram_pll_inst/rpll_inst/CLKOUTP}] -add
create_clock -name usb_user_clk -period 16.667 -waveform {0 8.333}  [get_pins {usb_pll_inst/rpll_inst/CLKOUTD}] -add
create_generated_clock -name usb_fclk -source [get_ports {i_clk}] -master_clock i_clk -divide_by 1 -multiply_by 20 [get_pins {usb_pll_inst/rpll_inst/CLKOUT}]

# create_clock -name 	usb_top_inst/usb2_0_softphy_inst/usb2_0_softphy/u_usb_20_phy_utmi/u_usb2_0_softphy/u_usb_phy_hs/clkdiv_inst/CLKOUT.default_gen_clk -period 7.407 -waveform {0 3.703} [get_pins {usb_top_inst/usb2_0_softphy_inst/usb2_0_softphy/u_usb_20_phy_utmi/u_usb2_0_softphy/u_usb_phy_hs/clkdiv_inst/CLKOUT }] -add
# create_clock -name usb_user_clk -period 13.888 -waveform {0 6.944}  [get_pins {usb_pll_inst/rpll_inst/CLKOUTD}] -add
# create_clock -name clk_display -period 33.334 -waveform {0 16.667}  [get_pins {clkdiv2_ir_30m_inst/clkdiv_inst/CLKOUT }] -add
# create_clock -name sensor_mc   -period 166.667 -waveform {0 83.333}  [get_pins {clkdiv4_ir_mc_inst/clkdiv_inst/CLKOUT }] -add

set_clock_groups -asynchronous -group [get_clocks {i_clk}] -group [get_clocks {sdrc_clk}]
#可见光 数据时钟
set_clock_groups -asynchronous -group [get_clocks {i_tv_pclk}] -group [get_clocks {sdrc_clk}]

set_clock_groups -asynchronous -group [get_clocks {i_sensor_pclk}] -group [get_clocks {sdrc_clk}]

set_clock_groups -asynchronous -group [get_clocks {sdrc_clk}] -group [get_clocks {i_clk}]
set_clock_groups -asynchronous -group [get_clocks {sdrc_clk}] -group [get_clocks {i_tv_pclk}]
set_clock_groups -asynchronous -group [get_clocks {sdrc_clk}] -group [get_clocks {i_sensor_pclk}]
set_clock_groups -asynchronous -group [get_clocks {sdrc_clk}] -group [get_clocks {sdram_clk}]
set_clock_groups -asynchronous -group [get_clocks {sdram_clk}] -group [get_clocks {sdrc_clk}]

# set_clock_groups -asynchronous -group [get_clocks {i_clk}] -group [get_clocks {i_tv_pclk}] -group [get_clocks {i_sensor_pclk}]
# set_clock_groups -asynchronous -group [get_clocks {i_tv_pclk}] -group [get_clocks {i_sensor_pclk}] -group [get_clocks {sdrc_clk sdram_clk}] -group [get_clocks {sensor_mc}] -group [get_clocks {usb_fclk usb_user_clk clk_display}]