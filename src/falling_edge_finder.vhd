-- filepath: /home/jimmy/fpga/gpsdo-neorv32/src/rising_edge_finder.vhd
-- Copyright 2024 Grug Huhler.
-- License SPDX BSD-2-Clause.

library ieee;
use ieee.std_logic_1164.all;

-- Falling Edge Finder
entity falling_edge_finder is
    port (
        clk     : in  std_logic;  -- Clock signal
        reset_n : in  std_logic;  -- Active-low reset signal
        sig_in  : in  std_logic;  -- Input signal to monitor for falling edge
        pulse   : out std_logic   -- Output pulse, high for one clock cycle on falling edge
    );
end falling_edge_finder;

architecture Behavioral of falling_edge_finder is
    signal stage1, stage2, stage3, stage4 : std_logic := '0';
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            stage1 <= '0';
            stage2 <= '0';
            stage3 <= '0';
            stage4 <= '0';
            pulse  <= '0';
        elsif rising_edge(clk) then
            stage1 <= sig_in;  -- Might be metastable
            stage2 <= stage1;
            stage3 <= stage2;
            stage4 <= stage3;  -- stage4 is the oldest data
            -- Look for falling edge
            if stage4 = '1' and stage3 = '0' then
                pulse <= '1';
            else
                pulse <= '0';
            end if;
        end if;
    end process;
end Behavioral;

