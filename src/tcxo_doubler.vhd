

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY tcxo_doubler IS
    PORT (
        clkout : OUT STD_LOGIC;
        lock : OUT STD_LOGIC;
        clkin : IN STD_LOGIC
    );
END tcxo_doubler;

ARCHITECTURE Behavioral OF tcxo_doubler IS

    -- Internal signals
    SIGNAL clkoutp_o : STD_LOGIC;
    SIGNAL clkoutd_o : STD_LOGIC;
    SIGNAL clkoutd3_o : STD_LOGIC;
    SIGNAL gw_gnd : STD_LOGIC := '0';
    SIGNAL FBDSEL_i : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL IDSEL_i : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL ODSEL_i : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL PSDA_i : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL DUTYDA_i : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL FDLY_i : STD_LOGIC_VECTOR(3 DOWNTO 0);

    --component declaration
    COMPONENT rPLL
        GENERIC (
            FCLKIN : IN STRING := "100.0";
            DEVICE : IN STRING := "GW1N-4";
            DYN_IDIV_SEL : IN STRING := "false";
            IDIV_SEL : IN INTEGER := 0;
            DYN_FBDIV_SEL : IN STRING := "false";
            FBDIV_SEL : IN INTEGER := 0;
            DYN_ODIV_SEL : IN STRING := "false";
            ODIV_SEL : IN INTEGER := 8;
            PSDA_SEL : IN STRING := "0000";
            DYN_DA_EN : IN STRING := "false";
            DUTYDA_SEL : IN STRING := "1000";
            CLKOUT_FT_DIR : IN BIT := '1';
            CLKOUTP_FT_DIR : IN BIT := '1';
            CLKOUT_DLY_STEP : IN INTEGER := 0;
            CLKOUTP_DLY_STEP : IN INTEGER := 0;
            CLKOUTD3_SRC : IN STRING := "CLKOUT";
            CLKFB_SEL : IN STRING := "internal";
            CLKOUT_BYPASS : IN STRING := "false";
            CLKOUTP_BYPASS : IN STRING := "false";
            CLKOUTD_BYPASS : IN STRING := "false";
            CLKOUTD_SRC : IN STRING := "CLKOUT";
            DYN_SDIV_SEL : IN INTEGER := 2
        );
        PORT (
            CLKOUT : OUT STD_LOGIC;
            LOCK : OUT STD_LOGIC;
            CLKOUTP : OUT STD_LOGIC;
            CLKOUTD : OUT STD_LOGIC;
            CLKOUTD3 : OUT STD_LOGIC;
            RESET : IN STD_LOGIC;
            RESET_P : IN STD_LOGIC;
            CLKIN : IN STD_LOGIC;
            CLKFB : IN STD_LOGIC;
            FBDSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
            IDSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
            ODSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
            PSDA : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            DUTYDA : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            FDLY : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT;

BEGIN

    gw_gnd <= '0';

    FBDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    IDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    PSDA_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DUTYDA_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    FDLY_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    -- Set parameters for the rPLL instance
    -- These are equivalent to the `defparam` statements in Verilog
    rpll_inst_generic : rPLL
    GENERIC MAP(
        FCLKIN => "10",
        DEVICE => "GW1NR-9C",
        DYN_IDIV_SEL => "false",
        IDIV_SEL => 0,
        DYN_FBDIV_SEL => "false",
        FBDIV_SEL => 9,
        DYN_ODIV_SEL => "false",
        ODIV_SEL => 4,
        PSDA_SEL => "0000",
        DYN_DA_EN => "true",
        DUTYDA_SEL => "1000",
        CLKOUT_FT_DIR => '1',
        CLKOUTP_FT_DIR => '1',
        CLKOUT_DLY_STEP => 0,
        CLKOUTP_DLY_STEP => 0,
        CLKFB_SEL => "internal",
        CLKOUT_BYPASS => "false",
        CLKOUTP_BYPASS => "false",
        CLKOUTD_BYPASS => "false",
        DYN_SDIV_SEL => 2,
        CLKOUTD_SRC => "CLKOUT",
        CLKOUTD3_SRC => "CLKOUT"
    )
    PORT MAP(
        CLKOUT => clkout,
        LOCK => lock,
        CLKOUTP => clkoutp_o,
        CLKOUTD => clkoutd_o,
        CLKOUTD3 => clkoutd3_o,
        RESET => gw_gnd,
        RESET_P => gw_gnd,
        CLKIN => clkin,
        CLKFB => gw_gnd,
        FBDSEL => FBDSEL_i,
        IDSEL => IDSEL_i,
        ODSEL => ODSEL_i,
        PSDA => PSDA_i,
        DUTYDA => DUTYDA_i,
        FDLY => FDLY_i
    );
END Behavioral;