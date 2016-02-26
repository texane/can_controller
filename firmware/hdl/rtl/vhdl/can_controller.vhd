--
-- controller interface documentation:
-- 8051 MCU to SJA1000 standalone CAN controller
-- http://www.nxp.com/documents/application_note/AN97076.pdf
-- http://www.e-lab.de/downloads/DOCs/PCA82C200.pdf
-- http://web.mit.edu/6.115/www/document/8051.pdf

--
-- MCR: mode control register
-- address: 0x00
-- bit<0>: RM_RR, reset mode / request bit
-- bit<1>:
-- bit<2>:
-- bit<3>:
-- bit<4>:

--
-- CMR: command register
-- address: 0x01
-- bit<0>: TR, transmit request
-- bit<1>: AT, abort transmit

--
-- controller reset procedure
-- while ((MCR & RM_RR_MASK) == 0x00) MCR |= RM_RR_bit;

--
-- can_top.v expected to interface either as a wishbone or 8051 8 bit slave
-- cs_can: chip select
-- ale: address latch enable. high to address slave register
-- port_0: data to read / write from register, 8 bits interface
-- rx: read enable
-- tx: transmit enable
-- irq_on: data rxtx, errors
-- clkout: out std_logic
--
-- the register mapping is defined in can_registers.v
-- basic_mode:
-- 0x00: we_mode
--  0: reset_mode
--  1: receive_irq_en_basic
--  2: transmit_irq_en_basic
--  3: error_irq_en_basic
--  4: overrun_irq_en_basic
-- 0x01: we_command
--  0 or 4: tx_request
--  1: abort_tx
--  2: release_buffer
--  3: clear_data_overrun
-- 0x02: status
--  0: receive_buffer
--  1: overrun
--  2: transmit_buffer_status
--  3: transmit_complete
--  4: receive_status
--  5: transmit_status
--  6: error_status
--  7: node_bus_off
-- 0x03: read_irq_reg
-- 0x04: we_acceptance_mask_0
-- 0x05: we_acceptance_mask_2
-- 0x06: we_bus_timing_0
--  <5:0>: baud_r_presc
--  <7:6>: sync_jump_width
-- 0x06: we_bus_timing_1
--  <3:0>: time_segment_1
--  <6:4>: time_segment_2
--     7 : triple_sampling
-- 0x0a + i: we_tx_data[i]
-- 0x1f: we_clock_divider_lo
--      3: clock_off
--  <2:0>: clkout_div



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;


entity controller is

generic
(
 CLK_FREQ: integer
);
port
(
 -- clocking
 clk: in std_logic;
 rst: in std_logic;

 -- configuration registers
 -- TODO

 -- transmit registers
 tx_dat: in std_logic_vector(87 downto 0);

 -- receive registers
 rx_dat: out std_logic_vector(87 downto 0);
 rx_irq: in std_logic;

 -- operation control and status
 -- op_en: 1 to start operation
 -- op_code, one in OP_CODE_xxx
 -- op_busy 1 means caller must wait to issue an operation
 -- op_err valid only during the op_done pulse
 op_en: in std_logic;
 op_code: in std_logic_vector(2 downto 0);
 op_busy: out std_logic;
 op_done: out std_logic;
 op_err: out std_logic;

 -- can signals
 can_rx: in std_logic;
 can_tx: out std_logic
);

end entity;


architecture can_controller_rtl of controller is


--
-- can_top.v module

component can_top
port
(
 rst_i: in std_logic;
 ale_i: in std_logic;
 rd_i: in std_logic;
 wr_i: in std_logic;
 port_0_io: inout std_logic_vector(7 downto 0);
 cs_can_i: in std_logic;
 clk_i: in std_logic;
 rx_i: in std_logic;
 tx_o: out std_logic;
 bus_off_on: out std_logic;
 irq_on: out std_logic;
 clkout_o: out std_logic
);
end component;


