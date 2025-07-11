-------------------------------------------------------------------------
--  Nano Apple IIe for Tang Nano 20k
--  2025 Stefan Voss
--  based on the work of many others
-------------------------------------------------------------------------
--
-- Apple II+ toplevel for the MiST board
-- https://github.com/wsoltys/mist_apple2
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nanoapple2 is
  port (
    clk_in      : in std_logic;
    s2_reset    : in std_logic; -- S2 button
    user        : in std_logic; -- S1 button
    leds_n      : out std_logic_vector(5 downto 0);
    -- onboard USB-C Tang BL616 UART
    uart_rx     : in std_logic;
    uart_tx     : out std_logic;
    -- external hw pin UART
    uart_ext_rx : in std_logic;
    uart_ext_tx : out std_logic;
    -- SPI interface Sipeed M0S Dock external BL616 uC
    --m0s         : inout std_logic_vector(4 downto 0);
    -- SPI connection to onboard BL616
    spi_sclk    : in std_logic;
    spi_csn     : in std_logic;
    spi_dir     : out std_logic;
    spi_dat     : in std_logic;
    spi_irqn    : out std_logic;
    -- internal lcd
    tmds_clk_n  : out std_logic;
    tmds_clk_p  : out std_logic;
    tmds_d_n    : out std_logic_vector( 2 downto 0);
    tmds_d_p    : out std_logic_vector( 2 downto 0);
    hpd_en      : in std_logic;
    -- sd interface
    sd_clk      : out std_logic;
    sd_cmd      : inout std_logic;
    sd_dat      : inout std_logic_vector(3 downto 0);

    ws2812       : out std_logic;
    -- "Magic" port names that the gowin compiler connects to the on-chip SDRAM
    O_sdram_clk  : out std_logic;
    O_sdram_cke  : out std_logic;
    O_sdram_cs_n : out std_logic;
    O_sdram_cas_n: out std_logic;
    O_sdram_ras_n: out std_logic;
    O_sdram_wen_n: out std_logic;
    IO_sdram_dq  : inout std_logic_vector(31 downto 0);
    O_sdram_addr : out std_logic_vector(10 downto 0);
    O_sdram_ba   : out std_logic_vector(1 downto 0);
    O_sdram_dqm  : out std_logic_vector(3 downto 0);
    -- Gamepad Dualshock P0
    ds_clk          : out std_logic;
    ds_mosi         : out std_logic;
    ds_miso         : in std_logic;
    ds_cs           : out std_logic;
    -- Gamepad DualShock P1
    ds2_clk       : out std_logic;
    ds2_mosi      : out std_logic;
    ds2_miso      : in std_logic;
    ds2_cs        : out std_logic
    );

end nanoapple2;

architecture datapath of nanoapple2 is

signal clk_sys : std_logic;
signal clk_core : std_logic;
signal clk_pixel_x5 : std_logic;
attribute syn_keep : integer;
attribute syn_keep of clk_sys : signal is 1;
attribute syn_keep of clk_core : signal is 1;
attribute syn_keep of clk_pixel_x5 : signal is 1;
signal CLK_2M, CLK_2M_D, PHASE_ZERO, PHASE_ZERO_R, PHASE_ZERO_F : std_logic;
signal clk_div : unsigned(1 downto 0);
signal IO_SELECT, DEVICE_SELECT : std_logic_vector(7 downto 0);
signal IO_STROBE : std_logic;
signal ADDR : unsigned(15 downto 0);
signal D, PD: unsigned(7 downto 0);
signal HDD_DO, DISK_DO, PSG_DO, SSC_DO, MOUSE_DO : unsigned(7 downto 0);
signal SSC_OE, MOUSE_OE : std_logic := '0';
signal DO : std_logic_vector(15 downto 0);
signal aux : std_logic;
signal cpu_we : std_logic;
signal psg_irq_n : std_logic := '1';
signal mouse_irq_n : std_logic :='1';
signal ssc_irq_n : std_logic := '1';
signal irq_n : std_logic;
signal we_ram : std_logic;
signal VIDEO, HBL, VBL : std_logic;
signal COLOR_LINE : std_logic;
signal COLOR_LINE_CONTROL : std_logic;
signal GAMEPORT : std_logic_vector(7 downto 0);
signal scandoubler_disable : std_logic;
signal ypbpr : std_logic;
signal no_csync : std_logic;

signal K : unsigned(7 downto 0);
signal read_key : std_logic;
signal akd : std_logic;

signal flash_clk : unsigned(22 downto 0) := (others => '0');
signal power_on_reset : std_logic := '1';
signal reset : std_logic := '1';

signal D1_ACTIVE, D2_ACTIVE : std_logic;
signal TRACK1_RAM_BUSY : std_logic;
signal TRACK1_RAM_ADDR : unsigned(12 downto 0);
signal TRACK1_RAM_DI : unsigned(7 downto 0);
signal TRACK1_RAM_DO : unsigned(7 downto 0);
signal TRACK1_RAM_WE : std_logic;
signal TRACK1 : unsigned(5 downto 0);
signal TRACK2_RAM_BUSY : std_logic;
signal TRACK2_RAM_ADDR : unsigned(12 downto 0);
signal TRACK2_RAM_DI : unsigned(7 downto 0);
signal TRACK2_RAM_DO : unsigned(7 downto 0);
signal TRACK2_RAM_WE : std_logic;
signal TRACK2 : unsigned(5 downto 0);
signal DISK_READY : std_logic_vector(1 downto 0);
signal DISK_CHANGE : std_logic_vector(1 downto 0);
signal DISK_MOUNT : std_logic_vector(1 downto 0);

signal a_ram: unsigned(15 downto 0);
signal r : unsigned(7 downto 0);
signal g : unsigned(7 downto 0);
signal b : unsigned(7 downto 0);
signal hblank : std_logic;
signal vblank : std_logic;
signal hsync : std_logic;
signal vsync : std_logic;
signal ram_we : std_logic;
signal ram_di : std_logic_vector(7 downto 0);
signal ram_addr : std_logic_vector(24 downto 0);
signal joy        : std_logic_vector(7 downto 0);
signal joy_an     : std_logic_vector(15 downto 0);
signal mouse_strobe : std_logic;
signal mouse_flags  : std_logic_vector(7 downto 0);
signal mouse_x_pos : signed(8 downto 0);
signal mouse_y_pos : signed(8 downto 0);
signal mouse_x_joy : std_logic_vector(7 downto 0);
signal mouse_y_joy : std_logic_vector(7 downto 0);
signal mouse_btns  : std_logic_vector(1 downto 0);
signal audio_sp    : unsigned(9 downto 0);
signal psg_audio_l : unsigned(9 downto 0);
signal psg_audio_r : unsigned(9 downto 0);
signal audio       : std_logic;

