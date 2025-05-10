
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pps_wrapper is
    port (
        clk_in         : in  std_ulogic;  -- The 9MHz clock
        clk            : in  std_ulogic;  -- The system clock
        reset_n        : in  std_ulogic;  -- Active low reset, '1' if system is running
        sel            : in  std_ulogic;
        addr           : in  std_ulogic_vector(2 downto 0);  -- Word address
        is_write       : in  std_ulogic;
        data_i         : in  std_ulogic_vector(31 downto 0);
        ready          : out std_ulogic;
        data_o         : out std_ulogic_vector(31 downto 0);
        tcxo_in        : in  std_ulogic;
        pps_in         : in  std_ulogic;
        pps_pulse_out  : out std_ulogic;
        pll_out        : out std_ulogic
    );
end pps_wrapper;

architecture Behavioral of pps_wrapper is

    -- State machine states
    type state_type is (AWAIT_SEL, FIFO_WRITE, AWAIT_FIFO, FIFO_READ, WAIT_FINISH);
    signal state : state_type;

    -- Signals
    signal tcxo_clk         : std_ulogic;
    signal reset_n_inv      : std_ulogic;
    signal from_pps_wr_en   : std_ulogic;
    signal from_pps_rd_en   : std_ulogic := '0';
    signal from_pps_empty   : std_ulogic;
    signal from_pps_full    : std_ulogic;
    signal to_pps_wr_en     : std_ulogic := '0';
    signal to_pps_rd_en     : std_ulogic;
    signal to_pps_empty     : std_ulogic;
    signal to_pps_full      : std_ulogic;
    signal data_from_pps    : std_ulogic_vector(31 downto 0);
    signal data_to_pps      : std_ulogic_vector(35 downto 0);
    signal lock             : std_ulogic;
    signal pps_wr_data     : std_ulogic_vector(35 downto 0);
    signal rst_and_lock : std_ulogic;

begin

    -- PLL instantiation
    --rpll_pps: entity work.tcxo_doubler
    --    port map (
    --        clkout => tcxo_clk,  -- PLL 100 MHz
    --        clkin  => tcxo_in,   -- TCXO 10 MHz
    --        lock   => lock
    --    );
    tcxo_clk <= tcxo_in; -- For simulation purposes, use the TCXO clock directly


    -- Assign outputs
    pps_pulse_out <= tcxo_in;
    pll_out <= tcxo_clk;
    reset_n_inv <= not reset_n;
    pps_wr_data <= (0 => is_write) & addr & data_i;
    rst_and_lock <= reset_n; -- and lock; -- Reset the FIFO if the PLL is not locked

    -- FIFO to pass data from the upscaled TCXO clock into the system clock
    to_pps_fifo: entity work.fifo
        generic map (
            DATA_WIDTH => 36,  -- 1 bit for is_write, 3 bits for addr, 32 bits for data
            ADDR_WIDTH      => 2   -- FIFO depth
        )
        port map (
            wr_clk  => clk,
            wr_rst   => reset_n_inv,
            wr_en    => to_pps_wr_en,
            wr_data    => pps_wr_data,
            wr_full    => to_pps_full,

            rd_clk   => tcxo_clk,
            rd_rst   => reset_n_inv,
            rd_en    => to_pps_rd_en,
            rd_data       => data_to_pps,
            rd_empty   => to_pps_empty
        );

    from_pps_fifo: entity work.fifo
        generic map (
            DATA_WIDTH => 32,  -- 32 bits for data
            ADDR_WIDTH      => 2   -- FIFO depth
        )
        port map (
            wr_clk   => tcxo_clk,
            wr_rst   => reset_n_inv,
            wr_en    => from_pps_wr_en,
            wr_data    => data_from_pps,
            wr_full    => from_pps_full,

            rd_clk   => clk,
            rd_rst   => reset_n_inv,
            rd_en    => from_pps_rd_en,
            rd_data       => data_o,
            rd_empty   => from_pps_empty
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
            reset_n        => rst_and_lock,
            pps_clk        => pps_in,
            data_to_pps    => data_to_pps,
            to_pps_rd_en   => to_pps_rd_en,
            to_pps_empty   => to_pps_empty,
            data_from_pps  => data_from_pps,
            from_pps_wr_en => from_pps_wr_en,
            from_pps_full  => from_pps_full
        );

end Behavioral;