----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/22/2021 08:55:42 PM
-- Design Name: 
-- Module Name: fft_dig_top - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: dig_top_pckg
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;



ENTITY fft_dig_top IS
    PORT ( 
           -----------------------clocks and resets---------------------------------
           
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic;
            
           -------------------------------data-------------------------------------
           
           data_re_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
           
           -------------------------------address-----------------------------------
           
           addr_0_in          :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_1_in          :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                      
           
           ------------------------------handshake control--------------------------
           
           busy              : OUT std_logic;   --fft processor is doing something
           request           : IN  std_logic;   --request from external master, starts operation
           rx_ready          : OUT std_logic;   --a sample is ready to be pushed into memory
           rx_val            : OUT std_logic;   --a sample has been pushed into memory 
           rx_ack            : IN  std_logic;   --end rx transaction of this sample and move onto another           :
           push              : IN  std_logic;   --memory write signal for incoming sample, not used in burst mode
           rx_done           : IN  std_logic;   --the memory is filled with external data, computation can begin
           comp_done         : OUT std_logic;   --algorithm has finished
           tx_ready          : OUT std_logic;   --ready to transmit dft sample
           tx_val            : OUT std_logic;   --the sample at the output is valid
           tx_ack            : IN  std_logic;   --end tx transaction of this sample and move onto another
           pop               : IN  std_logic;   --memory read acknowledge signal, not used in burst mode
           tx_done           : IN  std_logic;   --all dft samples have been transmited
           all_done          : OUT std_logic;    --everything is done
           
           ----------------------------status & IF config control---------------------
           
           overflow_warn            : OUT std_logic;   --somewhere in the computation, an addition overflow has ocurred, result may be unreliable (clipped)
           rx_single_ndouble_mode   : IN  std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
           tx_single_ndouble_mode   : IN  std_logic;   -- = '1' - output samples are transmited one at a time through port 0
                                                       -- = '0' - output samples are transmited two at a time
           burst_mode_en            : IN  std_logic    --burst mode enable                                                                                                              
          
           
           );
END fft_dig_top;

ARCHITECTURE structural OF fft_dig_top IS

    SIGNAL addr_twiddle   :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL en_A           :     std_logic;
    SIGNAL en_B           :     std_logic;           
    SIGNAL wr_en_A        :     std_logic;
    SIGNAL wr_en_B        :     std_logic;
    SIGNAL dpth_cnt       :     std_logic_vector(natural(ceil(log2(real(C_FFT_SIZE_LOG2))))-1 DOWNTO 0);  --tree depth, counter output
    SIGNAL brdth_cnt      :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                             --tree breadth, counter output
    SIGNAL alg_ctrl       :     alg_command;
    SIGNAL addr_even_c    :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_odd_c     :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL in_even_re     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL in_even_im     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL in_odd_re      :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL in_odd_im      :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);           
    SIGNAL out_even_re    :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_even_im    :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_re     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL out_odd_im     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL twiddle_re     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL twiddle_im     :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);     
    SIGNAL twiddle_en     :     std_logic;

            
    COMPONENT fft_fsm
       PORT ( 
           -------------------clocks and reset--------------------------------
    
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic; 
           
           -------------------algorithm control-----------------------------------------
           
           dpth_cnt          : OUT std_logic_vector(natural(ceil(log2(real(C_FFT_SIZE_LOG2))))-1 DOWNTO 0);  --tree depth, counter output
           brdth_cnt         : OUT std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                             --tree breadth, counter output
           alg_ctrl          : OUT alg_command;                                                              --controls ROM MUXes and ROM wr_en and en signals, also shifts twiddle address masking register
           burst_mode_en     : IN  std_logic;   --burst mode enable

           
           -------------------handshake control-----------------------------------------
           
           busy              : OUT std_logic;   --fft processor is doing something
           request           : IN  std_logic;   --request from external master, starts operation
           rx_ready          : OUT std_logic;   --a sample is ready to be pushed into memory
           rx_val            : OUT std_logic;   --a sample has been pushed into memory
           rx_ack            : IN  std_logic;   --end rx transaction of this sample and move onto another
           push              : IN  std_logic;   --memory write signal for incoming sample, not used in burst mode
           rx_done           : IN  std_logic;   --the memory is filled with external data, computation can begin
           comp_done         : OUT std_logic;   --algorithm has finished
           tx_ready          : OUT std_logic;   --ready to transmit computed sample
           tx_val            : OUT std_logic;   --the sample at the output is valid
           tx_ack            : IN  std_logic;   --end tx transaction of this sample and move onto another
           pop               : IN  std_logic;   --memory read acknowledge signal, not used in burst mode
           tx_done           : IN  std_logic;   --all dft samples have been transmited
           all_done          : OUT std_logic    --everything is done
                   
           );
    END COMPONENT fft_fsm;   

    
    COMPONENT fft_bttr2
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
    END COMPONENT fft_bttr2;
    
    COMPONENT fft_addr_gen
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
           addr_twiddle        : OUT  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0)
            
           );
    END COMPONENT fft_addr_gen;
    
    COMPONENT fft_twiddle_LUT
        PORT ( 
           -------------------clocks and reset--------------------------------
           
           sys_clk_in     : IN  std_logic;
           twiddle_en     : IN  std_logic; 
           
           -------------------address--------------------------------------------
            
           addr_twiddle : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           
           -------------------data----------------------------------------------
           
           twiddle_re     : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           twiddle_im     : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0)
          
            
           );
    END COMPONENT fft_twiddle_LUT;
    
    COMPONENT fft_mem
        PORT ( 
           -----------------------clocks and resets--------------------------------
           
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic;
            
           -------------------------internal data-------------------------------------
           
           in_even_re          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_even_im          : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_odd_re           : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           in_odd_im           : IN std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           
           out_even_re         : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_even_im         : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_odd_re          : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           out_odd_im          : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           
           -------------------------external data-------------------------------------
           
           data_re_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
           
           -------------------------------address-----------------------------------
           
           addr_0_in           :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_1_in           :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_even_c         : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_odd_c          : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                       
           
           ------------------------------control-----------------------------------
           
           alg_ctrl                 : IN alg_command;                                                             --controls ROM MUXes and ROM wr_en and en signals, also shifts twiddle address masking register
           twiddle_en               : OUT std_logic;
           rx_single_ndouble_mode   : IN  std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
           tx_single_ndouble_mode   : IN  std_logic    -- = '1' - output samples are transmited one at a time through port 0
           
           );
    END COMPONENT fft_mem;
    
            

