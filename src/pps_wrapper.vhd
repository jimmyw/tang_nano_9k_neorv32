
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pps_wrapper is
    port (
        clk_in         : in  std_logic;  -- The 9MHz clock
        clk            : in  std_logic;  -- The system clock
        reset_n        : in  std_logic;
        sel            : in  std_logic;
        addr           : in  std_logic_vector(2 downto 0);  -- Word address
        is_write       : in  std_logic;
        data_i         : in  std_logic_vector(31 downto 0);
        ready          : out std_logic;
        data_o         : out std_logic_vector(31 downto 0);
        tcxo_in        : in  std_logic;
        pps_in         : in  std_logic;
        pps_pulse_out  : out std_logic;
        pll_out        : out std_logic
    );
end pps_wrapper;

architecture Behavioral of pps_wrapper is

    -- State machine states
    type state_type is (AWAIT_SEL, FIFO_WRITE, AWAIT_FIFO, FIFO_READ, WAIT_FINISH);
    signal state : state_type;

    -- Signals
    signal tcxo_clk         : std_logic;
    signal from_pps_wr_en   : std_logic;
    signal from_pps_rd_en   : std_logic := '0';
    signal from_pps_empty   : std_logic;
    signal from_pps_full    : std_logic;
    signal to_pps_wr_en     : std_logic := '0';
    signal to_pps_rd_en     : std_logic;
    signal to_pps_empty     : std_logic;
    signal to_pps_full      : std_logic;
    signal data_from_pps    : std_logic_vector(31 downto 0);
    signal data_to_pps      : std_logic_vector(35 downto 0);
    signal lock             : std_logic;

begin

    -- PLL instantiation
    rpll_pps: entity work.tcxo_doubler
        port map (
            clkout => tcxo_clk,  -- PLL 100 MHz
            clkin  => tcxo_in,   -- TCXO 10 MHz
            lock   => lock
        );

    -- Assign outputs
    pps_pulse_out <= tcxo_in;
    pll_out <= tcxo_clk;

    -- FIFO to pass data from the upscaled TCXO clock into the system clock
    to_pps_fifo: entity work.fifo
        port map (
            Data    => is_write & addr & data_i,
            Reset   => not reset_n,
            WrClk   => clk,
            RdClk   => tcxo_clk,
            WrEn    => to_pps_wr_en,
            RdEn    => to_pps_rd_en,
            Q       => data_to_pps,
            Empty   => to_pps_empty,
            Full    => to_pps_full
        );

    from_pps_fifo: entity work.fifo
        port map (
            Data    => data_from_pps,
            Reset   => not reset_n,
            WrClk   => tcxo_clk,
            RdClk   => clk,
            WrEn    => from_pps_wr_en,
            RdEn    => from_pps_rd_en,
            Q       => data_o,
            Empty   => from_pps_empty,
            Full    => from_pps_full
        );

    -- State machine for reads and writes from the RISC-V core
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            ready          <= '0';
            from_pps_rd_en <= '0';
            to_pps_wr_en   <= '0';
            state          <= AWAIT_SEL;
        elsif rising_edge(clk) then
            case state is
                when AWAIT_SEL =>
                    ready <= '0';
                    if sel = '1' and to_pps_full = '0' then
                        state        <= FIFO_WRITE;
                        to_pps_wr_en <= '1';
                    else
                        state <= AWAIT_SEL;
                    end if;

                when FIFO_WRITE =>
                    to_pps_wr_en <= '0';
                    if is_write = '1' then
                        ready <= '1';
                        state <= AWAIT_SEL;
                    else
                        state <= AWAIT_FIFO;
                    end if;

                when AWAIT_FIFO =>
                    if from_pps_empty = '0' then
                        from_pps_rd_en <= '1';
                        state          <= FIFO_READ;
                    else
                        state <= AWAIT_FIFO;
                    end if;

                when FIFO_READ =>
                    from_pps_rd_en <= '0';
                    ready          <= '1';
                    state          <= WAIT_FINISH;

                when WAIT_FINISH =>
                    ready <= '0';
                    state <= AWAIT_SEL;

            end case;
        end if;
    end process;

    -- Instantiate the pps_timer module
    pps_timer0: entity work.pps_timer
        port map (
            tcxo_clk       => tcxo_clk,
            reset_n        => reset_n and lock,
            pps_clk        => pps_in,
            data_to_pps    => data_to_pps,
            to_pps_rd_en   => to_pps_rd_en,
            to_pps_empty   => to_pps_empty,
            data_from_pps  => data_from_pps,
            from_pps_wr_en => from_pps_wr_en,
            from_pps_full  => from_pps_full
        );

end Behavioral;