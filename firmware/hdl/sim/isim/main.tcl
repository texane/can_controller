# system clock

isim force add {/main/clk} \
 1 -value 0 -radix bin -time 10 ns -repeat 20 ns

isim force add {/main/rst} \
 1 -value 0 -time 2000 ns


#
# configuration operation

isim force add {/main/op_code} \
0 -time 0 ns \
-value 4 -time 4000 ns \
-value 1 -time 5000 ns

isim force add {/main/op_en} \
0 -time 0 ns \
-value 1 -time 4020 ns \
-value 0 -time 4080 ns \
-value 1 -time 5020 ns \
-value 0 -time 5080 ns


#
# signals of interest

wave add /main/clk
wave add /main/rst

wave add /main/can_rx
wave add /main/can_tx

wave add /main/can_controller/can_irq_on
wave add /main/can_controller/can_bus_off_on

wave add /main/can_controller/op_en
wave add /main/can_controller/op_busy
wave add /main/can_controller/op_done

wave add /main/can_controller/can_wr
wave add /main/can_controller/can_ale
wave add /main/can_controller/can_cs
wave add /main/can_controller/can_port

wave add /main/can_controller/op_curr_state

wave add /main/can_controller/can_top_v/clk_i
wave add /main/can_controller/can_top_v/addr_latched
wave add /main/can_controller/can_top_v/data_in

wave add /main/can_controller/can_top_v/i_can_registers/we_mode
wave add /main/can_controller/can_top_v/i_can_registers/tx_request
wave add /main/can_controller/can_top_v/i_can_registers/command
wave add /main/can_controller/can_top_v/i_can_registers/mode
wave add /main/can_controller/can_top_v/i_can_registers/mode_basic
wave add /main/can_controller/can_top_v/i_can_registers/mode_ext

run 10 us
