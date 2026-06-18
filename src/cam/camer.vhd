library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity camer is
    generic (
        LINE_SCALE   : integer := 640;    -- ширина выходного изображения
        COLUMN_SCALE : integer := 480;    -- высота
        CLK_DEVIDE   : integer := 1000    -- делитель для SCLK (должен быть кратен 4)
    );
    port (
        clk_main            : in  std_logic;                     -- системный такт (для I2C)
        cam_pix_clk         : in  std_logic;                     -- такт пикселей от камеры
        cam_line_vld        : in  std_logic;                     -- LVLD
        cam_frame_vld       : in  std_logic;                     -- FVLD
        rst_n               : in  std_logic;                     -- сброс (активный низкий)

        cam_data_i          : in  std_logic_vector(11 downto 0); -- 12‑битные данные

        cam_reset_o         : out std_logic;                     -- сброс камеры (активный низкий)
        cam_xclkin_o        : out std_logic;                     -- такт для камеры
        cam_sdata_io        : inout std_logic;                   -- I2C данные
        cam_trigger_photo   : out std_logic;                     -- триггер снимка
        clk_i2c             : out std_logic;                     -- I2C такт

        rgb_r               : out std_logic_vector(7 downto 0);
        rgb_g               : out std_logic_vector(7 downto 0);
        rgb_b               : out std_logic_vector(7 downto 0);
        rgb_pix_vld         : out std_logic;
        rgb_frame_vld       : out std_logic;
        rgb_line_vld        : out std_logic;

        -- вывод сырых данных с камеры (Bayer)
        bayer_data_o        : out std_logic_vector(11 downto 0);
        bayer_vld_o         : out std_logic;
        bayer_frame_vld_o   : out std_logic;
        bayer_line_vld_o    : out std_logic
    );
end camer;

architecture arch of camer is

    -- ========== Константы для I2C ==========
    constant LINE_SCALE_REG   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(LINE_SCALE, 16));
    constant COLUMN_SCALE_REG : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(COLUMN_SCALE, 16));
    constant CLK_MULTIPLY     : integer := 25000;   -- 25 МГц -> 1 мс (подстройте под clk_main)

    -- ========== Сигналы I2C ==========
    signal clk_i2c_reg : integer range 0 to CLK_DEVIDE := 0;
    signal counter     : integer range 0 to 31 := 0;
    signal reg_comm    : std_logic_vector(7 downto 0);
    signal sdata_out   : std_logic := '1';
    signal sdata_oe    : std_logic := '0';
    signal wati_time   : integer range 0 to (CLK_MULTIPLY / CLK_DEVIDE);

    -- ========== Сигналы дебайеринга и обрезки ==========
    type line_mem_t is array (0 to LINE_SCALE+1) of std_logic_vector(11 downto 0);
    signal line_mem             : line_mem_t;
    signal wr_addr              : integer range 0 to LINE_SCALE+1 := 0;
    signal Line_parity          : std_logic := '0';
    signal cam_line_vld_prev    : std_logic := '0';

    signal h_cnt       : integer range 0 to LINE_SCALE+1 := 0;
    signal v_cnt       : integer range 0 to COLUMN_SCALE+1 := 0;
    signal in_active   : boolean;

    signal Red_reg     : std_logic_vector(11 downto 0);
    signal Green_reg   : std_logic_vector(11 downto 0);
    signal Blue_reg    : std_logic_vector(11 downto 0);

    signal rgb_pix_vld_reg : std_logic := '0';

    -- задержки для синхронизации выходных сигналов
    signal rgb_frame_vld_delay : std_logic_vector(3 downto 0) := (others => '0');
    signal rgb_line_vld_delay  : std_logic_vector(3 downto 0) := (others => '0');
    signal rgb_pix_vld_delay   : std_logic_vector(3 downto 0) := (others => '0');

    -- ========== Тип состояний I2C ==========
    type state_type is (
        st_transfer, st_ask, st_unres, st_wait, st_loading,
        st_start, st_id,
        st_reg_res1, st_reg_res2, st_com_res1, st_com_res2,
        st_reg_pll1, st_reg_pll2, st_com_pll1, st_com_pll2,
        st_reg_pll21, st_reg_pll22, st_com_pll21, st_com_pll22,
        st_reg_inf1, st_reg_inf2, st_com_inf1, st_com_inf2,
        st_blc_off1, st_blc_off2, st_blc_off3,
        st_test_pattern, st_test_pattern_data,
        st_reg_lin1, st_reg_lin2, st_com_lin1, st_com_lin2,
        st_reg_col1, st_reg_col2, st_com_col1, st_com_col2,
        st_end, st_end_out
    );
    signal state, prev_state, next_state : state_type;

