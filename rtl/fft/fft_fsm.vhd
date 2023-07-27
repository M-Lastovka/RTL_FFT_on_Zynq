----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/17/2021 05:27:38 PM
-- Design Name: 
-- Module Name: fft_fsm - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: moore type fsm, outputs are cached, contains tree depth and breadth counters
-- 
-- Dependencies: dig_top_pckg
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
--


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.MATH_REAL.ALL;
USE IEEE.NUMERIC_STD.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY fft_fsm IS
    PORT ( 
           -------------------clocks and reset--------------------------------
    
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic; 
           
           -------------------algorithm control-----------------------------------------
           
           dpth_cnt          : OUT std_logic_vector(natural(ceil(log2(real(C_FFT_SIZE_LOG2))))-1 DOWNTO 0);  --tree depth, counter output
           brdth_cnt         : OUT std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                             --tree breadth, counter output
           alg_ctrl          : OUT alg_command;                                                              --controls ROM MUXes and ROM wr_en and en signals, also shifts twiddle address masking register
           burst_mode_en     : IN  std_logic;
           
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
END fft_fsm;

ARCHITECTURE rtl OF fft_fsm IS

    TYPE fsm_state IS (
      IDLE,                 --default state
      START_UP,             --inicialization
      RX_BURST,             --burst mode transfer
      RX_WAIT,              --wait for sample 
      PUSH_INCR,            --push sample into memory
      RX_VALID,               --sample has been pushed
      MEM_FULL,             --all samples are loaded
      COMP_0,               --sweep the whole breadth of the tree, ram_0 is read, ram_1 is written to
      COMP_1,               --sweep the whole breadth of the tree, ram_0 is read, ram_1 is written to
      SWEEP_DONE_0,         --one whole sweep is done
      SWEEP_DONE_1,         --one whole sweep is done
      BUFFER_WAIT_0,        --wait for last few writes
      BUFFER_WAIT_1,        --wait for last few writes
      TREE_DONE,            --whole computation is done
      TX_BURST,             --burst mode transfer
      TX_WAIT,              --wait for pop
      TX_VALID,             --sample has been read
      POP_INCR,             --read sample from memory
      MEM_SENT,             --all outputs have been transmited
      DONE                  --everything done, wait for request deassert and go to sleep
    );
    
    SIGNAL curr_state   :   fsm_state;
    SIGNAL next_state   :   fsm_state;
    
    --there is an offset between write and read because of pipeline, we need to wait
    SIGNAL  buffer_overflow    :   std_logic;      --counter overflow
    SUBTYPE buffer_int IS natural RANGE 0 TO 2**natural(ceil(log2(real(C_BUFFER_DELAY))))-1; 
    SIGNAL  buffer_cnt        :   buffer_int;
    
    SIGNAL  dpth_overflow    :   std_logic;      --counter overflow
    SUBTYPE dpth_int IS natural RANGE 0 TO 2**natural(ceil(log2(real(C_FFT_SIZE_LOG2))))-1; 
    SIGNAL  dpth_cnt_i   :   dpth_int;
    
    SIGNAL  brdth_overflow   :   std_logic;      --counter overflow
    SUBTYPE brdth_int IS natural RANGE 0 TO 2**(C_FFT_SIZE_LOG2-1)-1; 
    SIGNAL  brdth_cnt_i   :   brdth_int;
    
    --all outputs are cached
    SIGNAL alg_ctrl_c          : alg_command;
    SIGNAL busy_c              : std_logic;   --fft processor is doing something
    SIGNAL rx_ready_c          : std_logic;   --a sample is ready to be pushed into memory
    SIGNAL comp_done_c         : std_logic;   --algorithm has finished
    SIGNAL tx_ready_c          : std_logic;   --ready to transmit dft sample
    SIGNAL all_done_c          : std_logic;   --everything is done
    SIGNAL rx_val_c            : std_logic;   --a sample has been pushed into memory
    SIGNAL tx_val_c            : std_logic;   --the sample at the output is valid
    
BEGIN

    state_reg : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
    
        IF(rst_n_in = '0') THEN
            curr_state <= IDLE;
        ELSIF(rising_edge(sys_clk_in)) THEN
            curr_state <= next_state;
        END IF;
        
    END PROCESS state_reg;
    
    next_state_proc : PROCESS(curr_state, request, push, pop, dpth_overflow, brdth_overflow, buffer_overflow, rx_done, 
        tx_done, rx_ack, tx_ack, burst_mode_en)
    BEGIN
    
        next_state <= curr_state;
        
        CASE curr_state IS
            WHEN IDLE                           =>
                IF request = '1' THEN
                    next_state <= START_UP;               --wake up, assert busy
                ELSE
                    next_state <= IDLE;          
                END IF;     
            WHEN START_UP                       =>
                IF burst_mode_en = '1' THEN
                    next_state <= RX_BURST;
                ELSE
                    next_state <= RX_WAIT;
                END IF;
            WHEN RX_WAIT                        =>
                IF push = '1' THEN
                    next_state <= PUSH_INCR;              --push data into memory
                ELSIF rx_done = '1' THEN
                    next_state <= MEM_FULL;
                ELSE
                    next_state <= RX_WAIT;          
                END IF;        
            WHEN PUSH_INCR                      =>
                next_state <= RX_VALID;
            WHEN RX_VALID                       =>
                IF rx_ack = '1' THEN
                    next_state <= RX_WAIT;
                ELSE
                    next_state <= RX_VALID;
                END IF;     
            WHEN RX_BURST                        =>
                IF rx_done = '1' THEN
                    next_state <= MEM_FULL;              --transfer has ended
                ELSE
                    next_state <= RX_BURST;              
                END IF;          
            WHEN MEM_FULL                       =>
                next_state <= COMP_0;                    --start computing           
            WHEN COMP_0                         =>
                IF brdth_overflow = '1' THEN   
                    next_state <= BUFFER_WAIT_0;         --whole sweep is done, wait for last few operations  
                ELSE
                    next_state <= COMP_0;        
                END IF;
            WHEN BUFFER_WAIT_0                  =>
                IF buffer_overflow = '1' THEN
                    next_state <= SWEEP_DONE_0;          --change read/write MUXes
                ELSE
                    next_state <= BUFFER_WAIT_0;         --wait for the last few write operations
                END IF;
            WHEN SWEEP_DONE_0                   =>
                IF dpth_overflow = '1' THEN
                    next_state <= TREE_DONE;             --all done, ready to transmit
                ELSE
                    next_state <= COMP_1;     
                END IF;
            WHEN COMP_1                         =>
                IF brdth_overflow = '1' THEN   
                    next_state <= BUFFER_WAIT_1;         --whole sweep is done, wait for last few operations  
                ELSE
                    next_state <= COMP_1;        
                END IF;
            WHEN BUFFER_WAIT_1                  =>
                IF buffer_overflow = '1' THEN
                    next_state <= SWEEP_DONE_1;          --change read/write MUXes
                ELSE
                    next_state <= BUFFER_WAIT_1;         --wait for the last few write operations
                END IF;
            WHEN SWEEP_DONE_1                   =>
                IF dpth_overflow = '1' THEN
                    next_state <= TREE_DONE;             --all done, ready to transmit
                ELSE
                    next_state <= COMP_0;     
                END IF;
            WHEN TREE_DONE                      =>
                IF request = '1' THEN
                    IF burst_mode_en = '1' THEN
                        next_state <= TX_BURST;
                    ELSE
                        next_state <= TX_WAIT;
                    END IF;
                ELSE
                    next_state <= TREE_DONE;    
                END IF;
            WHEN TX_WAIT                        =>
                IF pop = '1' THEN
                    next_state <= POP_INCR;              --allow reading of output
                ELSIF tx_done = '1' THEN
                    next_state <= MEM_SENT;
                ELSE
                    next_state <= TX_WAIT;          
                END IF;
            WHEN POP_INCR                       =>
                next_state <= TX_VALID;                  --wait for another pop signal
            WHEN TX_VALID                       =>
                IF tx_ack = '1' THEN
                    next_state <= TX_WAIT;                  
                ELSE 
                    next_state <= TX_VALID;                  
                END IF;
            WHEN TX_BURST                        =>
                IF tx_done = '1' THEN
                    next_state <= MEM_SENT;              --transfer has ended
                ELSE
                    next_state <= TX_BURST;              
                END IF;
            WHEN MEM_SENT                       =>
                next_state <= DONE;
            WHEN DONE                           =>  
                IF request = '0' THEN
                    next_state <= IDLE;          
                ELSE
                    next_state <= DONE;
                END IF;
        END CASE;
    
    
    END PROCESS next_state_proc;
    
    output_proc : PROCESS(curr_state)
    BEGIN
    
        CASE curr_state IS
            WHEN IDLE                               =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '0';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN START_UP                           =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN RX_WAIT                            =>
                alg_ctrl_c  <= RX_SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '1';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN PUSH_INCR                          =>
                alg_ctrl_c  <= RX;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN RX_VALID                           =>
                alg_ctrl_c  <= RX_SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '1';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN RX_BURST                           =>
                alg_ctrl_c  <= RX;
                busy_c      <= '1';
                rx_ready_c  <= '1';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN MEM_FULL                           =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN COMP_0                             =>
                alg_ctrl_c  <= RD_0_WR_1;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN BUFFER_WAIT_0                      =>
                alg_ctrl_c  <= RD_0_WR_1;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN SWEEP_DONE_0                       =>
                alg_ctrl_c  <= SWEEP_FINISH;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN COMP_1                             =>
                alg_ctrl_c  <= RD_1_WR_0;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN BUFFER_WAIT_1                      =>
                alg_ctrl_c  <= RD_1_WR_0;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN SWEEP_DONE_1                       =>
                alg_ctrl_c  <= SWEEP_FINISH;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN TREE_DONE                          =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '1';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN TX_WAIT                            =>
                alg_ctrl_c  <= TX_SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '1';
                all_done_c  <= '0';
            WHEN POP_INCR                           =>
                alg_ctrl_c  <= TX;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN TX_VALID                           =>
                alg_ctrl_c  <= TX_SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '1';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN TX_BURST                           =>
                alg_ctrl_c  <= TX;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '1';
                all_done_c  <= '0';          
            WHEN MEM_SENT                           =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '0';
            WHEN DONE                               =>
                alg_ctrl_c  <= SLEEP;
                busy_c      <= '1';
                rx_ready_c  <= '0';
                rx_val_c    <= '0';
                tx_val_c    <= '0';
                comp_done_c <= '0';
                tx_ready_c  <= '0';
                all_done_c  <= '1';                             
       END CASE;
    END PROCESS output_proc;
    
    output_cache : PROCESS(sys_clk_in, rst_n_in)      
    BEGIN
        IF(rst_n_in = '0') THEN
            alg_ctrl  <= SLEEP;
            busy      <= '0';
            rx_ready  <= '0';
            rx_val    <= '0';
            comp_done <= '0';
            tx_ready  <= '0';
            tx_val    <= '0';
            all_done  <= '0';
            dpth_cnt  <= (OTHERS => '0');
            brdth_cnt <= (OTHERS => '0');
        ELSIF(rising_edge(sys_clk_in)) THEN
            alg_ctrl  <= alg_ctrl_c;
            busy      <= busy_c;
            rx_ready  <= rx_ready_c;
            rx_val    <= rx_val_c;
            comp_done <= comp_done_c;
            tx_ready  <= tx_ready_c;
            tx_val    <= tx_val_c;
            all_done  <= all_done_c;
            dpth_cnt  <= std_logic_vector(to_unsigned(dpth_cnt_i,natural(ceil(log2(real(C_FFT_SIZE_LOG2))))));
            brdth_cnt <= std_logic_vector(to_unsigned(brdth_cnt_i,C_FFT_SIZE_LOG2));
        END IF;    
    END PROCESS output_cache;
    
    depth_timer : PROCESS(sys_clk_in, rst_n_in)        
    BEGIN
        IF(rst_n_in = '0') THEN
            dpth_cnt_i    <= 0;
        ELSIF(rising_edge(sys_clk_in)) THEN
            IF curr_state = SWEEP_DONE_0 OR curr_state = SWEEP_DONE_1 THEN
                IF dpth_cnt_i > C_FFT_SIZE_LOG2-2 THEN                        --TODO: probably off by 1, check in simulation
                    dpth_cnt_i      <= dpth_cnt_i;
                ELSE
                    dpth_cnt_i  <= dpth_cnt_i + 1;
                END IF;
            ELSIF curr_state = IDLE THEN
                dpth_cnt_i     <= 0;
            END IF;       
        END IF;
    END PROCESS depth_timer;
    
    dpth_overflow_compar : PROCESS(dpth_cnt_i)
    BEGIN
        IF dpth_cnt_i > C_FFT_SIZE_LOG2-2 THEN
            dpth_overflow <= '1';
        ELSE
            dpth_overflow <= '0';
        END IF;
    END PROCESS dpth_overflow_compar;
    
    breadth_timer : PROCESS(sys_clk_in, rst_n_in)        
    BEGIN
        IF(rst_n_in = '0') THEN
            brdth_cnt_i    <= 0;
            brdth_overflow <= '0';
        ELSIF(rising_edge(sys_clk_in)) THEN
            IF curr_state = COMP_0 OR curr_state = COMP_1 THEN
                IF brdth_cnt_i = 2**(C_FFT_SIZE_LOG2-1)-1 THEN                        --TODO: probably off by 1, check in simulation
                    brdth_cnt_i      <= brdth_cnt_i;
                    brdth_overflow   <= '1';
                ELSE
                    brdth_cnt_i      <= brdth_cnt_i + 1;
                    brdth_overflow   <= '0';
                END IF;
            ELSIF curr_state = IDLE OR curr_state = MEM_FULL OR curr_state = MEM_SENT OR curr_state = SWEEP_DONE_0 OR curr_state = SWEEP_DONE_1 THEN
                brdth_cnt_i     <= 0;
                brdth_overflow  <= '0';
            END IF;       
        END IF;    
    END PROCESS breadth_timer;
    
    buffer_timer : PROCESS(sys_clk_in, rst_n_in)        
    BEGIN
        IF(rst_n_in = '0') THEN
            buffer_cnt      <= 0;
            buffer_overflow <= '0';
        ELSIF(rising_edge(sys_clk_in)) THEN
            IF curr_state = BUFFER_WAIT_0 OR curr_state = BUFFER_WAIT_1 THEN
                IF buffer_cnt >= C_BUFFER_DELAY-1 THEN                        --TODO: probably off by 1, check in simulation
                    buffer_cnt        <= buffer_cnt;
                    buffer_overflow   <= '1';
                ELSE
                    buffer_cnt        <= buffer_cnt + 1;
                    buffer_overflow   <= '0';
                END IF;
            ELSIF curr_state = IDLE OR curr_state = SWEEP_DONE_0 OR curr_state = SWEEP_DONE_1 THEN
                buffer_cnt       <= 0;
                buffer_overflow  <= '0';
            END IF;       
        END IF;    
    END PROCESS buffer_timer;
    
    ASSERT dpth_cnt_i <= C_FFT_SIZE_LOG2-1 REPORT "Faulty fft_fsm depth timer value!" SEVERITY error;
    


END rtl;
