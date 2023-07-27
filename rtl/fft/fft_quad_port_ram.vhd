----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/16/2021 05:32:58 PM
-- Design Name: 
-- Module Name: fft_quad_port_ram
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Simple dual port, two write BRAM
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-----------------------------------------------------------------------------------



LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY fft_quad_port_ram IS
    PORT ( 
           -------------------clocks and reset--------------------------------
           
           sys_clk_in     : IN  std_logic;
           rst_n_in       : IN  std_logic; 
           
           -------------------data--------------------------------------------
            
           din_A          : IN std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
           din_B          : IN std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
           
           dout_A          : OUT std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
           dout_B          : OUT std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
           
           addr_A          : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_B          : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
            
           -------------------control-----------------------------------------
           
           en_A               : IN std_logic;
           en_B               : IN std_logic;
           
           wr_en_A            : IN std_logic;
           wr_en_B            : IN std_logic
            
           );
END fft_quad_port_ram;

ARCHITECTURE rtl OF fft_quad_port_ram IS

    TYPE mem_space IS ARRAY (C_FFT_SIZE-1 DOWNTO 0) OF std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SHARED VARIABLE ram_v : mem_space;
    
    --debug variables to allow tracing of BRAM memory by xilinx tools
    SIGNAL ram_A_debug : mem_space;
    SIGNAL ram_B_debug : mem_space;
    
    SIGNAL clk_a :  std_logic;
    SIGNAL clk_b :  std_logic;  
    
BEGIN

    clk_a <= sys_clk_in;
    clk_b <= sys_clk_in;

    bram_A : PROCESS(clk_a)
    BEGIN    
    
        IF rising_edge(clk_a) THEN          
            IF en_A = '1' THEN   --read access        
                dout_A <= ram_v(to_integer(unsigned(addr_A))); 
                IF(C_VERB = VERB_HIGH) THEN
                  REPORT "Value: " & integer'image(to_integer(signed(ram_v(to_integer(unsigned(addr_A)))))) & 
                  "@ addr: [" & integer'image(to_integer(unsigned(addr_A))) & 
                  "] read from the FFT memory A";
                END IF;             
                IF wr_en_A = '1' THEN --write access
                    ram_v(to_integer(unsigned(addr_A))) := din_A;
                    -- synthesis translate_off
                    ram_A_debug(to_integer(unsigned(addr_A))) <= din_A;
                    IF(C_VERB = VERB_HIGH) THEN
                      REPORT "Value: " & integer'image(to_integer(signed(din_A))) & 
                      "@ addr: [" & integer'image(to_integer(unsigned(addr_A))) & 
                      "] written to the FFT memory B";
                    END IF;
                    -- synthesis translate_on
                END IF;       
            END IF;       
        END IF;    
           
    END PROCESS bram_A;

    bram_B : PROCESS(clk_b)
    BEGIN
    
        IF rising_edge(clk_b) THEN 
            IF en_B = '1' THEN
                dout_B <= ram_v(to_integer(unsigned(addr_B)));  
                IF(C_VERB = VERB_HIGH) THEN
                  REPORT "Value: " & integer'image(to_integer(signed(ram_v(to_integer(unsigned(addr_B)))))) & 
                  "@ addr: [" & integer'image(to_integer(unsigned(addr_B))) & 
                  "] read from the FFT memory B";
                END IF;
                IF wr_en_B = '1' THEN
                    ram_v(to_integer(unsigned(addr_B))) := din_B;
                    -- synthesis translate_off
                    ram_B_debug(to_integer(unsigned(addr_B))) <= din_B;
                    IF(C_VERB = VERB_HIGH) THEN
                      REPORT "Value: " & integer'image(to_integer(signed(din_B))) & 
                      "@ addr: [" & integer'image(to_integer(unsigned(addr_B))) & 
                      "] written to the FFT memory B";
                    END IF;
                    -- synthesis translate_on
                END IF;                
            END IF;       
        END IF;    
    
    END PROCESS bram_B;

    
END rtl;