begin

    -- ======================================================================
    -- 1. Выходы, не связанные с I2C или дебайерингом
    -- ======================================================================
    cam_trigger_photo   <= '0';
    cam_xclkin_o        <= clk_main;          -- подаём системный такт на камеру
    clk_i2c             <= '1' when clk_i2c_reg >= CLK_DEVIDE/2 else '0';
    cam_sdata_io        <= sdata_out when sdata_oe = '1' else 'Z';

    -- ======================================================================
    -- 2. Выходы сырых байеровских данных (прямой пропуск)
    -- ======================================================================
    bayer_data_o        <= cam_data_i;
    bayer_vld_o         <= cam_line_vld and cam_frame_vld;
    bayer_frame_vld_o   <= cam_frame_vld;
    bayer_line_vld_o    <= cam_line_vld;

    -- ======================================================================
    -- 3. Процесс I2C управления (автомат)
    -- ======================================================================
    process(clk_main, rst_n)
    begin
        if rst_n = '0' then
            clk_i2c_reg    <= 0;
            state      <= st_unres;
            prev_state <= st_unres;
            next_state <= st_unres;
            counter    <= 0;
            sdata_oe   <= '1';
            sdata_out  <= '1';
            reg_comm   <= x"00";
            cam_reset_o <= '0';
        elsif rising_edge(clk_main) then
            -- генератор счётчика для SCLK
            if clk_i2c_reg = CLK_DEVIDE-1 then
                clk_i2c_reg <= 0;
            else
                clk_i2c_reg <= clk_i2c_reg + 1;
            end if;

            -- автомат срабатывает в середине низкого/высокого уровня SCLK
            if (clk_i2c_reg = CLK_DEVIDE/4) or ((state = st_ask or state = st_start or state = st_end) and clk_i2c_reg = CLK_DEVIDE*3/4) then
                case state is
                    -- отправка байта
                    when st_transfer =>
                        sdata_oe <= '1';
                        if counter < 8 then
                            sdata_out <= reg_comm(7 - counter);
                            counter   <= counter + 1;
                        else
                            counter   <= 0;
                            sdata_oe  <= '0';
                            state     <= st_wait;
                        end if;

                    -- задержка перед чтением ACK
                    when st_wait =>
                        state <= st_ask;

                    -- проверка ACK
                    when st_ask =>
                        if cam_sdata_io = '0' then
                            state <= next_state;
                        else
                            state <= prev_state;
                        end if;

                    -- задержка (1 мс) для стабилизации питания/PLL
                    when st_loading =>
                        if wati_time = (CLK_MULTIPLY / CLK_DEVIDE) then
                            state     <= prev_state;
                            wati_time <= 0;
                        else
                            wati_time <= wati_time + 1;
                        end if;

                    -- аппаратный сброс камеры
                    when st_unres =>
                        cam_reset_o <= '1';
                        state <= st_loading;
                        prev_state <= st_start;

                    -- начало I2C транзакции (START)
                    when st_start =>
                        if clk_i2c_reg = CLK_DEVIDE*3/4 then
                            sdata_oe  <= '1';
                            sdata_out <= '0';
                            state     <= st_id;
                        end if;

                    -- ID устройства (0xBA)
                    when st_id =>
                        reg_comm   <= x"BA";
                        state      <= st_transfer;
                        prev_state <= st_id;
                        next_state <= st_reg_res1;

                    -- === Мягкий сброс (0x000D = 0x0001) ===
                    when st_reg_res1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_reg_res1;
                        next_state <= st_reg_res2;
                    when st_reg_res2 =>
                        reg_comm   <= x"09";
                        state      <= st_transfer;
                        prev_state <= st_reg_res2;
                        next_state <= st_com_res1;
                    when st_com_res1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_res1;
                        next_state <= st_com_res2;
                    when st_com_res2 =>
                        reg_comm   <= x"01";
                        prev_state <= st_reg_pll1;
                        next_state <= st_loading;
                        state      <= st_transfer;

                    -- === Настройка PLL (Pixel Clock Control 0x0A = 0x0000) ===
                    when st_reg_pll1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_reg_pll1;
                        next_state <= st_reg_pll2;
                    when st_reg_pll2 =>
                        reg_comm   <= x"0A";
                        state      <= st_transfer;
                        prev_state <= st_reg_pll2;
                        next_state <= st_com_pll1;
                    when st_com_pll1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_pll1;
                        next_state <= st_com_pll2;
                    when st_com_pll2 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_pll2;
                        next_state <= st_reg_pll21;

                    -- === Настройка PLL (Control 0x10 = 0x0000 – bypass) ===
                    when st_reg_pll21 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_reg_pll21;
                        next_state <= st_reg_pll22;
                    when st_reg_pll22 =>
                        reg_comm   <= x"10";
                        state      <= st_transfer;
                        prev_state <= st_reg_pll22;
                        next_state <= st_com_pll21;
                    when st_com_pll21 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_pll21;
                        next_state <= st_com_pll22;
                    when st_com_pll22 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_pll22;
                        next_state <= st_reg_inf1;

                    -- === Непрерывный режим (0x0B = 0x0000) ===
                    when st_reg_inf1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_reg_inf1;
                        next_state <= st_reg_inf2;
                    when st_reg_inf2 =>
                        reg_comm   <= x"0B";
                        state      <= st_transfer;
                        prev_state <= st_reg_inf2;
                        next_state <= st_com_inf1;
                    when st_com_inf1 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_inf1;
                        next_state <= st_com_inf2;
                    when st_com_inf2 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_com_inf2;
                        next_state <= st_blc_off1;

                    -- === Отключение BLC (0x62 = 0x0000) ===
                    when st_blc_off1 =>
                        reg_comm   <= x"62";
                        state      <= st_transfer;
                        prev_state <= st_blc_off1;
                        next_state <= st_blc_off2;
                    when st_blc_off2 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_blc_off2;
                        next_state <= st_blc_off3;
                    when st_blc_off3 =>
                        reg_comm   <= x"00";
                        state      <= st_transfer;
                        prev_state <= st_blc_off3;
                        next_state <= st_test_pattern;

                    -- === Включение тестового паттерна (0x0C = 0x02) ===
                    when st_test_pattern =>
                        reg_comm   <= x"0C";
                        state      <= st_transfer;
                        prev_state <= st_test_pattern;
                        next_state <= st_test_pattern_data;
                    when st_test_pattern_data =>
                        reg_comm   <= x"02";   -- вертикальные цветные полосы
                        state      <= st_transfer;
                        prev_state <= st_test_pattern_data;
                        next_state <= st_reg_lin1;

                    -- === Установка размера окна (ширина) ===
                    when st_reg_lin1 =>
                        reg_comm   <= x"03";
                        state      <= st_transfer;
                        prev_state <= st_reg_lin1;
                        next_state <= st_reg_lin2;
                    when st_reg_lin2 =>
                        reg_comm   <= x"46";
                        state      <= st_transfer;
                        prev_state <= st_reg_lin2;
                        next_state <= st_com_lin1;
                    when st_com_lin1 =>
                        reg_comm   <= LINE_SCALE_REG(15 downto 8);
                        state      <= st_transfer;
                        prev_state <= st_com_lin1;
                        next_state <= st_com_lin2;
                    when st_com_lin2 =>
                        reg_comm   <= LINE_SCALE_REG(7 downto 0);
                        state      <= st_transfer;
                        prev_state <= st_com_lin2;
                        next_state <= st_reg_col1;

                    -- === Установка размера окна (высота) ===
                    when st_reg_col1 =>
                        reg_comm   <= x"03";
                        state      <= st_transfer;
                        prev_state <= st_reg_col1;
                        next_state <= st_reg_col2;
                    when st_reg_col2 =>
                        reg_comm   <= x"44";
                        state      <= st_transfer;
                        prev_state <= st_reg_col2;
                        next_state <= st_com_col1;
                    when st_com_col1 =>
                        reg_comm   <= COLUMN_SCALE_REG(15 downto 8);
                        state      <= st_transfer;
                        prev_state <= st_com_col1;
                        next_state <= st_com_col2;
                    when st_com_col2 =>
                        reg_comm   <= COLUMN_SCALE_REG(7 downto 0);
                        state      <= st_transfer;
                        prev_state <= st_com_col2;
                        next_state <= st_end;

                    -- === Завершение I2C (STOP) ===
                    when st_end =>
                        counter <= 0;
                        if clk_i2c_reg >= CLK_DEVIDE/2 then
                            sdata_oe  <= '1';
                            sdata_out <= '1';
                            state     <= st_end_out;
                        end if;

                    when st_end_out =>
                        sdata_oe <= '0';
                        -- после инициализации сброс больше не трогаем

                    when others =>
                        state <= st_start;
                end case;
            end if;
        end if;
    end process;

    -- ======================================================================
    -- 4. Процесс дебайеринга и обрезки кадра (с использованием счётчиков)
    -- ======================================================================
    in_active <= (h_cnt < LINE_SCALE) and (v_cnt < COLUMN_SCALE);

    process(cam_pix_clk, rst_n)
    begin
        if rst_n = '0' then
            -- сброс всех внутренних сигналов
            h_cnt <= 0;
            v_cnt <= 0;
            wr_addr <= 0;
            Line_parity <= '0';
            cam_line_vld_prev <= '0';
            Red_reg <= (others => '0');
            Green_reg <= (others => '0');
            Blue_reg <= (others => '0');
            rgb_pix_vld_reg <= '0';
            rgb_frame_vld_delay <= (others => '0');
            rgb_line_vld_delay <= (others => '0');
            rgb_pix_vld_delay <= (others => '0');

        elsif rising_edge(cam_pix_clk) then
            rgb_pix_vld_reg <= '0';
            -- детектор фронта LINE_VLD
            cam_line_vld_prev <= cam_line_vld;

            -- обновление счётчиков
            if cam_frame_vld = '1' then
                if cam_line_vld = '1' then
                    if h_cnt < LINE_SCALE then
                        h_cnt <= h_cnt + 1;
                    end if;
                    if cam_line_vld_prev = '0' and cam_line_vld = '1' then
                        Line_parity <= not Line_parity;
                        v_cnt <= v_cnt + 1;
                        wr_addr <= 0;
                    end if;
                else
                    h_cnt <= 0;
                end if;
            else
                v_cnt <= 0;
                h_cnt <= 0;
                Line_parity <= '0';
                wr_addr <= 0;
            end if;

            -- обработка пикселей только в активной области
            if cam_frame_vld = '1' and cam_line_vld = '1' and in_active then

                -- запись текущего пикселя в память (для чётных строк)
                if Line_parity = '0' then
                    line_mem(wr_addr) <= cam_data_i;
                end if;

                -- дебайеринг (для нечётных строк)
                if Line_parity = '1' then
                    if (wr_addr mod 2) = 0 then
                        Blue_reg   <= cam_data_i;
                        Green_reg  <= line_mem(wr_addr);
                        Red_reg    <= line_mem(wr_addr+1);
                    else
                        rgb_pix_vld_reg <= '1';
                    end if;
                end if;

                -- инкремент адреса записи
                if wr_addr < LINE_SCALE-1 then
                    wr_addr <= wr_addr + 1;
                else
                    wr_addr <= 0;
                end if;

            else
            end if;

            -- задержка выходных сигналов (3 такта)
            rgb_frame_vld_delay     <= rgb_frame_vld_delay(2 downto 0) & cam_frame_vld;
            rgb_line_vld_delay     <= rgb_line_vld_delay(2 downto 0) & cam_line_vld;
            rgb_pix_vld_delay   <= rgb_pix_vld_delay(2 downto 0)  & rgb_pix_vld_reg;

            rgb_frame_vld   <= rgb_frame_vld_delay(3);
            rgb_line_vld   <= rgb_line_vld_delay(3);
            rgb_pix_vld <= rgb_pix_vld_delay(3);

        end if;
    end process;

    -- выходные RGB (8 бит)
    rgb_r <= Red_reg(11 downto 4);
    rgb_g <= std_logic_vector( (unsigned(Green_reg) + unsigned(cam_data_i)) / 2 )(11 downto 4);
    rgb_b <= Blue_reg(11 downto 4);

end arch;