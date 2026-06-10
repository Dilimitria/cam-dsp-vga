library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_output is 
    generic(
        PIXEL_WIDTH     : integer := 8;
        ADDR_WIDTH      : integer := 19;

        H_RES           : integer := 640;
        V_RES           : integer := 480;

        TEST_MODE       : boolean := true
    );
    port(
        clk             : in std_logic;
        rst             : in std_logic;

        hpos_i          : in integer;
        vpos_i          : in integer;
        
        hsync_i         : in std_logic;
        vsync_i         : in std_logic;

        active_i        : in std_logic;
        
        fifo_rdreq_o    : out std_logic;
        fifo_q_i        : in  std_logic_vector(PIXEL_WIDTH-1 downto 0);

        vga_hsync_o     : out std_logic;
        vga_vsync_o     : out std_logic;

        vga_r           : out std_logic_vector(PIXEL_WIDTH-1 downto 0);
        vga_g           : out std_logic_vector(PIXEL_WIDTH-1 downto 0);
        vga_b           : out std_logic_vector(PIXEL_WIDTH-1 downto 0)
    );
end vga_output;

architecture rtl_vga_out of vga_output is
    signal hsync_dly    : std_logic;
    signal vsync_dly    : std_logic;
    signal active_dly   : std_logic;
    signal rgb_dly      : std_logic_vector(7 downto 0);

begin

    fifo_rdreq_o <= active_i;   

    process (clk) 
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                hsync_dly   <= '0';
                vsync_dly   <= '0';
                active_dly  <= '0';
            else 
                hsync_dly   <= hsync_i;
                vsync_dly   <= vsync_i;
                active_dly  <= active_i;
            end if;
        end if;    
    end process;

    vga_hsync_o <= hsync_dly;
    vga_vsync_o <= vsync_dly;
    vga_r <= fifo_q_i when active_dly = '1' else (others => '0');
    vga_g <= fifo_q_i when active_dly = '1' else (others => '0');
    vga_b <= fifo_q_i when active_dly = '1' else (others => '0');

end rtl_vga_out;