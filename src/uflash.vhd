--   Copyright 2024 Grug Huhler, 2025 Jimmy Wennlund.
--   License SPDX BSD-2-Clause.
--
--   Rewritten in VHDL from the original Verilog, and ported to
--   the generic Wishbone b4 bus by Jimmy Wennlund
--
--
--   Original authors notes:
--
--   This module implements a controller for the user flash on the Tang
--   Nano 9K FPGA development board.  It also instantiates the
--   actual flash.  Note: the Tang Nano 20K does not contain user
--   flash.
--
--   See document UG295 "Gowin User Flash".
--
--   The Flash is 608 Kbits, 32-bits wide, organized into 304 rows of 64
--   columns each.  The erase page size is 2048 bytes, so there are
--   38 pages that may be separately erased.
--
--   This controller expects a system clock no more than 40 Mhz.  The
--   actual clock frequency must be passed to the module via the
--   CLK_FREQ parameter.
--
--   Leave at least 10 millisconds between a write and an erase and do
--   not write the same address twice without an erase between the writes.
--   The controller does not enforce these rules.
--
--   Reads can be 8, 16, or 32 bits wide.  Erasing is done on a page basis.
--   To erase a page, do an 8 bit write to a 32-bit aligned address in the
--   page. To program (write), do a 32-bit write to the address to be
--   programmed.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uflash is
    generic (
        CLK_FREQ : integer := 5400000
    );
    port (
        reset_n : in std_ulogic;
        clk : in std_ulogic;
        wb_cyc_i : in std_ulogic;
        wb_stb_i : in std_ulogic;
        wb_we_i : in std_ulogic;
        wb_sel_i : in std_ulogic_vector(3 downto 0);
        wb_adr_i : in std_ulogic_vector(14 downto 0);
        wb_dat_i : in std_ulogic_vector(31 downto 0);
        wb_dat_o : out std_ulogic_vector(31 downto 0);
        wb_ack_o : out std_ulogic;
        wb_err_o : out std_ulogic
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

    signal xe    : std_ulogic := '0';
    signal ye    : std_ulogic := '0';
    signal se    : std_ulogic := '0';
    signal erase : std_ulogic := '0';
    signal nvstr : std_ulogic := '0';
    signal prog  : std_ulogic := '0';
    signal cycle_count : unsigned(23 downto 0) := (others => '0');



    -- Signals for type conversion
    signal xe_std_logic    : std_logic;
    signal ye_std_logic    : std_logic;
    signal se_std_logic    : std_logic;
    signal erase_std_logic : std_logic;
    signal nvstr_std_logic : std_logic;
    signal prog_std_logic  : std_logic;
    signal wb_adr_i_std_logic : std_logic_vector(14 downto 0);
    signal wb_dat_i_std_logic : std_logic_vector(31 downto 0);
    signal wb_dat_o_std_logic : std_logic_vector(31 downto 0);

begin

    -- Type conversions
    xe_std_logic    <= std_logic(xe);
    ye_std_logic    <= std_logic(ye);
    se_std_logic    <= std_logic(se);
    erase_std_logic <= std_logic(erase);
    nvstr_std_logic <= std_logic(nvstr);
    prog_std_logic  <= std_logic(prog);
    wb_adr_i_std_logic <= std_logic_vector(wb_adr_i);
    wb_dat_i_std_logic <= std_logic_vector(wb_dat_i);
    wb_dat_o <= std_ulogic_vector(wb_dat_o_std_logic);

    wb_ack_o <= '1' when state = DONE else '0';

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
            wb_err_o    <= '0';
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if wb_cyc_i = '1' and wb_stb_i = '1' then
                        if wb_we_i = '0' then
                            -- Read
                            state <= READ1;
                            xe    <= '1';
                            ye    <= '1';
                        else
                            if wb_sel_i = "0001" then
                                -- Erase
                                ye    <= '0';
                                se    <= '0';
                                xe    <= '1';
                                erase <= '0';
                                nvstr <= '0';
                                state <= ERASE1;
                            elsif wb_sel_i = "1111" then
                                -- Write
                                state <= WRITE1;
                                xe    <= '1';
                            else
                                -- Error
                                state <= DONE;
                                wb_err_o <= '1';
                            end if;
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
                    wb_err_o <= '0';
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
                        wb_err_o <= '0';
                    end if;
                when DONE =>
                    state <= IDLE;
                    xe    <= '0';
                    ye    <= '0';
                    se    <= '0';
                    erase <= '0';
                    nvstr <= '0';
                    prog  <= '0';
                    wb_err_o <= '0';
            end case;
        end if;
    end process;

    flash_inst : entity work.Gowin_User_Flash
        port map (
            DOUT => wb_dat_o_std_logic,
            XE => xe_std_logic,
            YE => ye_std_logic,
            SE => se_std_logic,
            PROG => prog_std_logic,
            ERASE => erase_std_logic,
            NVSTR => nvstr_std_logic,
            XADR => wb_adr_i_std_logic(14 downto 6),
            YADR => wb_adr_i_std_logic(5 downto 0),
            DIN => wb_dat_i_std_logic
        );

end architecture uflash_rtl;