-- signals to connect sd card emulation with io controller
signal sd_lba:  std_logic_vector(31 downto 0) := (others => '0');
signal sd_rd:   std_logic_vector(5 downto 0) := (others => '0');
signal sd_wr:   std_logic_vector(5 downto 0) := (others => '0');
signal SD_LBA1:  std_logic_vector(31 downto 0);
signal SD_LBA2:  std_logic_vector(31 downto 0);
signal SD_LBA3:  std_logic_vector(31 downto 0);
signal SD_LBA4:  std_logic_vector(31 downto 0);

-- data from io controller to sd card emulation
signal sd_data_in: std_logic_vector(7 downto 0);
signal sd_data_out: std_logic_vector(7 downto 0);
signal sd_data_out_strobe:  std_logic;
signal sd_buff_addr: std_logic_vector(8 downto 0);
signal SD_DATA_IN1: std_logic_vector(7 downto 0);
signal SD_DATA_IN2: std_logic_vector(7 downto 0);
signal SD_DATA_IN3: std_logic_vector(7 downto 0);

signal pll_locked : std_logic;
signal joyx       : std_logic;
signal joyy       : std_logic;
signal pdl_strobe : std_logic;
signal open_apple : std_logic;
signal closed_apple : std_logic;
-- joystick interface
signal joyUsb1      : std_logic_vector(7 downto 0);
signal joyUsb2      : std_logic_vector(7 downto 0);
signal joyDS2_p1    : std_logic_vector(7 downto 0);
signal joyDS2_p2    : std_logic_vector(7 downto 0);
signal joyMouse     : std_logic_vector(7 downto 0);
signal port_1_sel   : std_logic_vector(2 downto 0);
-- mouse / paddle
signal posx            : std_logic_vector(7 downto 0);
signal posy            : std_logic_vector(7 downto 0);
signal joystick0ax     : std_logic_vector(7 downto 0);
signal joystick0ay     : std_logic_vector(7 downto 0);
signal joystick1ax     : std_logic_vector(7 downto 0);
signal joystick1ay     : std_logic_vector(7 downto 0);
signal joystick_strobe : std_logic;
signal joystick0_x_pos : std_logic_vector(7 downto 0);
signal joystick0_y_pos : std_logic_vector(7 downto 0);
signal joystick1_x_pos : std_logic_vector(7 downto 0);
signal joystick1_y_pos : std_logic_vector(7 downto 0);
signal extra_button0   : std_logic_vector(7 downto 0);
signal extra_button1   : std_logic_vector(7 downto 0);
signal joystick0       : std_logic_vector(7 downto 0);
signal joystick1       : std_logic_vector(7 downto 0);

signal mouse_btnsC     : std_logic_vector(1 downto 0);
signal mouse_btnsD     : std_logic_vector(1 downto 0);
signal mouse_xC        : signed(7 downto 0);
signal mouse_yC        : signed(7 downto 0);
signal mouse_xD        : signed(7 downto 0);
signal mouse_yD        : signed(7 downto 0);
signal mouse_x         : signed(7 downto 0);
signal mouse_y         : signed(7 downto 0);
signal mouse_strobeC   : std_logic;
signal mouse_strobeD   : std_logic;
signal paddle_1        : std_logic_vector(7 downto 0);
signal paddle_2        : std_logic_vector(7 downto 0);
signal paddle_3        : std_logic_vector(7 downto 0);
signal paddle_4        : std_logic_vector(7 downto 0);
signal key_r1          : std_logic;
signal key_r2          : std_logic;
signal key_l1          : std_logic;
signal key_l2          : std_logic;
signal key_triangle    : std_logic;
signal key_square      : std_logic;
signal key_circle      : std_logic;
signal key_cross       : std_logic;
signal key_up          : std_logic;
signal key_down        : std_logic;
signal key_left        : std_logic;
signal key_right       : std_logic;
signal key_start       : std_logic;
signal key_select      : std_logic;
signal key_r12         : std_logic;
signal key_r22         : std_logic;
signal key_l12         : std_logic;
signal key_l22         : std_logic;
signal key_triangle2   : std_logic;
signal key_square2     : std_logic;
signal key_circle2     : std_logic;
signal key_cross2      : std_logic;
signal key_up2         : std_logic;
signal key_down2       : std_logic;
signal key_left2       : std_logic;
signal key_right2      : std_logic;
signal key_start2      : std_logic;
signal key_select2     : std_logic;
signal sdc_int        : std_logic :='0';
signal sdc_iack       : std_logic;
signal int_ack        : std_logic_vector(7 downto 0);
signal spi_io_din     : std_logic;
signal spi_io_ss      : std_logic;
signal spi_io_clk     : std_logic;
signal spi_io_dout    : std_logic;
signal mcu_start      : std_logic;
signal mcu_sys_strobe : std_logic;
signal mcu_hid_strobe : std_logic;
signal mcu_osd_strobe : std_logic;
signal mcu_sdc_strobe : std_logic;
signal data_in_start  : std_logic;
signal mcu_data_out   : std_logic_vector(7 downto 0);
signal hid_data_out   : std_logic_vector(7 downto 0);
signal osd_data_out   : std_logic_vector(7 downto 0) :=  X"55";
signal sys_data_out   : std_logic_vector(7 downto 0);
signal sdc_data_out   : std_logic_vector(7 downto 0);
signal hid_int        : std_logic;
signal usb_key        : std_logic_vector(7 downto 0);
signal ws2812_color   : std_logic_vector(23 downto 0);
signal system_reset   : std_logic_vector(1 downto 0);
signal kbd_strobe     : std_logic;
signal system_wide_screen : std_logic;
signal system_scanlines : std_logic_vector(1 downto 0);
signal system_volume  : std_logic_vector(1 downto 0);
signal sd_img_size    : std_logic_vector(31 downto 0);
signal sd_img_mounted : std_logic_vector(5 downto 0);
signal sd_busy        : std_logic;
signal sd_busyD, sd_busyD2 : std_logic;
signal sd_done        : std_logic;
signal sd_rd_byte_strobe : std_logic;
signal sd_byte_index  : std_logic_vector(8 downto 0);
signal sd_rd_data     : std_logic_vector(7 downto 0);
signal sd_wr_data     : std_logic_vector(7 downto 0);
signal disk_chg_trg   : std_logic;
signal sector             : unsigned(15 downto 0);
signal hdd_mounted        : std_logic := '0';
signal hdd_read           : std_logic;
signal hdd_write          : std_logic;
signal hdd_protect        : std_logic;
signal cpu_wait_hdd       : std_logic := '0';
signal cpu_wait_hddD      : std_logic := '0';
signal cpu_wait_hddD2     : std_logic := '0';
signal hdd_read_pending   : std_logic := '0';
signal hdd_write_pending  : std_logic := '0';
signal state              : std_logic_vector(1 downto 0) := "00";
signal old_ack            : std_logic := '0';
signal hdd_readD2, hdd_readD  : std_logic;
signal hdd_writeD2, hdd_writeD  : std_logic;
signal system_floppy_wprot: std_logic_vector(1 downto 0);
signal system_cpu         : std_logic;
signal system_monitor     : std_logic_vector(1 downto 0);
signal system_palette     : std_logic_vector(1 downto 0);
signal system_video_std   : std_logic;
signal system_ssc         : std_logic;
signal system_mb          : std_logic;
signal system_mouse       : std_logic;
signal system_hdd         : std_logic;
signal system_videorom    : std_logic;
signal system_analogxy    : std_logic;
signal system_hdd_prot    : std_logic;
signal soft_reset         : std_logic;
signal reset_cold         : std_logic := '1';
signal reset_warm         : std_logic;
signal dd_reset           : std_logic := '1';
signal uart_rx_muxed      : std_logic;
signal system_uart        : std_logic_vector(1 downto 0);
signal ssc_sw1            : std_logic_vector(6 downto 1) := "111111";
signal ssc_sw2            : std_logic_vector(5 downto 1) := "11111";
signal system_databits    : std_logic;
signal system_parity      : std_logic_vector(1 downto 0);
signal system_baudrate    : std_logic_vector(3 downto 0);
signal system_sscirq      : std_logic;
signal system_lfcr        : std_logic;
signal loader_busy        : std_logic;
signal load_rom           : std_logic := '0';
signal load_palette       : std_logic := '0';
signal ioctl_download     : std_logic := '0';
signal ioctl_load_addr    : std_logic_vector(22 downto 0);
signal ioctl_wr           : std_logic;
signal ioctl_data         : std_logic_vector(7 downto 0);
signal ioctl_addr         : std_logic_vector(22 downto 0);
signal ioctl_wait         : std_logic := '0';
signal pause              : std_logic;
signal serial_status      : std_logic_vector(31 downto 0);
signal serial_tx_available: std_logic_vector(7 downto 0);
signal serial_tx_strobe   : std_logic;
signal serial_tx_data     : std_logic_vector(7 downto 0);
signal serial_rx_available: std_logic_vector(7 downto 0);
signal serial_rx_strobe   : std_logic;
signal serial_rx_data     : std_logic_vector(7 downto 0);
signal TEXT_COLOR         : std_logic;
signal TEXT_MODE          : std_logic;
signal system_lores_text  : std_logic;
signal disk_mount_d       : std_logic_vector(1 downto 0);
signal disk_chg_trg_d     : std_logic;
signal nullmdm1, nullmdm2 : std_logic;
signal leds               : std_logic_vector(5 downto 0);

