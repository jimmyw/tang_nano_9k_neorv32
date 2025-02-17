-- filepath: /home/jimmy/fpga/gpsdo-nerorv32/gpsdo_nerorv32/src/uflash_controller.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uflash is
    generic (
        CLK_FREQ : integer := 5400000
    );
    port (
        reset_n : in std_logic;
        clk : in std_logic;
        sel : in std_logic;
        wstrb : in std_logic_vector(3 downto 0);
        addr : in std_logic_vector(14 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        ready : out std_logic;
        data_o : out std_logic_vector(31 downto 0)
    );
end entity uflash;

architecture uflash_rtl of uflash is

    -- Function to perform the multiplication
    function calc_clks(freq : integer; time : real) return integer is
    begin
        return integer(real(freq) * time) + 1;
    end function;

    -- state machine states
    type state_t is (
        IDLE,
        READ1,
        READ2,
        ERASE1,
        ERASE2,
        ERASE3,
        ERASE4,
        ERASE5,
        WRITE1,
        WRITE2,
        WRITE3,
        WRITE4,
        WRITE5,
        WRITE6,
        WRITE7,
        DONE
    );

    signal state : state_t := IDLE;

    -- clocks required in state when > 1
    constant E2_CLKS : integer := calc_clks(CLK_FREQ, 6.0e-6);
    constant E3_CLKS : integer := calc_clks(CLK_FREQ, 120.0e-3);
    constant E4_CLKS : integer := calc_clks(CLK_FREQ, 6.0e-6);
    constant E5_CLKS : integer := calc_clks(CLK_FREQ, 11.0e-6);
    constant W2_CLKS : integer := calc_clks(CLK_FREQ, 6.0e-6);
    constant W3_CLKS : integer := calc_clks(CLK_FREQ, 11.0e-6);
    constant W4_CLKS : integer := calc_clks(CLK_FREQ, 16.0e-6);
    constant W6_CLKS : integer := calc_clks(CLK_FREQ, 6.0e-6);
    constant W7_CLKS : integer := calc_clks(CLK_FREQ, 11.0e-6);

    signal xe    : std_logic := '0';
    signal ye    : std_logic := '0';
    signal se    : std_logic := '0';
    signal erase : std_logic := '0';
    signal nvstr : std_logic := '0';
    signal prog  : std_logic := '0';
    signal cycle_count : unsigned(23 downto 0) := (others => '0');

    -- Component declaration for FLASH608K
    component FLASH608K
        port (
            DOUT  : out std_logic_vector(31 downto 0);
            XE    : in std_logic;
            YE    : in std_logic;
            SE    : in std_logic;
            PROG  : in std_logic;
            ERASE : in std_logic;
            NVSTR : in std_logic;
            XADR  : in std_logic_vector(8 downto 0);
            YADR  : in std_logic_vector(5 downto 0);
            DIN   : in std_logic_vector(31 downto 0)
        );
    end component;

begin

    ready <= '1' when state = DONE else '0';

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state       <= IDLE;
            se          <= '0';
            xe          <= '0';
            ye          <= '0';
            erase       <= '0';
            nvstr       <= '0';
            prog        <= '0';
            cycle_count <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if sel = '1' then
                        if wstrb = "0000" then
                            -- Read
                            state <= READ1;
                            xe    <= '1';
                            ye    <= '1';
                        elsif wstrb = "1111" then
                            -- Write
                            state <= WRITE1;
                            xe    <= '1';
                        elsif wstrb = "0001" then
                            -- Erase
                            ye    <= '0';
                            se    <= '0';
                            xe    <= '1';
                            erase <= '0';
                            nvstr <= '0';
                            state <= ERASE1;
                        else
                            -- Unsupported
                            state <= DONE;
                        end if;
                    else
                        state <= IDLE;
                    end if;
                when READ1 =>
                    se    <= '1';
                    state <= READ2;
                when READ2 =>
                    se    <= '0';
                    state <= DONE;
                when ERASE1 =>
                    state       <= ERASE2;
                    cycle_count <= (others => '0');
                    erase       <= '1';
                when ERASE2 =>
                    if cycle_count < to_unsigned(E2_CLKS, 24) then
                        state       <= ERASE2;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= ERASE3;
                        cycle_count <= (others => '0');
                        nvstr       <= '1';
                    end if;
                when ERASE3 =>
                    if cycle_count < to_unsigned(E3_CLKS, 24) then
                        state       <= ERASE3;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= ERASE4;
                        cycle_count <= (others => '0');
                        erase       <= '0';
                    end if;
                when ERASE4 =>
                    if cycle_count < to_unsigned(E4_CLKS, 24) then
                        state       <= ERASE4;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= ERASE5;
                        cycle_count <= (others => '0');
                        nvstr       <= '0';
                    end if;
                when ERASE5 =>
                    if cycle_count < to_unsigned(E5_CLKS, 24) then
                        state       <= ERASE5;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= DONE;
                        cycle_count <= (others => '0');
                        xe          <= '0';
                    end if;
                when WRITE1 =>
                    state <= WRITE2;
                    prog  <= '1';
                when WRITE2 =>
                    if cycle_count < to_unsigned(W2_CLKS, 24) then
                        state       <= WRITE2;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= WRITE3;
                        cycle_count <= (others => '0');
                        nvstr       <= '1';
                    end if;
                when WRITE3 =>
                    if cycle_count < to_unsigned(W3_CLKS, 24) then
                        state       <= WRITE3;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= WRITE4;
                        cycle_count <= (others => '0');
                        ye          <= '1';
                    end if;
                when WRITE4 =>
                    if cycle_count < to_unsigned(W4_CLKS, 24) then
                        state       <= WRITE4;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= WRITE5;
                        cycle_count <= (others => '0');
                        ye          <= '0';
                    end if;
                when WRITE5 =>
                    state <= WRITE6;
                    prog  <= '0';
                when WRITE6 =>
                    if cycle_count < to_unsigned(W6_CLKS, 24) then
                        state       <= WRITE6;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= WRITE7;
                        cycle_count <= (others => '0');
                        nvstr       <= '0';
                    end if;
                when WRITE7 =>
                    if cycle_count < to_unsigned(W7_CLKS, 24) then
                        state       <= WRITE7;
                        cycle_count <= cycle_count + 1;
                    else
                        state       <= DONE;
                        cycle_count <= (others => '0');
                        xe          <= '0';
                    end if;
                when DONE =>
                    state <= IDLE;
                    xe    <= '0';
                    ye    <= '0';
                    se    <= '0';
                    erase <= '0';
                    nvstr <= '0';
                    prog  <= '0';
            end case;
        end if;
    end process;

    flash_inst : FLASH608K
        port map (
            DOUT => data_o,
            XE => xe,
            YE => ye,
            SE => se,
            PROG => prog,
            ERASE => erase,
            NVSTR => nvstr,
            XADR => addr(14 downto 6),
            YADR => addr(5 downto 0),
            DIN => data_i
        );


end architecture uflash_rtl;