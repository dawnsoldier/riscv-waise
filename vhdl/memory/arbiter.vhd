-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.configure.all;
use work.wire.all;

entity arbiter is
	port(
		reset        : in  std_logic;
		clock        : in  std_logic;
		imem_i       : in  mem_in_type;
		imem_o       : out mem_out_type;
		dmem_i       : in  mem_in_type;
		dmem_o       : out mem_out_type;
		memory_valid : out std_logic;
		memory_ready : in  std_logic;
		memory_instr : out std_logic;
		memory_addr  : out std_logic_vector(63 downto 0);
		memory_wdata : out std_logic_vector(63 downto 0);
		memory_wstrb : out std_logic_vector(7 downto 0);
		memory_rdata : in  std_logic_vector(63 downto 0)
	);
end arbiter;

architecture behavior of arbiter is

constant instr_access : std_logic := '0';
constant data_access  : std_logic := '1';

signal access_type  : std_logic;
signal release_type : std_logic;

begin

	process(imem_i,dmem_i,memory_ready,memory_rdata,access_type,release_type)

	begin

		access_type <= data_access when dmem_i.mem_valid = '1' else instr_access;

		if release_type = data_access and memory_ready = '0' then
			memory_valid <= '0';
			memory_instr <= '0';
			memory_addr <= (others => '0');
			memory_wdata <= (others => '0');
			memory_wstrb <= (others => '0');
		else
			memory_valid <= imem_i.mem_valid when access_type = instr_access else dmem_i.mem_valid;
			memory_instr <= imem_i.mem_instr when access_type = instr_access else dmem_i.mem_instr;
			memory_addr <= imem_i.mem_addr when access_type = instr_access else dmem_i.mem_addr;
			memory_wdata <= imem_i.mem_wdata when access_type = instr_access else dmem_i.mem_wdata;
			memory_wstrb <= imem_i.mem_wstrb when access_type = instr_access else dmem_i.mem_wstrb;
		end if;

		imem_o.mem_ready <= memory_ready when release_type = instr_access else '0';
		imem_o.mem_rdata <= memory_rdata when release_type = instr_access else (others => '0');

		dmem_o.mem_ready <= memory_ready when release_type = data_access else '0';
		dmem_o.mem_rdata <= memory_rdata when release_type = data_access else (others => '0');

	end process;

	process(clock)

	begin

		if rising_edge(clock) then

			if reset = '0' then
				release_type <= instr_access;
			else
				if release_type = instr_access then
					if access_type = data_access then
						release_type <= data_access;
					end if;
				elsif release_type = data_access then
					if memory_ready = '1' and access_type = instr_access then
						release_type <= instr_access;
					end if;
				end if;

			end if;

		end if;

	end process;

end architecture;
