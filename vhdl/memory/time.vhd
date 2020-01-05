-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.wire.all;

entity time is
	port(
		reset      : in  std_logic;
		clock_rtc  : in  std_logic;
		time_valid : in  std_logic;
		time_instr : in  std_logic;
		time_ready : out std_logic;
		time_addr  : in  std_logic_vector(63 downto 0);
		time_wdata : in  std_logic_vector(63 downto 0);
		time_wstrb : in  std_logic_vector(7 downto 0);
		time_rdata : out std_logic_vector(63 downto 0);
		time_irpt  : out std_logic
	);
end time;

architecture behavior of time is

	type reg_type is record
		mtime_re    : std_logic;
		mtime_we    : std_logic;
		mtimecmp_re : std_logic;
		mtimecmp_we : std_logic;
		mtime       : unsigned(63 downto 0);
		mtimecmp    : unsigned(63 downto 0);
	end record;

	constant init_reg : reg_type := (
		mtime_re    => '0',
		mtime_we    => '0',
		mtimecmp_re => '0',
		mtimecmp_we => '0',
		mtime       => X"0000000000000000",
		mtimecmp    => X"0000000000000000"
	);

	signal r, rin : reg_type := init_reg;

begin

	process(r, time_valid, time_addr, time_wdata, time_wstrb)

	variable v : reg_type;

	begin

		v := r;

		v.mtime_re := '0';
		v.mtime_we := '0';
		v.mtimecmp_re := '0';
		v.mtimecmp_we := '0';

		if time_valid = '1' then
			if nor_reduce(time_addr xor X"0000000000000000") = '1' then
				if or_reduce(time_wstrb) = '0' then
					v.mtime_re := '1';
				elsif or_reduce(time_wstrb) = '1' then
					if time_wstrb(0) = '1' then
						v.mtime(7 downto 0) := unsigned(time_wdata(7 downto 0));
					end if;
					if time_wstrb(1) = '1' then
						v.mtime(15 downto 8) := unsigned(time_wdata(15 downto 8));
					end if;
					if time_wstrb(2) = '1' then
						v.mtime(23 downto 16) := unsigned(time_wdata(23 downto 16));
					end if;
					if time_wstrb(3) = '1' then
						v.mtime(31 downto 24) := unsigned(time_wdata(31 downto 24));
					end if;
					if time_wstrb(4) = '1' then
						v.mtime(39 downto 32) := unsigned(time_wdata(39 downto 32));
					end if;
					if time_wstrb(5) = '1' then
						v.mtime(47 downto 40) := unsigned(time_wdata(47 downto 40));
					end if;
					if time_wstrb(6) = '1' then
						v.mtime(55 downto 48) := unsigned(time_wdata(55 downto 48));
					end if;
					if time_wstrb(7) = '1' then
						v.mtime(63 downto 56) := unsigned(time_wdata(63 downto 56));
					end if;
					v.mtime_we := '1';
				end if;
			end if;
			if nor_reduce(time_addr xor X"0000000000000008") = '1' then
				if or_reduce(time_wstrb) = '0' then
					v.mtimecmp_re := '1';
				elsif or_reduce(time_wstrb) = '1' then
					if time_wstrb(0) = '1' then
						v.mtimecmp(7 downto 0) := unsigned(time_wdata(7 downto 0));
					end if;
					if time_wstrb(1) = '1' then
						v.mtimecmp(15 downto 8) := unsigned(time_wdata(15 downto 8));
					end if;
					if time_wstrb(2) = '1' then
						v.mtimecmp(23 downto 16) := unsigned(time_wdata(23 downto 16));
					end if;
					if time_wstrb(3) = '1' then
						v.mtimecmp(31 downto 24) := unsigned(time_wdata(31 downto 24));
					end if;
					if time_wstrb(4) = '1' then
						v.mtimecmp(39 downto 32) := unsigned(time_wdata(39 downto 32));
					end if;
					if time_wstrb(5) = '1' then
						v.mtimecmp(47 downto 40) := unsigned(time_wdata(47 downto 40));
					end if;
					if time_wstrb(6) = '1' then
						v.mtimecmp(55 downto 48) := unsigned(time_wdata(55 downto 48));
					end if;
					if time_wstrb(7) = '1' then
						v.mtimecmp(63 downto 56) := unsigned(time_wdata(63 downto 56));
					end if;
					v.mtimecmp_we := '1';
				end if;
			end if;
		end if;

		if v.mtime >= v.mtimecmp then
			time_irpt <= '1';
		else
			time_irpt <= '0';
		end if;

		v.mtime := v.mtime + 1;

		rin <= v;

	end process;

	time_rdata <= std_logic_vector(r.mtime) when r.mtime_re = '1' else
								std_logic_vector(r.mtimecmp) when r.mtimecmp_re = '1' else X"0000000000000000";
	time_ready <= r.mtime_re or r.mtime_we or r.mtimecmp_re or r.mtimecmp_we;

	process(clock_rtc)
	begin

		if rising_edge(clock_rtc) then

			if reset = '0' then

				r <= init_reg;

			else

				r <= rin;

			end if;

		end if;

	end process;

end architecture;