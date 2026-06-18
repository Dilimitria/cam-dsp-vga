library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_output is 
    generic(
        PIXEL_WIDTH     : integer := 1;         
        ADDR_WIDTH      : integer := 19;       
        H_RES           : integer := 640;
        V_RES           : integer := 480;
        TEST_MODE       : boolean := false     
    );
    port(
        clk             : in std_logic;
        rst             : in std_logic;

        hpos_i          : in integer;
        vpos_i          : in integer;
        
        hsync_i         : in std_logic;
        vsync_i         : in std_logic;
        active_i        : in std_logic;
        
        -- интерфейс к буферу памяти
        rd_data_i       : in  std_logic_vector(PIXEL_WIDTH-1 downto 0);
        rd_addr_o       : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        rd_en_o         : out std_logic;

        vga_hsync_o     : out std_logic;
        vga_vsync_o     : out std_logic;
        vga_r           : out std_logic_vector(7 downto 0);
        vga_g           : out std_logic_vector(7 downto 0);
        vga_b           : out std_logic_vector(7 downto 0)
    );
end vga_output;

architecture rtl_vga_out of vga_output is
    signal hsync_dly    : std_logic;
    signal vsync_dly    : std_logic;
    signal active_dly   : std_logic;

    signal rd_data_dly  : std_logic_vector(PIXEL_WIDTH-1 downto 0);
    signal color_8b     : std_logic_vector(7 downto 0);
begin
    -- 1. Вычисление адреса и сигнала разрешения чтения
    rd_en_o <= active_i;
    process(clk)
    begin
        if rising_edge (clk) then
            if active_i = '1' then
                rd_addr_o <= std_logic_vector(to_unsigned(vpos_i * H_RES + hpos_i, ADDR_WIDTH));
            else
                rd_addr_o <= (others => '0');
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                hsync_dly   <= '0';
                vsync_dly   <= '0';
                active_dly  <= '0';

                rd_data_dly <= (others => '0');
            else
                hsync_dly   <= hsync_i;
                vsync_dly   <= vsync_i;
                active_dly  <= active_i;
                rd_data_dly <= rd_data_i;

            end if;
        end if;
    end process;

    color_8b <= (others => '1') when rd_data_i = "1" else (others => '0');

    vga_hsync_o <= hsync_dly;
    vga_vsync_o <= vsync_dly;
    
    vga_r <= color_8b when active_dly = '1' else (others => '0');
    vga_g <= color_8b when active_dly = '1' else (others => '0');
    vga_b <= color_8b when active_dly = '1' else (others => '0');
end rtl_vga_out;