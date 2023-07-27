----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/22/2021 10:08:31 PM
-- Design Name: 
-- Module Name: fft_mem - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: memory unit, containts two dual port BRAMs and MUXing of data and address signals
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
USE xil_defaultlib.dig_top_pckg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;-

ENTITY fft_mem IS
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
END fft_mem;

ARCHITECTURE structural OF fft_mem IS
    
    SIGNAL in_even_0        :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL in_odd_0         :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL out_even_0       :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL out_odd_0        :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL addr_even_0_c    :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_odd_0_c     :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL en_even_0_c      :     std_logic;
    SIGNAL en_odd_0_c       :     std_logic;
    SIGNAL wr_en_even_0_c   :     std_logic;
    SIGNAL wr_en_odd_0_c    :     std_logic;
    
    SIGNAL in_even_1        :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL in_odd_1         :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL out_even_1       :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL out_odd_1        :     std_logic_vector(C_DFT_WDT-1 DOWNTO 0);
    SIGNAL addr_even_1_c    :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_odd_1_c     :     std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL en_even_1_c      :     std_logic;
    SIGNAL en_odd_1_c       :     std_logic;
    SIGNAL wr_en_even_1_c   :     std_logic;
    SIGNAL wr_en_odd_1_c    :     std_logic;
    
    --debug signals
    SIGNAL re_in_even_0_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_in_odd_0_d         :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_out_even_0_d       :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_out_odd_0_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_in_even_1_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_in_odd_1_d         :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_out_even_1_d       :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL re_out_odd_1_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);    
    SIGNAL im_in_even_0_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_in_odd_0_d         :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_out_even_0_d       :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_out_odd_0_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_in_even_1_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_in_odd_1_d         :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_out_even_1_d       :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL im_out_odd_1_d        :     std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    
    TYPE pipeline_delay_arr IS ARRAY (C_BUFFER_DELAY+2 DOWNTO 0) OF std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_even_del   : pipeline_delay_arr;
    SIGNAL addr_odd_del    : pipeline_delay_arr;
    
    SIGNAL addr_0_in_rev     : std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0); --bit permuted addresses
    SIGNAL addr_1_in_rev     : std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0); 

    COMPONENT fft_quad_port_ram
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
    END COMPONENT fft_quad_port_ram;
    
            

