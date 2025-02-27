--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--Tool Version: V1.9.10.02
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Thu Feb 27 17:31:54 2025

library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_User_Flash is
    port (
        dout: out std_logic_vector(31 downto 0);
        xe: in std_logic;
        ye: in std_logic;
        se: in std_logic;
        prog: in std_logic;
        erase: in std_logic;
        nvstr: in std_logic;
        xadr: in std_logic_vector(8 downto 0);
        yadr: in std_logic_vector(5 downto 0);
        din: in std_logic_vector(31 downto 0)
    );
end Gowin_User_Flash;

architecture Behavioral of Gowin_User_Flash is

    --component declaration
    component FLASH608K
        port (
            DOUT: out std_logic_vector(31 downto 0);
            XE: in std_logic;
            YE: in std_logic;
            SE: in std_logic;
            PROG: in std_logic;
            ERASE: in std_logic;
            NVSTR: in std_logic;
            XADR: in std_logic_vector(8 downto 0);
            YADR: in std_logic_vector(5 downto 0);
            DIN: in std_logic_vector(31 downto 0)
        );
    end component;

begin
    flash_inst: FLASH608K
        port map (
            DOUT => dout,
            XE => xe,
            YE => ye,
            SE => se,
            PROG => prog,
            ERASE => erase,
            NVSTR => nvstr,
            XADR => xadr,
            YADR => yadr,
            DIN => din
        );

end Behavioral; --Gowin_User_Flash