--
-- can_top.v signals

signal can_ale: std_logic;
signal can_rd: std_logic;
signal can_wr: std_logic;
signal can_port: std_logic_vector(7 downto 0);
signal can_cs: std_logic;
signal can_bus_off_on: std_logic;
signal can_irq_on: std_logic;
signal can_clkout: std_logic;


--
-- main operation fsm

type op_state_t is
(
 OP_IDLE,
 OP_CYCLE_0,
 OP_CYCLE_1,
 OP_CYCLE_2,
 OP_CYCLE_3,
 OP_CYCLE_4,
 OP_CYCLE_5,
 OP_CYCLE_6,
 OP_CYCLE_7,
 OP_CYCLE_8,
 OP_CYCLE_9,
 OP_CYCLE_A,
 OP_CYCLE_B,
 OP_END
);

signal op_curr_state: op_state_t;
signal op_next_state: op_state_t;

alias op_tx: std_logic is op_code(work.can_pkg.OP_CODE_TX_BIT);
alias op_rx: std_logic is op_code(work.can_pkg.OP_CODE_RX_BIT);
alias op_conf: std_logic is op_code(work.can_pkg.OP_CODE_CONF_BIT);

signal op_code_conf: std_logic_vector(2 downto 0);


--
-- generate a cycle

procedure gen_cycle
(
 signal can_cs: out std_logic;
 signal can_ale: inout std_logic;
 signal can_rd: out std_logic;
 signal can_wr: out std_logic;
 signal can_port: inout std_logic_vector(7 downto 0);

 signal op_done: out std_logic;
 signal op_busy: out std_logic;
 signal op_code: in std_logic_vector(2 downto 0);

 constant txrx_addr: in std_logic_vector(7 downto 0);
 signal tx_data: in std_logic_vector(7 downto 0);
 signal rx_data: out std_logic_vector(7 downto 0);

 constant conf_addr: in std_logic_vector(7 downto 0);
 constant conf_data: in std_logic_vector(7 downto 0)
)
is begin

 op_done <= '0';
 op_busy <= '1';
 can_cs <= '1';
 can_ale <= not can_ale;
 can_wr <= '0';
 can_rd <= '0';

 if can_ale = '0' then -- addressing phase

  if op_code(work.can_pkg.OP_CODE_TX_BIT) = '1' then
   can_rd <= '0';
   can_wr <= '1';
   can_port <= txrx_addr;
  elsif op_code(work.can_pkg.OP_CODE_RX_BIT) = '1' then
   can_rd <= '1';
   can_wr <= '0';
   can_port <= txrx_addr;
  else -- if op_conf = '1' then
   can_rd <= '0';
   can_wr <= '1';
   can_port <= conf_addr;
  end if;

 else -- data phase

  if op_code(work.can_pkg.OP_CODE_TX_BIT) = '1' then
   can_rd <= '0';
   can_wr <= '1';
   can_port <= tx_data;
  elsif op_code(work.can_pkg.OP_CODE_RX_BIT) = '1' then
   can_rd <= '1';
   can_wr <= '0';
   rx_data <= can_port;
  else -- if op_conf = '1' then
   can_rd <= '0';
   can_wr <= '1';
   can_port <= conf_data;
  end if;

 end if;
 
end procedure;


begin

--
-- can_top.v

can_top_v: can_top
port map
(
 rst_i => rst,
 ale_i => can_ale,
 rd_i => can_rd,
 wr_i => can_wr,
 port_0_io => can_port,
 cs_can_i => can_cs,
 clk_i => clk,
 rx_i => can_rx,
 tx_o => can_tx,
 bus_off_on => can_bus_off_on,
 irq_on => can_irq_on,
 clkout_o => can_clkout
);


--
-- main operation fsm

process
begin
 wait until rising_edge(clk);

 if (rst = '1') then
  op_curr_state <= OP_IDLE;
 else
  op_curr_state <= op_next_state;
 end if;