component DCS
generic (
    DCS_MODE : STRING := "RISING"
);
port (
    CLKOUT: out std_logic;
    CLKSEL: in std_logic_vector(3 downto 0);
    CLKIN0: in std_logic;
    CLKIN1: in std_logic;
    CLKIN2: in std_logic;
    CLKIN3: in std_logic;
    SELFORCE: in std_logic
);
end component;

component CLKDIV
    generic (
        DIV_MODE : STRING := "2";
        GSREN: in string := "false"
    );
    port (
        CLKOUT: out std_logic;
        HCLKIN: in std_logic;
        RESETN: in std_logic;
        CALIB: in std_logic
    );
end component;

begin

  reset_cold <= system_reset(1) or not pll_locked or pause;

  process(clk_sys, pll_locked)
    variable pause_cnt : integer range 0 to 2147483647;
    begin
    if pll_locked = '0' then
      pause <= '1';
      pause_cnt := 34000000;
    elsif rising_edge(clk_sys) then
      if pause_cnt /= 0 then
        pause_cnt := pause_cnt - 1;
      elsif pause_cnt = 0 then 
        pause <= '0';
      end if;
    end if;
  end process;

  -- In the Apple ][, this was a 555 timer
  power_on : process(clk_core)
  begin
    if rising_edge(clk_core) then
      reset <= reset_warm or power_on_reset;
      reset_warm <= system_reset(0) or not pll_locked or pause;
      dd_reset   <= reset_cold or soft_reset;

      if reset_cold = '1' or soft_reset ='1' then
        power_on_reset <= '1';
        flash_clk <= (others=>'0');
      else
		  if flash_clk(22) = '1' then
          power_on_reset <= '0';
			end if;
			 
        flash_clk <= flash_clk + 1;
      end if;
    end if;
  end process;
  
pll_inst: entity work.Gowin_rPLL_tn20k
    port map (
        clkout => clk_pixel_x5,
        lock   => pll_locked,
        clkin  => clk_in
    );

div1_28mhz: CLKDIV
generic map(
    DIV_MODE => "5",
    GSREN    => "false"
)
port map(
    CLKOUT => clk_sys,
    HCLKIN => clk_pixel_x5,
    RESETN => pll_locked,
    CALIB  => '0'
);

div2_14mhz: CLKDIV
generic map(
  DIV_MODE => "2",
  GSREN    => "false"
)
port map(
    CLKOUT => clk_core,
    HCLKIN => clk_sys,
    RESETN => pll_locked,
    CALIB  => '0'
);

led_ws2812: entity work.ws2812
  port map
  (
   clk    => clk_sys,
   color  => ws2812_color,
   data   => ws2812
  );

gamepad_p1: entity work.dualshock2
    port map (
    clk           => clk_core,
    rst           => reset,
    vsync         => vsync,
    ds2_dat       => ds_miso,
    ds2_cmd       => ds_mosi,
    ds2_att       => ds_cs,
    ds2_clk       => ds_clk,
    ds2_ack       => '0',
    analog        => '1',
    stick_lx      => paddle_1,
    stick_ly      => paddle_2,
    stick_rx      => open,
    stick_ry      => open,
    key_up        => open,
    key_down      => open,
    key_left      => open,
    key_right     => open,
    key_l1        => open,
    key_l2        => open,
    key_r1        => open,
    key_r2        => open,
    key_triangle  => key_triangle,
    key_square    => key_square,
    key_circle    => key_circle,
    key_cross     => key_cross,
    key_start     => open,
    key_select    => open,
    key_lstick    => open,
    key_rstick    => open,
    debug1        => open,
    debug2        => open
    );

    gamepad_p2: entity work.dualshock2
    port map (
    clk           => clk_core,
    rst           => reset,
    vsync         => vsync,
    ds2_dat       => ds2_miso,
    ds2_cmd       => ds2_mosi,
    ds2_att       => ds2_cs,
    ds2_clk       => ds2_clk,
    ds2_ack       => '0',
    analog        => '1',
    stick_lx      => paddle_3,
    stick_ly      => paddle_4,
    stick_rx      => open,
    stick_ry      => open,
    key_up        => open,
    key_down      => open,
    key_left      => open,
    key_right     => open,
    key_l1        => open,
    key_l2        => open,
    key_r1        => open,
    key_r2        => open,
    key_triangle  => key_triangle2,
    key_square    => key_square2,
    key_circle    => key_circle2,
    key_cross     => key_cross2,
    key_start     => open,
    key_select    => open,
    key_lstick    => open,
    key_rstick    => open,
    debug1        => open,
    debug2        => open
    );

joyUsb1    <= "00" & joystick0(5 downto 4) & x"0";
joyUsb2    <= "00" & joystick1(5 downto 4) & x"0";
joyDS2_p1  <= "00" & key_cross  & key_square  & x"0";
joyDS2_p2  <= "00" & key_cross2 & key_square2 & x"0";
joyMouse   <= "00" & mouse_btns & x"0";

process(clk_core)
begin
	if rising_edge(clk_core) then
    case port_1_sel is
      when "000"  => joy <= joyUsb1;
      when "001"  => joy <= joyUsb2;
      when "010"  => joy <= joyDS2_p1;
      when "011"  => joy <= joyDS2_p2;
      when "100"  => joy <= joyMouse;
      when others => joy <= (others => '0');
      end case;
  end if;
end process;

posy <= paddle_2(7) & not paddle_2(6 downto 0) when port_1_sel = "010" else
        paddle_4(7) & not paddle_4(6 downto 0) when port_1_sel = "011" else
        not joystick0ay(7) & joystick0ay(6 downto 0) when port_1_sel = "000" else
        not joystick1ay(7) & joystick1ay(6 downto 0) when port_1_sel = "001" else
        std_logic_vector(mouse_y_joy(7 downto 0)) when port_1_sel = "100" else
        x"ff";

posx <= paddle_1(7) & not paddle_1(6 downto 0) when port_1_sel = "010" else
        paddle_3(7) & not paddle_3(6 downto 0) when port_1_sel = "011" else
        not joystick0ax(7) & joystick0ax(6 downto 0) when port_1_sel = "000" else 
        not joystick1ax(7) & joystick1ax(6 downto 0) when port_1_sel = "001" else
        std_logic_vector(mouse_x_joy(7 downto 0)) when port_1_sel = "100" else
        x"ff";

joy_an <= (posy & posx) when system_analogxy = '1' else (posx & posy);

  -- Paddle buttons
  -- GAMEPORT input bits:
  --  7    6    5    4    3   2   1    0
  -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
  GAMEPORT <=  "00" & joyy & joyx & "0" & (joy(5) or closed_apple) & (joy(4) or open_apple) & uart_rx_muxed;
  
  process(clk_core, pdl_strobe)
    variable cx, cy : integer range -100 to 5800 := 0;
  begin
    if rising_edge(clk_core) then
     CLK_2M_D <= CLK_2M;
     if CLK_2M_D = '0' and CLK_2M = '1' then
      if cx > 0 then
        cx := cx -1;
        joyx <= '1';
      else
        joyx <= '0';
      end if;
      if cy > 0 then
        cy := cy -1;
        joyy <= '1';
      else
        joyy <= '0';
      end if;
      if pdl_strobe = '1' then
        cx := 2800+(22*to_integer(signed(joy_an(15 downto 8))));
        cy := 2800+(22*to_integer(signed(joy_an(7 downto 0)))); -- max 5650
        if cx < 0 then
          cx := 0;
        elsif cx >= 5590 then
          cx := 5650;
        end if;
        if cy < 0 then
          cy := 0;
        elsif cy >= 5590 then
          cy := 5650;
        end if;
      end if;
     end if;
    end if;
  end process;

  TEXT_COLOR <= '1' when system_monitor = "00" and system_lores_text = '1'else '0';
  COLOR_LINE_CONTROL <= (COLOR_LINE or (TEXT_COLOR and not TEXT_MODE)) and not (system_monitor(1) or system_monitor(0));  -- Color or B&W mode

dram_inst: entity work.sdram port map(
    SDRAM_CLK  => O_sdram_clk,
    SDRAM_CKE  => O_sdram_cke,
    SDRAM_DQ   => IO_sdram_dq,   -- 32 bit bidirectional data bus
    SDRAM_A    => O_sdram_addr,  -- 11 bit multiplexed address bus
    SD_DQM     => O_sdram_dqm,   -- two byte masks
    SDRAM_BA   => O_sdram_ba,    -- two banks
    SDRAM_nCS  => O_sdram_cs_n,  -- a single chip select
    SDRAM_nWE  => O_sdram_wen_n, -- write enable
    SDRAM_nRAS => O_sdram_ras_n, -- row address select
    SDRAM_nCAS => O_sdram_cas_n, -- columns address select
    -- cpu/chipset interface
    init       => not pll_locked,-- init signal after FPGA config to initialize RAM
    clk        => clk_sys,
    clkref     => CLK_2M,
    din        => ram_di,          -- 8bit data input from chipset/cpu
    dout       => DO,              -- Data from RAM (lo byte: MAIN RAM, hi byte: AUX RAM)
    addr       => ram_addr(21 downto 0),
    oe         => not ram_we,      -- cpu/chipset requests read/wrie
    we         => ram_we,          -- cpu/chipset requests write
    aux        => aux              -- Write to MAIN or AUX RAM
  );

  -- Simulate power up on cold reset to go to the disk boot routine
  ram_we   <= we_ram when reset_cold = '0' else '1';
  ram_addr <= "000000000" & std_logic_vector(a_ram) when reset_cold = '0' else std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4
  ram_di   <= std_logic_vector(D) when reset_cold = '0' else "00000000";

  PD <= PSG_DO when IO_SELECT(4) = '1' and system_mb = '1' else
        SSC_DO when SSC_OE = '1' and system_ssc = '1' else
        HDD_DO when (IO_SELECT(7) or DEVICE_SELECT(7)) = '1' and system_hdd = '1' else
        MOUSE_DO when MOUSE_OE = '1' and system_mouse = '1' else
        DISK_DO;

  irq_n <= '0' when (psg_irq_n = '0' and system_mb = '1')
                or (mouse_irq_n = '0' and system_mouse = '1')
                or (ssc_irq_n = '0' and system_ssc = '1' and system_sscirq = '1') else '1';

  core : entity work.apple2 port map (
    CLK_14M        => clk_core,
    CLK_2M         => CLK_2M,
    CPU_WAIT       => cpu_wait_hdd,
    PHASE_ZERO     => PHASE_ZERO,
    PHASE_ZERO_R   => PHASE_ZERO_R,
    PHASE_ZERO_F   => PHASE_ZERO_F,
    FLASH_CLK      => flash_clk(22),
    reset          => reset,
    cpu            => system_cpu,
    ADDR           => ADDR,
    ram_addr       => a_ram,
    D              => D,
    ram_do         => unsigned(DO),
    aux            => aux,
    PD             => PD,
    CPU_WE         => cpu_we,
    IRQ_N          => irq_n,
    NMI_N          => '1',
    ram_we         => we_ram,
    VIDEO          => VIDEO,
    PALMODE        => not system_video_std,
    ROMSWITCH      => not system_videorom,
    COLOR_LINE     => COLOR_LINE,
    TEXT_MODE      => TEXT_MODE,
    HBL            => HBL,
    VBL            => VBL,
    K              => K,
    KEYSTROBE      => read_key,
    AKD            => akd,
    AN             => open,
    GAMEPORT       => GAMEPORT,
    PDL_strobe     => pdl_strobe,
    IO_SELECT      => IO_SELECT,
    DEVICE_SELECT  => DEVICE_SELECT,
    speaker        => audio,
    -- load different video roms
    ioctl_addr     => "00" & ioctl_addr,
    ioctl_data     => ioctl_data,
    ioctl_index    => 7x"00" & load_rom,
    ioctl_download => ioctl_download,
    ioctl_wr       => ioctl_wr,
    ioctl_clk      => clk_sys
    );

  vga_controller_inst : entity work.vga_controller port map (
    CLK_14M       => clk_core,
    VIDEO         => VIDEO,
    COLOR_LINE    => COLOR_LINE_CONTROL,
    SCREEN_MODE   => system_monitor, -- 00: Color, 01: B&W, 10: Green, 11: Amber
    COLOR_PALETTE => system_palette, -- 00: Original, 01: //gs, 02: //e, 03: //e alternative
    HBL           => HBL,
    VBL           => VBL,
    VGA_HS        => hsync,
    VGA_VS        => vsync,
		VGA_HBL       => hblank,
		VGA_VBL       => vblank,
    VGA_R         => r,
    VGA_G         => g,
    VGA_B         => b,
    -- load different palettes
    ioctl_addr    => "00" & ioctl_addr,
    ioctl_data    => ioctl_data,
    ioctl_index   => 6x"00" & load_palette & '0',
    ioctl_download=> ioctl_download,
    ioctl_wr      => ioctl_wr,
    ioctl_wait    => open,
    ioctl_clk     => clk_sys
    );

  keyboard : entity work.keyboard 
  port map (
    usb_key  => usb_key,
    kbd_strobe => kbd_strobe,
    CLK_14M   => clk_core,
    reset    => reset_cold, -- not reset so we keep the
                    -- keyboard state machine running for key up 
                    -- events during / after reset
    reads    => read_key,
    K        => K,
    akd      => akd,
    open_apple => open_apple,
    closed_apple => closed_apple,

    soft_reset => soft_reset,
    video_toggle => open,
    palette_toggle => open
    );

SD_LBA3 <= std_logic_vector( x"0000" & sector);
sd_lba <= SD_LBA4 when (sd_rd(4) or sd_wr(4) or sd_rd(3) or sd_wr(3)) = '1' else SD_LBA3 when (sd_rd(2) or sd_wr(2)) = '1' else SD_LBA2 when (sd_rd(1) or sd_wr(1)) = '1' else SD_LBA1;
sd_wr_data <= SD_DATA_IN3 when (sd_rd(2) or sd_wr(2)) = '1' else SD_DATA_IN2 when (sd_rd(1) or sd_wr(1)) = '1' else SD_DATA_IN1;
sd_rd(5) <= '0';
sd_wr(5) <= '0';

process(clk_sys, pll_locked)
variable reset_cnt : integer range 0 to 2147483647;
  begin
  if pll_locked = '0' then
    DISK_MOUNT(1 downto 0) <= "00";
    DISK_CHANGE(1 downto 0) <= "00";
    hdd_mounted <= '0';
    disk_chg_trg <= '0';
    reset_cnt := 64000000;
  elsif rising_edge(clk_sys) then
    disk_mount_d <= DISK_MOUNT;
    disk_chg_trg_d <= disk_chg_trg;

    if reset_cnt /= 0 then
          reset_cnt := reset_cnt - 1;
    elsif reset_cnt = 0 then
          disk_chg_trg <= '1';
    end if;

    if sd_img_mounted(0) = '1' then
        DISK_MOUNT(0) <= '0' when unsigned(sd_img_size) = 0 else '1';
    elsif sd_img_mounted(1) = '1' then
        DISK_MOUNT(1) <= '0' when unsigned(sd_img_size) = 0 else '1';
    elsif sd_img_mounted(2) = '1' then
      hdd_mounted <= '0' when unsigned(sd_img_size) = 0 else '1';
      hdd_protect <= system_hdd_prot;
    end if;

    if DISK_MOUNT(0) /= disk_mount_d(0)
        or (disk_chg_trg_d = '0' and disk_chg_trg = '1') then
        DISK_CHANGE(0) <= '1';
    else
        DISK_CHANGE(0) <= '0';
    end if;

    if DISK_MOUNT(1) /= disk_mount_d(1)
        or (disk_chg_trg_d = '0' and disk_chg_trg = '1') then
        DISK_CHANGE(1) <= '1';
    else
        DISK_CHANGE(1) <= '0';
    end if;

  end if;
end process;

sdcard_interface1: entity work.floppy_track port map (
    clk          => clk_core,
    clk2         => clk_sys,
    reset        => dd_reset,
	
    ram_addr     => TRACK1_RAM_ADDR, 
    ram_di       => TRACK1_RAM_DI,
    ram_do       => TRACK1_RAM_DO,
    ram_we       => TRACK1_RAM_WE,
	
    track        => std_logic_vector(TRACK1),
    busy         => TRACK1_RAM_BUSY,
    change       => DISK_CHANGE(0),
    mount        => DISK_MOUNT(0),
    ready        => DISK_READY(0),
    active       => D1_ACTIVE,

    sd_buff_addr => sd_byte_index,
    sd_buff_dout => sd_rd_data,
    sd_buff_din  => SD_DATA_IN1,
    sd_buff_wr   => sd_rd_byte_strobe,

    sd_lba       => SD_LBA1,
    sd_rd        => sd_rd(0),
    sd_wr        => sd_wr(0),
    sd_ack       => sd_busy
);

sdcard_interface2: entity work.floppy_track port map (
    clk          => clk_core,
    clk2         => clk_sys,
    reset        => dd_reset,
	
    ram_addr     => TRACK2_RAM_ADDR,
    ram_di       => TRACK2_RAM_DI,
    ram_do       => TRACK2_RAM_DO,
    ram_we       => TRACK2_RAM_WE,
	
    track        => std_logic_vector(TRACK2),
    busy         => TRACK2_RAM_BUSY,
    change       => DISK_CHANGE(1),
    mount        => DISK_MOUNT(1),
    ready        => DISK_READY(1),
    active       => D2_ACTIVE,

    sd_buff_addr => sd_byte_index,
    sd_buff_dout => sd_rd_data,
    sd_buff_din  => SD_DATA_IN2,
    sd_buff_wr   => sd_rd_byte_strobe,

    sd_lba       => SD_LBA2,
    sd_rd        => sd_rd(1),
    sd_wr        => sd_wr(1),
    sd_ack       => sd_busy
    );

  disk : entity work.disk_ii port map (
    CLK_14M        => clk_core,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(6),
    DEVICE_SELECT  => DEVICE_SELECT(6),
    RESET          => reset,
    DISK_READY     => DISK_READY,
    A              => ADDR,
    D_IN           => D,
    D_OUT          => DISK_DO,
    D1_ACTIVE      => D1_ACTIVE,
    D2_ACTIVE      => D2_ACTIVE,
    D1_WP          => system_floppy_wprot(0),
    D2_WP          => system_floppy_wprot(1),
    -- track buffer interface for disk 1
    TRACK1         => TRACK1,
    TRACK1_ADDR    => TRACK1_RAM_ADDR,
    TRACK1_DO      => TRACK1_RAM_DO,
    TRACK1_DI      => TRACK1_RAM_DI,
    TRACK1_WE      => TRACK1_RAM_WE,
    TRACK1_BUSY    => TRACK1_RAM_BUSY,
    -- track buffer interface for disk 2
    TRACK2         => TRACK2,
    TRACK2_ADDR    => TRACK2_RAM_ADDR,
    TRACK2_DO      => TRACK2_RAM_DO,
    TRACK2_DI      => TRACK2_RAM_DI,
    TRACK2_WE      => TRACK2_RAM_WE,
    TRACK2_BUSY    => TRACK2_RAM_BUSY
    );

  leds_n <= not leds;
  leds(0) <= D1_ACTIVE;
  leds(1) <= D2_ACTIVE;
  leds(2) <= DISK_MOUNT(0);
  leds(3) <= DISK_MOUNT(1);
  leds(4) <= hdd_mounted;
  leds(5) <= '0';

  mb : entity  work.mockingboard port map (
      CLK_14M      => clk_core,
      PHASE_ZERO => PHASE_ZERO,
      PHASE_ZERO_R => PHASE_ZERO_R,
      PHASE_ZERO_F => PHASE_ZERO_F,
      I_RESET_L => not reset,
      I_ENA_H   => system_mb,

      I_ADDR    => std_logic_vector(ADDR(7 downto 0)),
      I_DATA    => std_logic_vector(D),
      unsigned(O_DATA)    => PSG_DO,
      I_RW_L    => not cpu_we,
      I_IOSEL_L => not IO_SELECT(4),
      O_IRQ_L   => psg_irq_n,
      O_NMI_L   => open,
      unsigned(O_AUDIO_L) => psg_audio_l,
      unsigned(O_AUDIO_R) => psg_audio_r
      );

  hdd : entity work.hdd port map (
    CLK_14M        => clk_core,
    clk2           => clk_sys,
    IO_SELECT      => IO_SELECT(7),
    DEVICE_SELECT  => DEVICE_SELECT(7),
    RESET          => reset,
    A              => ADDR,
    RD             => not cpu_we,
    D_IN           => D,
    D_OUT          => HDD_DO,
    sector         => sector,
    hdd_read       => hdd_read,
    hdd_write      => hdd_write,
    hdd_mounted    => hdd_mounted,
    hdd_protect    => hdd_protect,

    ram_addr       => unsigned(sd_byte_index),
    ram_di         => unsigned(sd_rd_data),
    unsigned(ram_do)=> SD_DATA_IN3,
    ram_we          => sd_rd_byte_strobe and sd_busy
    );

process(clk_core)
  begin
    if rising_edge(clk_core) then
      cpu_wait_hddD <= cpu_wait_hddD2;
      cpu_wait_hdd <= cpu_wait_hddD;
    end if;
end process;

process(clk_sys, dd_reset)
  begin
    if dd_reset = '1' then
        state <= "00";
        cpu_wait_hddD2 <= '0';
        hdd_read_pending <= '0';
        hdd_write_pending <= '0';
        sd_rd(2) <= '0';
        sd_wr(2) <= '0';
    elsif rising_edge(clk_sys) then
      hdd_readD <= hdd_read;
      hdd_readD2 <= hdd_readD;
      hdd_writeD <= hdd_write;
      hdd_writeD2 <= hdd_writeD;

      old_ack <= sd_busy;
    	hdd_read_pending <= '1' when hdd_read_pending = '1' or (hdd_readD = '0' and hdd_readD2 = '1') else '0';
    	hdd_write_pending <= '1' when hdd_write_pending = '1' or (hdd_writeD = '0' and hdd_writeD2 = '1') else '0';

      if state = "00" then
        if loader_busy = '0' then
          state <= "01";
        else 
          state <= "00";
        end if;
      elsif state = "01" then
        if hdd_read_pending or hdd_write_pending then
          state <= "10";
          sd_rd(2) <= hdd_read_pending;
          sd_wr(2) <= hdd_write_pending;
          cpu_wait_hddD2 <= '1';
        end if;
      elsif state = "10" then
        if old_ack = '0' and sd_busy = '1' then
          hdd_read_pending <= '0';
          hdd_write_pending <= '0';
          sd_rd(2) <= '0';
          sd_wr(2) <= '0';
        elsif old_ack = '1' and sd_busy = '0' then
          state <= "00";
          cpu_wait_hddD2 <= '0';
        end if;
      end if;
  end if;
end process;

  ssc_sw1 <= "00" & system_baudrate(0) & system_baudrate(1) & system_baudrate(2) & system_baudrate(3);

  ssc_sw2(5) <= system_lfcr; -- LF after CR
  ssc_sw2(4 downto 3) <= "00" when system_parity = "00" else -- no parity
                         "10" when system_parity = "01" else -- odd parity
                         "11"; -- even parity
  ssc_sw2(2) <= system_databits; -- 8 data bits
  ssc_sw2(1) <= '0'; -- 1 stop bit

  ssc : entity work.ssc port map (
    CLK_14M        => clk_core,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(2),
    IO_STROBE      => IO_STROBE,
    DEVICE_SELECT  => DEVICE_SELECT(2),
    RESET          => reset,
    A              => ADDR,
    RNW            => not cpu_we,
    D_IN           => D,
    D_OUT          => SSC_DO,
    OE             => SSC_OE,
    IRQ_N          => ssc_irq_n,

    SW1            => ssc_sw1,
    SW2            => ssc_sw2,

    UART_RX        => uart_rx_muxed,
    UART_TX        => uart_tx,
    UART_CTS       => nullmdm1,
    UART_RTS       => nullmdm1,
    UART_DCD       => nullmdm2,
    UART_DSR       => nullmdm2,
    UART_DTR       => nullmdm2,

    clk_sys             => clk_sys,
    wifimodem           => system_uart(1),
    -- serial/rs232 interface io-controller<-> UART
    serial_status_out   => serial_status,
    serial_data_out_available => serial_tx_available,
    serial_strobe_out   => serial_tx_strobe,
    serial_data_out     => serial_tx_data,

    serial_data_in_free => serial_rx_available,
    serial_strobe_in    => serial_rx_strobe,
    serial_data_in      => serial_rx_data
  );

-- external HW pin UART interface
uart_rx_muxed <= uart_rx when system_uart = "00" else uart_ext_rx when system_uart = "01" else '1';
uart_ext_tx <= uart_tx;

  mouse : entity work.applemouse port map (
    CLK_14M        => clk_core,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(5),
    IO_STROBE      => IO_STROBE,
    DEVICE_SELECT  => DEVICE_SELECT(5),
    RESET          => reset,
    A              => ADDR,
    RNW            => not cpu_we,
    D_IN           => D,
    D_OUT          => MOUSE_DO,
    OE             => MOUSE_OE,
    IRQ_N          => mouse_irq_n,

    STROBE         => mouse_strobe,
    X              => mouse_x_pos,
    Y              => mouse_y_pos,
    BUTTON         => mouse_btns(0)
  );

process(clk_core, reset)
 variable mx  : signed(8 downto 0);
 variable nmx : signed(8 downto 0);
 variable mdx : signed(8 downto 0);
 variable mdx2: signed(8 downto 0);
 variable nmy : signed(8 downto 0);
 variable mdy : signed(8 downto 0);
 variable mdy2: signed(8 downto 0);
 variable my  : signed(8 downto 0);

 begin
  if reset = '1' then
    mouse_x_pos <= (others => '0');
    mouse_y_pos <= (others => '0');
    mouse_x_joy <= (others => '0');
    mouse_y_joy <= (others => '0');
    nmx := to_signed(0, nmx'length);
    nmy := to_signed(0, nmy'length);
    mx := to_signed(0, mx'length);
    my := to_signed(0, my'length);
  elsif rising_edge(clk_core) then
    mouse_strobeD <=mouse_strobeC;
    mouse_strobe <=mouse_strobeD;
    mouse_xD <= mouse_xC;
    mouse_x <= mouse_xD;
    mouse_yD <= mouse_yC;
    mouse_y <= mouse_yD;
    mouse_btnsD <= mouse_btnsC;
    mouse_btns <= mouse_btnsD;
    mouse_x_pos <= resize(mouse_x, mouse_x_pos'length);
    mouse_y_pos <= - resize(mouse_y, mouse_y_pos'length);

    if mouse_strobe = '1' then
      mdx := resize(mouse_x, mdx'length);
      if mdx > 10 then 
        mdx2:= to_signed(10,mdx2'length);
      elsif mdx < -10 then 
        mdx2:= to_signed(-10,mdx2'length);
      else 
        mdx2 := mdx;
      end if;
      nmx := mx + mdx2;

      mdy := resize(mouse_y, mdy'length);
      if mdy > 10 then 
        mdy2:= to_signed(10,mdy2'length);
      elsif mdy < -10 then 
        mdy2:= to_signed(-10,mdy2'length);
      else 
        mdy2 := mdy;
      end if;
      nmy := my + mdy2;

      mx := to_signed(-128, mx'length) when nmx < -128
          else to_signed(127, mx'length) when nmx > 127
          else nmx;

      my := to_signed(-128, my'length) when nmy < -128
          else to_signed(127, my'length) when nmy > 127
          else nmy;

      mouse_x_joy <= std_logic_vector(mx(7 downto 0));
      mouse_y_joy <= std_logic_vector(my(7 downto 0));
    end if;
  end if;
end process;

audio_sp(6 downto 0) <= (others => '0');
audio_sp(7) <= audio;
audio_sp(9 downto 8) <= (others => '0');

video_inst: entity work.video
generic map
(
  STEREO  => false
)
port map(
      pll_lock     => pll_locked, 
      clk          => clk_sys,
      clk_pixel_x5 => clk_pixel_x5,
      audio_div    => (others => '0'),
      
      ntscmode  => system_video_std,
      vb_in     => vblank,
      hb_in     => hblank,
      hs_in_n   => hsync,
      vs_in_n   => vsync,

      r_in      => r(7 downto 4),
      g_in      => g(7 downto 4),
      b_in      => b(7 downto 4),

      audio_l => ("0" & (psg_audio_l + audio_sp) & psg_audio_l(9 downto 5)),
      audio_r => ("0" & (psg_audio_r + audio_sp) & psg_audio_r(9 downto 5)),
      osd_status => open,

      mcu_start => mcu_start,
      mcu_osd_strobe => mcu_osd_strobe,
      mcu_data  => mcu_data_out,

      -- values that can be configure by the user via osd
      system_wide_screen => system_wide_screen,
      system_scanlines => system_scanlines,
      system_volume => system_volume,

      tmds_clk_n => tmds_clk_n,
      tmds_clk_p => tmds_clk_p,
      tmds_d_n   => tmds_d_n,
      tmds_d_p   => tmds_d_p,

      lcd_clk  => open,
      lcd_hs_n => open,
      lcd_vs_n => open,
      lcd_de   => open,
      lcd_r    => open,
      lcd_g    => open,
      lcd_b    => open,
      lcd_bl   => open,

      hp_bck   => open,
      hp_ws    => open,
      hp_din   => open,
      pa_en    => open
      );

-- onboard BL616
spi_io_din  <= spi_dat;
spi_io_ss   <= spi_csn;
spi_io_clk  <= spi_sclk;
spi_dir     <= spi_io_dout;

-- M0S Dock
--spi_io_din  <= m0s(1);
--spi_io_ss   <= m0s(2);
--spi_io_clk  <= m0s(3);
--m0s(0)      <= spi_io_dout;

mcu_spi_inst: entity work.mcu_spi 
port map (
  clk            => clk_sys,
  reset          => not pll_locked,
  -- SPI interface to BL616 MCU
  spi_io_ss      => spi_io_ss,      -- SPI CSn
  spi_io_clk     => spi_io_clk,     -- SPI SCLK
  spi_io_din     => spi_io_din,     -- SPI MOSI
  spi_io_dout    => spi_io_dout,    -- SPI MISO
  -- byte interface to the various core components
  mcu_sys_strobe => mcu_sys_strobe, -- byte strobe for system control target
  mcu_hid_strobe => mcu_hid_strobe, -- byte strobe for HID target  
  mcu_osd_strobe => mcu_osd_strobe, -- byte strobe for OSD target
  mcu_sdc_strobe => mcu_sdc_strobe, -- byte strobe for SD card target
  mcu_start      => mcu_start,
  mcu_sys_din    => sys_data_out,
  mcu_hid_din    => hid_data_out,
  mcu_osd_din    => osd_data_out,
  mcu_sdc_din    => sdc_data_out,
  mcu_dout       => mcu_data_out
);

-- decode SPI/MCU data received for human input devices (HID) 
hid_inst: entity work.hid
 port map 
 (
  clk             => clk_sys,
  reset           => not pll_locked,
  -- interface to receive user data from MCU (mouse, kbd, ...)
  data_in_strobe  => mcu_hid_strobe,
  data_in_start   => mcu_start,
  data_in         => mcu_data_out,
  data_out        => hid_data_out,

  -- input local db9 port events to be sent to MCU
  db9_port        => 6x"00",
  irq             => hid_int,
  iack            => int_ack(1),

  -- output HID data received from USB
  usb_kbd         => usb_key,
  kbd_strobe      => kbd_strobe,
  joystick0       => joystick0,
  joystick1       => joystick1,
  mouse_btns      => mouse_btnsC,
  mouse_x         => mouse_xC,
  mouse_y         => mouse_yC,
  mouse_strobe    => mouse_strobeC,
  joystick0ax     => joystick0ax,
  joystick0ay     => joystick0ay,
  joystick1ax     => joystick1ax,
  joystick1ay     => joystick1ay,
  joystick_strobe => joystick_strobe,
  extra_button0   => extra_button0,
  extra_button1   => extra_button1
  );

module_inst: entity work.sysctrl 
 port map 
 (
  clk                 => clk_sys,
  reset               => not pll_locked,
--
  data_in_strobe      => mcu_sys_strobe,
  data_in_start       => mcu_start,
  data_in             => mcu_data_out,
  data_out            => sys_data_out,

  -- values that can be configured by the user
  system_monitor      => system_monitor,
  system_cpu          => system_cpu,
  system_reset        => system_reset,
  system_scanlines    => system_scanlines,
  system_volume       => system_volume,
  system_wide_screen  => system_wide_screen,
  system_floppy_wprot => system_floppy_wprot,
  system_port_1       => port_1_sel,
  system_palette      => system_palette,
  system_video_std    => system_video_std,
  system_ssc          => system_ssc,
  system_mb           => system_mb,
  system_mouse        => system_mouse,
  system_hdd          => system_hdd,
  system_videorom     => system_videorom,
  system_analogxy     => system_analogxy,
  system_uart         => system_uart,
  system_hdd_prot     => system_hdd_prot,
  system_databits     => system_databits,
  system_parity       => system_parity,
  system_baudrate     => system_baudrate,
  system_sscirq       => system_sscirq,
  system_lfcr         => system_lfcr,
  system_lores_text   => system_lores_text,

  -- port io (used to expose rs232)
  port_status         => serial_status,
  port_out_available  => serial_tx_available,
  port_out_strobe     => serial_tx_strobe,
  port_out_data       => serial_tx_data,
  port_in_available   => serial_rx_available,
  port_in_strobe      => serial_rx_strobe,
  port_in_data        => serial_rx_data,

  int_out_n           => spi_irqn, -- internal BL616
--int_out_n           => m0s(4), -- M0S Dock
  int_in              => unsigned'(x"0" & sdc_int & '0' & hid_int & '0'),
  int_ack             => int_ack,

  buttons             => unsigned'(s2_reset & user), -- S0 and S1 buttons on Tang Nano 20k
  leds                => open,-- two leds can be controlled from the MCU
  color               => ws2812_color -- a 24bit color to e.g. be used to drive the ws2812
);

sdc_iack <= int_ack(3);

sd_card_inst: entity work.sd_card
generic map (
    CLK_DIV  => 1
  )
    port map (
    rstn            => pll_locked,
    clk             => clk_sys,
  
    -- SD card signals
    sdclk           => sd_clk,
    sdcmd           => sd_cmd,
    sddat           => sd_dat,

    -- mcu interface
    data_strobe     => mcu_sdc_strobe,
    data_start      => mcu_start,
    data_in         => mcu_data_out,
    data_out        => sdc_data_out,

    -- interrupt to signal communication request
    irq             => sdc_int,
    iack            => sdc_iack,

    -- output file/image information. Image size is e.g. used by fdc to 
    -- translate between sector/track/side and lba sector
    image_size      => sd_img_size,
    image_mounted   => sd_img_mounted,

    -- user read sector command interface (sync with clk)
    rstart          => sd_rd,
    wstart          => sd_wr, 
    rsector         => sd_lba,
    rbusy           => sd_busy,
    rdone           => sd_done,

    -- sector data output interface (sync with clk)
    inbyte          => sd_wr_data,        -- sector data output interface (sync with clk)
    outen           => sd_rd_byte_strobe, -- when outen=1, a byte of sector content is read out from outbyte
    outaddr         => sd_byte_index,     -- outaddr from 0 to 511, because the sector size is 512
    outbyte         => sd_rd_data         -- a byte of sector content
);

  loader_inst : entity work.loader_sd_card
  port map (
    clk               => clk_sys,
    reset             => not pll_locked,
  
    sd_lba            => SD_LBA4,
    sd_rd             => sd_rd(4 downto 3),
    sd_wr             => sd_wr(4 downto 3),
    sd_busy           => sd_busy,
    sd_done           => sd_done,
  
    sd_byte_index     => sd_byte_index,
    sd_rd_data        => sd_rd_data,
    sd_rd_byte_strobe => sd_rd_byte_strobe,
  
    sd_img_mounted    => sd_img_mounted(4 downto 3),
    loader_busy       => loader_busy,
    load_rom          => load_rom,
    load_palette      => load_palette,
    sd_img_size       => sd_img_size,
  
    ioctl_download    => ioctl_download,
    ioctl_addr        => ioctl_addr,
    ioctl_data        => ioctl_data,
    ioctl_wr          => ioctl_wr,
    ioctl_wait        => '0'
  );

end datapath;