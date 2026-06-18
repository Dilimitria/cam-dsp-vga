library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer is
    generic(
        H_RES       : integer := 640;          -- ширина кадра
        V_RES       : integer := 480;          -- высота кадра
        PIXEL_WIDTH : integer := 1             -- бит на пиксель (1 для бинаризации)
    );
    port(
        clk_wr      : in  std_logic;           -- такт записи (96 МГц)
        clk_rd      : in  std_logic;           -- такт чтения (24 МГц)
        rst         : in  std_logic;           -- сброс (активный высокий)
        wr_en       : in  std_logic;           -- разрешение записи
        wr_addr     : in  integer range 0 to H_RES*V_RES-1;
        wr_data     : in  std_logic_vector(PIXEL_WIDTH-1 downto 0);
        rd_addr     : in  integer range 0 to H_RES*V_RES-1;
        rd_data     : out std_logic_vector(PIXEL_WIDTH-1 downto 0)
    );
end frame_buffer;

architecture rtl of frame_buffer is
    constant DEPTH : integer := H_RES * V_RES;
    type ram_type is array (0 to DEPTH - 1) of std_logic_vector(PIXEL_WIDTH - 1 downto 0);
    signal ram : ram_type;
    signal rd_addr_reg : integer range 0 to DEPTH-1;

    -- принудительное использование M9K
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";
begin
    -- процесс записи (такт clk_wr)
    process(clk_wr)
    begin
        if rising_edge(clk_wr) then
            if wr_en = '1' then
                ram(wr_addr) <= wr_data;
            end if;
        end if;
    end process;

    -- процесс чтения (такт clk_rd), с регистрацией адреса
    process(clk_rd)
    begin
        if rising_edge(clk_rd) then
            rd_addr_reg <= rd_addr;
            rd_data <= ram(rd_addr_reg);
        end if;
    end process;
end rtl;