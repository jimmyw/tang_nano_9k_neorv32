library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo is
    generic (
        DATA_WIDTH : integer := 32;  -- Width of the data bus
        DEPTH      : integer := 16   -- Depth of the FIFO (number of entries)
    );
    port (
        Data    : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Input data
        Reset   : in  std_logic;                              -- Reset signal (active high)
        WrClk   : in  std_logic;                              -- Write clock
        RdClk   : in  std_logic;                              -- Read clock
        WrEn    : in  std_logic;                              -- Write enable
        RdEn    : in  std_logic;                              -- Read enable
        Q       : out std_logic_vector(DATA_WIDTH-1 downto 0);-- Output data
        Empty   : out std_logic;                              -- FIFO empty flag
        Full    : out std_logic                               -- FIFO full flag
    );
end fifo;

architecture Behavioral of fifo is

    -- Internal signals
    type memory_array is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memory : memory_array := (others => (others => '0')); -- FIFO memory
    signal wr_ptr : integer range 0 to DEPTH-1 := 0;             -- Write pointer
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;             -- Read pointer
    signal count  : integer range 0 to DEPTH := 0;               -- Number of elements in FIFO

begin

    -- Write process
    process(WrClk)
    begin
        if rising_edge(WrClk) then
            if Reset = '1' then
                wr_ptr <= 0;
            elsif WrEn = '1' and Full = '0' then
                memory(wr_ptr) <= Data;
                wr_ptr <= (wr_ptr + 1) mod DEPTH;
            end if;
        end if;
    end process;

    -- Read process
    process(RdClk)
    begin
        if rising_edge(RdClk) then
            if Reset = '1' then
                rd_ptr <= 0;
            elsif RdEn = '1' and Empty = '0' then
                Q <= memory(rd_ptr);
                rd_ptr <= (rd_ptr + 1) mod DEPTH;
            end if;
        end if;
    end process;

    -- Count process
    process(WrClk, RdClk)
    begin
        if Reset = '1' then
            count <= 0;
        elsif rising_edge(WrClk) and WrEn = '1' and Full = '0' then
            count <= count + 1;
        elsif rising_edge(RdClk) and RdEn = '1' and Empty = '0' then
            count <= count - 1;
        end if;
    end process;

    -- Empty and Full flags
    Empty <= '1' when count = 0 else '0';
    Full  <= '1' when count = DEPTH else '0';

end Behavioral;