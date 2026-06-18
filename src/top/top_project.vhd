library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_project is
    generic(
        H_VISIBLE       : integer := 1280;
        V_VISIBLE       : integer := 960
    );
    port(
        clk_50          : in  std_logic;
        rst             : in  std_logic;

        vga_hsync       : out std_logic;
        vga_vsync       : out std_logic;
        vga_r           : out std_logic_vector(7 downto 0);
        vga_g           : out std_logic_vector(7 downto 0);
        vga_b           : out std_logic_vector(7 downto 0);
        vga_clk         : out std_logic;
        vga_blank_n     : out std_logic;
        vga_sync_n      : out std_logic;

        led_1           : out std_logic;
        led_0           : out std_logic;

        cam_pix_clk     : in  std_logic;
        cam_line_val    : in  std_logic;
        cam_frame_val   : in  std_logic;
        cam_data        : in  std_logic_vector(11 downto 0);
        cam_sclk        : out std_logic;
        cam_sdata       : inout std_logic;
        cam_reset_n     : out std_logic;
        cam_trigger     : out std_logic;
        cam_xclkin      : out std_logic;

        use_test_data   : in std_logic
    );
end top_project;

architecture arch of top_project is
    signal clk_96, clk_24           : std_logic;
    signal pll_locked               : std_logic;
    signal rst_96, rst_24           : std_logic;

    -- Камера
    signal rgb_r, rgb_g, rgb_b      : std_logic_vector(7 downto 0);
    signal rgb_pix_vld              : std_logic;
    signal rgb_frame_vld            : std_logic;
    signal rgb_line_vld             : std_logic;

    signal bayer_data               : std_logic_vector(11 downto 0);
    signal bayer_valid              : std_logic;
	signal bayer_fval               : std_logic;
    signal bayer_lval               : std_logic;

    -- Буферизация
    signal wr_addr_cnt              : integer range 0 to 307199 := 0;
    signal h_cnt                    : integer range 0 to H_VISIBLE - 1;
    signal v_cnt                    : integer range 0 to V_VISIBLE - 1;
    signal bin_data                 : std_logic_vector(0 downto 0);
    signal wr_bank, rd_bank         : std_logic := '0';
    signal wr_en_bank0, wr_en_bank1 : std_logic;
    
    signal rd_data_from_bank0       : std_logic_vector(0 downto 0);
    signal rd_data_from_bank1       : std_logic_vector(0 downto 0);
    signal rd_data_mux              : std_logic_vector(0 downto 0);

    signal frame_ready              : std_logic := '0';  -- импульс в домене cam_pix_clk
    signal frame_ready_sync1        : std_logic := '0';  -- синхронизатор стадия 1 (clk_24)
    signal frame_ready_sync2        : std_logic := '0';  -- синхронизатор стадия 2
   
    signal frame_clear              : std_logic := '0';  -- подтверждение из домена clk_24
    signal frame_clear_sync1        : std_logic := '0';  -- синхронизатор clear в cam_pix_clk
    signal frame_clear_sync2        : std_logic := '0';
    
    -- VGA
    signal vga_rd_addr              : std_logic_vector(18 downto 0);
    signal vga_rd_en                : std_logic;
    signal vga_frame_end            : std_logic;
 
