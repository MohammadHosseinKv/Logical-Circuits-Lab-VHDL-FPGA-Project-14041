library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity LCL_Project1_14041 is
  generic (
    CLK_FREQ      : integer := 24_000_000;
    TOTAL_SCAN_HZ : integer := 4000
  );

  port (
    clk   : in  std_logic;
    ts    : in  std_logic_vector(3 downto 0);
    pw_in : in  std_logic_vector(3 downto 0);
    seg   : out std_logic_vector(6 downto 0);
    ad    : out std_logic_vector(3 downto 0)

  );
end entity;

architecture RTL of LCL_Project1_14041 is

  type state is (student_number, counter, enter_pw, lightshow);
  signal cr_state   : state := counter;
  signal next_state : state := cr_state;

  type seg_array is array (0 to 30) of std_logic_vector(6 downto 0);
  constant seg_display : seg_array := (
    0  => "1000000",
    1  => "1111001",
    2  => "0100100",
    3  => "0110000",
    4  => "0011001",
    5  => "0010010",
    6  => "0000010",
    7  => "1111000",
    8  => "0000000",
    9  => "0010000",
    -- 10 to 29 for light show
    -- P , Light Show 10-14
    10 => "1101111",
    11 => "1001111",
    12 => "1001110",
    13 => "1001100",
    14 => "0001100",
    -- A , Light Show 15-19
    15 => "1101111",
    16 => "1001111",
    17 => "0001110",
    18 => "0001100",
    19 => "0001000",
    -- S1 , Light Show 20-24
    20 => "1111110",
    21 => "1011110",
    22 => "0011110",
    23 => "0011010",
    24 => "0010010",
    -- S2 , Light Show 25-29
    25 => "1110111",
    26 => "1110011",
    27 => "0110011",
    28 => "0010011",
    29 => "0010010",
    -- End of light show variations
    30 => "0111111" -- -
  );

  constant DIV_TICKS : integer := integer(CLK_FREQ / TOTAL_SCAN_HZ);
  signal refresh_cnt : integer range 0 to DIV_TICKS := 0;
  signal active_slot : integer range 0 to 3         := 0;

  signal sec_count   : integer range 0 to CLK_FREQ := 0;
  signal counter_val : integer range 0 to 15       := 0;

  signal light_show_hz   : integer                          := integer(CLK_FREQ / 2);
  signal lightshow_count : integer range 0 to light_show_hz := 0;
  signal lightshow_step  : integer range 0 to 5             := 0;

  constant pw : std_logic_vector(3 downto 0) := "1001";
  type array2d_4to4 is array (0 to 3) of std_logic_vector(3 downto 0);
  type array2d_4to5 is array (0 to 3) of std_logic_vector(4 downto 0);
  signal seg_slots_reg  : array2d_4to5 := (others => (others => '0'));
  signal seg_slots_next : array2d_4to5 := (others => (others => '0'));

  constant ad_pattern : array2d_4to4 := (
    0 => "1110",
    1 => "1101",
    2 => "1011",
    3 => "0111"
  );

  signal correct_pw : std_logic := '0';

  signal ts_sync_0 : std_logic_vector(3 downto 0) := (others => '1');
  signal ts_sync_1 : std_logic_vector(3 downto 0) := (others => '1');

