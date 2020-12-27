-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.configure.all;
use work.constants.all;
use work.wire.all;

entity dctrl is
	generic(
		cache_type      : integer;
		cache_set_depth : integer
	);
	port(
		reset   : in  std_logic;
		clock   : in  std_logic;
		ctrl_i  : in  ctrl_in_type;
		ctrl_o  : out ctrl_out_type;
		cache_i : in  mem_in_type;
		cache_o : out mem_out_type;
		mem_o   : in  mem_out_type;
		mem_i   : out mem_in_type
	);
end dctrl;

architecture behavior of dctrl is

	type state_type is (HIT,MISS,UPDATE,INVALIDATE);

	type ctrl_type is record
		addr    : std_logic_vector(63 downto 0);
		data    : std_logic_vector(63 downto 0);
		strb    : std_logic_vector(7 downto 0);
		tag     : std_logic_vector(58-cache_set_depth downto 0);
		sid     : integer range 0 to 2**cache_set_depth-1;
		lid     : integer range 0 to 4;
		invalid : std_logic;
		rden    : std_logic;
		wren    : std_logic;
	end record;

	constant init_ctrl_type : ctrl_type := (
		addr    => (others => '0'),
		data    => (others => '0'),
		strb    => (others => '0'),
		tag     => (others => '0'),
		sid     => 0,
		lid     => 0,
		invalid => '0',
		rden    => '0',
		wren    => '0'
	);

	type data_type is record
		state   : state_type;
		addr    : std_logic_vector(63 downto 0);
		data    : std_logic_vector(63 downto 0);
		strb    : std_logic_vector(7 downto 0);
		rdata   : std_logic_vector(63 downto 0);
		wdata   : std_logic_vector(63 downto 0);
		wstrb   : std_logic_vector(7 downto 0);
		tag     : std_logic_vector(58-cache_set_depth downto 0);
		dtag    : std_logic_vector(58-cache_set_depth downto 0);
		cline   : std_logic_vector(255 downto 0);
		dline   : std_logic_vector(255 downto 0);
		wen     : std_logic_vector(7 downto 0);
		wvec    : std_logic_vector(7 downto 0);
		dvec    : std_logic_vector(7 downto 0);
		sid     : integer range 0 to 2**cache_set_depth-1;
		lid     : integer range 0 to 4;
		count   : integer range 0 to 7;
		wid     : integer range 0 to 7;
		invalid : std_logic;
		valid   : std_logic;
		hit     : std_logic;
		miss    : std_logic;
		dirty   : std_logic;
		rden    : std_logic;
		wren    : std_logic;
		den     : std_logic;
		ready   : std_logic;
	end record;

	constant init_data_type : data_type := (
		state   => INVALIDATE,
		addr    => (others => '0'),
		data    => (others => '0'),
		strb    => (others => '0'),
		rdata   => (others => '0'),
		wdata   => (others => '0'),
		wstrb   => (others => '0'),
		tag     => (others => '0'),
		dtag    => (others => '0'),
		cline   => (others => '0'),
		dline   => (others => '0'),
		wen     => (others => '0'),
		wvec    => (others => '0'),
		dvec    => (others => '0'),
		sid     => 0,
		lid     => 0,
		wid     => 0,
		count   => 0,
		invalid => '0',
		valid   => '0',
		hit     => '0',
		miss    => '0',
		dirty   => '0',
		rden    => '0',
		wren    => '0',
		den     => '0',
		ready   => '0'
	);

	signal r,rin : ctrl_type := init_ctrl_type;
	signal r_next,rin_next : data_type := init_data_type;

