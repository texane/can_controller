--
-- controller interface documentation:
-- 8051 MCU to SJA1000 standalone CAN controller
-- http://www.nxp.com/documents/application_note/AN97076.pdf
-- http://www.e-lab.de/downloads/DOCs/PCA82C200.pdf
-- http://web.mit.edu/6.115/www/document/8051.pdf

--
-- 8051 MCU signals
-- cs: chip select
-- ale: address latch enable. high to address slave register
-- port_0: data to read / write from register, 8 bits interface
-- rx: read enable
-- tx: transmit enable
-- irq_on: data rx tx, errors
-- clkout: out std_logic

--
-- register mapping
-- AN97076.pdf, Appendix (basic mode)

--
-- MCR: mode control register
-- address: 0x00
-- bit<0>: RM_RR, reset mode / request bit
-- bit<1>: RIE, rx interrupt enable
-- bit<2>: TIE, tx interrupt enable
-- bit<3>: EIE, error interrupt enable
-- bit<4>: OIE, overrun interrupt enable

--
-- CMR: command register
-- address: 0x01
-- bit<0>: TR, transmit request
-- bit<1>: AT, abort transmit
-- bit<2>: RRB, release receive buffer

--
-- STR: status register
-- address: 0x02
-- bit<0>: RBS, receive buffer
-- bit<1>: DOS, data overrun
-- bit<2>: TBS, transmit buffer
-- bit<3>: TCS, transmit complete
-- bit<4>: RS, receive status
-- bit<5>: TS, transmit status
-- bit<6>: ES, error status
-- bit<7>: BS, bus status

--
-- IR: interrupt register
-- address: 0x03
-- bit<0>: RI, receive interrupt
-- bit<1>: TI, transmit interrupt
-- bit<2>: EI, error interrupt
-- bit<3>: DOI, data overrun interrupt
-- bit<4>: WUI, wake up interrupt

--
-- bus timing 0 register
-- address: 0x06
-- bit<5:0>: baud rate prescaler
-- bit<7:6>: sync jump width (ie. tsync)

--
-- bus timing 1 register
-- address: 0x07
-- bit<3:0>: time segment 1
-- bit<6:4>: time segment 2
-- bit<7>: triple sampling

--
-- clock divide register
-- address: 0x1f
-- bit<3>: clock off
-- bit<2:0>: clock divider

--
-- controller reset procedure
-- while ((MCR & RM_RR_MASK) == 0x00) MCR |= RM_RR_bit;

--
-- frame transmission procedure

--
-- frame reception procedure
-- AN97076.pdf, p.32
-- a message ready to be transfered to the host
-- controller is signaled by the CMR.RBS flag.
-- the host controller has to transfer the message
-- to its local memory, and release the buffer by
-- setting the CMR.RRB.

--
-- data overrun procedure
-- AN97076.pdf, p.36



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;


