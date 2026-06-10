library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_sync is
    generic(
        H_SYNC      : integer := 96;
        H_BACK      : integer := 48;
        H_VISIBLE   : integer := 640;
        H_FRONT     : integer := 16;

        V_SYNC      : integer := 2;
        V_BACK      : integer := 33;
        V_VISIBLE   : integer := 480;
        V_FRONT     : integer := 10
    );
    port (
        clk         : in std_logic;
        rst         : in std_logic;

        hsync_o     : out std_logic;
        vsync_o     : out std_logic;

        hpos_o      : out integer;
        vpos_o      : out integer;
        
        active_o    : out std_logic
    );
end vga_sync;



architecture rtl_vga_sync of vga_sync is
    constant V_TOTAL  : integer := V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
    constant H_TOTAL  : integer := H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    signal h_cnt : integer range 0 to H_TOTAL-1;
    signal v_cnt : integer range 0 to V_TOTAL-1;

    
begin
    hsync_o  <= '0' when (h_cnt < H_SYNC) else '1';
    vsync_o  <= '0' when (v_cnt < V_SYNC) else '1';

    active_o <= '1' when ((h_cnt >= H_SYNC + H_BACK) and
                    (h_cnt < H_SYNC + H_BACK + H_VISIBLE) and
                    (v_cnt >= V_SYNC + V_BACK) and
                    (v_cnt < V_SYNC + V_BACK + V_VISIBLE)) else '0';
                        
    hpos_o  <= (h_cnt - (H_SYNC + H_BACK)) 
            when active_o = '1' else 0;
    vpos_o  <= (v_cnt - (V_SYNC + V_BACK)) 
            when active_o = '1' else 0;

    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                h_cnt <= 0;
                v_cnt <= 0;
            else 
                if h_cnt = H_TOTAL - 1 then
                    h_cnt <= 0;
                    if v_cnt = V_TOTAL - 1 then
                        v_cnt <= 0;
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;
            end if;
        end if;       
    end process; 
end architecture rtl_vga_sync;
