-- ================================================================================ --
-- NEORV32 - Test Setup Using The UART-Bootloader To Upload And Run Executables     --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) 2020 - 2025 Stephan Nolting. All rights reserved.                  --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity tang_nano_9k is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   : natural := 27000000;  -- clock frequency of clk_i in Hz
    MEM_INT_IMEM_SIZE : natural := 16*1024;   -- size of processor-internal instruction memory in bytes
    MEM_INT_DMEM_SIZE : natural := 8*1024;     -- size of processor-internal data memory in bytes
    SLAVE_A_BASE : std_logic_vector(31 downto 0) := x"90000000";
    SLAVE_A_SIZE : std_logic_vector(31 downto 0) := x"00013000" -- 38 pages * 2048 bytes

  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- GPIO --
    gpio_o : out std_ulogic_vector(5 downto 0); -- parallel output
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic;  -- UART0 receive data

    -- JTAG --
    jtag_tck_i     : in  std_ulogic;                                 -- serial clock
    jtag_tdi_i     : in  std_ulogic;                                 -- serial data input
    jtag_tdo_o     : out std_ulogic;                                 -- serial data output
    jtag_tms_i     : in  std_ulogic                                 -- mode select
  );
end entity;

architecture top_rtl of tang_nano_9k is

  signal con_gpio_out : std_ulogic_vector(31 downto 0);


  -- Xbus signals
  signal xbus_adr_o : std_ulogic_vector(31 downto 0);
  signal xbus_dat_o : std_ulogic_vector(31 downto 0);
  signal xbus_tag_o : std_ulogic_vector(2 downto 0);
  signal xbus_we_o : std_ulogic;
  signal xbus_sel_o : std_ulogic_vector(3 downto 0);
  signal xbus_stb_o : std_ulogic;
  signal xbus_cyc_o : std_ulogic;
  signal xbus_dat_i : std_ulogic_vector(31 downto 0);
  signal xbus_ack_i : std_ulogic;
  signal xbus_err_i : std_ulogic;

  -- Xbus interconnect
  signal sel_uflash    : std_logic := '0';


  -- Slave A signals
  signal uflash_ack_i : std_logic;
  signal uflash_err_i : std_logic := '0';
  signal uflash_dat_i : std_logic_vector(31 downto 0);

begin

 process(xbus_adr_o)
    variable addr : unsigned(31 downto 0);
    variable uflash_base : unsigned(31 downto 0);
    variable uflash_end  : unsigned(31 downto 0);


  begin
    -- Convert generics and input address to unsigned for easy compare
    addr := unsigned(xbus_adr_o);

    uflash_base := unsigned(SLAVE_A_BASE);
    -- uflash_end = uflash_base + SLAVE_A_SIZE - 1
    uflash_end  := unsigned(SLAVE_A_BASE) + unsigned(SLAVE_A_SIZE) - 1;


    -- Default to not selecting any slave
    sel_uflash   <= '0';

    -- Check if address is in uflash range
    if (addr >= uflash_base) and (addr <= uflash_end) then
      sel_uflash <= '1';
    end if;
  end process;



  -- Connect the Xbus signals to the selected slave, or default to err if no slave is selected
  xbus_ack_i <= uflash_ack_i when (sel_uflash = '1') else
             '1';

  xbus_err_i <= uflash_err_i when (sel_uflash = '1') else
             '1'; -- default to err if no slave is selected

  xbus_dat_i <= uflash_dat_i when (sel_uflash = '1') else
             (others => '0'); -- default to 0 if no slave is selected

  uflash_inst: entity work.uflash
  generic map (
    CLK_FREQ => CLOCK_FREQUENCY
  )
  port map (
    reset_n => rstn_i,
    clk => clk_i,
    wb_cyc_i => xbus_cyc_o,
    wb_stb_i => xbus_stb_o,
    wb_we_i => xbus_we_o,
    wb_sel_i => xbus_sel_o,
    wb_adr_i => xbus_adr_o(16 downto 2),
    wb_dat_o => uflash_dat_i,
    wb_dat_i => xbus_dat_o,
    wb_ack_o => uflash_ack_i
  );




  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- Clocking --
    CLOCK_FREQUENCY   => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    -- Boot Configuration --
    BOOT_MODE_SELECT  => 0,                 -- boot via internal bootloader
    -- RISC-V CPU Extensions --
    RISCV_ISA_C       => true,              -- implement compressed extension?
    RISCV_ISA_M       => true,              -- implement mul/div extension?
    RISCV_ISA_Zicntr  => true,              -- implement base counters?
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN   => true,              -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE => MEM_INT_IMEM_SIZE, -- size of processor-internal instruction memory in bytes
    -- Internal Data memory --
    MEM_INT_DMEM_EN   => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes
    -- Processor peripherals --
    IO_GPIO_NUM       => 6,                 -- number of GPIO input/output pairs (0..32)
    IO_CLINT_EN       => true,              -- implement core local interruptor (CLINT)?
    IO_UART0_EN       => true,              -- implement primary universal asynchronous receiver/transmitter (UART0)?
    OCD_EN        => true,               -- implement JTAG interface

    XBUS_EN      => true              -- implement X-Bus interface
  )
  port map (
    -- Global control --
    clk_i       => clk_i,        -- global clock, rising edge
    rstn_i      => rstn_i,       -- global reset, low-active, async

    -- GPIO (available if IO_GPIO_NUM > 0) --
    gpio_o      => con_gpio_out, -- parallel output

    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o,  -- UART0 send data
    uart0_rxd_i => uart0_rxd_i,   -- UART0 receive data

    -- JTAG (available if IO_JTAG_EN = true) --
    jtag_tck_i => jtag_tck_i,                                 -- serial clock
    jtag_tdi_i => jtag_tdi_i,                                 -- serial data input
    jtag_tdo_o => jtag_tdo_o,                                 -- serial data output
    jtag_tms_i => jtag_tms_i,                                 -- mode select

    -- Xbus signals
    xbus_adr_o => xbus_adr_o,
    xbus_dat_o => xbus_dat_o,
    xbus_tag_o => xbus_tag_o,
    xbus_we_o => xbus_we_o,
    xbus_sel_o => xbus_sel_o,
    xbus_stb_o => xbus_stb_o,
    xbus_cyc_o => xbus_cyc_o,
    xbus_dat_i => xbus_dat_i,
    xbus_ack_i => xbus_ack_i,
    xbus_err_i => xbus_err_i

  );

  -- GPIO output --
  gpio_o <= con_gpio_out(5 downto 0);


end architecture;