begin

	process(cache_i,r)

	variable v : ctrl_type;

	begin

		v := r;

		v.invalid := '0';
		v.rden := '0';
		v.wren := '0';

		if cache_i.mem_valid = '1' then
			if cache_i.mem_invalid = '1' then
				v.invalid := '1';
			else
				v.rden := nor_reduce(cache_i.mem_wstrb);
				v.wren := or_reduce(cache_i.mem_wstrb);
				v.data := cache_i.mem_wdata;
				v.strb := cache_i.mem_wstrb;
				v.addr := cache_i.mem_addr(63 downto 5) & "00000";
				v.tag := cache_i.mem_addr(63 downto cache_set_depth+5);
				v.sid := to_integer(unsigned(cache_i.mem_addr(cache_set_depth+4 downto 5)));
				v.lid := to_integer(unsigned(cache_i.mem_addr(4 downto 3)));
			end if;
		end if;

		ctrl_o.data0_i.raddr <= v.sid;
		ctrl_o.data1_i.raddr <= v.sid;
		ctrl_o.data2_i.raddr <= v.sid;
		ctrl_o.data3_i.raddr <= v.sid;
		ctrl_o.data4_i.raddr <= v.sid;
		ctrl_o.data5_i.raddr <= v.sid;
		ctrl_o.data6_i.raddr <= v.sid;
		ctrl_o.data7_i.raddr <= v.sid;

		ctrl_o.tag0_i.raddr <= v.sid;
		ctrl_o.tag1_i.raddr <= v.sid;
		ctrl_o.tag2_i.raddr <= v.sid;
		ctrl_o.tag3_i.raddr <= v.sid;
		ctrl_o.tag4_i.raddr <= v.sid;
		ctrl_o.tag5_i.raddr <= v.sid;
		ctrl_o.tag6_i.raddr <= v.sid;
		ctrl_o.tag7_i.raddr <= v.sid;

		ctrl_o.valid_i.raddr <= v.sid;

		ctrl_o.dirty_i.raddr <= v.sid;

		rin <= v;

	end process;

	process(ctrl_i,cache_i,mem_o,r,r_next)

	variable v : data_type;

	begin

		v := r_next;

		v.rden := '0';
		v.wren := '0';
		v.den := '0';
		v.hit := '0';
		v.miss := '0';
		v.invalid := '0';
		v.wstrb := X"00";

		if r_next.state = HIT then
			v.rden := r.rden;
			v.wren := r.wren;
			v.addr := r.addr;
			v.data := r.data;
			v.strb := r.strb;
			v.tag := r.tag;
			v.sid := r.sid;
			v.lid := r.lid;
		end if;

		if (r.invalid) = '1' then
			v.sid := 0;
			v.state := INVALIDATE;
		end if;

		ctrl_o.hit_i.tag <= v.tag;
		ctrl_o.hit_i.tag0 <= ctrl_i.tag0_o.rdata;
		ctrl_o.hit_i.tag1 <= ctrl_i.tag1_o.rdata;
		ctrl_o.hit_i.tag2 <= ctrl_i.tag2_o.rdata;
		ctrl_o.hit_i.tag3 <= ctrl_i.tag3_o.rdata;
		ctrl_o.hit_i.tag4 <= ctrl_i.tag4_o.rdata;
		ctrl_o.hit_i.tag5 <= ctrl_i.tag5_o.rdata;
		ctrl_o.hit_i.tag6 <= ctrl_i.tag6_o.rdata;
		ctrl_o.hit_i.tag7 <= ctrl_i.tag7_o.rdata;
		ctrl_o.hit_i.valid <= ctrl_i.valid_o.rdata;

		case r_next.state is

			when HIT =>

				v.wvec := ctrl_i.valid_o.rdata;
				v.dvec := ctrl_i.dirty_o.rdata;
				v.wen := (others => '0');

				v.hit := ctrl_i.hit_o.hit and (v.rden or v.wren);
				v.miss := ctrl_i.hit_o.miss and (v.rden or v.wren);
				v.wid := ctrl_i.hit_o.wid;

				if v.miss = '1' then
					v.state := MISS;
					v.count := 0;
					v.valid := '1';
				elsif v.hit = '1' then
					v.wen(v.wid) := v.wren;
					v.wvec(v.wid) := v.wren;
					v.dvec(v.wid) := v.wren;
					v.den := v.wren;
					if v.wid = 0 then
							v.cline := ctrl_i.data0_o.rdata;
					elsif v.wid = 1 then
							v.cline := ctrl_i.data1_o.rdata;
					elsif v.wid = 2 then
							v.cline := ctrl_i.data2_o.rdata;
					elsif v.wid = 3 then
							v.cline := ctrl_i.data3_o.rdata;
					elsif v.wid = 4 then
							v.cline := ctrl_i.data4_o.rdata;
					elsif v.wid = 5 then
							v.cline := ctrl_i.data5_o.rdata;
					elsif v.wid = 6 then
							v.cline := ctrl_i.data6_o.rdata;
					elsif v.wid = 7 then
							v.cline := ctrl_i.data7_o.rdata;
					end if;
					v.valid := '0';
					if v.wren = '1' then
						v.state := UPDATE;
					end if;
				else
					v.valid := '0';
				end if;

			when MISS =>

				if r_next.miss = '1' then
					v.wid := ctrl_i.lru_o.wid;
					v.dirty := v.dvec(v.wid);
					v.dvec(v.wid) := r_next.wren;
					v.den := '1';
					if v.wid = 0 then
						v.dline := ctrl_i.data0_o.rdata;
						v.dtag := ctrl_i.tag0_o.rdata;
					elsif v.wid = 1 then
						v.dline := ctrl_i.data1_o.rdata;
						v.dtag := ctrl_i.tag1_o.rdata;
					elsif v.wid = 2 then
						v.dline := ctrl_i.data2_o.rdata;
						v.dtag := ctrl_i.tag2_o.rdata;
					elsif v.wid = 3 then
						v.dline := ctrl_i.data3_o.rdata;
						v.dtag := ctrl_i.tag3_o.rdata;
					elsif v.wid = 4 then
						v.dline := ctrl_i.data4_o.rdata;
						v.dtag := ctrl_i.tag4_o.rdata;
					elsif v.wid = 5 then
						v.dline := ctrl_i.data5_o.rdata;
						v.dtag := ctrl_i.tag5_o.rdata;
					elsif v.wid = 6 then
						v.dline := ctrl_i.data6_o.rdata;
						v.dtag := ctrl_i.tag6_o.rdata;
					elsif v.wid = 7 then
						v.dline := ctrl_i.data7_o.rdata;
						v.dtag := ctrl_i.tag7_o.rdata;
					end if;
				end if;

				if mem_o.mem_ready = '1' then

					case r_next.count is
						when 0 =>
							v.cline(63 downto 0) := mem_o.mem_rdata;
						when 1 =>
							v.cline(127 downto 64) := mem_o.mem_rdata;
						when 2 =>
							v.cline(191 downto 128) := mem_o.mem_rdata;
						when 3 =>
							v.cline(255 downto 192) := mem_o.mem_rdata;
							if v.dirty = '0' then
								v.wen(v.wid) := '1';
								v.wvec(v.wid) := '1';
								v.valid := '0';
								v.state := UPDATE;
							elsif v.dirty = '1' then
								v.addr := v.dtag & std_logic_vector(to_unsigned(v.sid,cache_set_depth)) & "00000";
								v.wdata := v.dline(63 downto 0);
								v.wstrb := X"FF";
							end if;
						when 4 =>
							v.wdata := v.dline(127 downto 64);
							v.wstrb := X"FF";
						when 5 =>
							v.wdata := v.dline(191 downto 128);
							v.wstrb := X"FF";
						when 6 =>
							v.wdata := v.dline(255 downto 192);
							v.wstrb := X"FF";
						when 7 =>
							v.wen(v.wid) := '1';
							v.wvec(v.wid) := '1';
							v.valid := '0';
							v.state := UPDATE;
						when others =>
							null;
					end case;

					if v.count /= 3 then
						v.addr(63 downto 3) := std_logic_vector(unsigned(v.addr(63 downto 3))+1);
					end if;

					if v.count /= 7 then
						v.count := v.count + 1;
					end if;

				end if;

			when UPDATE =>

				v.wen := (others => '0');
				v.wvec := (others => '0');
				v.dvec := (others => '0');
				v.valid := '0';
				v.state := HIT;

			when INVALIDATE =>

				v.wen := (others => '0');
				v.wvec := (others => '0');
				v.dvec := (others => '0');
				v.valid := '0';
				v.invalid := '1';

			when others =>

				null;

		end case;

		for i in 0 to 3 loop
			if v.lid = i then
				for j in 0 to 7 loop
					if v.strb(j) = '1' then
						v.cline(i*64+(j+1)*8-1 downto i*64+j*8) := v.data((j+1)*8-1 downto j*8);
					end if;
				end loop;
			end if;
		end loop;

		ctrl_o.data0_i.waddr <= v.sid;
		ctrl_o.data1_i.waddr <= v.sid;
		ctrl_o.data2_i.waddr <= v.sid;
		ctrl_o.data3_i.waddr <= v.sid;
		ctrl_o.data4_i.waddr <= v.sid;
		ctrl_o.data5_i.waddr <= v.sid;
		ctrl_o.data6_i.waddr <= v.sid;
		ctrl_o.data7_i.waddr <= v.sid;

		ctrl_o.data0_i.wen <= v.wen(0);
		ctrl_o.data1_i.wen <= v.wen(1);
		ctrl_o.data2_i.wen <= v.wen(2);
		ctrl_o.data3_i.wen <= v.wen(3);
		ctrl_o.data4_i.wen <= v.wen(4);
		ctrl_o.data5_i.wen <= v.wen(5);
		ctrl_o.data6_i.wen <= v.wen(6);
		ctrl_o.data7_i.wen <= v.wen(7);

		ctrl_o.data0_i.wdata <= v.cline;
		ctrl_o.data1_i.wdata <= v.cline;
		ctrl_o.data2_i.wdata <= v.cline;
		ctrl_o.data3_i.wdata <= v.cline;
		ctrl_o.data4_i.wdata <= v.cline;
		ctrl_o.data5_i.wdata <= v.cline;
		ctrl_o.data6_i.wdata <= v.cline;
		ctrl_o.data7_i.wdata <= v.cline;

		ctrl_o.tag0_i.waddr <= v.sid;
		ctrl_o.tag1_i.waddr <= v.sid;
		ctrl_o.tag2_i.waddr <= v.sid;
		ctrl_o.tag3_i.waddr <= v.sid;
		ctrl_o.tag4_i.waddr <= v.sid;
		ctrl_o.tag5_i.waddr <= v.sid;
		ctrl_o.tag6_i.waddr <= v.sid;
		ctrl_o.tag7_i.waddr <= v.sid;

		ctrl_o.tag0_i.wen <= v.wen(0);
		ctrl_o.tag1_i.wen <= v.wen(1);
		ctrl_o.tag2_i.wen <= v.wen(2);
		ctrl_o.tag3_i.wen <= v.wen(3);
		ctrl_o.tag4_i.wen <= v.wen(4);
		ctrl_o.tag5_i.wen <= v.wen(5);
		ctrl_o.tag6_i.wen <= v.wen(6);
		ctrl_o.tag7_i.wen <= v.wen(7);

		ctrl_o.tag0_i.wdata <= v.tag;
		ctrl_o.tag1_i.wdata <= v.tag;
		ctrl_o.tag2_i.wdata <= v.tag;
		ctrl_o.tag3_i.wdata <= v.tag;
		ctrl_o.tag4_i.wdata <= v.tag;
		ctrl_o.tag5_i.wdata <= v.tag;
		ctrl_o.tag6_i.wdata <= v.tag;
		ctrl_o.tag7_i.wdata <= v.tag;

		ctrl_o.lru_i.sid <= v.sid;
		ctrl_o.lru_i.wid <= v.wid;
		ctrl_o.lru_i.hit <= v.hit;
		ctrl_o.lru_i.miss <= v.miss;

		ctrl_o.dirty_i.waddr <= v.sid;
		ctrl_o.dirty_i.wen <= v.den or v.invalid;
		ctrl_o.dirty_i.wdata <= v.dvec;

		ctrl_o.valid_i.waddr <= v.sid;
		ctrl_o.valid_i.wen <= or_reduce(v.wen) or v.invalid;
		ctrl_o.valid_i.wdata <= v.wvec;

		if r_next.state = INVALIDATE then
			if v.sid = 2**cache_set_depth-1 then
				v.state := HIT;
			else
				v.sid := v.sid+1;
			end if;
		end if;

		if v.lid = 0 then
			v.rdata := v.cline(63 downto 0);
		elsif v.lid = 1 then
			v.rdata := v.cline(127 downto 64);
		elsif v.lid = 2 then
			v.rdata := v.cline(191 downto 128);
		elsif v.lid = 3 then
			v.rdata := v.cline(255 downto 192);
		end if;

		if r_next.state = HIT then
			v.ready := (v.rden or v.wren) and v.hit;
		elsif r_next.state = UPDATE then
			v.ready := '1';
		else
			v.ready := '0';
		end if;

		mem_i.mem_valid <= v.valid;
		mem_i.mem_instr <= '0';
		mem_i.mem_invalid <= '0';
		mem_i.mem_spec <= '0';
		mem_i.mem_addr <= v.addr;
		mem_i.mem_wdata <= v.wdata;
		mem_i.mem_wstrb <= v.wstrb;

		cache_o.mem_rdata <= v.rdata;
		cache_o.mem_ready <= v.ready;

		rin_next <= v;

	end process;

	process(clock)

	begin

		if rising_edge(clock) then

			if reset = '0' then

				r <= init_ctrl_type;
				r_next <= init_data_type;

			else

				r <= rin;
				r_next <= rin_next;

			end if;

		end if;

	end process;

end architecture;