BEGIN

    --simple signal assignement
    addr_even_del(0) <= addr_even_c;
    addr_odd_del(0)  <= addr_odd_c;
    

    pipeline_delay : FOR index IN 0 TO C_BUFFER_DELAY+1 GENERATE       --delays of the write address
        
        dff : PROCESS(sys_clk_in, rst_n_in)
        BEGIN
        
            IF (rst_n_in = '0') THEN
                addr_even_del(index+1) <= (OTHERS => '0');
                addr_odd_del(index+1)  <= (OTHERS => '0');
            ELSIF(rising_edge(sys_clk_in)) THEN
                addr_even_del(index+1) <= addr_even_del(index);
                addr_odd_del(index+1) <= addr_odd_del(index);
            END IF;
        
        END PROCESS dff;
        
    END GENERATE pipeline_delay;
    
    bit_reversal : PROCESS(addr_0_in, addr_1_in)         --bit reversal permutation
    BEGIN
        FOR index IN 0 TO C_FFT_SIZE_LOG2-1 LOOP
            addr_0_in_rev(index) <= addr_0_in(C_FFT_SIZE_LOG2-1-index);
            addr_1_in_rev(index) <= addr_1_in(C_FFT_SIZE_LOG2-1-index);
        END LOOP;
    END PROCESS bit_reversal;
    
    addr_mux : PROCESS(alg_ctrl, addr_even_del(C_BUFFER_DELAY+2), addr_odd_del(C_BUFFER_DELAY+2), addr_even_c, 
                       addr_odd_c, addr_0_in_rev, addr_1_in_rev, addr_0_in, addr_1_in, rx_single_ndouble_mode, tx_single_ndouble_mode)
    BEGIN
        CASE(alg_ctrl) IS
            WHEN RX                                 =>
                IF (rx_single_ndouble_mode = '1') THEN --single transfer
                    addr_even_0_c <= addr_0_in_rev;
                    addr_odd_0_c  <= (OTHERS => '0');
                    addr_even_1_c <= (OTHERS => '0');
                    addr_odd_1_c  <= (OTHERS => '0');
                ELSE                                   --double transfer
                    addr_even_0_c <= addr_0_in_rev;
                    addr_odd_0_c  <= addr_1_in_rev;
                    addr_even_1_c <= (OTHERS => '0');
                    addr_odd_1_c  <= (OTHERS => '0');
                END IF;
            WHEN RD_0_WR_1                          =>
                addr_even_0_c <= addr_even_c;
                addr_odd_0_c  <= addr_odd_c;
                addr_even_1_c <= addr_even_del(C_BUFFER_DELAY+2);
                addr_odd_1_c  <= addr_odd_del(C_BUFFER_DELAY+2);
           WHEN RD_1_WR_0                           =>
                addr_even_0_c <= addr_even_del(C_BUFFER_DELAY+2);
                addr_odd_0_c  <= addr_odd_del(C_BUFFER_DELAY+2); 
                addr_even_1_c <= addr_even_c;
                addr_odd_1_c  <= addr_odd_c;
           WHEN TX                                  =>
                IF ((C_FFT_SIZE_LOG2 mod 2) = 0) THEN
                    IF (tx_single_ndouble_mode = '1') THEN --single transfer
                        addr_even_0_c <= addr_0_in;
                        addr_odd_0_c  <= (OTHERS => '0');
                        addr_even_1_c <= (OTHERS => '0');
                        addr_odd_1_c  <= (OTHERS => '0');
                    ELSE                                   --double transfer
                        addr_even_0_c <= addr_0_in;
                        addr_odd_0_c  <= addr_1_in;
                        addr_even_1_c <= (OTHERS => '0');
                        addr_odd_1_c  <= (OTHERS => '0');
                    END IF;
                ELSE
                    IF (tx_single_ndouble_mode = '1') THEN --single transfer
                        addr_even_0_c <= (OTHERS => '0');
                        addr_odd_0_c  <= (OTHERS => '0');
                        addr_even_1_c <= addr_0_in;
                        addr_odd_1_c  <= (OTHERS => '0');
                    ELSE                                   --double transfer
                        addr_even_0_c <= (OTHERS => '0');
                        addr_odd_0_c  <= (OTHERS => '0');
                        addr_even_1_c <= addr_0_in;
                        addr_odd_1_c  <= addr_1_in;
                    END IF;
                END IF;
           WHEN OTHERS                              =>
                addr_even_0_c <= (OTHERS => '0');
                addr_odd_0_c  <= (OTHERS => '0'); 
                addr_even_1_c <= (OTHERS => '0');
                addr_odd_1_c  <= (OTHERS => '0')
                ;  
        END CASE;
    END PROCESS addr_mux;
    
    data_in_mux : PROCESS(alg_ctrl, data_re_0_in, data_im_0_in, data_re_1_in, data_im_1_in, in_even_re,
     in_even_im, in_odd_re, in_odd_im, rx_single_ndouble_mode)
    BEGIN
        CASE(alg_ctrl) IS
            WHEN RX                                 =>
                IF (rx_single_ndouble_mode = '1') THEN
                    in_even_0   <= data_re_0_in & data_im_0_in;
                    in_odd_0    <= (OTHERS => '0');
                    in_even_1   <= (OTHERS => '0');
                    in_odd_1    <= (OTHERS => '0');
                ELSE
                    in_even_0   <= data_re_0_in & data_im_0_in;
                    in_odd_0    <= data_re_1_in & data_im_1_in;
                    in_even_1   <= (OTHERS => '0');
                    in_odd_1    <= (OTHERS => '0');
                END IF;
            WHEN RX_SLEEP                           =>
                IF (rx_single_ndouble_mode = '1') THEN          
                    in_even_0   <= data_re_0_in & data_im_0_in; 
                    in_odd_0    <= (OTHERS => '0');             
                    in_even_1   <= (OTHERS => '0');             
                    in_odd_1    <= (OTHERS => '0');             
                ELSE                                            
                    in_even_0   <= data_re_0_in & data_im_0_in; 
                    in_odd_0    <= data_re_1_in & data_im_1_in; 
                    in_even_1   <= (OTHERS => '0');             
                    in_odd_1    <= (OTHERS => '0');             
                END IF;                                         
            WHEN RD_0_WR_1                          =>
                in_even_0   <= (OTHERS => '0');
                in_odd_0    <= (OTHERS => '0');
                in_even_1   <= in_even_re & in_even_im;
                in_odd_1    <= in_odd_re & in_odd_im;
           WHEN RD_1_WR_0                           =>
                in_even_0   <= in_even_re & in_even_im;
                in_odd_0    <= in_odd_re & in_odd_im;
                in_even_1   <= (OTHERS => '0');
                in_odd_1    <= (OTHERS => '0');
           WHEN OTHERS                              =>
                in_even_0   <= (OTHERS => '0');
                in_odd_0    <= (OTHERS => '0');
                in_even_1   <= (OTHERS => '0');
                in_odd_1    <= (OTHERS => '0');  
        END CASE;
    END PROCESS data_in_mux;
    
    ram_0 : fft_quad_port_ram
        PORT MAP (
            sys_clk_in  =>      sys_clk_in,
            rst_n_in    =>      rst_n_in,
            din_A       =>      in_even_0,
            din_B       =>      in_odd_0,
            dout_A      =>      out_even_0,
            dout_B      =>      out_odd_0,
            addr_A      =>      addr_even_0_c,
            addr_B      =>      addr_odd_0_c,
            en_A        =>      en_even_0_c,
            en_B        =>      en_odd_0_c,
            wr_en_A     =>      wr_en_even_0_c,
            wr_en_B     =>      wr_en_odd_0_c  
        );
      
     ram_1 : fft_quad_port_ram
        PORT MAP (
            sys_clk_in  =>      sys_clk_in,
            rst_n_in    =>      rst_n_in,
            din_A       =>      in_even_1,
            din_B       =>      in_odd_1,
            dout_A      =>      out_even_1,
            dout_B      =>      out_odd_1,
            addr_A      =>      addr_even_1_c,
            addr_B      =>      addr_odd_1_c,
            en_A        =>      en_even_1_c,
            en_B        =>      en_odd_1_c,
            wr_en_A     =>      wr_en_even_1_c,
            wr_en_B     =>      wr_en_odd_1_c  
        );
        
    access_dec : PROCESS(alg_ctrl,rx_single_ndouble_mode,tx_single_ndouble_mode)       --decodes fsm input to RAM enables and write enables
    BEGIN
    
        CASE(alg_ctrl) IS
            WHEN RX                     =>
                IF (rx_single_ndouble_mode = '1') THEN
                    en_even_0_c     <= '1';
                    en_odd_0_c      <= '0';
                    wr_en_even_0_c  <= '1';
                    wr_en_odd_0_c   <= '0';
                    en_even_1_c     <= '0';
                    en_odd_1_c      <= '0';
                    wr_en_even_1_c  <= '0';
                    wr_en_odd_1_c   <= '0';
                    twiddle_en      <= '0';
                ELSE
                    en_even_0_c     <= '1';
                    en_odd_0_c      <= '1';
                    wr_en_even_0_c  <= '1';
                    wr_en_odd_0_c   <= '1';
                    en_even_1_c     <= '0';
                    en_odd_1_c      <= '0';
                    wr_en_even_1_c  <= '0';
                    wr_en_odd_1_c   <= '0';
                    twiddle_en      <= '0';
                END IF;
            WHEN RD_0_WR_1              =>
                en_even_0_c     <= '1';
                en_odd_0_c      <= '1';
                wr_en_even_0_c  <= '0';
                wr_en_odd_0_c   <= '0';
                en_even_1_c     <= '1';
                en_odd_1_c      <= '1';
                wr_en_even_1_c  <= '1';
                wr_en_odd_1_c   <= '1';
                twiddle_en      <= '1';
            WHEN RD_1_WR_0              =>
                en_even_0_c     <= '1';
                en_odd_0_c      <= '1';
                wr_en_even_0_c  <= '1';
                wr_en_odd_0_c   <= '1';
                en_even_1_c     <= '1';
                en_odd_1_c      <= '1';
                wr_en_even_1_c  <= '0';
                wr_en_odd_1_c   <= '0';
                twiddle_en      <= '1';
            WHEN TX                     =>
                IF ((C_FFT_SIZE_LOG2 mod 2) = 0) THEN
                   IF (tx_single_ndouble_mode = '1') THEN  
                       en_even_0_c     <= '1';             
                       en_odd_0_c      <= '0';             
                       wr_en_even_0_c  <= '0';             
                       wr_en_odd_0_c   <= '0';             
                       en_even_1_c     <= '0';             
                       en_odd_1_c      <= '0';             
                       wr_en_even_1_c  <= '0';             
                       wr_en_odd_1_c   <= '0';             
                       twiddle_en      <= '0';             
                   ELSE                                    
                       en_even_0_c     <= '1';             
                       en_odd_0_c      <= '1';             
                       wr_en_even_0_c  <= '0';             
                       wr_en_odd_0_c   <= '0';             
                       en_even_1_c     <= '0';             
                       en_odd_1_c      <= '0';             
                       wr_en_even_1_c  <= '0';             
                       wr_en_odd_1_c   <= '0';             
                       twiddle_en      <= '0';             
                   END IF;                                               
                ELSE
                    IF (tx_single_ndouble_mode = '1') THEN  
                        en_even_0_c     <= '0';             
                        en_odd_0_c      <= '0';             
                        wr_en_even_0_c  <= '0';             
                        wr_en_odd_0_c   <= '0';             
                        en_even_1_c     <= '1';             
                        en_odd_1_c      <= '0';             
                        wr_en_even_1_c  <= '0';             
                        wr_en_odd_1_c   <= '0';             
                        twiddle_en      <= '0';             
                    ELSE                                    
                        en_even_0_c     <= '0';             
                        en_odd_0_c      <= '0';             
                        wr_en_even_0_c  <= '0';             
                        wr_en_odd_0_c   <= '0';             
                        en_even_1_c     <= '1';             
                        en_odd_1_c      <= '1';             
                        wr_en_even_1_c  <= '0';             
                        wr_en_odd_1_c   <= '0';             
                        twiddle_en      <= '0';             
                    END IF;                                                    
                END IF;
            WHEN OTHERS                 =>
                en_even_0_c     <= '0';
                en_odd_0_c      <= '0';
                wr_en_even_0_c  <= '0';
                wr_en_odd_0_c   <= '0';
                en_even_1_c     <= '0';
                en_odd_1_c      <= '0';
                wr_en_even_1_c  <= '0';
                wr_en_odd_1_c   <= '0';
                twiddle_en      <= '0';
        END CASE;
    
    END PROCESS access_dec;
    
    data_out_mux : PROCESS(alg_ctrl, out_even_0, out_odd_0, out_even_1, out_odd_1, tx_single_ndouble_mode)
    BEGIN
        CASE(alg_ctrl) IS
            WHEN TX                                 =>
                IF ((C_FFT_SIZE_LOG2 mod 2) = 0) THEN
                    IF(tx_single_ndouble_mode = '1') THEN
                        data_re_0_out   <= out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);
                        data_re_1_out   <= (OTHERS => '0');
                        data_im_1_out   <= (OTHERS => '0');
                        out_even_re     <= (OTHERS => '0');
                        out_even_im     <= (OTHERS => '0');
                        out_odd_re      <= (OTHERS => '0');
                        out_odd_im      <= (OTHERS => '0'); 
                    ELSE
                        data_re_0_out   <= out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT); 
                        data_im_0_out   <= out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);         
                        data_re_1_out   <= out_odd_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);                             
                        data_im_1_out   <= out_odd_0(C_SAMPLE_WDT-1 DOWNTO 0);    
                        out_even_re     <= (OTHERS => '0');
                        out_even_im     <= (OTHERS => '0');
                        out_odd_re      <= (OTHERS => '0');
                        out_odd_im      <= (OTHERS => '0');                                                      
                    END IF;                       
                ELSE
                    IF(tx_single_ndouble_mode = '1') THEN                              
                        data_re_0_out   <= out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);        
                        data_re_1_out   <= (OTHERS => '0');                            
                        data_im_1_out   <= (OTHERS => '0');                            
                        out_even_re     <= (OTHERS => '0');                            
                        out_even_im     <= (OTHERS => '0');                            
                        out_odd_re      <= (OTHERS => '0');                            
                        out_odd_im      <= (OTHERS => '0');                            
                    ELSE                                                               
                        data_re_0_out   <= out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);        
                        data_re_1_out   <= out_odd_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT); 
                        data_im_1_out   <= out_odd_1(C_SAMPLE_WDT-1 DOWNTO 0);         
                        out_even_re     <= (OTHERS => '0');                            
                        out_even_im     <= (OTHERS => '0');                            
                        out_odd_re      <= (OTHERS => '0');                            
                        out_odd_im      <= (OTHERS => '0');                            
                    END IF;                                                                                   
                END IF;
            WHEN TX_SLEEP                            =>
                IF ((C_FFT_SIZE_LOG2 mod 2) = 0) THEN
                    IF(tx_single_ndouble_mode = '1') THEN
                        data_re_0_out   <= out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);
                        data_re_1_out   <= (OTHERS => '0');
                        data_im_1_out   <= (OTHERS => '0');
                        out_even_re     <= (OTHERS => '0');
                        out_even_im     <= (OTHERS => '0');
                        out_odd_re      <= (OTHERS => '0');
                        out_odd_im      <= (OTHERS => '0'); 
                    ELSE
                        data_re_0_out   <= out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT); 
                        data_im_0_out   <= out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);         
                        data_re_1_out   <= out_odd_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);                             
                        data_im_1_out   <= out_odd_0(C_SAMPLE_WDT-1 DOWNTO 0);    
                        out_even_re     <= (OTHERS => '0');
                        out_even_im     <= (OTHERS => '0');
                        out_odd_re      <= (OTHERS => '0');
                        out_odd_im      <= (OTHERS => '0');                                                      
                    END IF;                       
                ELSE
                    IF(tx_single_ndouble_mode = '1') THEN                              
                        data_re_0_out   <= out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);        
                        data_re_1_out   <= (OTHERS => '0');                            
                        data_im_1_out   <= (OTHERS => '0');                            
                        out_even_re     <= (OTHERS => '0');                            
                        out_even_im     <= (OTHERS => '0');                            
                        out_odd_re      <= (OTHERS => '0');                            
                        out_odd_im      <= (OTHERS => '0');                            
                    ELSE                                                               
                        data_re_0_out   <= out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                        data_im_0_out   <= out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);        
                        data_re_1_out   <= out_odd_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT); 
                        data_im_1_out   <= out_odd_1(C_SAMPLE_WDT-1 DOWNTO 0);         
                        out_even_re     <= (OTHERS => '0');                            
                        out_even_im     <= (OTHERS => '0');                            
                        out_odd_re      <= (OTHERS => '0');                            
                        out_odd_im      <= (OTHERS => '0');                            
                    END IF;                                                                                   
                END IF;
            WHEN RD_0_WR_1                          =>
                data_re_0_out   <= (OTHERS => '0'); 
                data_im_0_out   <= (OTHERS => '0'); 
                data_re_1_out   <= (OTHERS => '0'); 
                data_im_1_out   <= (OTHERS => '0'); 
                out_even_re     <= out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                out_even_im     <= out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);
                out_odd_re      <= out_odd_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                out_odd_im      <= out_odd_0(C_SAMPLE_WDT-1 DOWNTO 0);
           WHEN RD_1_WR_0                           =>
                data_re_0_out   <= (OTHERS => '0');
                data_im_0_out   <= (OTHERS => '0');
                data_re_1_out   <= (OTHERS => '0');
                data_im_1_out   <= (OTHERS => '0');
                
                out_even_re   <= out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                out_even_im   <= out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);
                out_odd_re    <= out_odd_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
                out_odd_im    <= out_odd_1(C_SAMPLE_WDT-1 DOWNTO 0);
           WHEN OTHERS                              =>
                data_re_0_out   <= (OTHERS => '0');
                data_im_0_out   <= (OTHERS => '0');
                data_re_1_out   <= (OTHERS => '0');
                data_im_1_out   <= (OTHERS => '0');                 
                out_even_re  <= (OTHERS => '0');
                out_even_im  <= (OTHERS => '0'); 
                out_odd_re   <= (OTHERS => '0');
                out_odd_im   <= (OTHERS => '0');  
        END CASE;
    END PROCESS data_out_mux;
    
   
    --debug signals assignement
    re_in_even_0_d    <=       in_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_in_odd_0_d     <=       in_odd_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_out_even_0_d   <=       out_even_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_out_odd_0_d    <=       out_odd_0(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_in_even_1_d    <=       in_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_in_odd_1_d     <=       in_odd_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_out_even_1_d   <=       out_even_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    re_out_odd_1_d    <=       out_odd_1(C_DFT_WDT-1 DOWNTO C_SAMPLE_WDT);
    
    im_in_even_0_d    <=       in_even_0(C_SAMPLE_WDT-1 DOWNTO 0); 
    im_in_odd_0_d     <=       in_odd_0(C_SAMPLE_WDT-1 DOWNTO 0);
    im_out_even_0_d   <=       out_even_0(C_SAMPLE_WDT-1 DOWNTO 0);
    im_out_odd_0_d    <=       out_odd_0(C_SAMPLE_WDT-1 DOWNTO 0); 
    im_in_even_1_d    <=       in_even_1(C_SAMPLE_WDT-1 DOWNTO 0); 
    im_in_odd_1_d     <=       in_odd_1(C_SAMPLE_WDT-1 DOWNTO 0);  
    im_out_even_1_d   <=       out_even_1(C_SAMPLE_WDT-1 DOWNTO 0);
    im_out_odd_1_d    <=       out_odd_1(C_SAMPLE_WDT-1 DOWNTO 0); 

    --synthesis translate_off
    io_debug_proc : PROCESS(sys_clk_in) --generate logs when data is inputted or outputted from the FFT block
    BEGIN
        IF(rising_edge(sys_clk_in) AND rx_single_ndouble_mode = '1' AND 
        (C_VERB = VERB_MED OR C_VERB = VERB_HIGH)) THEN --only single transfers
            IF(alg_ctrl = RX) THEN
              REPORT "Real: " & integer'image(to_integer(signed(data_re_0_in))) & 
              " Imag: " & integer'image(to_integer(signed(data_im_0_in))) & 
              "@ addr: [" & integer'image(to_integer(unsigned(addr_0_in))) & 
              "] written to the FFT memory";
            ELSIF(alg_ctrl = TX) THEN
              REPORT "Real: " & integer'image(to_integer(signed(data_re_0_out))) & 
              " Imag: " & integer'image(to_integer(signed(data_im_0_out))) & 
              "@ addr: [" & integer'image(to_integer(unsigned(addr_0_in))) & 
              "] read from the FFT memory";
            END IF;
        END IF;
    END PROCESS io_debug_proc;
    --synthesis translate_on
    

END structural;
