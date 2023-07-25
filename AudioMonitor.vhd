-- AudioMonitor.vhd
-- This SCOMP peripheral translates bursts of snaps to strings of letters.
-- Short bursts of sound will be recognized as snaps. Snaps associated with
-- each other will be stored a number that corresponds to a letter, and longer
-- pauses between snaps will indicate a new letter to be encoded. 
-- Examples: 1 snap is A, 2 snaps is B, ... , 6 snaps is F. Only letters A-F
-- are detected correctly by the peripheral. Anything above 6 snaps is outputted
-- as 7 by default as an error value (7-segment display can only show A-F).
-- Group 1 
-- ECE 2031 L10 
-- 4/14/23

library IEEE;
library lpm;

use IEEE.std_logic_1164.all;
use lpm.lpm_components.all;
use IEEE.numeric_std.all;				-- added to use to_integer

entity AudioMonitor is
port(
    CS          : in  std_logic;
    IO_WRITE    : in  std_logic;
    SYS_CLK     : in  std_logic;  -- SCOMP's clock
    RESETN      : in  std_logic;
    AUD_DATA    : in  std_logic_vector(15 downto 0);
    AUD_NEW     : in  std_logic;
    IO_DATA     : inout  std_logic_vector(15 downto 0)
);
end AudioMonitor;

architecture a of AudioMonitor is

    signal out_en      : std_logic;
	 
	 -- rising-edge latched version of parsed_data
    signal output_data : std_logic_vector(15 downto 0);
	 
    -- output of up to four letters goes here
	 signal parsed_data : std_logic_vector(15 downto 0);
	 
	 -- parsed_data is concatenation of letters 1-4
	 signal letter1 : std_logic_vector (3 downto 0);
	 signal letter2 : std_logic_vector (3 downto 0);
	 signal letter3 : std_logic_vector (3 downto 0);
	 signal letter4 : std_logic_vector (3 downto 0);

	 -- constants
	 ------------
	 -- minimum magnitude the ADC input must cross to count as a snap
	 constant SOUND_THRESHOLD : signed := x"0900";
	 -- minimum number of ticks a snap should last for
	 constant SNAP_DECAY_TICKS : integer := 1000; -- ticks of ADC
	 -- minimum number of ticks for a pause between letters (about 1 second)
	 constant BETWEEN_LETTERS : integer := 50000;
	 -- minimum number of ticks for a pause between snaps (about 0.02 seconds)
	 constant BETWEEN_SNAPS : integer := 1000;
	 
	 -- state variables, set on RESET (below)
	 ----------
	 -- holds number of ticks since the peripheral was last reset
	 shared variable current_time : integer;
	 -- the value of the tick starting a new snap
	 shared variable snap_start_time : integer;
	 -- true if the value of snap_start_time is valid (becomes invalid after used once)
	 shared variable snap_start_time_valid : boolean;
	 -- the number of snaps in the current letter
	 shared variable snaps_in_this_burst : integer;
	 -- variable for convenience, to avoid repeatedly copy-pasting (current_time - snap_start_time)
	 shared variable time_since_snap_started : integer; 
	 
begin

    -- Latch data on rising edge of CS to keep it stable during IN
    process (CS) begin
        if rising_edge(CS) then
            output_data <= parsed_data;
        end if;
    end process;
    -- Drive IO_DATA when needed.
    out_en <= CS AND ( NOT IO_WRITE );
    with out_en select IO_DATA <=
        output_data        when '1',
        "ZZZZZZZZZZZZZZZZ" when others;
	 
	 process (RESETN, SYS_CLK, CS, IO_WRITE)
    begin
			-- on RESET or OUT from SCOMP
			if (RESETN = '0'  OR (CS = '1' AND IO_WRITE = '1')) then
				-- reset state of peripheral
				current_time := 0;
				snap_start_time := 0;
				snap_start_time_valid := false;
				snaps_in_this_burst := 0;
				time_since_snap_started := 0;
				
				-- clear output
				letter1 <= "0000";
				letter2 <= "0000";
				letter3 <= "0000";
				letter4 <= "0000";
				parsed_data <= x"0000";
				
			-- on new audio sample from ADC (every ADC tick)
			elsif (rising_edge(AUD_NEW)) then
				-- count ticks since peripheral was started/reset
				current_time := current_time + 1;

				-- latch output to concatenation of all 4 letters
				parsed_data <= letter1 & letter2 & letter3 & letter4;
				
				-- special case: if we only get one letter ever, make sure it is output
				if (snaps_in_this_burst /= 0) then
					if (snaps_in_this_burst < 7) then 
						letter4 <= std_logic_vector(to_unsigned(snaps_in_this_burst + 9,4));
					else 
						letter4 <= std_logic_vector(to_unsigned(7,4));
					end if;
				end if;
				
				if not snap_start_time_valid then
					-- save first tick when the sound is high enough
					-- mark snap_start_time_valid to enter the logic below 
					if (to_integer(signed(AUD_DATA)) > to_integer(signed(SOUND_THRESHOLD))) then						
						 snap_start_time := current_time;
						 snap_start_time_valid := true;
					end if;
				else
					-- if we are still in snap sound's decay period, don't do anything
					time_since_snap_started := (current_time - snap_start_time);
					if (time_since_snap_started < SNAP_DECAY_TICKS) then 
						snaps_in_this_burst := snaps_in_this_burst;
						
					-- after the decay period, determine if a snap or simply a loud continuous noise happened
					elsif (time_since_snap_started < BETWEEN_SNAPS) then
						 if (to_integer(signed(AUD_DATA)) > to_integer(signed(SOUND_THRESHOLD))) then
							  -- if we get a noise after decay and before expecting a new snap
							  -- then it must be loud continuous noise
							  -- exit snap detection logic
							  snap_start_time_valid := false;
						 end if;
						 
					-- if it is a snap (otherwise it would've exited above), increment snap count	
					elsif (time_since_snap_started = BETWEEN_SNAPS) then
						snaps_in_this_burst := snaps_in_this_burst + 1;		
						
					-- if we detect a new loud sound before a long pause, it must be a new snap in the same burst
					elsif (time_since_snap_started < BETWEEN_LETTERS) then
						if (to_integer(signed(AUD_DATA)) > to_integer(signed(SOUND_THRESHOLD))) then
							snap_start_time_valid := true;
							current_time := 0;
							snap_start_time := 0;
						end if;
						
					-- if it's been enough time for a new letter, shift each letter over, and prepare for new burst
					elsif (time_since_snap_started > BETWEEN_LETTERS) then
						if (to_integer(signed(AUD_DATA)) > to_integer(signed(SOUND_THRESHOLD))) then
						
							if(snaps_in_this_burst /= 0) then
								-- get the newest letter
								letter4 <= std_logic_vector(to_unsigned(snaps_in_this_burst + 9, 4));
								
								-- shift over the other letters
								letter1 <= letter2; 
								letter2 <= letter3;
								letter3 <= letter4;
								letter4 <= "0000"; -- leave space for the last letter to be added
							end if;
							
							-- finally, reset everything to start counting new burst
							current_time := 0;
							snap_start_time := 0;
							snap_start_time_valid := true;
							snaps_in_this_burst := 0;
						end if;
					end if;					
				end if;
        end if;
    end process;
end a;
