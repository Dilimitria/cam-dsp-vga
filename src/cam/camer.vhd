library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity camer is
	generic (
	Line_scale 	 : integer := 640;                                                   -- ширина изображения
	Column_scale : integer := 480;													 -- высота изображения
	DEVIDE		 : integer := 1000 													 -- коэффициент деления тактового сигнала для отправки команд (макс 400кГц) !ДОЛЖЕН БЫТЬ КРАТЕН 4!
	);
	port (
		CLK             	: in  std_logic;                                         -- тактовый сигнал плисы (для отправки команд)
		PIX_CLK          	: in  std_logic;                                         -- тактовый сигнал от камеры
		Line_VAL			: in  std_logic;										 -- сигнал означает что передаем строку
		Frame_VAL			: in  std_logic;										 -- сигнал означает что передаем кадр
		rst					: in  std_logic;
		
		DATA              	: in  std_logic_vector(11 downto 0) := x"000"; 		     -- 12-битная шина данных
		RESET 	            : out std_logic;                                         -- перезагрузка камеры
		XCLKin				: out std_logic;										 -- тактирование канала команд
		SDATA				: inout std_logic;										 -- последовательный канал команд
		TRIGGER				: out std_logic;										 -- команда "сделать снимок"
		-- преобразование в RGB
		SCLK		: out std_logic; 												 -- тактовый сигнал управления камерой
		rgb_r       : out std_logic_vector(7 downto 0);
        rgb_g       : out std_logic_vector(7 downto 0);
        rgb_b       : out std_logic_vector(7 downto 0);
		PIX_OUT_VLD : out std_logic;
        rgb_fval    : out std_logic;
        rgb_lval    : out std_logic
		);
end camer;

architecture arch of camer is

constant Line_scale_vect 	: std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(Line_scale, 16));
constant Column_scale_vect  : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(Column_scale, 16));
constant CLK_MULTIPLY		: integer := 25000;			-- во сколько раз частота CLK больше частоты 1кГц (для ожидания сброса 1мс)

type   memor is array (0 to Line_scale) of std_logic_vector(11 downto 0);
signal line_mem			: memor;
signal wr_addr 			: integer range 0 to Line_scale;
signal Line_parity 		: std_logic := '0';
signal Red_reg			: std_logic_vector(11 downto 0);
signal Blue_reg			: std_logic_vector(11 downto 0);
signal Green_reg		: std_logic_vector(11 downto 0);
signal Comm_VLD 		: std_logic := '0';
signal CLK_dev			: integer range 0 to DEVIDE;
signal PIX_OUT_VLD_reg	: std_logic := '0';
signal reg_comm 		: std_logic_vector(7 downto 0);
signal counter			: integer range 0 to 31 ;
signal Line_VAL_reg		: std_logic := '0';
signal wati_time		: integer range 0 to (CLK_MULTIPLY / DEVIDE);
signal fval_delay       : std_logic_vector(2 downto 0);
signal lval_delay       : std_logic_vector(2 downto 0);

signal sdata_out 		: std_logic := '1';
signal sdata_oe  		: std_logic := '0';

type state_type is (st_transfer, st_ask, st_unres, st_wait, st_loading, st_start, st_id, st_reg_col1, st_reg_col2, st_reg_lin1, st_reg_lin2,
st_reg_res1, st_reg_res2, st_com_res1, st_com_res2, st_reg_inf1, st_reg_inf2, st_com_inf1, st_com_inf2,
st_reg_pll1, st_reg_pll2, st_com_pll1, st_com_pll2, st_reg_pll21, st_reg_pll22, st_com_pll21, st_com_pll22,
st_com_col1, st_com_col2, st_com_lin1, st_com_lin2, st_end, st_end_out);
signal prev_state, state, next_state : state_type;

