

library ieee;
use ieee.std_logic_1164.all;


-- Rising Edge Finder but bounch detection.
-- Will only pass a pulse that transisioned in one clock cycle.
-- Its more important that we get a perfect timed pulse, then
-- that we get a pulse at all.
entity rising_edge_finder is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        sig_in  : in  std_logic;
        pulse   : out std_logic;
        valid_pulse   : out std_logic
    );
end rising_edge_finder;

architecture Behavioral of rising_edge_finder is
    signal stage1, stage2, stage3, stage4, stage5, stage6, stage7 : std_logic := '0';
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            stage1 <= '0';
            stage2 <= '0';
            stage3 <= '0';
            stage4 <= '0';
            stage5 <= '0';
            stage6 <= '0';
            stage7 <= '0';
            pulse  <= '0';
            valid_pulse <= '0';

        elsif rising_edge(clk) then
            stage1 <= sig_in;
            stage2 <= stage1;
            stage3 <= stage2;
            stage4 <= stage3;
            stage5 <= stage4;
            stage6 <= stage5;
            stage7 <= stage6;

            -- pulse is hight when 3 consecutive stages are high
            if stage3 = '1' and stage2 = '1' and stage1 = '1' and sig_in = '1' then
                pulse <= '1';
            elsif stage3 = '0' and stage2 = '0' and stage1 = '0' and sig_in = '0' then
                pulse <= '0';
            end if;

            -- A valid pulse is when 3 consecutive stages are high and the last 4 stages are low
            if stage7 = '0' and stage6 = '0' and stage5 = '0' and stage4 = '0' and stage3 = '1' and stage2 = '1' and stage1 = '1' and sig_in = '1' then
                valid_pulse <= '1';
            else
                valid_pulse <= '0';
            end if;
        end if;
    end process;
end Behavioral;