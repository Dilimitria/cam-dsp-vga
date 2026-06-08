library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_vga is
    port(
        clk_50    : in  std_logic;  
        rst       : in  std_logic; 
        vga_hsync : out std_logic;
        vga_vsync : out std_logic;
        vga_r     : out std_logic_vector(7 downto 0);
        vga_g     : out std_logic_vector(7 downto 0);
        vga_b     : out std_logic_vector(7 downto 0)
    );
end top_vga;

architecture rtl_top_vga of top_vga is
    signal clk_vga     : std_logic;
    signal pll_locked  : std_logic;
    signal hsync, vsync, active : std_logic;
    signal hpos, vpos  : integer;
    signal rst_sync    : std_logic;  
begin
    PLL_CAM_inst : entity work.PLL_CAM
        port map (
            areset => rst,         
            inclk0 => clk_50,
            c0     => clk_vga,
            locked => pll_locked
        );

    process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            rst_sync <= not pll_locked; 
        end if;
    end process;

    sync_inst: entity work.vga_sync
        generic map(
            H_SYNC    => 96, H_BACK => 48, H_VISIBLE => 640, H_FRONT => 16,
            V_SYNC    => 2,  V_BACK => 33, V_VISIBLE => 480, V_FRONT => 10
        )
        port map(
            clk      => clk_vga,
            rst      => rst_sync,      
            hsync_o  => hsync,
            vsync_o  => vsync,
            hpos_o   => hpos,
            vpos_o   => vpos,
            active_o => active
        );

    out_inst: entity work.vga_output
        generic map(
            PIXEL_WIDTH => 8,
            ADDR_WIDTH  => 19,
            H_RES       => 640,
            V_RES       => 480,
            TEST_MODE   => true
        )
        port map(
            clk         => clk_vga,
            rst         => rst_sync,
            hpos_i      => hpos,
            vpos_i      => vpos,
            hsync_i     => hsync,
            vsync_i     => vsync,
            active_i    => active,
            rd_data_i   => (others => '0'),
            rd_addr_o   => open,
            rd_en_o     => open,
            vga_hsync_o => vga_hsync,
            vga_vsync_o => vga_vsync,
            vga_r       => vga_r,
            vga_g       => vga_g,
            vga_b       => vga_b
        );
end rtl_top_vga;