begin
    -- -----------------------------------------------------------------
    -- Инстансы блоков
    -- -----------------------------------------------------------------
    -- -----------------------------------------------------------------
    -- Два экземпляра frame_buffer
    -- -----------------------------------------------------------------
    bank0: entity work.frame_buffer
        generic map (H_RES => H_VISIBLE, V_RES => V_VISIBLE, PIXEL_WIDTH => 1)
        port map (
            clk_wr  => cam_pix_clk,
            clk_rd  => clk_24,
            rst     => rst,
            wr_en   => wr_en_bank0,
            wr_addr => wr_addr_cnt,
            wr_data => bin_data,
            rd_addr => to_integer(unsigned(vga_rd_addr)),
            rd_data => rd_data_from_bank0
        );

    bank1: entity work.frame_buffer
        generic map (H_RES => H_VISIBLE, V_RES => V_VISIBLE, PIXEL_WIDTH => 1)
        port map (
            clk_wr  => cam_pix_clk,
            clk_rd  => clk_24,
            rst     => rst,
            wr_en   => wr_en_bank1,
            wr_addr => wr_addr_cnt,
            wr_data => bin_data,
            rd_addr => to_integer(unsigned(vga_rd_addr)),
            rd_data => rd_data_from_bank1
        );
    -- -----------------------------------------------------------------
    -- VGA модуль
    -- -----------------------------------------------------------------
    vga_inst : entity work.top_vga
        port map (
            clk_vga         => clk_24,
            rst             => rst,
            rd_data         => rd_data_mux,
            rd_addr         => vga_rd_addr,
            rd_en           => vga_rd_en,
            vga_hsync       => vga_hsync,
            vga_vsync       => vga_vsync,
            vga_r           => vga_r,
            vga_g           => vga_g,
            vga_b           => vga_b,
            vga_clk         => vga_clk,
            vga_blank_n     => vga_blank_n,
            vga_sync_n      => vga_sync_n,
            vga_frame_end   => vga_frame_end
        );
    -- -----------------------------------------------------------------
    -- Камера
    -- -----------------------------------------------------------------
    cam_inst : entity work.camer
        generic map (LINE_SCALE => H_VISIBLE, COLUMN_SCALE => V_VISIBLE, CLK_DEVIDE => 2000)
        port map (
            clk_main            => clk_96,
            cam_pix_clk         => cam_pix_clk,
            cam_line_vld        => cam_line_val,      
            cam_frame_vld       => cam_frame_val,
            rst_n               => not rst,

            cam_data_i          => cam_data,
            cam_reset_o         => cam_reset_n,
            cam_xclkin_o        => cam_xclkin,
            cam_sdata_io        => cam_sdata,
            cam_trigger_photo   => cam_trigger,
            clk_i2c             => cam_sclk,

            rgb_r               => rgb_r,
            rgb_g               => rgb_g,
            rgb_b               => rgb_b,
            rgb_pix_vld         => rgb_pix_vld,
            rgb_frame_vld       => rgb_frame_vld,
            rgb_line_vld        => rgb_line_vld,

            bayer_data_o        => bayer_data,
            bayer_vld_o         => bayer_valid,
		    bayer_frame_vld_o   => bayer_fval, 
            bayer_line_vld_o    => bayer_lval
        );
    -- -----------------------------------------------------------------
    -- PLL
    -- -----------------------------------------------------------------
    PLL_CAM_inst : entity work.PLL_CAM
        port map ( 
            areset  => '0', 
            inclk0  => clk_50, 
            c0      => clk_24, 
            c1      => clk_96, 
            locked  => pll_locked 
        );
    -- -----------------------------------------------------------------
    -- Формирование данных (бинарное изображение)
    -- -----------------------------------------------------------------
    process(cam_pix_clk)
        variable x_pos : integer range 0 to H_VISIBLE-1;
    begin
        if rising_edge(cam_pix_clk) then
            if use_test_data = '1' then
                x_pos := wr_addr_cnt mod H_VISIBLE;
                if (x_pos / 80) mod 2 = 0 then
                    bin_data(0) <= '1';
                else
                    bin_data(0) <= '0';
                end if;
            else
                if unsigned(rgb_g) > 100 then
                    bin_data(0) <= '1';
                else
                    bin_data(0) <= '0';
                end if;
            end if;
        end if;
    end process;

    -- -----------------------------------------------------------------
    -- Управление банками через счетчик и конец кадров
    -- -----------------------------------------------------------------
    process(cam_pix_clk, rst)
        variable fval_reg : std_logic := '0';
    begin
        if rst = '1' then
            wr_addr_cnt         <= 0;
            wr_bank             <= '0';
            frame_ready         <= '0';
            fval_reg            := '0';

            frame_clear_sync1   <= '0';
            frame_clear_sync2   <= '0';

        elsif rising_edge(cam_pix_clk) then
            if fval_reg = '1' and rgb_frame_vld = '0' then
                frame_ready <= '1';   
                wr_addr_cnt <= 0;
                wr_bank <= not wr_bank;  
            end if;
            fval_reg := rgb_frame_vld;

            if rgb_pix_vld = '1' then
                if wr_addr_cnt < 307199 then
                    wr_addr_cnt <= wr_addr_cnt + 1;
                end if;
            end if;

            frame_clear_sync1 <= frame_clear;
            frame_clear_sync2 <= frame_clear_sync1;
            if frame_clear_sync2 = '1' then
                frame_ready <= '0';
            end if;
        end if;
    end process;

    process(clk_24, rst)
    begin
        if rst = '1' then
            frame_ready_sync1 <= '0';
            frame_ready_sync2 <= '0';
            frame_clear <= '0';
            rd_bank <= '0';

        elsif rising_edge(clk_24) then
            frame_ready_sync1 <= frame_ready;
            frame_ready_sync2 <= frame_ready_sync1;

            if frame_ready_sync2 = '1' and vga_frame_end = '1' then
                rd_bank <= not rd_bank;      
                frame_clear <= '1';           
            else
                frame_clear <= '0';
            end if;
        end if;
    end process;

    wr_en_bank0 <= '1' when wr_bank = '0' and rgb_pix_vld = '1' else '0';
    wr_en_bank1 <= '1' when wr_bank = '1' and rgb_pix_vld = '1' else '0';

    rd_data_mux <= rd_data_from_bank0 when rd_bank = '0' else rd_data_from_bank1;
    --rd_data_mux <= rd_data_from_bank0;
    -- -----------------------------------------------------------------
    -- Отладочные светодиоды
    -- -----------------------------------------------------------------
    led_1 <= wr_bank;   
    led_0 <= rd_bank;

end architecture;