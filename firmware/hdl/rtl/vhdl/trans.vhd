

architecture beh_can_controller of can_controller is
type type_main_state is (IDLE,
                                 CONFIGURE,
                                 TRANSMIT,
                                 RECEIVE);

type type_config_state is (RESET_MODE_ON,
                                    ACTIVE_BASIC_CONFIG,
                                    SET_BAUD_SYNC,
                                    SET_ACCEPTANCE_MASK,
                                    SET_ACCEPTANCE_MASK2,
                                    SET_BUS_TIMING,
                                    RESET_MODE_OFF);

type type_reg_read_state is ( RD_SET_CS,
                                  RD_SET_REG_ADR,
                                  RD_GET_reg_data_buffer);

type type_can_read_state is ( FRAME_INFORMATION,
                                        IDENTIFIER_0,
                                        IDENTIFIER_1,
                                        BYTE_0,
                                       BYTE_1,
                                        BYTE_2,
                                        BYTE_3,
                                        BYTE_4,
                                        BYTE_5,
                                        BYTE_6,
                                        BYTE_7);

-- STATE HANDLER --                                                                 
signal state_main : type_main_state := IDLE;
signal state_config : type_config_state := RESET_MODE_ON;
signal state_can_rw : type_can_read_state := FRAME_INFORMATION; 

-- CAN READY FLAGS --
shared variable ready_can_cfg : boolean := false;
shared variable ready_can_wr : boolean := false;
shared variable ready_can_rd : boolean := false;

-- REG READY FLAGS --
signal ready_reg_wr : boolean := false;
signal ready_reg_rd : boolean := false;

-- TEMP VARIABLES --
shared variable reg_data_buffer : std_logic_vector(7 downto 0); 

-- PROCEDURES
procedure CAN_REG_READ ( ADDRESS : in std_logic_vector(7 downto 0);
                                 DATA : out std_logic_vector(7 downto 0);
                                 signal READY_FLAG : out boolean ) is
begin
    cs_can <= '1';
    ale <= '1';
    port_0 <= ADDRESS; -- PORT_0 RELEVENT FOR RACE CONDITION
    ale <= '0';
    rd <= '1';
    DATA := port_0; 
    rd <= '0';
    cs_can <= '0';
    READY_FLAG <= true;
end procedure CAN_REG_READ;

procedure CAN_REG_WRITE( ADDRESS : in std_logic_vector(7 downto 0);
                                 DATA : in std_logic_vector(7 downto 0);
                                 signal READY_FLAG : out boolean ) is
begin
    cs_can <= '1';
    ale <= '1';
    port_0 <= ADDRESS;
    ale <= '0';
    wr <= '1';
    port_0 <= DATA;
    wr <= '0';
    cs_can <= '0';
end procedure CAN_REG_WRITE;

