

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pps_timer is
    port (
        tcxo_clk       : in  std_ulogic;               -- TXCO clock, upscaled by PLL (100 MHz)
        reset_n        : in  std_ulogic;               -- Active low reset, '1' if system is running
        pps_clk        : in  std_ulogic;               -- PPS input (1 Hz)
        data_to_pps    : in  std_ulogic_vector(35 downto 0); -- is_write, addr, data in from FIFO
        to_pps_rd_en   : out std_ulogic;
        to_pps_empty   : in  std_ulogic;
        data_from_pps  : out std_ulogic_vector(31 downto 0); -- result for reads from core
        from_pps_wr_en : out std_ulogic;
        from_pps_full  : in  std_ulogic
    );
end pps_timer;

architecture Behavioral of pps_timer is

    -- Internal signals
    signal reset_pps_n      : std_ulogic;
    signal pps_clk_sync     : std_ulogic;
    signal pps_valid        : std_ulogic;
    signal txco_ctr         : std_ulogic_vector(63 downto 0) := (others => '0');
    signal pps_ctr          : std_ulogic_vector(32 downto 0) := (others => '0');
    signal timestamp        : std_ulogic_vector(63 downto 0) := (others => '0');
    signal timstamp_valid   : std_ulogic;
    signal is_write         : std_ulogic;
    signal addr             : std_ulogic_vector(2 downto 0);
    signal value_to_write   : std_ulogic_vector(31 downto 0);
    signal state            : std_ulogic_vector(1 downto 0) := "00";

    -- State machine states
    constant AWAIT_NONEMPTY : std_ulogic_vector(1 downto 0) := "00";
    constant FIFO_READ      : std_ulogic_vector(1 downto 0) := "01";
    constant DO_OP          : std_ulogic_vector(1 downto 0) := "10";

    -- Synchronizer for reset_n
    signal reset_sync       : std_ulogic_vector(2 downto 0) := (others => '0');
    signal pps_clk_sync_prev : std_ulogic := '0';
begin


    -- Synchronize reset_n to the PPS clock domain
    process(tcxo_clk, reset_n)
    begin
        if reset_n = '0' then
            reset_sync <= (others => '0');
            reset_pps_n <= '0';
        elsif rising_edge(tcxo_clk) then
            reset_sync <= reset_sync(1 downto 0) & '1';
            reset_pps_n <= reset_sync(2);
        end if;
    end process;

    -- Rising edge finder for PPS clock
    rising_edge_finder: entity work.rising_edge_finder
        port map (
        clk    => tcxo_clk,
        reset_n => reset_n,
        sig_in => pps_clk,
        pulse  => pps_clk_sync,
        valid_pulse => pps_valid
        );


    -- TXCO counter
    process(tcxo_clk, reset_pps_n)
    begin
        if reset_pps_n = '0' then
            txco_ctr <= (others => '0');
        elsif rising_edge(tcxo_clk) then
            txco_ctr <= std_ulogic_vector(unsigned(txco_ctr) + 1);
        end if;
    end process;

    -- TXCO PPS counter
    process(tcxo_clk, reset_pps_n)
    begin
        if reset_pps_n = '0' then
            pps_ctr <= (others => '0');
            timestamp <= (others => '0');
            timstamp_valid <= '0';
            pps_clk_sync_prev <= '0';
        elsif rising_edge(tcxo_clk) then
            pps_clk_sync_prev <= pps_clk_sync;
            if (pps_clk_sync_prev = '0') and (pps_clk_sync = '1') then
                timestamp <= txco_ctr;
                pps_ctr <= std_ulogic_vector(unsigned(pps_ctr) + 1);
                timstamp_valid <= pps_valid;
            end if;
        end if;
    end process;

    -- Break the data from the incoming FIFO into its parts
    is_write <= data_to_pps(35);
    addr <= data_to_pps(34 downto 32);
    value_to_write <= data_to_pps(31 downto 0);

    -- Connect the right thing to the outgoing FIFO for reads
    data_from_pps <= timestamp(31 downto 0) when addr = "000" else
                     timestamp(63 downto 32) when addr = "001" else
                     (31 downto 1 => '0') & timstamp_valid  when addr = "010" else
                     pps_ctr(31 downto 0) when addr = "011" else
                     x"beeeeeef";

    -- State machine for handling reads and writes
    process(tcxo_clk, reset_pps_n)
    begin
        if reset_pps_n = '0' then
            to_pps_rd_en <= '0';
            from_pps_wr_en <= '0';
            state <= AWAIT_NONEMPTY;
        elsif rising_edge(tcxo_clk) then
            case state is
                when AWAIT_NONEMPTY =>
                    from_pps_wr_en <= '0';
                    if to_pps_empty = '0' then
                        to_pps_rd_en <= '1';
                        state <= FIFO_READ;
                    end if;

                when FIFO_READ =>
                    to_pps_rd_en <= '0';
                    state <= DO_OP;

                when DO_OP =>
                    if is_write = '1' then
                        -- Handle write operations here if needed
                        state <= AWAIT_NONEMPTY;
                    else
                        if from_pps_full = '1' then
                            state <= DO_OP;
                        else
                            from_pps_wr_en <= '1';
                            state <= AWAIT_NONEMPTY;
                        end if;
                    end if;

                when others =>
                    state <= AWAIT_NONEMPTY;
            end case;
        end if;
    end process;

end Behavioral;