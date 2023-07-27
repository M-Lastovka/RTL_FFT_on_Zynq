----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/17/2021 05:27:38 PM
-- Design Name: 
-- Module Name: fft_butterfly - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: pipelined butterfly unit
-- 
-- Dependencies: dig_top_pckg
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------h


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.MATH_REAL.ALL;
USE IEEE.NUMERIC_STD.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY fft_bttr2 IS
    PORT ( 
           -------------------clocks and reset--------------------------------
    
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic; 
           
           -------------------control-----------------------------------------
           
           alg_ctrl            : IN alg_command;
           
           -------------------data--------------------------------------------
           
           in_even_re          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_even_im          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_odd_re           : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_odd_im           : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           
           out_even_re         : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_even_im         : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_odd_re          : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_odd_im          : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           
           twiddle_re          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           twiddle_im          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0)
           
           );
END fft_bttr2;

ARCHITECTURE rtl OF fft_bttr2 IS

    --signals used to generate variable delay line
    TYPE pipeline_delay_arr IS ARRAY (C_BUFFER_DELAY DOWNTO 0) OF signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL even_re_del   : pipeline_delay_arr; 
    SIGNAL even_im_del   : pipeline_delay_arr;
    
    --cached alg_ctrl
    SIGNAL alg_ctrl_i    : alg_command;
    
    --cached odd and twiddle inputs
    SIGNAL in_odd_re_i        : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL in_odd_im_i        : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL twiddle_re_i       : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL twiddle_im_i       : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    
    --partal products of odd and twiddle factor complex multiplication
    SIGNAL par_prod_ac_c   : signed(2*C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_bd_c   : signed(2*C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_bc_c   : signed(2*C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_ad_c   : signed(2*C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_ac_i   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_bd_i   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_bc_i   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL par_prod_ad_i   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    
    --product of odd and twiddle factor complex multiplication
    SIGNAL prod_re_unsat_c   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL prod_im_unsat_c   : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL prod_re_c         : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL prod_im_c         : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL prod_re_i         : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL prod_im_i         : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    
    --final butterfly result
    SIGNAL out_even_re_c       : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_even_im_c       : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_re_c        : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_im_c        : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_even_re_unsat_c : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_even_im_unsat_c : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_re_unsat_c  : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_im_unsat_c  : signed(C_SAMPLE_WDT-1 DOWNTO 0);
    
BEGIN

    --simple signal assignement
    even_re_del(0) <= signed(in_even_re);
    even_im_del(0) <= signed(in_even_im);
    
    alg_ctrl_cache : PROCESS(sys_clk_in, rst_n_in)   
    BEGIN
    
        IF(rst_n_in = '0') THEN
            alg_ctrl_i   <= SLEEP;    
        ELSIF(rising_edge(sys_clk_in)) THEN
            alg_ctrl_i   <= alg_ctrl;  
        END IF;
    
    END PROCESS alg_ctrl_cache;
    
    
    pipeline_delay : FOR index IN 0 TO C_BUFFER_DELAY-1 GENERATE       --delays the even data signal by C_BUFFER_DELAY clock cycles
        
        dff : PROCESS(sys_clk_in, rst_n_in)
        BEGIN
        
            IF (rst_n_in = '0') THEN
                even_re_del(index+1) <= (OTHERS => '0');
                even_im_del(index+1) <= (OTHERS => '0');
            ELSIF(rising_edge(sys_clk_in)) THEN
                IF alg_ctrl_i = RD_0_WR_1 OR alg_ctrl_i = RD_1_WR_0 THEN    
                    even_re_del(index+1) <= even_re_del(index);
                    even_im_del(index+1) <= even_im_del(index);
                END IF;
            END IF;
        
        END PROCESS dff;
        
    END GENERATE pipeline_delay;
    
    in_cache : PROCESS(sys_clk_in, rst_n_in)    --inputs are cached
    BEGIN
    
        IF(rst_n_in = '0') THEN
            in_odd_re_i   <= (OTHERS => '0');
            in_odd_im_i   <= (OTHERS => '0');  
            twiddle_re_i  <= (OTHERS => '0');  
            twiddle_im_i  <= (OTHERS => '0');    
        ELSIF(rising_edge(sys_clk_in)) THEN
            IF alg_ctrl_i = RD_0_WR_1 OR alg_ctrl_i = RD_1_WR_0 THEN 
                in_odd_re_i   <= signed(in_odd_re);
                in_odd_im_i   <= signed(in_odd_im);  
                twiddle_re_i  <= signed(twiddle_re);  
                twiddle_im_i  <= signed(twiddle_im);  
            END IF;
        END IF;
    
    END PROCESS in_cache;
    
    odd_twiddle_mult : PROCESS(in_odd_re_i, in_odd_im_i, twiddle_re_i, twiddle_im_i) --partial products : (a+i*b)*(c+i*d) = (ac-bd) + i*(bc+ad)
    BEGIN
        par_prod_ac_c <= in_odd_re_i*signed(twiddle_re_i);
        par_prod_bd_c <= in_odd_im_i*signed(twiddle_im_i);
        par_prod_bc_c <= in_odd_im_i*signed(twiddle_re_i);
        par_prod_ad_c <= in_odd_re_i*signed(twiddle_im_i);
    END PROCESS odd_twiddle_mult;
    
    par_product_cache : PROCESS(sys_clk_in, rst_n_in)    --partial products are cached
    BEGIN
    
        IF(rst_n_in = '0') THEN
            par_prod_ac_i   <= (OTHERS => '0');
            par_prod_bd_i   <= (OTHERS => '0');  
            par_prod_bc_i   <= (OTHERS => '0');  
            par_prod_ad_i   <= (OTHERS => '0');    
        ELSIF(rising_edge(sys_clk_in)) THEN
            par_prod_ac_i   <=  shift_right(par_prod_ac_c,C_SCALE_LOG2)(C_SAMPLE_WDT-1 DOWNTO 0);
            par_prod_bd_i   <=  shift_right(par_prod_bd_c,C_SCALE_LOG2)(C_SAMPLE_WDT-1 DOWNTO 0);  
            par_prod_bc_i   <=  shift_right(par_prod_bc_c,C_SCALE_LOG2)(C_SAMPLE_WDT-1 DOWNTO 0);  
            par_prod_ad_i   <=  shift_right(par_prod_ad_c,C_SCALE_LOG2)(C_SAMPLE_WDT-1 DOWNTO 0);  
        END IF;
    
    END PROCESS par_product_cache;
    
    --partial products are added to form odd*twiddle
    odd_twiddle_add : PROCESS(par_prod_ac_i, par_prod_bd_i, par_prod_bc_i, par_prod_ad_i) 
    BEGIN
        
        prod_re_unsat_c <= par_prod_ac_i - par_prod_bd_i;
        prod_im_unsat_c <= par_prod_bc_i + par_prod_ad_i;
        
    END PROCESS odd_twiddle_add;
    
    -- on overflow, partial product is saturated
    odd_twiddle_sat : PROCESS(par_prod_ac_i,par_prod_bd_i,par_prod_bc_i,par_prod_ad_i,prod_re_unsat_c,prod_im_unsat_c, sys_clk_in)
    BEGIN
    
        --overflow detection
        IF ( (par_prod_ac_i(C_SAMPLE_WDT-1) /= par_prod_bd_i(C_SAMPLE_WDT-1)) AND ((prod_re_unsat_c(C_SAMPLE_WDT-1) XOR par_prod_bd_i(C_SAMPLE_WDT-1)) = '0') ) THEN 
            IF (par_prod_bd_i(C_SAMPLE_WDT-1) = '1') THEN   
                prod_re_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                prod_re_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Substraction overflow on Re{odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on
            
        ELSE
            prod_re_c <= prod_re_unsat_c;
        END IF; 
        
        --overflow detection
        IF ( (par_prod_bc_i(C_SAMPLE_WDT-1) = par_prod_ad_i(C_SAMPLE_WDT-1)) AND ((prod_im_unsat_c(C_SAMPLE_WDT-1) XOR par_prod_bc_i(C_SAMPLE_WDT-1)) = '1') ) THEN 
            IF (par_prod_bc_i(C_SAMPLE_WDT-1) = '1') THEN   
                prod_im_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                prod_im_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Addition overflow on Im{odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on
            
        ELSE
            prod_im_c <= prod_im_unsat_c;
        END IF; 
        
    END PROCESS odd_twiddle_sat;
    
    
    product_cache : PROCESS(sys_clk_in, rst_n_in)    --twiddle*odd product is cached
    BEGIN
    
        IF(rst_n_in = '0') THEN
            prod_re_i <= (OTHERS => '0');
            prod_im_i <= (OTHERS => '0');     
        ELSIF(rising_edge(sys_clk_in)) THEN
            prod_re_i <= prod_re_c;
            prod_im_i <= prod_im_c;  
        END IF;
    
    END PROCESS product_cache;
    
    final_add : PROCESS(prod_re_i, prod_im_i,even_re_del(C_BUFFER_DELAY), even_im_del(C_BUFFER_DELAY))
    BEGIN
    
        out_even_re_unsat_c <= even_re_del(C_BUFFER_DELAY) + prod_re_i;
        out_even_im_unsat_c <= even_im_del(C_BUFFER_DELAY) + prod_im_i;
        
        out_odd_re_unsat_c <= (even_re_del(C_BUFFER_DELAY) - prod_re_i);
        out_odd_im_unsat_c <= (even_im_del(C_BUFFER_DELAY) - prod_im_i);
    
    END PROCESS final_add;
    
    -- on overflow, final sum is saturated
    final_add_sat : PROCESS(prod_re_i,prod_im_i,even_re_del(C_BUFFER_DELAY),even_im_del(C_BUFFER_DELAY),out_even_re_unsat_c,out_even_im_unsat_c,out_odd_re_unsat_c,out_odd_im_unsat_c, sys_clk_in)
    BEGIN
        
        --overflow detection
        IF ( (prod_re_i(C_SAMPLE_WDT-1) = even_re_del(C_BUFFER_DELAY)(C_SAMPLE_WDT-1)) AND ((out_even_re_unsat_c(C_SAMPLE_WDT-1) XOR prod_re_i(C_SAMPLE_WDT-1)) = '1') ) THEN 
            IF (out_even_re_unsat_c(C_SAMPLE_WDT-1) = '1') THEN   
                out_even_re_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                out_even_re_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Addition overflow - final addition of Re{out_even} = Re{in_even + in_odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on
            
        ELSE
            out_even_re_c <= out_even_re_unsat_c;
        END IF; 
        
        --overflow detection
        IF ( (prod_im_i(C_SAMPLE_WDT-1) = even_im_del(C_BUFFER_DELAY)(C_SAMPLE_WDT-1)) AND ((out_even_im_unsat_c(C_SAMPLE_WDT-1) XOR prod_im_i(C_SAMPLE_WDT-1)) = '1') ) THEN 
            IF (out_even_im_unsat_c(C_SAMPLE_WDT-1) = '1') THEN   
                out_even_im_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                out_even_im_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Addition overflow - final addition of Im{out_even} = Im{in_even + in_odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on     
            
        ELSE
            out_even_im_c <= out_even_im_unsat_c;
        END IF;
        
        --overflow detection
        IF ( (even_re_del(C_BUFFER_DELAY)(C_SAMPLE_WDT-1) /= prod_re_i(C_SAMPLE_WDT-1)) AND ((out_odd_re_unsat_c(C_SAMPLE_WDT-1) XOR prod_re_i(C_SAMPLE_WDT-1)) = '0') ) THEN 
            IF (prod_re_i(C_SAMPLE_WDT-1) = '1') THEN   
                out_odd_re_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                out_odd_re_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Substraction overflow - final substraction of Re{out_odd} = Im{in_even - in_odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on
            
        ELSE
            out_odd_re_c <= out_odd_re_unsat_c;
        END IF; 
        
        --overflow detection
        IF ( (even_im_del(C_BUFFER_DELAY)(C_SAMPLE_WDT-1) /= prod_im_i(C_SAMPLE_WDT-1)) AND ((out_odd_im_unsat_c(C_SAMPLE_WDT-1) XOR prod_im_i(C_SAMPLE_WDT-1)) = '0') ) THEN --overflow detection
            IF (prod_im_i(C_SAMPLE_WDT-1) = '1') THEN   
                out_odd_im_c <= to_signed(2**(C_SAMPLE_WDT-1)-1,C_SAMPLE_WDT);     --saturate to max positive         
            ELSE
                out_odd_im_c <= to_signed(-2**(C_SAMPLE_WDT-1),C_SAMPLE_WDT);     --saturate to max negative
            END IF;
            
            -- synthesis translate_off
            IF(rising_edge(sys_clk_in)) THEN
                ASSERT FALSE
                REPORT "Substraction overflow - final substraction of Im{out_odd} = Im{in_even - in_odd*twiddle}!" SEVERITY WARNING;
            END IF;
            -- synthesis translate_on
                     
        ELSE
            out_odd_im_c <= out_odd_im_unsat_c;
        END IF; 
        
        
        
    END PROCESS final_add_sat;
    
    final_cache : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
    
        IF(rst_n_in = '0') THEN
            out_even_re <= (OTHERS => '0');
            out_even_im <= (OTHERS => '0');
            out_odd_re  <= (OTHERS => '0');
            out_odd_im  <= (OTHERS => '0');     
        ELSIF(rising_edge(sys_clk_in)) THEN
            out_even_re <= std_logic_vector(out_even_re_c);
            out_even_im <= std_logic_vector(out_even_im_c);
            out_odd_re  <= std_logic_vector(out_odd_re_c);
            out_odd_im  <= std_logic_vector(out_odd_im_c);  
        END IF;
    
    END PROCESS final_cache;
    
    
END rtl;
