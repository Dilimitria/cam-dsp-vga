library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_vga is
    port(
        clk_vga         : in  std_logic;
        rst             : in  std_logic;
        -- новые порты для памяти
        rd_data         : in  std_logic_vector(0 downto 0);   -- 1 бит от буфера
        rd_addr         : out std_logic_vector(18 downto 0);  -- 19 бит адреса
        rd_en           : out std_logic;                      -- разрешение чтения
        -- VGA выходы
        vga_hsync       : out std_logic;
        vga_vsync       : out std_logic;
        vga_r           : out std_logic_vector(7 downto 0);
        vga_g           : out std_logic_vector(7 downto 0);
        vga_b           : out std_logic_vector(7 downto 0);
        vga_clk         : out std_logic;
        vga_blank_n     : out std_logic;
        vga_sync_n      : out std_logic;
        vga_frame_end   : out std_logic 
    );
end top_vga;

architecture rtl_top_vga of top_vga is
    signal hsync, vsync, active : std_logic;
    signal hpos, vpos : integer;
    signal frame_end : std_logic;
begin
    sync_inst: entity work.vga_sync
        generic map(
            H_SYNC    => 96, H_BACK => 48, H_VISIBLE => 640, H_FRONT => 16,
            V_SYNC    => 2,  V_BACK => 33, V_VISIBLE => 480, V_FRONT => 10
        )
        port map(
            clk         => clk_vga,
            rst         => rst,
            hsync_o     => hsync,
            vsync_o     => vsync,
            hpos_o      => hpos,
            vpos_o      => vpos,
            active_o    => active,
            frame_end_o => frame_end
        );

    out_inst: entity work.vga_output
        generic map(
            PIXEL_WIDTH => 1,          -- бинаризированное изображение
            H_RES       => 640,
            V_RES       => 480,
            TEST_MODE   => false
        )
        port map(
            clk             => clk_vga,
            rst             => rst,
            hpos_i          => hpos,
            vpos_i          => vpos,
            hsync_i         => hsync,
            vsync_i         => vsync,
            active_i        => active,
            rd_data_i       => rd_data,
            rd_addr_o       => rd_addr,
            rd_en_o         => rd_en,
            vga_hsync_o     => vga_hsync,
            vga_vsync_o     => vga_vsync,
            vga_r           => vga_r,
            vga_g           => vga_g,
            vga_b           => vga_b
        );

    vga_clk     <= clk_vga;
    vga_frame_end <= frame_end;
    vga_blank_n <= '1';
    vga_sync_n  <= '0';
end rtl_top_vga;