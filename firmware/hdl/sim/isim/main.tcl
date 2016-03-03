# system clock

isim force add {/main/clk} \
 1 -value 0 -radix bin -time 10 ns -repeat 20 ns

isim force add {/main/rst} \
 1 -value 0 -time 2000 ns


#
# configuration operation

isim force add {/main/op_code} \
0 -time 0 ns \
-value 2 -time 4000 ns \
-value 1 -time 5000 ns

isim force add {/main/op_en} \
0 -time 0 ns \
-value 1 -time 4020 ns \
-value 0 -time 4080 ns \
-value 1 -time 5020 ns \
-value 0 -time 5080 ns \
-value 1 -time 305020 ns \
-value 0 -time 305080 ns


#
# signals of interest

wave add /main/clk
wave add /main/rst

wave add /main/can_rx
wave add /main/can_tx

wave add /main/can_controller/op_en
# wave add /main/can_controller/op_code
# wave add /main/can_controller/op_busy
wave add /main/can_controller/op_done

wave add /main/can_controller/can_ale
wave add /main/can_controller/can_cs
wave add /main/can_controller/can_wr
wave add /main/can_controller/can_rd

wave add /main/can_controller/curr_state

# bus cycle related
# wave add /main/can_controller/can_top_v/clk_i
# wave add /main/can_controller/can_top_v/addr_latched
# wave add /main/can_controller/can_top_v/i_can_registers/addr
# wave add /main/can_controller/can_top_v/port_0_io
# wave add /main/can_controller/can_top_v/data_in

# wave add /main/can_controller/can_top_v/i_can_registers/we_mode
wave add /main/can_controller/can_top_v/i_can_registers/command
# wave add /main/can_controller/can_top_v/i_can_registers/mode
# wave add /main/can_controller/can_top_v/i_can_registers/mode_basic
# wave add /main/can_controller/can_top_v/i_can_registers/mode_ext

# irq related
wave add /main/can_controller/can_irq_on
wave add /main/can_controller/can_top_v/i_can_registers/irq_reg
# wave add /main/can_controller/irq_reg
# wave add /main/can_controller/can_top_v/data_out
# wave add /main/can_controller/can_port_i
# wave add /main/can_controller/can_port_o
# wave add /main/can_controller/can_port

wave add /main/can_controller/can_top_v/i_can_registers/status

# data to be transmited
# wave add /main/can_controller/can_top_v/i_can_registers/tx_data_0
# wave add /main/can_controller/can_top_v/i_can_registers/tx_data_1

# error related
# wave add /main/can_controller/can_top_v/i_can_bsp/go_error_frame
# wave add /main/can_controller/can_top_v/i_can_bsp/error_frame
# wave add /main/can_controller/can_top_v/i_can_bsp/go_overload_frame
# wave add /main/can_controller/can_top_v/i_can_bsp/overload_frame

# tx related
# wave add /main/can_controller/can_top_v/i_can_bsp/tx_request
# wave add /main/can_controller/can_top_v/i_can_bsp/sample_point
# wave add /main/can_controller/can_top_v/i_can_bsp/need_to_tx
# wave add /main/can_controller/can_top_v/i_can_bsp/go_early_tx
# wave add /main/can_controller/can_top_v/i_can_bsp/suspend
# wave add /main/can_controller/can_top_v/i_can_bsp/rx_idle
# wave add /main/can_controller/can_top_v/i_can_bsp/go_early_tx
# wave add /main/can_controller/can_top_v/i_can_bsp/go_tx
# wave add /main/can_controller/can_top_v/i_can_bsp/tx_state
# wave add /main/can_controller/can_top_v/i_can_bsp/tx_next
# wave add /main/can_controller/can_top_v/i_can_bsp/tx

# wave add /main/op_en_latch_once
# wave add /main/can_controller2/can_irq_on
# wave add /main/can_controller2/can_top_v/i_can_registers/irq_reg
# wave add /main/can_controller2/can_top_v/i_can_registers/status
# wave add /main/can_controller2/can_top_v/i_can_registers/mode_basic
# wave add /main/can_controller2/can_top_v/i_can_registers/rx_err_cnt
# wave add /main/can_controller2/can_top_v/i_can_bsp/err
# wave add /main/can_controller2/can_top_v/i_can_bsp/form_err
# wave add /main/can_controller2/can_top_v/i_can_bsp/stuff_err
# wave add /main/can_controller2/can_top_v/i_can_bsp/bit_err
# wave add /main/can_controller2/can_top_v/i_can_bsp/ack_err
# wave add /main/can_controller2/can_top_v/i_can_bsp/crc_err
# wave add /main/can_controller2/can_top_v/i_can_bsp/rx_ack
# wave add /main/can_controller2/can_top_v/i_can_bsp/tx

run 1000 us
