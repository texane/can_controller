#!/usr/bin/env sh

vlib work

# vcom -quiet ../rtl/verilog/can_acf.v
# vcom -quiet ../rtl/verilog/can_bsp.v
# vcom -quiet ../rtl/verilog/can_btl.v
# vcom -quiet ../rtl/verilog/can_crc.v
# vcom -quiet ../rtl/verilog/can_defines.v
# vcom -quiet ../rtl/verilog/can_fifo.v
# vcom -quiet ../rtl/verilog/can_ibo.v
# vcom -quiet ../rtl/verilog/can_register_asyn_syn.v
# vcom -quiet ../rtl/verilog/can_register_asyn.v
# vcom -quiet ../rtl/verilog/can_registers.v
# vcom -quiet ../rtl/verilog/can_register_syn.v
# vcom -quiet ../rtl/verilog/can_register.v
# vcom -quiet ../rtl/verilog/can_top.v

vcom -quiet ../rtl/vhdl/can_pkg.vhd
vcom -quiet ../rtl/vhdl/can_controller.vhd