entity controller is
port
(
 -- clocking
 clk: in std_logic;
 rst: in std_logic;

 -- transmit registers
 tx_dat: in std_logic_vector(79 downto 0);

 -- receive registers
 rx_dat: out std_logic_vector(79 downto 0);
 rx_irq: out std_logic;

 -- operation control and status
 -- op_en: 1 to start operation
 -- op_code, one in OP_CODE_xxx
 -- op_busy 1 means caller must wait to issue an operation
 -- op_err valid only during the op_done pulse
 op_regs: in work.can_pkg.op_reg_array_t;
 op_en: in std_logic;
 op_code: in std_logic_vector(1 downto 0);
 op_busy: out std_logic;
 op_done: out std_logic;
 op_err: out std_logic;

 -- can signals
 can_rx: in std_logic;
 can_tx: out std_logic;

 -- debugging
 dbg_reg: out std_logic_vector(31 downto 0)
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
signal can_port_o: std_logic_vector(7 downto 0);
signal can_port_i: std_logic_vector(7 downto 0);
signal can_cs: std_logic;
signal can_bus_off_on: std_logic;
signal can_irq_on: std_logic;
signal can_clkout: std_logic;

--
-- controller internal registers

signal status_reg: std_logic_vector(7 downto 0);
signal irq_reg: std_logic_vector(7 downto 0);

--
-- main operation fsm

type state_t is
(
 --
 -- TODO
 -- replace by a minimal 8 bit MCU
 -- instructions:
 -- READ_REG
 -- WRITE_REG
 -- WAIT_UNTIL (irq or status or timer)

 STATE_IDLE,

 --
 -- conf states

 STATE_CONF_0,
 STATE_CONF_1,
 STATE_CONF_2,
 STATE_CONF_3,
 STATE_CONF_4,
 STATE_CONF_5,
 STATE_CONF_6,

 --
 -- transmit states

 STATE_TX_0,
 STATE_TX_1,
 STATE_TX_2,
 STATE_TX_3,
 STATE_TX_4,
 STATE_TX_5,
 STATE_TX_6,
 STATE_TX_7,
 STATE_TX_8,
 STATE_TX_9,
 STATE_TX_10,

 --
 -- IRQ states

 STATE_IRQ_0,
 STATE_IRQ_1,

 --
 -- receive interrupt

 STATE_RI_0,
 STATE_RI_1,
 STATE_RI_2,
 STATE_RI_3,
 STATE_RI_4,
 STATE_RI_5,
 STATE_RI_6,
 STATE_RI_7,
 STATE_RI_8,
 STATE_RI_9,
 STATE_RI_10,

 --
 -- transmit interrupt

 STATE_TI_0,

 --
 -- error interrupt

 STATE_EI_0,

 --
 -- data overrun interrupt

 STATE_DOI_0,

 --
 -- final state

 STATE_END
);

signal curr_state: state_t;
signal next_state: state_t;

alias op_tx: std_logic is op_code(work.can_pkg.OP_CODE_TX_BIT);
alias op_conf: std_logic is op_code(work.can_pkg.OP_CODE_CONF_BIT);

signal rd_bubble: std_logic;
signal rd_bubble1: std_logic;

--
-- generate a 8051 MCU bus cycle

procedure gen_read_cycle
(
 signal can_cs: out std_logic;
 signal can_ale: inout std_logic;
 signal can_rd: out std_logic;
 signal can_wr: out std_logic;
 signal can_port_i: in std_logic_vector(7 downto 0);
 signal can_port_o: out std_logic_vector(7 downto 0);

 signal rd_bubble: inout std_logic;
 signal rd_bubble1: inout std_logic;

 signal op_done: out std_logic;
 signal op_busy: out std_logic;

 constant addr: in std_logic_vector(7 downto 0);
 signal data: out std_logic_vector(7 downto 0)
)
is begin

 data <= can_port_i;

 if rd_bubble = '0' then

  op_done <= '0';
  op_busy <= '1';
  can_cs <= '1';
  can_ale <= not can_ale;
  can_wr <= '0';
  can_rd <= '0';

  if can_ale = '0' then -- addressing phase
   can_port_o <= addr;
  else -- data phase
   can_rd <= '1';
   rd_bubble <= '1';
   rd_bubble1 <= '0';
  end if;

 else
  -- bubble, do nothing

  op_done <= '0';
  op_busy <= '1';
  can_cs <= '1';
  can_ale <= '0';
  can_wr <= '0';
  can_rd <= '1';
  rd_bubble <= '0';
  rd_bubble1 <= not rd_bubble1;
  
 end if;
 
end procedure;


procedure gen_write_cycle
(
 signal can_cs: out std_logic;
 signal can_ale: inout std_logic;
 signal can_rd: out std_logic;
 signal can_wr: out std_logic;
 signal can_port: out std_logic_vector(7 downto 0);

 signal op_done: out std_logic;
 signal op_busy: out std_logic;

 constant addr: in std_logic_vector(7 downto 0);
 signal data: in std_logic_vector(7 downto 0)
)
is begin

 op_done <= '0';
 op_busy <= '1';
 can_cs <= '1';
 can_ale <= not can_ale;
 can_wr <= '0';
 can_rd <= '0';

 if can_ale = '0' then -- addressing phase
  can_port <= addr;
 else -- data phase
  can_wr <= '1';
  can_port <= data;
 end if;
 
end procedure;


procedure gen_write_cycle_const
(
 signal can_cs: out std_logic;
 signal can_ale: inout std_logic;
 signal can_rd: out std_logic;
 signal can_wr: out std_logic;
 signal can_port: out std_logic_vector(7 downto 0);

 signal op_done: out std_logic;
 signal op_busy: out std_logic;

 constant addr: in std_logic_vector(7 downto 0);
 constant data: in std_logic_vector(7 downto 0)
)
is begin

 op_done <= '0';
 op_busy <= '1';
 can_cs <= '1';
 can_ale <= not can_ale;
 can_wr <= '0';
 can_rd <= '0';

 if can_ale = '0' then -- addressing phase
  can_port <= addr;
 else -- data phase
  can_wr <= '1';
  can_port <= data;
 end if;
 
end procedure;


begin

--
-- can_top.v

can_port <=
 can_port_o when ((can_cs and (not can_rd)) = '1') else
 (others => 'Z');

process(can_cs, can_rd, can_port, can_port_i)
begin
-- wait until rising_edge(clk);
 if (can_cs and can_rd) = '1' then
  can_port_i <= can_port;
 else
  can_port_i <= can_port_i;
 end if;
end process;


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


process
begin
 wait until rising_edge(clk);

 if (rst = '1') then
  curr_state <= STATE_IDLE;
 else
  curr_state <= next_state;
 end if;

end process;


process
(
 curr_state,
 op_en, op_conf, op_tx,
 can_ale, can_irq_on,
 rd_bubble1,
 irq_reg
)
begin

 next_state <= curr_state;

 case curr_state is

  when STATE_IDLE =>
   if can_irq_on = '0' then
    next_state <= STATE_IRQ_0;
   elsif op_en = '1' then
    if op_tx = '1' then
     next_state <= STATE_TX_0;
    elsif op_conf = '1' then
     next_state <= STATE_CONF_0;
    end if;
   end if;

  when STATE_CONF_0 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_1;
   end if;

  when STATE_CONF_1 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_2;
   end if;

  when STATE_CONF_2 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_3;
   end if;

  when STATE_CONF_3 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_4;
   end if;

  when STATE_CONF_4 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_5;
   end if;

  when STATE_CONF_5 =>
   if can_ale = '1' then
    next_state <= STATE_CONF_6;
   end if;

  when STATE_CONF_6 =>
   if can_ale = '1' then
    next_state <= STATE_END;
   end if;

  when STATE_TX_0 =>
   if can_ale = '1' then
    next_state <= STATE_TX_1;
   end if;

  when STATE_TX_1 =>
   if can_ale = '1' then
    next_state <= STATE_TX_2;
   end if;

  when STATE_TX_2 =>
   if can_ale = '1' then
    next_state <= STATE_TX_3;
   end if;

  when STATE_TX_3 =>
   if can_ale = '1' then
    next_state <= STATE_TX_4;
   end if;

  when STATE_TX_4 =>
   if can_ale = '1' then
    next_state <= STATE_TX_5;
   end if;

  when STATE_TX_5 =>
   if can_ale = '1' then
    next_state <= STATE_TX_6;
   end if;

  when STATE_TX_6 =>
   if can_ale = '1' then
    next_state <= STATE_TX_7;
   end if;

  when STATE_TX_7 =>
   if can_ale = '1' then
    next_state <= STATE_TX_8;
   end if;

  when STATE_TX_8 =>
   if can_ale = '1' then
    next_state <= STATE_TX_9;
   end if;

  when STATE_TX_9 =>
   if can_ale = '1' then
    next_state <= STATE_TX_10;
   end if;

  when STATE_TX_10 =>
   if can_ale = '1' then
    next_state <= STATE_END;
   end if;

  when STATE_IRQ_0 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_IRQ_1;
   end if;

  when STATE_IRQ_1 =>
   -- determine irq source
   if irq_reg(0) = '1' then
    next_state <= STATE_RI_0;
   elsif irq_reg(1) = '1' then
    next_state <= STATE_TI_0;
   elsif irq_reg(2) = '1' then
    next_state <= STATE_EI_0;
   elsif irq_reg(3) = '1' then
    next_state <= STATE_DOI_0;
   else
    -- TODO: op_err = '1'
    next_state <= STATE_END;
   end if;

  when STATE_RI_0 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_1;
   end if;

  when STATE_RI_1 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_2;
   end if;

  when STATE_RI_2 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_3;
   end if;

  when STATE_RI_3 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_4;
   end if;

  when STATE_RI_4 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_5;
   end if;

  when STATE_RI_5 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_6;
   end if;

  when STATE_RI_6 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_7;
   end if;

  when STATE_RI_7 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_8;
   end if;

  when STATE_RI_8 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_9;
   end if;

  when STATE_RI_9 =>
   if rd_bubble1 = '1' then
    next_state <= STATE_RI_10;
   end if;

  when STATE_RI_10 =>
   if can_ale = '1' then
    next_state <= STATE_END;
   end if;

  when STATE_TI_0 =>
   next_state <= STATE_END;

  when STATE_EI_0 =>
   next_state <= STATE_END;

  when STATE_DOI_0 =>
   next_state <= STATE_END;

  when STATE_END =>
   next_state <= STATE_IDLE;

  when others =>

 end case;

end process;


process
begin
 wait until rising_edge(clk);

 case curr_state is

  when STATE_IDLE =>
   rx_irq <= '0';
   op_done <= '0';
   op_busy <= op_en;
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';
   rd_bubble <= '0';
   rd_bubble1 <= '0';

  when STATE_CONF_0 =>
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"00", x"01" -- MCR.RM_RR
   );

  when STATE_CONF_1 =>
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"1f", x"07"
   );

  when STATE_CONF_2 =>
   -- bus timing register 0
   --
   -- can_clock = clk / ((prescaler + 1) * 2)
   --
   -- if clk = 125MHz and prescaler = 49, can_clock = 1.25MHz
   -- the bit rate is then can_clock / tbit
   -- with tbit = tprop + tsync + tseg1 + tseg2
   --
   -- tprop is fixed to 1 in the can_btl.v
   -- tsync = 3 defined here by sync_jump_width
   -- tseg1 = 3, tseg2 = 3 defined in bus timing register 1
   --
   -- thus, tbit = 10 and fbit = 125Khz

   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"06", x"f1"
   );

  when STATE_CONF_3 =>
   -- accept code
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"04", x"00"
   );

  when STATE_CONF_4 =>
   -- accept mask
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"05", x"ff"
   );

  when STATE_CONF_5 =>
   -- bus timing register 1
   -- tseg1, tseg2 defined here = 3 + 3 = 6
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"07", x"33"
   );

  when STATE_CONF_6 =>
   -- enable all irqs (basic mode)
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"00", x"1e"
   );

  when STATE_TX_0 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0a", tx_dat(7 downto 0)
   );

  when STATE_TX_1 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0b", tx_dat(15 downto 8)
   );

  when STATE_TX_2 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0c", tx_dat(23 downto 16)
   );

  when STATE_TX_3 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0d", tx_dat(31 downto 24)
   );

  when STATE_TX_4 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0e", tx_dat(39 downto 32)
   );

  when STATE_TX_5 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"0f", tx_dat(47 downto 40)
   );

  when STATE_TX_6 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"10", tx_dat(55 downto 48)
   );

  when STATE_TX_7 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"11", tx_dat(63 downto 56)
   );

  when STATE_TX_8 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"12", tx_dat(71 downto 64)
   );

  when STATE_TX_9 =>
   gen_write_cycle
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"13", tx_dat(79 downto 72)
   );

  when STATE_TX_10 =>
   -- transmit (TR and AT set for single shot)
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr, can_port_o,
    op_done, op_busy,
    x"01", x"03"
   );

  when STATE_IRQ_0 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"03", irq_reg
   );

  when STATE_IRQ_1 =>
   op_done <= '0';
   op_busy <= '1';
   can_cs <= '1';
   can_ale <= '0';
   can_rd <= '1';
   can_wr <= '0';

  when STATE_RI_0 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0a", rx_dat(7 downto 0)
   );

  when STATE_RI_1 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0b", rx_dat(15 downto 8)
   );

  when STATE_RI_2 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0c", rx_dat(23 downto 16)
   );

  when STATE_RI_3 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0d", rx_dat(31 downto 24)
   );

  when STATE_RI_4 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0e", rx_dat(39 downto 32)
   );

  when STATE_RI_5 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"0f", rx_dat(47 downto 40)
   );

  when STATE_RI_6 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"10", rx_dat(55 downto 48)
   );

  when STATE_RI_7 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"11", rx_dat(63 downto 56)
   );

  when STATE_RI_8 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"12", rx_dat(71 downto 64)
   );

  when STATE_RI_9 =>
   gen_read_cycle
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_i, can_port_o,
    rd_bubble, rd_bubble1,
    op_done, op_busy,
    x"13", rx_dat(79 downto 72)
   );

  when STATE_RI_10 =>
   -- release buffer, CMR.RRB = 1
   gen_write_cycle_const
   (
    can_cs, can_ale, can_rd, can_wr,
    can_port_o,
    op_done, op_busy,
    x"01", x"04"
   );

   rx_irq <= '1';

  when STATE_TI_0 =>
   op_done <= '1';
   op_busy <= '0';
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';

  when STATE_EI_0 =>
   op_done <= '0';
   op_busy <= '1';
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';

  when STATE_DOI_0 =>
   op_done <= '0';
   op_busy <= '1';
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';

  when STATE_END =>
   rx_irq <= '0';
   op_done <= '1';
   op_busy <= '0';
   can_cs <= '0';
   can_ale <= '0';
   can_rd <= '0';
   can_wr <= '0';

  when others =>

 end case;

end process;


--
-- debugging

dbg_reg(0) <= can_clkout;


end can_controller_rtl; 
