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
        S_AXIS_TDATA	: IN std_logic_vector(S_TDATA_WDT-1 DOWNTO 0);         --data in
        S_AXIS_TLAST	: IN std_logic;                                        --indicates boundary of last packet
        S_AXIS_TVALID	: IN std_logic;                                        --master initiate
        
        -----------------------AXI stream PL to memory---------------------------
        
        M_AXIS_TREADY	: IN  std_logic;                                        --slave ready
        M_AXIS_TDATA	: OUT std_logic_vector(M_TDATA_WDT-1 DOWNTO 0);         --data in
        M_AXIS_TLAST	: OUT std_logic;                                        --indicates boundary of last packet
        M_AXIS_TVALID	: OUT std_logic
  
  );
END dig_top;

ARCHITECTURE  rtl OF dig_top IS

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
    
    SIGNAL m_axis_if_busy           :    std_logic;   
    SIGNAL m_axis_if_addr           :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL s_axis_if_addr           :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL s_axis_if_busy           :    std_logic;
    
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
           all_done          : OUT std_logic;   --everything is done
           
           ----------------------------status & IF config control---------------------
           
           overflow_warn            : OUT std_logic;   --somewhere in the computation, an addition overflow has ocurred, result may be unreliable (clipped)
           rx_single_ndouble_mode   : IN  std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
           tx_single_ndouble_mode   : IN  std_logic;   -- = '1' - output samples are transmited one at a time through port 0
                                                       -- = '0' - output samples are transmited two at a time
           burst_mode_en            : IN  std_logic    --burst mode enable                                                                                                                       
           
           );
    END COMPONENT fft_dig_top;

    COMPONENT axis_master_if IS
        PORT ( 
            clk             : IN  std_logic;
            rst_n           : IN  std_logic;
            M_AXIS_TREADY	: IN  std_logic;                                        --slave ready
            M_AXIS_TDATA	: OUT std_logic_vector(M_TDATA_WDT-1 DOWNTO 0);         --data in
            M_AXIS_TLAST	: OUT std_logic;                                        --indicates boundary of last packet
            M_AXIS_TVALID	: OUT std_logic;
            m_axis_if_addr  : OUT std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
            data_re_0_out   : IN  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
            data_im_0_out   : IN  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
            pop             : OUT std_logic;
            tx_ready        : IN  std_logic;
            tx_done         : OUT std_logic;
            m_axis_if_busy  : OUT std_logic
           );
    END COMPONENT axis_master_if;

    COMPONENT axis_slave_if IS
        PORT ( 
            clk             : IN  std_logic;
            rst_n           : IN  std_logic;
            S_AXIS_TREADY	: OUT std_logic;                                        --slave ready
            S_AXIS_TDATA	: IN  std_logic_vector(M_TDATA_WDT-1 DOWNTO 0);         --data in
            S_AXIS_TLAST	: IN  std_logic;                                        --indicates boundary of last packet
            S_AXIS_TVALID	: IN  std_logic;
            s_axis_if_addr  : OUT std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
            data_re_0_in    : OUT std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
            data_im_0_in    : OUT std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
            push            : OUT std_logic;
            comp_busy       : IN  std_logic;
            m_axis_if_busy  : IN  std_logic;
            rx_done         : OUT std_logic;
            s_axis_if_busy  : OUT std_logic
           );
    END COMPONENT axis_slave_if;
    
    
BEGIN

    --fft block configuration
    addr_1_in    <= (OTHERS => '0');
    data_re_1_in <= (OTHERS => '0');
    data_im_1_in <= (OTHERS => '0');

    rx_ack       <= '0';
    tx_ack       <= '0';

    rx_single_ndouble_mode <= '1';
    tx_single_ndouble_mode <= '1';
    burst_mode_en          <= '1';

    request <= s_axis_if_busy;

    --FFT address arbitration
    fft_addr_arbitr : process (s_axis_if_busy, s_axis_if_addr, m_axis_if_addr)
    begin
        if s_axis_if_busy = '1' then
            addr_0_in <= s_axis_if_addr;
        elsif m_axis_if_busy = '1' then
            addr_0_in <= m_axis_if_addr;
        else                
            addr_0_in <= (others => '0');
        end if;
    end process;


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

    master_if : axis_master_if
        PORT MAP( 
            clk             => clk,
            rst_n           => rst_n,
            M_AXIS_TREADY	=> M_AXIS_TREADY,     --slave ready
            M_AXIS_TDATA	=> M_AXIS_TDATA,     --data in
            M_AXIS_TLAST	=> M_AXIS_TLAST,     --indicates boundary of last packet
            M_AXIS_TVALID	=> M_AXIS_TVALID,
            m_axis_if_addr  => m_axis_if_addr,
            data_re_0_out   => data_re_0_out,
            data_im_0_out   => data_im_0_out,
            pop             => pop,
            tx_ready        => tx_ready,
            tx_done         => tx_done,
            m_axis_if_busy  => m_axis_if_busy
           );

    slave_if : axis_slave_if
        PORT MAP( 
            clk             => clk,
            rst_n           => rst_n,
            S_AXIS_TREADY   => S_AXIS_TREADY,
            S_AXIS_TDATA    => S_AXIS_TDATA,
            S_AXIS_TLAST    => S_AXIS_TLAST,
            S_AXIS_TVALID   => S_AXIS_TVALID,
            s_axis_if_addr  => s_axis_if_addr,
            data_re_0_in    => data_re_0_in,
            data_im_0_in    => data_im_0_in,
            push            => push,
            comp_busy       => busy,
            m_axis_if_busy  => m_axis_if_busy,
            rx_done         => rx_done,
            s_axis_if_busy  => s_axis_if_busy
           );
    

END rtl;