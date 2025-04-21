library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo is
  generic (
    DATA_WIDTH : integer := 8;
    ADDR_WIDTH : integer := 4  -- Depth = 2^ADDR_WIDTH
  );
  port (
    wr_clk     : in  std_ulogic;
    wr_rst     : in  std_ulogic;
    wr_en      : in  std_ulogic;
    wr_data    : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
    wr_full    : out std_ulogic;

    rd_clk     : in  std_ulogic;
    rd_rst     : in  std_ulogic;
    rd_en      : in  std_ulogic;
    rd_data    : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
    rd_empty   : out std_ulogic
  );
end fifo;

architecture rtl of fifo is
  constant DEPTH : integer := 2 ** ADDR_WIDTH;

  type mem_type is array (0 to DEPTH-1) of std_ulogic_vector(DATA_WIDTH-1 downto 0);
  signal mem : mem_type;

  signal wr_ptr_bin, wr_ptr_bin_next : unsigned(ADDR_WIDTH downto 0);
  signal rd_ptr_bin, rd_ptr_bin_next : unsigned(ADDR_WIDTH downto 0);
  signal wr_ptr_gray, wr_ptr_gray_next : unsigned(ADDR_WIDTH downto 0);
  signal rd_ptr_gray, rd_ptr_gray_next : unsigned(ADDR_WIDTH downto 0);

  signal wr_ptr_gray_sync_rd : unsigned(ADDR_WIDTH downto 0);
  signal rd_ptr_gray_sync_wr : unsigned(ADDR_WIDTH downto 0);

  -- Double sync stages
  signal wr_ptr_gray_sync_rd1, wr_ptr_gray_sync_rd2 : unsigned(ADDR_WIDTH downto 0);
  signal rd_ptr_gray_sync_wr1, rd_ptr_gray_sync_wr2 : unsigned(ADDR_WIDTH downto 0);

  -- Internal signals for full and empty flags
  signal wr_full_int : std_ulogic;
  signal rd_empty_int : std_ulogic;
begin

  -- Assign internal signals to output ports
  wr_full <= wr_full_int;
  rd_empty <= rd_empty_int;

  -- Memory write
  process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      if wr_en = '1' and wr_full_int = '0' then
        mem(to_integer(wr_ptr_bin(ADDR_WIDTH-1 downto 0))) <= wr_data;
      end if;
    end if;
  end process;

  -- Memory read
  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      if rd_en = '1' and rd_empty_int = '0' then
        rd_data <= mem(to_integer(rd_ptr_bin(ADDR_WIDTH-1 downto 0)));
      end if;
    end if;
  end process;

  -- Write pointer logic
  process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      if wr_rst = '1' then
        wr_ptr_bin <= (others => '0');
        wr_ptr_gray <= (others => '0');
      else
        if wr_en = '1' and wr_full_int = '0' then
          wr_ptr_bin <= wr_ptr_bin + 1;
        end if;
        wr_ptr_gray <= (wr_ptr_bin xor (wr_ptr_bin srl 1));
      end if;
    end if;
  end process;

  -- Read pointer logic
  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      if rd_rst = '1' then
        rd_ptr_bin <= (others => '0');
        rd_ptr_gray <= (others => '0');
      else
        if rd_en = '1' and rd_empty_int = '0' then
          rd_ptr_bin <= rd_ptr_bin + 1;
        end if;
        rd_ptr_gray <= (rd_ptr_bin xor (rd_ptr_bin srl 1));
      end if;
    end if;
  end process;

  -- Synchronize gray pointers across domains
  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      wr_ptr_gray_sync_rd1 <= wr_ptr_gray;
      wr_ptr_gray_sync_rd2 <= wr_ptr_gray_sync_rd1;
      wr_ptr_gray_sync_rd  <= wr_ptr_gray_sync_rd2;
    end if;
  end process;

  process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      rd_ptr_gray_sync_wr1 <= rd_ptr_gray;
      rd_ptr_gray_sync_wr2 <= rd_ptr_gray_sync_wr1;
      rd_ptr_gray_sync_wr  <= rd_ptr_gray_sync_wr2;
    end if;
  end process;

  -- Generate full flag
  wr_full_int <= '1' when
    (wr_ptr_gray(ADDR_WIDTH downto ADDR_WIDTH-1) = not rd_ptr_gray_sync_wr(ADDR_WIDTH downto ADDR_WIDTH-1) and
     wr_ptr_gray(ADDR_WIDTH-2 downto 0) = rd_ptr_gray_sync_wr(ADDR_WIDTH-2 downto 0))
    else '0';

  -- Generate empty flag
  rd_empty_int <= '1' when rd_ptr_gray = wr_ptr_gray_sync_rd else '0';

end rtl;