begin 
    process(clk,reset) -- MAIN STATEMACHINE
    begin
        if reset = '0' then -- aktive low
            state_main <= CONFIGURE;
        elsif rising_edge(clk) and ready_can_cfg then
            if can_rd = '1' then
                state_main <= RECEIVE;
            elsif can_wr = '1' then
                state_main <= TRANSMIT;
            end if;
        end if;
    end process;

    config : process(clk) -- CONFIGURE STATEMACHINE
    begin
        if state_main = CONFIGURE then
            case state_config is
                when RESET_MODE_ON =>
                    ready_can_cfg := false;
                    CAN_REG_WRITE(x"00",x"01",ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= ACTIVE_BASIC_CONFIG;
                    end if;
                when ACTIVE_BASIC_CONFIG =>
                    CAN_REG_WRITE(x"1F",x"07",ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= SET_BAUD_SYNC;
                    end if;
                when SET_BAUD_SYNC =>
                    CAN_REG_WRITE(x"06",x"01",ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= SET_ACCEPTANCE_MASK;
                    end if;
                when SET_ACCEPTANCE_MASK =>
                    CAN_REG_WRITE(x"04",x"00",ready_reg_wr);                    
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= SET_ACCEPTANCE_MASK2;
                    end if;
                when SET_ACCEPTANCE_MASK2 =>
                    CAN_REG_WRITE(x"05",x"00",ready_reg_wr);                    
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= SET_BUS_TIMING;
                    end if;         
                when SET_BUS_TIMING =>
                    CAN_REG_WRITE(x"07",x"7F",ready_reg_wr);                    
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= RESET_MODE_OFF;
                    end if;
                when RESET_MODE_OFF =>
                    CAN_REG_WRITE(x"00",x"00",ready_reg_wr);                    
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_config <= RESET_MODE_ON;
                    end if;
                    ready_can_cfg := true;
            end case;
        end if;
    end process config;

    can_read : process(clk) -- CAN READ STATEMACHINE -> READS 88Bit
    begin
        if state_main = RECEIVE then
            case state_can_rw is
                when FRAME_INFORMATION =>
                    ready_can_rd := false;
                    CAN_REG_READ(x"10", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(7 downto 0) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= IDENTIFIER_0;
                    end if;
                when IDENTIFIER_0 =>
                    CAN_REG_READ(x"11", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(15 downto 8) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= IDENTIFIER_1;
                    end if;
                when IDENTIFIER_1 =>
                    CAN_REG_READ(x"12", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(23 downto 16) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_0;
                    end if;
                when BYTE_0 =>
                    CAN_REG_READ(x"13", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(31 downto 24) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_1;
                    end if;
                when BYTE_1 =>
                    CAN_REG_READ(x"14", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(39 downto 32) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_2;
                    end if;
                when BYTE_2 =>
                    CAN_REG_READ(x"15", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(47 downto 40) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_3;
                    end if;
                when BYTE_3 =>
                    CAN_REG_READ(x"16", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(55 downto 48) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_4;
                    end if;
                when BYTE_4 =>
                    CAN_REG_READ(x"17", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(63 downto 56) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_5;
                    end if;
                when BYTE_5 =>
                    CAN_REG_READ(x"18", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(71 downto 64) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_6;
                    end if;
                when BYTE_6 =>
                    CAN_REG_READ(x"19", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(79 downto 72) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= BYTE_7;
                    end if;
                when BYTE_7 =>
                    CAN_REG_READ(x"1A", reg_data_buffer, ready_reg_rd);
                    if ready_reg_rd then
                        can_data(87 downto 80) <= reg_data_buffer(7 downto 0);
                        ready_reg_rd <= false;
                        state_can_rw <= FRAME_INFORMATION;
                    end if;
                    ready_can_rd := true;
            end case;
        end if;
    end process can_read;

    can_write: process(clk) -- CAN WRITE STATEMACHINE -> WRITE 88Bit
    begin
        if state_main = TRANSMIT then
            case state_can_rw is
                when FRAME_INFORMATION =>
                    ready_can_wr := false;
                    CAN_REG_WRITE(x"10", can_data(7 downto 0), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= IDENTIFIER_0;
                    end if;
                when IDENTIFIER_0 =>
                    CAN_REG_WRITE(x"11", can_data(15 downto 8), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= IDENTIFIER_1;
                    end if;
                when IDENTIFIER_1 =>
                    CAN_REG_WRITE(x"12", can_data(23 downto 16), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_0;
                    end if;
                when BYTE_0 =>
                    CAN_REG_WRITE(x"13", can_data(31 downto 24), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_1;
                    end if;
                when BYTE_1 =>
                    CAN_REG_WRITE(x"14", can_data(39 downto 32), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_2;
                    end if;
                when BYTE_2 =>
                    CAN_REG_WRITE(x"15", can_data(47 downto 40), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_3;
                    end if;
                when BYTE_3 =>
                    CAN_REG_WRITE(x"16", can_data(55 downto 48), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_4;
                    end if;
                when BYTE_4 =>
                    CAN_REG_WRITE(x"17", can_data(63 downto 56), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_5;
                    end if;
                when BYTE_5 =>
                    CAN_REG_WRITE(x"18", can_data(71 downto 64), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_6;
                    end if;
                when BYTE_6 =>
                    CAN_REG_WRITE(x"19", can_data(79 downto 72), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= BYTE_7;
                    end if;
                when BYTE_7 =>
                    CAN_REG_WRITE(x"1A", can_data(87 downto 80), ready_reg_wr);
                    if ready_reg_wr = true then
                        ready_reg_wr <= false;
                        state_can_rw <= FRAME_INFORMATION;
                    end if;
                    ready_can_wr := true;
            end case;
        end if;
    end process can_write;

end beh_can_controller;
