library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga is
    generic(
        H_VISIBLE   : integer := 1280;
        H_FRONT     : integer := 110;
        H_SYNC      : integer := 40;
        H_BACK      : integer := 220;

        V_VISIBLE   : integer := 720;
        V_FRONT     : integer := 5;
        V_SYNC      : integer := 5;
        V_BACK      : integer := 20;
    );
    port (
        clk         : in std_logic;
        rst         : in std_logic;

        hsync_o     : out std_logic;
        vsync_o     : out std_logic;
        hpos_o      : out std_logic;
        vpos_o      : out std_logic;
        
        active_o    : out std
    );
end vga;

architecture 