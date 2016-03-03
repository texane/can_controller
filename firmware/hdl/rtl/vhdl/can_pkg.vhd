library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


package can_pkg is


constant OP_CODE_TX_BIT: integer := 0;
constant OP_CODE_CONF_BIT: integer := 1;
constant OP_CODE_TX: std_logic_vector(1 downto 0) :=
 (OP_CODE_TX_BIT => '1', others => '0');
constant OP_CODE_CONF: std_logic_vector(1 downto 0) :=
 (OP_CODE_CONF_BIT => '1', others => '0');


subtype op_reg_t is std_logic_vector(31 downto 0);
type op_reg_array_t is array(10 downto 0) of op_reg_t;


component controller
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
 op_regs: in op_reg_array_t;
 op_en: in std_logic;
 op_code: in std_logic_vector(1 downto 0);
 op_busy: out std_logic;
 op_done: out std_logic;
 op_err: out std_logic;

 -- can signals
 can_rx: in std_logic;
 can_tx: out std_logic;

 -- debug
 dbg_reg: out std_logic_vector(31 downto 0)
);
end component;

end package can_pkg;