BEGIN

    fsm : fft_fsm
        PORT MAP (
            sys_clk_in      =>      sys_clk_in,     
            rst_n_in        =>      rst_n_in,       
            dpth_cnt        =>      dpth_cnt,       
            brdth_cnt       =>      brdth_cnt,      
            alg_ctrl        =>      alg_ctrl,       
            busy            =>      busy,           
            request         =>      request,        
            rx_ready        =>      rx_ready, 
            rx_val          =>      rx_val,
            rx_ack          =>      rx_ack,      
            push            =>      push,           
            rx_done         =>      rx_done,        
            comp_done       =>      comp_done,      
            tx_ready        =>      tx_ready,
            tx_val          =>      tx_val,
            tx_ack          =>      tx_ack,             
            pop             =>      pop,            
            tx_done         =>      tx_done,  
            burst_mode_en   =>      burst_mode_en,      
            all_done        =>      all_done        
        );
        
    bttr2 : fft_bttr2
        PORT MAP (
           sys_clk_in       =>      sys_clk_in,
           rst_n_in         =>      rst_n_in,  
           alg_ctrl         =>      alg_ctrl,         
           in_even_re       =>      out_even_re,
           in_even_im       =>      out_even_im,
           in_odd_re        =>      out_odd_re,
           in_odd_im        =>      out_odd_im,
           out_even_re      =>      in_even_re,
           out_even_im      =>      in_even_im,
           out_odd_re       =>      in_odd_re,
           out_odd_im       =>      in_odd_im,
           twiddle_re       =>      twiddle_re,
           twiddle_im       =>      twiddle_im
        );
        
    addr_gen : fft_addr_gen
        PORT MAP (
           sys_clk_in       =>      sys_clk_in,
           rst_n_in         =>      rst_n_in,
           dpth_cnt         =>      dpth_cnt,
           brdth_cnt        =>      brdth_cnt,
           alg_ctrl         =>      alg_ctrl,
           addr_even_c      =>      addr_even_c,
           addr_odd_c       =>      addr_odd_c,
           addr_twiddle     =>      addr_twiddle
           );
           
    LUT : fft_twiddle_LUT
        PORT MAP (
           sys_clk_in       =>      sys_clk_in,
           addr_twiddle     =>      addr_twiddle,
           twiddle_en       =>      twiddle_en,
           twiddle_re       =>      twiddle_re, 
           twiddle_im       =>      twiddle_im
           );
           
    mem : fft_mem 
      PORT MAP ( 
           sys_clk_in              =>      sys_clk_in,
           rst_n_in                =>      rst_n_in,
           in_even_re              =>      in_even_re,
           in_even_im              =>      in_even_im,
           in_odd_re               =>      in_odd_re,
           in_odd_im               =>      in_odd_im,
           out_even_re             =>      out_even_re,
           out_even_im             =>      out_even_im,
           out_odd_re              =>      out_odd_re,
           out_odd_im              =>      out_odd_im,
           data_re_0_in            =>      data_re_0_in, 
           data_im_0_in            =>      data_im_0_in, 
           data_re_1_in            =>      data_re_1_in, 
           data_im_1_in            =>      data_im_1_in, 
           data_re_0_out           =>      data_re_0_out,
           data_im_0_out           =>      data_im_0_out,
           data_re_1_out           =>      data_re_1_out,
           data_im_1_out           =>      data_im_1_out,
           addr_0_in               =>      addr_0_in,
           addr_1_in               =>      addr_1_in,         
           addr_even_c             =>      addr_even_c,
           addr_odd_c              =>      addr_odd_c,                       
           alg_ctrl                =>      alg_ctrl,
           twiddle_en              =>      twiddle_en,
           rx_single_ndouble_mode  =>      rx_single_ndouble_mode,
           tx_single_ndouble_mode  =>      tx_single_ndouble_mode
           );


END structural;
