library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_output is 
    generic(
        PIXEL_WIDTH : integer := 8;
        ADDR_WIDTH  : integer := 19;

        H_RES       : integer := 640;
        V_RES       : integer := 480;

        TEST_MODE   : boolean := true
    );
    port(
        clk         : in std_logic;
        rst         : in std_logic;

        hpos_i : in integer;
        vpos_i : in integer;
        
        hsync_i     : in std_logic;
        vsync_i     : in std_logic;

        active_i    : in std_logic;
        
        rd_data_i   : in std_logic_vector(PIXEL_WIDTH - 1 downto 0);

        rd_addr_o   : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
        rd_en_o     : out std_logic;

        vga_hsync_o : out std_logic;
        vga_vsync_o : out std_logic;

        vga_r : out std_logic_vector(PIXEL_WIDTH-1 downto 0);
        vga_g : out std_logic_vector(PIXEL_WIDTH-1 downto 0);
        vga_b : out std_logic_vector(PIXEL_WIDTH-1 downto 0)
    );
end vga_output;

architecture rtl_vga_out of vga_output is
    signal hsync_dly    : std_logic;
    signal vsync_dly    : std_logic;
    signal active_dly   : std_logic;
    signal rgb_dly      : std_logic_vector(7 downto 0);

begin

    rd_addr_o <= std_logic_vector(to_unsigned(vpos_i * H_RES + hpos_i, ADDR_WIDTH)) 
                when active_i = '1' else (others => '0');

    rd_en_o <= '1' when active_i = '1' else '0';

    process (clk) 
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                hsync_dly   <= '0';
                vsync_dly   <= '0';
                active_dly  <= '0';
                rgb_dly     <= (others => '0');
            else 
                hsync_dly   <= hsync_i;
                vsync_dly   <= vsync_i;
                active_dly  <= active_i;
                rgb_dly     <= std_logic_vector(to_unsigned(hpos_i, PIXEL_WIDTH));
            end if;
        end if;    
    end process;

    process (rd_data_i, active_dly, hsync_dly, vsync_dly, rgb_dly)
    begin
        vga_hsync_o <= hsync_dly;
        vga_vsync_o <= vsync_dly;

        if TEST_MODE then
            if active_dly = '1' then
                vga_r <= rgb_dly;
                vga_g <= rgb_dly;
                vga_b <= rgb_dly;
            else
                vga_r <= (others => '0');
                vga_g <= (others => '0');
                vga_b <= (others => '0');
            end if;
        else
            if active_dly = '1' then
                vga_r <= rd_data_i;
                vga_g <= rd_data_i;
                vga_b <= rd_data_i;
            else
                vga_r <= (others => '0');
                vga_g <= (others => '0');
                vga_b <= (others => '0');
            end if;
        end if;
    end process;

end rtl_vga_out;