begin
-- процесс для считывания данных
process (PIX_CLK, rst)
begin
	if rst = '0' then
		wr_addr  		<= 0;
		Line_parity 	<= '0';
		PIX_OUT_VLD_reg <= '0';
	
	elsif rising_edge(PIX_CLK) then
		if (Line_VAL = '1' and Line_VAL_reg = '0') then
			Line_parity <= not (Line_parity);
		end if;
		PIX_OUT_VLD_reg <= '0';
		if (Frame_VAL = '1') then
			if (Line_VAL = '1') then
				-- блок записи данных в память
				if (Line_parity = '0') then							--0,2,4... строки
					line_mem(wr_addr) <= DATA;
					PIX_OUT_VLD_reg <= '0';
				-- блок дебайеризации
				elsif ((wr_addr mod 2) = 0) then  					--0,2,4... ячейки памяти
					Blue_reg  <= DATA;
					Green_reg <= line_mem(wr_addr); 
					Red_reg   <= line_mem(wr_addr+1);
					PIX_OUT_VLD_reg <= '0';
				else
					PIX_OUT_VLD_reg <= '1';    							-- это крайний зеленый пиксель, мы накопили регистры, пожно выдавать на линию
				end if;
				if (wr_addr = Line_scale-1) then
						wr_addr <= 0;
				else 
						wr_addr <= wr_addr + 1;
				end if;
			end if;
		else 
			Line_parity <= '0';   									-- сброс четоности строки после окончания кадра
		end if;
	Line_VAL_reg <= Line_VAL;
	fval_delay <= fval_delay(1 downto 0) & Frame_VAL;
	lval_delay <= lval_delay(1 downto 0) & Line_VAL;
	rgb_fval <= fval_delay(2) and Line_parity;
	rgb_lval <= lval_delay(2) and Line_parity;
	TRIGGER  	 <= '0';
	end if;
	
end process;

PIX_OUT_VLD <= PIX_OUT_VLD_reg;
rgb_r <= Red_reg(11 downto 4);
rgb_g <= std_logic_vector( (unsigned(Green_reg) + unsigned(DATA)) / 2 )(11 downto 4);
rgb_b <= Blue_reg(11 downto 4);
XCLKin<= CLK;