begin

  refresh_prc: process (clk) is
  begin
    if rising_edge(clk) then
      if refresh_cnt < DIV_TICKS then
        refresh_cnt <= refresh_cnt + 1;
      else
        refresh_cnt <= 0;
        if active_slot = 3 then
          active_slot <= 0;
        else
          active_slot <= active_slot + 1;
        end if;
      end if;
    end if;
  end process;

  ad <= ad_pattern(active_slot);

  sync_proc: process (clk)
  begin
    if rising_edge(clk) then
      ts_sync_0 <= ts; -- capture async input
      ts_sync_1 <= ts_sync_0; -- stable in clk domain
    end if;
  end process;

  state_update: process (clk) is
  begin
    if rising_edge(clk) then
      cr_state <= next_state;
    end if;
  end process;

  set_transitions: process (cr_state, ts) is
  begin

    if rising_edge(clk) then
      if ts_sync_1(0) = '0' then
        next_state <= student_number;
      elsif ts_sync_1(1) = '0' then
        next_state <= counter;
      elsif ts_sync_1(2) = '0' then
        next_state <= enter_pw;
      elsif ts = "0111" then
        if cr_state = enter_pw and correct_pw = '1' then
          next_state <= lightshow;
        elsif cr_state = lightshow and correct_pw = '0' then
          next_state <= enter_pw;
        end if;
      elsif ts = "1111" and cr_state = lightshow then
        next_state <= enter_pw;
      end if;
    end if;

    -- case ts is
    --   when "1110" => next_state <= student_number;
    --   when "1101" => next_state <= counter;
    --   when "1011" => next_state <= enter_pw;
    --   when "0111" =>
    --     if cr_state = enter_pw and correct_pw = '1' then
    --       -- light show
    --     end if;
    --   when others => next_state <= next_state;
    -- end case;
  end process;

  seg_slots_reg_update: process (clk)
  begin
    if rising_edge(clk) then
      seg_slots_reg <= seg_slots_next;
    end if;
  end process;

  counter_state: process (CLK) is
  begin
    if cr_state = counter then
      if rising_edge(clk) then
        if sec_count < CLK_FREQ then
          sec_count <= sec_count + 1;
        else
          sec_count <= 0;
          if counter_val = 15 then
            counter_val <= 0;
          else
            counter_val <= counter_val + 1;
          end if;
        end if;
      end if;
    else
      sec_count <= 0;
    end if;
  end process;

  seg <= seg_display(to_integer(unsigned(seg_slots_reg(active_slot))));

  seg_slots_next_set: process (cr_state, counter_val, correct_pw)
    variable counter_v   : integer;
    variable lightshow_s : integer;
  begin

    case cr_state is
      when student_number =>
        seg_slots_next(3) <= "00000";
        seg_slots_next(2) <= "00000";
        seg_slots_next(1) <= "00100";
        seg_slots_next(0) <= "00010";
      -- seg_slots_next(3) <= std_logic_vector(to_unsigned(24, 5));
      -- seg_slots_next(2) <= std_logic_vector(to_unsigned(24, 5));
      -- seg_slots_next(1) <= std_logic_vector(to_unsigned(19, 5));
      -- seg_slots_next(0) <= std_logic_vector(to_unsigned(14, 5));
      when counter =>
        counter_v := counter_val;

        seg_slots_next(3) <= std_logic_vector(to_unsigned(counter_v mod 10, 5));
        seg_slots_next(2) <= std_logic_vector(to_unsigned((counter_v / 10) mod 10, 5));
        seg_slots_next(1) <= std_logic_vector(to_unsigned((counter_v / 100) mod 10, 5));
        seg_slots_next(0) <= std_logic_vector(to_unsigned((counter_v / 1000) mod 10, 5));

      when enter_pw =>
        if correct_pw = '1' then
          seg_slots_next(3) <= std_logic_vector(to_unsigned(24, 5));
          seg_slots_next(2) <= std_logic_vector(to_unsigned(24, 5));
          seg_slots_next(1) <= std_logic_vector(to_unsigned(19, 5));
          seg_slots_next(0) <= std_logic_vector(to_unsigned(14, 5));
        else
          seg_slots_next <= (others => std_logic_vector(to_unsigned(30, 5)));
        end if;

      when lightshow =>
        lightshow_s := lightshow_step;

        seg_slots_next(3) <= std_logic_vector(to_unsigned(lightshow_s + 25, 5));
        seg_slots_next(2) <= std_logic_vector(to_unsigned(lightshow_s + 20, 5));
        seg_slots_next(1) <= std_logic_vector(to_unsigned(lightshow_s + 15, 5));
        seg_slots_next(0) <= std_logic_vector(to_unsigned(lightshow_s + 10, 5));

      when others =>
        seg_slots_next <= (others => (others => '0'));

    end case;
  end process;

  pw_check_proc: process (clk)
  begin
    if rising_edge(clk) then
      if pw_in = pw then
        correct_pw <= '1';
      else
        correct_pw <= '0';
      end if;
    end if;
  end process;

  light_show_proc: process (clk)
  begin
    if cr_state = lightshow then
      if rising_edge(clk) then
        if lightshow_count < light_show_hz then
          lightshow_count <= lightshow_count + 1;
        else
          lightshow_count <= 0;
          if lightshow_step = 4 then
            lightshow_step <= 0;
          else
            lightshow_step <= lightshow_step + 1;
          end if;
        end if;
      end if;
    else
      lightshow_count <= 0;
    end if;
  end process;

end architecture;
