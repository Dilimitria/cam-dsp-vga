library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_project is
    port(
        clk_50          : in std_logic;
        rst             : in std_logic;

        -- VGA outputs (были)
        vga_hsync       : out std_logic;
        vga_vsync       : out std_logic;
        vga_r           : out std_logic_vector(7 downto 0);
        vga_g           : out std_logic_vector(7 downto 0);
        vga_b           : out std_logic_vector(7 downto 0);
        vga_clk         : out std_logic;
        vga_blank_n     : out std_logic;
        vga_sync_n      : out std_logic;

        -- индикация FIFO (отладка)
        led_full        : out std_logic;
        led_empty       : out std_logic;

        -- ---- интерфейс камеры ---- 
        cam_pix_clk     : in std_logic;                     -- PIX_CLK камеры (100 МГц)
        cam_line_val    : in std_logic;                     -- LINE_VAL
        cam_frame_val   : in std_logic;                      -- FRAME_VAL
        cam_data        : in std_logic_vector(11 downto 0); -- данные байера
        -- I2C / управление (опционально, если нужно)
        cam_sclk        : out std_logic;                     -- SCLK
        cam_sdata       : inout std_logic;                   -- SDATA
        cam_reset       : out std_logic;                     -- сброс камеры (активный низкий)
        cam_trigger     : out std_logic;                     -- TRIGGER
        cam_xclkin      : out std_logic                      -- XCLKin (если нужно)
    );
end top_project;

architecture arch of top_project is
    signal clk_96, clk_24 : std_logic;
    signal pll_locked : std_logic;
    signal rst_96, rst_24 : std_logic;

    -- FIFO signals
    signal fifo_wrreq : std_logic;
    signal fifo_rdreq : std_logic;
    signal fifo_data  : std_logic_vector(7 downto 0);
    signal fifo_q     : std_logic_vector(7 downto 0);
    signal fifo_wrfull: std_logic;
    signal fifo_rdempty: std_logic;
    signal fifo_wrusedw: std_logic_vector(16 downto 0);

    -- Камера
    signal cam_r, cam_g, cam_b : std_logic_vector(7 downto 0);
    signal cam_valid : std_logic;
begin
    pll_inst : entity work.PLL_CAM
        port map (areset => '0', inclk0 => clk_50,
                  c0 => clk_24, c1 => clk_96, locked => pll_locked);

    process(clk_96) begin
        if rising_edge(clk_96) then rst_96 <= not pll_locked; end if;
    end process;
    process(clk_24) begin
        if rising_edge(clk_24) then rst_24 <= not pll_locked; end if;
    end process;

    -- FIFO асинхронный (write: 100 MHz, read: 24 MHz)
    fifo_inst : entity work.fifo
        port map (
            data    => fifo_data,
            wrclk   => clk_96,
            wrreq   => fifo_wrreq,
            wrfull  => fifo_wrfull,
            wrusedw => fifo_wrusedw,
            rdclk   => clk_24,
            rdreq   => fifo_rdreq,
            q       => fifo_q,
            rdempty => fifo_rdempty
        );

    -- Камера
    cam_inst : entity work.camer
        generic map (Line_scale => 640, Column_scale => 480, DEVIDE => 2000)
        port map (
            CLK          => clk_96,
            PIX_CLK      => cam_pix_clk,
            Line_VAL     => cam_line_val,
            Frame_VAL    => cam_frame_val,
            rst          => not rst,
            DATA         => cam_data,
            RESET        => cam_reset,
            XCLKin       => cam_xclkin,
            SDATA        => cam_sdata,
            TRIGGER      => cam_trigger,
            SCLK         => cam_sclk,
            rgb_r        => cam_r,
            rgb_g        => cam_g,
            rgb_b        => cam_b,
            PIX_OUT_VLD  => cam_valid,
            rgb_fval     => open,
            rgb_lval     => open
        );

    -- Преобразование RGB в яркость (усреднение)
    fifo_data <= cam_r;

    -- Управление записью в FIFO
    fifo_wrreq <= cam_valid and not fifo_wrfull;

    -- VGA модуль
    vga_inst : entity work.top_vga
        port map (
            clk_vga     => clk_24,
            rst         => rst,
            fifo_q      => fifo_q,
            fifo_rdreq  => fifo_rdreq,
            vga_hsync   => vga_hsync,
            vga_vsync   => vga_vsync,
            vga_r       => vga_r,
            vga_g       => vga_g,
            vga_b       => vga_b,
            vga_clk     => vga_clk,
            vga_blank_n => vga_blank_n,
            vga_sync_n  => vga_sync_n
        );

    led_full  <= fifo_wrfull;
    led_empty <= fifo_rdempty;
end architecture;