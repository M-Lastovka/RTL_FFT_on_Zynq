----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/17/2021 05:27:38 PM
-- Design Name: 
-- Module Name: fft_addr_gen - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: address generation unit for even and odd data + twiddle factors
-- 
-- Dependencies: dig_top_pckg
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- -
----------------------------------------------------------------------------------



LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;



ENTITY fft_addr_gen IS
    PORT (
           -------------------clocks and reset--------------------------------
           
           sys_clk_in     : IN  std_logic;
           rst_n_in       : IN  std_logic;
           
           -------------------data--------------------------------------------
            
           dpth_cnt          : IN std_logic_vector(natural(ceil(log2(real(C_FFT_SIZE_LOG2))))-1 DOWNTO 0);  --tree depth, counter output
           brdth_cnt         : IN std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                             --tree breadth, counter output
           
           alg_ctrl          : IN alg_command;                                                              --controls ROM MUXes and ROM wr_en and en signals, also shifts twiddle address masking register
           
           addr_even_c         : OUT  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_odd_c          : OUT  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_twiddle      : OUT  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0)
            
           );
END fft_addr_gen;

ARCHITECTURE rtl OF fft_addr_gen IS
 
    SIGNAL addr_twiddle_mask : std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);    --shift register mask to generate twiddle factor address
    
BEGIN
    
    --addr_even_c = rotate_left OF 2*brdth_cnt BY dpth_cnt 
    addr_even_c  <= std_logic_vector(rotate_left(unsigned(brdth_cnt(C_FFT_SIZE_LOG2-2 DOWNTO 0) & '0'),to_integer(unsigned(dpth_cnt))));
    --addr_odd_c = rotate_left OF 2*brdth_cnt + 1 BY dpth_cnt 
    addr_odd_c   <= std_logic_vector(rotate_left((unsigned(brdth_cnt(C_FFT_SIZE_LOG2-2 DOWNTO 0) & '0') + to_unsigned(1,C_FFT_SIZE_LOG2)),to_integer(unsigned(dpth_cnt))));
    
    addr_twiddle <= brdth_cnt AND addr_twiddle_mask;
    
    shift_reg : PROCESS(sys_clk_in, rst_n_in, alg_ctrl) 
    BEGIN
    
        IF(rst_n_in = '0' OR alg_ctrl = SLEEP) THEN
            addr_twiddle_mask <= '1' & std_logic_vector(to_unsigned(0,C_FFT_SIZE_LOG2-1));
        ELSIF(rising_edge(sys_clk_in)) THEN
            IF(alg_ctrl = SWEEP_FINISH) THEN
                addr_twiddle_mask <= '1' & addr_twiddle_mask(C_FFT_SIZE_LOG2-1 DOWNTO 1);    
            END IF;
        END IF;
        
    END PROCESS shift_reg;
    
END rtl;