end process;


process(op_curr_state, op_en, op_conf, can_ale)
begin

 op_next_state <= op_curr_state;

 case op_curr_state is

  when OP_IDLE =>
   if op_en = '1' then
    op_next_state <= OP_CYCLE_0;
   end if;

  when OP_CYCLE_0 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_1;
   end if;

  when OP_CYCLE_1 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_2;
   end if;

  when OP_CYCLE_2 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_3;
   end if;

  when OP_CYCLE_3 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_4;
   end if;

  when OP_CYCLE_4 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_5;
   end if;

  when OP_CYCLE_5 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_6;
   end if;

  when OP_CYCLE_6 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_7;
   end if;

  when OP_CYCLE_7 =>
   if can_ale = '1' then
    if op_conf = '1' then
     op_next_state <= OP_END;
    else
     op_next_state <= OP_CYCLE_8;
    end if;
   end if;

  when OP_CYCLE_8 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_9;
   end if;

  when OP_CYCLE_9 =>
   if can_ale = '1' then
    op_next_state <= OP_CYCLE_A;
   end if;

  when OP_CYCLE_A =>
   if can_ale = '1' then
    if op_rx = '1' then
     op_next_state <= OP_END;
    else
     op_next_state <= OP_CYCLE_B;
    end if;
   end if;

  when OP_CYCLE_B =>
   if can_ale = '1' then
    op_next_state <= OP_END;
   end if;

  when OP_END =>
   op_next_state <= OP_IDLE;

  when others =>

 end case;

end process;


op_code_conf <= work.can_pkg.OP_CODE_CONF;

process
begin
 wait until rising_edge(clk);

 case op_curr_state is

  when OP_IDLE =>
   op_done <= '0';
   op_busy <= op_en;
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';

  when OP_CYCLE_0 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"10", tx_dat(7 downto 0), rx_dat(7 downto 0),
    x"00", x"01" -- MCR.RM_RR = 1
   );

  when OP_CYCLE_1 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"11", tx_dat(15 downto 8), rx_dat(15 downto 8),
    x"1f", x"07"
   );

  when OP_CYCLE_2 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"12", tx_dat(23 downto 16), rx_dat(23 downto 16),
    x"06", x"01"
   );

  when OP_CYCLE_3 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"13", tx_dat(31 downto 24), rx_dat(31 downto 24),
    x"04", x"00"
   );

  when OP_CYCLE_4 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"14", tx_dat(39 downto 32), rx_dat(39 downto 32),
    x"05", x"00"
   );

  when OP_CYCLE_5 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"15", tx_dat(47 downto 40), rx_dat(47 downto 40),
    x"07", x"7f"
   );

  when OP_CYCLE_6 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"16", tx_dat(55 downto 48), rx_dat(55 downto 48),
    x"00", x"00"
   );

  when OP_CYCLE_7 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"17", tx_dat(63 downto 56), rx_dat(63 downto 56),
    x"00", x"00"
   );

  when OP_CYCLE_8 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"18", tx_dat(71 downto 64), rx_dat(71 downto 64),
    x"00", x"00"
   );

  when OP_CYCLE_9 =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"19", tx_dat(79 downto 72), rx_dat(79 downto 72),
    x"00", x"00"
   );

  when OP_CYCLE_A =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code,
    x"1a", tx_dat(87 downto 80), rx_dat(87 downto 80),
    x"00", x"00"
   );

  when OP_CYCLE_B =>
   gen_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port,
    op_done, op_busy, op_code_conf,
    x"00", tx_dat(87 downto 80), rx_dat(87 downto 80),
    x"01", x"01"
   );

  when OP_END =>
   op_busy <= '0';
   can_cs <= '0';
   can_ale <= '0';
   op_done <= '1';

  when others =>

 end case;

end process;


end can_controller_rtl; 
