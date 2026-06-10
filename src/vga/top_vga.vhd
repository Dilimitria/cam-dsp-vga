library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_vga is
    port(
        clk_vga         : in  std_logic;
        rst             : in  std_logic;
        fifo_q          : in  std_logic_vector(7 downto 0);
        fifo_rdreq      : out std_logic;
        vga_hsync       : out std_logic;
        vga_vsync       : out std_logic;
        vga_r           : out std_logic_vector(7 downto 0);
        vga_g           : out std_logic_vector(7 downto 0);
        vga_b           : out std_logic_vector(7 downto 0);
        vga_clk         : out std_logic;
        vga_blank_n     : out std_logic;
        vga_sync_n      : out std_logic
    );
end top_vga;

architecture rtl_top_vga of top_vga is
    signal hsync, vsync, active : std_logic;
    signal hpos, vpos : integer;
begin
    sync_inst: entity work.vga_sync
        generic map(
            H_SYNC    => 96, H_BACK => 48, H_VISIBLE => 640, H_FRONT => 16,
            V_SYNC    => 2,  V_BACK => 33, V_VISIBLE => 480, V_FRONT => 10
        )
        port map(
            clk      => clk_vga,
            rst      => rst,
            hsync_o  => hsync,
            vsync_o  => vsync,
            hpos_o   => hpos,
            vpos_o   => vpos,
            active_o => active
        );

    out_inst: entity work.vga_output
        generic map(
            PIXEL_WIDTH => 8,
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
            fifo_q_i        => fifo_q,
            fifo_rdreq_o    => fifo_rdreq,
            vga_hsync_o     => vga_hsync,
            vga_vsync_o     => vga_vsync,
            vga_r           => vga_r,
            vga_g           => vga_g,
            vga_b           => vga_b
        );

    vga_clk     <= clk_vga;
    vga_blank_n <= '1';
    vga_sync_n  <= '0';
end rtl_top_vga;