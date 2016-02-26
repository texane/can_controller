library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


package can_pkg is


constant OP_CODE_TX_BIT: integer := 0;
constant OP_CODE_RX_BIT: integer := 1;
constant OP_CODE_CONF_BIT: integer := 2;
constant OP_CODE_TX: std_logic_vector(2 downto 0) :=
 (OP_CODE_TX_BIT => '1', others => '0');
constant OP_CODE_RX: std_logic_vector(2 downto 0) :=
 (OP_CODE_RX_BIT => '1', others => '0');
constant OP_CODE_CONF: std_logic_vector(2 downto 0) :=
 (OP_CODE_CONF_BIT => '1', others => '0');


component controller
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
 tx_dat: in std_logic_vector(79 downto 0);

 -- receive registers
 rx_dat: out std_logic_vector(79 downto 0);
 rx_irq: out std_logic;

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
end component;

end package can_pkg;
