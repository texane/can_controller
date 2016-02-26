--
-- main

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


library work;


entity main is end main;


architecture rtl of main is


--
-- configuration constants

constant CLK_FREQ: integer := 50000000;

--
-- local clock and reset

signal rst: std_ulogic;
signal clk: std_ulogic;

--
-- controller signals

signal can_clk: std_logic;
signal tx_dat: std_logic_vector(87 downto 0);
signal rx_dat: std_logic_vector(87 downto 0);
signal rx_irq: std_logic;
signal op_en: std_logic;
signal op_en_latch: std_logic;
signal op_code: std_logic_vector(2 downto 0);
signal op_busy: std_logic;
signal op_done: std_logic;
signal op_err: std_logic;
signal can_rx: std_logic;
signal can_tx: std_logic;


begin


process
begin
 wait until rising_edge(clk);

 if rst = '1' then
  op_en_latch <= '0';
 else
  op_en_latch <= op_en;
 end if;

end process;


tx_dat(7 downto 0) <= x"ea";
tx_dat(15 downto 8) <= x"28";
tx_dat(47 downto 16) <= x"deadbeef";
tx_dat(79 downto 48) <= x"deadbeef";
tx_dat(87 downto 80) <= x"2a";


can_controller: work.can_pkg.controller
generic map
(
 CLK_FREQ => CLK_FREQ
)
port map
(
 clk => clk,
 rst => rst,
 can_clk => can_clk,
 tx_dat => tx_dat,
 rx_dat => rx_dat,
 rx_irq => rx_irq,
 op_en => op_en_latch,
 op_code => op_code,
 op_busy => op_busy,
 op_done => op_done,
 op_err => op_err,
 can_rx => can_rx,
 can_tx => can_tx
);


end rtl;
