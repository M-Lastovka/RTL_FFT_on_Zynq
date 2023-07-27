----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/13/2022 08:12:09 PM
-- Design Name: 
-- Module Name: dig_top.vhd
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: FFT on zynq top 
-- 
-- Dependencies: 
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
USE xil_defaultlib.fft_pckg.ALL;


ENTITY dig_top IS
  PORT ( 
        -----------------------clocks and resets---------------------------------
           
        clk             : IN  std_logic;
        rst_n           : IN  std_logic;
        
        -----------------------AXI stream memory to PL---------------------------
        
        S_AXIS_TREADY	: OUT std_logic;                                       --slave ready
        S_AXIS_TDATA	: IN std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
        S_AXIS_TLAST	: IN std_logic;                                        --indicates boundary of last packet
        S_AXIS_TVALID	: IN std_logic;                                        --master initiate
        
        -----------------------AXI stream PL to memory---------------------------
        
        M_AXIS_TREADY	: IN  std_logic;                                        --slave ready
        M_AXIS_TDATA	: OUT std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
        M_AXIS_TLAST	: OUT std_logic;                                        --indicates boundary of last packet
        M_AXIS_TVALID	: OUT std_logic
  
  );
END dig_top;

ARCHITECTURE structural OF dig_top IS

    --FFT block signals
    SIGNAL data_re_0_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_0_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_1_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_1_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_0_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_0_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_1_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_1_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
    SIGNAL addr_0_in                :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_1_in                :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                            
    SIGNAL busy                     :    std_logic;   --fft processor is doing something
    SIGNAL request                  :    std_logic;   --request from external master, starts operation
    SIGNAL rx_ready                 :    std_logic;   --a sample is ready to be pushed into memory
    SIGNAL rx_val                   :    std_logic;   --a sample has been pushed into memory 
    SIGNAL rx_ack                   :    std_logic;   --end rx transaction of this sample and move onto another           :
    SIGNAL push                     :    std_logic;   --memory write signal for incoming sample, not used in burst mode
    SIGNAL rx_done                  :    std_logic;   --the memory is filled with external data, computation can begin
    SIGNAL comp_done                :    std_logic;   --algorithm has finished
    SIGNAL tx_ready                 :    std_logic;   --ready to transmit dft sample
    SIGNAL tx_val                   :    std_logic;   --the sample at the output is valid
    SIGNAL tx_ack                   :    std_logic;   --end tx transaction of this sample and move onto another
    SIGNAL pop                      :    std_logic;   --memory read acknowledge signal, not used in burst mode
    SIGNAL tx_done                  :    std_logic;   --all dft samples have been transmited
    SIGNAL all_done                 :    std_logic;    --everything is done
    SIGNAL overflow_warn            :    std_logic;   --somewhere in the computation, an addition overflow has ocurred, result may be unreliable (clipped)
    SIGNAL rx_single_ndouble_mode   :    std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
    SIGNAL tx_single_ndouble_mode   :    std_logic;   -- = '1' - output samples are transmited one at a time through port 0
                                                       -- = '0' - output samples are transmited two at a time
    SIGNAL burst_mode_en            :    std_logic;    --burst mode enable    
    SIGNAL s_fifo_out_data_q        :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);          --FIFO output data
    SIGNAL addr_0_i_in              :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL data_re_window_d         :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL m_write_cnt_std          :    std_logic_vector(C_FFT_SPECTR_COUNT_LOG2-1 DOWNTO 0);
    
    SIGNAL addr_window_fnc_q        :    std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-1 DOWNTO 0);
    SIGNAL window_read_en_q         :    std_logic;
    SIGNAL window_sample_d          :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);	
    
    
    COMPONENT fft_dig_top IS
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
    END COMPONENT fft_dig_top;
    
    
BEGIN

    fft_block : fft_dig_top
        PORT MAP( 
          
           sys_clk_in              => clk, 
           rst_n_in                => rst_n, 
           data_re_0_in            => data_re_0_in, 
           data_im_0_in            => data_im_0_in, 
           data_re_1_in            => data_re_1_in, 
           data_im_1_in            => data_im_1_in, 
           data_re_0_out           => data_re_0_out, 
           data_im_0_out           => data_im_0_out, 
           data_re_1_out           => data_re_1_out, 
           data_im_1_out           => data_im_1_out,   
           addr_0_in               => addr_0_in, 
           addr_1_in               => addr_1_in,    
           busy                    => busy, 
           request                 => request, 
           rx_ready                => rx_ready, 
           rx_val                  => rx_val, 
           rx_ack                  => rx_ack, 
           push                    => push, 
           rx_done                 => rx_done, 
           comp_done               => comp_done, 
           tx_ready                => tx_ready, 
           tx_val                  => tx_val, 
           tx_ack                  => tx_ack, 
           pop                     => pop, 
           tx_done                 => tx_done, 
           all_done                => all_done,   
           overflow_warn           => overflow_warn,  
           rx_single_ndouble_mode  => rx_single_ndouble_mode,                                  
           tx_single_ndouble_mode  => tx_single_ndouble_mode,                                   
           burst_mode_en           => burst_mode_en            
           
           );
    

END rtl;