-- процесс для команд управления
process(CLK, rst) 
begin
	if rst = '0' then
        CLK_dev   <= 0;
        state     <= st_unres;
		prev_state<= st_unres;
		next_state<= st_unres;
        counter   <= 0;
        sdata_oe  <= '1';
		sdata_out <= '1';          -- линия в высоком уровне (подтяжка)
		reg_comm  <= x"00";
		RESET <= '0';
    elsif rising_edge(CLK) then
		
        if CLK_dev = DEVIDE-1 then
			CLK_dev <= 0;
		else
			CLK_dev <= CLK_dev + 1;
		end if;
		if (CLK_dev = (DEVIDE/4) or ((state = st_ask or state = st_start or state = st_end) and CLK_dev = (DEVIDE*3/4))) then
            case state is
				-- кейс отправки байта данных с выводом линии в z состояние
				when st_transfer =>
					sdata_oe <= '1';
					if counter < 8 then
						sdata_out   <= reg_comm(7 - counter);
						counter 	<= counter + 1;
					else
						counter 	<= 0;
						sdata_oe 	<= '0';
						state 		<= st_wait;
					end if;
				-- кейс ожидания
				when st_wait =>
					state 		<= st_ask;
				-- кейс проверки принятия байта
                when st_ask =>
					if SDATA = '0' then
						state 		<= next_state;
					else
						state 		<= prev_state;
					end if;
				
				-- кейс задержки на много тактово для загрузки
				when st_loading =>
					if (wati_time = (CLK_MULTIPLY / DEVIDE)) then
						state     <= prev_state;
						wati_time <= 0;
					else
						wati_time <= wati_time + 1;
					end if;
				
				-- работа с аппаратным сбросом камеры
				when st_unres =>
					RESET <= '1';
					state <= st_loading;
					prev_state <= st_start;
				-- начало - опускание канала
                when st_start =>
					if (CLK_dev = (DEVIDE*3/4)) then
						sdata_oe  <= '1'; 
						sdata_out <= '0';
						state 	  <= st_id;
					end if;
				-- выбор id устройства
                when st_id	 =>
					reg_comm   <= x"BA";
					state 	   <= st_transfer;
					prev_state <= st_id;
					next_state <= st_reg_lin1;
					
				-- отправка регистра сброса настроек	
				when st_reg_res1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_reg_res1;
					next_state <= st_reg_res2;
				
				when st_reg_res2 =>
					reg_comm   <= x"09";
					state 	   <= st_transfer;
					prev_state <= st_reg_res2;
					next_state <= st_com_res1;
				-- отправка данных сброса настроек	
				when st_com_res1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_res1;
					next_state <= st_com_res2;
				
				when st_com_res2 =>
					reg_comm   <= x"01";
					prev_state <= st_reg_pll1;
					next_state <= st_loading;
					state      <= st_transfer;
					
				-- отправка регистра для настройки pll Pixel Clock Control
				when st_reg_pll1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_reg_pll1;
					next_state <= st_reg_pll2;
				
				when st_reg_pll2 =>
					reg_comm   <= x"0A";
					state 	   <= st_transfer;
					prev_state <= st_reg_pll2;
					next_state <= st_com_pll1;
				-- отправка данных для настройки pll Pixel Clock Control
				when st_com_pll1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_pll1;
					next_state <= st_com_pll2;
				
				when st_com_pll2 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_pll2;
					next_state <= st_reg_pll21;
					
				-- отправка регистра для настройки pll Control
				when st_reg_pll21 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_reg_pll21;
					next_state <= st_reg_pll22;
				
				when st_reg_pll22 =>
					reg_comm   <= x"10";
					state 	   <= st_transfer;
					prev_state <= st_reg_pll22;
					next_state <= st_com_pll21;
				-- отправка данных для настройки pll Control
				when st_com_pll21 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_pll21;
					next_state <= st_com_pll22;
				
				when st_com_pll22 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_pll22;
					next_state <= st_reg_inf1;
					
				-- отправка регистра для непрерывной съемки	
				when st_reg_inf1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_reg_inf1;
					next_state <= st_reg_inf2;
				
				when st_reg_inf2 =>
					reg_comm   <= x"0B";
					state 	   <= st_transfer;
					prev_state <= st_reg_inf2;
					next_state <= st_com_inf1;
				-- отправка данных для непрерывной съемки	
				when st_com_inf1 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_inf1;
					next_state <= st_com_inf2;
				
				when st_com_inf2 =>
					reg_comm   <= x"00";
					state 	   <= st_transfer;
					prev_state <= st_com_inf2;
					next_state <= st_reg_lin1;
					
				-- отправка регистра команды ширины строки	
				when st_reg_lin1 =>
					reg_comm   <= x"03";
					state 	   <= st_transfer;
					prev_state <= st_reg_lin1;
					next_state <= st_reg_lin2;
				
				when st_reg_lin2 =>
					reg_comm   <= x"46";
					state 	   <= st_transfer;
					prev_state <= st_reg_lin2;
					next_state <= st_com_lin1;
				-- отправка данных ширины строки	
				when st_com_lin1 =>
					reg_comm   <= Line_scale_vect(15 downto 8);
					state 	   <= st_transfer;
					prev_state <= st_com_lin1;
					next_state <= st_com_lin2;
				
				when st_com_lin2 =>
					reg_comm   <= Line_scale_vect(7 downto 0);
					state 	   <= st_transfer;
					prev_state <= st_com_lin2;
					next_state <= st_reg_col1;
				-- отправка регистра команды высоты столбца	
				when st_reg_col1 =>
					reg_comm   <= x"03";
					state 	   <= st_transfer;
					prev_state <= st_reg_col1;
					next_state <= st_reg_col2;
				
				when st_reg_col2 =>
					reg_comm   <= x"44";
					state 	   <= st_transfer;
					prev_state <= st_reg_col2;
					next_state <= st_com_col1;
				-- отправка данных ширины строки	
				when st_com_col1 =>
					reg_comm   <= Line_scale_vect(15 downto 8);
					state 	   <= st_transfer;
					prev_state <= st_com_col1;
					next_state <= st_com_col2;
				
				when st_com_col2 =>
					reg_comm   <= Line_scale_vect(7 downto 0);
					state 	   <= st_transfer;
					prev_state <= st_com_col2;
					next_state <= st_end;
				
				when st_end =>
					counter  <= 0;
					if (CLK_dev >= DEVIDE/2) then 
						sdata_oe <= '1';
						sdata_out <= '1';
						state <= st_end_out;
					end if;
				when st_end_out =>
					sdata_oe <= '0';
				when others =>
					state <= st_start;
			end case;
		end if;
	end if;
end process;	
SDATA <= sdata_out when sdata_oe = '1' else 'Z';
SCLK  <= '1' when CLK_dev >= DEVIDE/2 else '0';	
end arch;