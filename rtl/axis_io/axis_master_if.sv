`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/19/2023 10:28:00 PM
// Design Name: 
// Module Name: axis_master_if
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI master interface, implementing a FIFO and a buffer to convert 
//              the internal memory representation of width VLW_WDT to
//              AXI data stream of width S_TDATA_WDT, where S_TDATA_WDT <= VLW_WDT 
//              biases then have to be zero padded
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_stream_pckg::*;

module axis_master_if(

    //clocks and resets
    input  clk,
    input  rst_n,

    //AXI stream master interface
    output  logic [M_TDATA_WDT-1:0] M_AXIS_TDATA,
    output  logic M_AXIS_TLAST,
    output  logic M_AXIS_TVALID,	
    input   logic M_AXIS_TREADY,
    
    //outputs memory interface
    output  logic [C_FFT_SIZE_LOG2-1:0]  m_axis_if_addr,
    input   logic [C_SAMPLE_WDT-1:0]     data_re_0_out,
    input   logic [C_SAMPLE_WDT-1:0]     data_im_0_out,

    //control
    output  logic pop,
    input   logic tx_ready,
    output  logic tx_done,
    output  logic m_axis_if_busy

    );

    logic [VLW_WDT-1:0] outputs_ext_mem_data;

    //write side
    logic fifo_full;
    logic fifo_wr_en;
    logic [M_FIFO_ADDR_WDT-1:0] fifo_wr_ptr;
    logic m_if_buffer_wr_done;
    logic m_if_buffer_done;
    logic m_if_buffer_done_c;
    logic m_if_buffer_done_i;
    logic m_fifo_wr_done;

    //read side
    logic fifo_empty;
    logic fifo_rd_en;
    logic [M_FIFO_ADDR_WDT-1:0] fifo_rd_ptr;

    logic [M_TDATA_WDT-1:0] fifo_mem[M_FIFO_SIZE];
    logic [M_TDATA_WDT-1:0] fifo_out;
    logic [M_TDATA_WDT-1:0] fifo_in;

    logic m_rd_done;

    logic [$clog2(M_IF_BUFFER_SIZE):0] m_if_buffer_cnt;
    logic [$clog2(FFT_MEM_SIZE):0]  m_if_buffer_wr_cnt;
    logic m_if_buffer_wr;
    logic m_if_buffer_shift;
    logic m_if_buffer_valid;
    logic pop_i;
    logic [M_TDATA_WDT-1:0] m_if_buffer_unpack[M_IF_BUFFER_SIZE-1:0];
    logic m_axis_tvalid_i;
    logic m_axis_tlast_i;

    typedef enum {
        M_WR_IDLE,
        M_WR_INIT,
        M_WR_FIFO,
        M_WR_WAIT
    } m_wr_state; //write side FSM

    typedef enum {
        M_RD_IDLE,
        M_RD_INIT,
        M_RD_FIFO,
        M_RD_DONE
    } m_rd_state; //read side FSM

    m_wr_state m_wr_curr_state;
    m_wr_state m_wr_curr_state_i;
    m_wr_state m_wr_next_state;
    m_rd_state m_rd_curr_state;
    m_rd_state m_rd_next_state;

    //-------------------------------------------------------------
    //BUFFER FOR WRITING TO MEMORY---------------------------------
    //-------------------------------------------------------------

    //pop reads from the activations memory and increments the address
    assign pop = m_wr_curr_state == M_WR_INIT | (m_if_buffer_cnt == 1 & !m_if_buffer_wr_done & !fifo_full); 
    //we write to buffer at counter == max and fifo is being written or at init
    assign m_if_buffer_wr    =  fifo_wr_en & m_if_buffer_cnt == M_IF_BUFFER_SIZE | m_wr_curr_state_i == M_WR_INIT; 
    //we shift the buffer on fifo_wr_en
    assign m_if_buffer_shift =  fifo_wr_en & !m_if_buffer_wr;
    assign m_if_buffer_done_c = m_if_buffer_cnt == M_IF_BUFFER_SIZE & m_if_buffer_wr_done & m_if_buffer_wr; //no more writes and reads to and from the IF buffer needed
    assign m_if_buffer_done = m_if_buffer_done_c | m_if_buffer_done_i; //final flag is OR result of latched flip flop value and combinational value => needed if there is fifo stall on last write

    always_ff @(posedge clk) begin : m_if_buffer_ctrl
        if(!rst_n) begin
            m_if_buffer_cnt         <= '0;
            m_if_buffer_valid       <= 1'b0;
            m_if_buffer_wr_cnt      <= '0;
            m_if_buffer_wr_done     <= 1'b0;
            m_if_buffer_done_i      <= 1'b0;
        end else begin
            if(m_wr_curr_state == M_WR_FIFO | m_wr_curr_state == M_WR_INIT) begin

                if(m_if_buffer_wr) begin
                    m_if_buffer_valid  <= 1'b1; //wait with valid until first write to buffer
                    m_if_buffer_wr_cnt <= m_if_buffer_wr_cnt + 1;
                    if(m_if_buffer_wr_cnt == FFT_MEM_SIZE-1)
                        m_if_buffer_wr_done <= 1'b1; //no more writes to the IF buffer needed
                end

                if(m_if_buffer_shift | m_if_buffer_wr) begin //increment counter
                    m_if_buffer_cnt <= m_if_buffer_cnt + 1;
                    if(m_if_buffer_cnt == M_IF_BUFFER_SIZE) //reset counter on max value
                        m_if_buffer_cnt <= 1;
                end

                if(m_if_buffer_done_c) 
                    m_if_buffer_done_i <= 1'b1; //latch onto combinatorial value (which is just a cycle count)
            end else begin
                m_if_buffer_cnt         <= '0;
                m_if_buffer_valid       <= 1'b0;
                m_if_buffer_wr_cnt      <= '0;
                m_if_buffer_wr_done     <= 1'b0;
                m_if_buffer_done_i      <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin : addr_gen //generate addresses for the activations memory and memory read done signal
        if(!rst_n) begin
            m_axis_if_addr <= OUTPUT_MEM_OFFSET;
            
        end else begin
            if(pop & m_wr_curr_state == M_WR_FIFO | m_wr_curr_state == M_WR_INIT) begin
                m_axis_if_addr <= m_axis_if_addr + 1;
            end else if(m_wr_curr_state == M_WR_IDLE) begin
                m_axis_if_addr <= OUTPUT_MEM_OFFSET;
            end
        end
    end

    //left half is real part, right half is imag. part, sign extend to M_TDATA_WDT
    assign outputs_ext_mem_data = {{{(M_TDATA_WDT-C_SAMPLE_WDT){data_re_0_out[C_SAMPLE_WDT-1]}}, data_re_0_out},
                                   {{(M_TDATA_WDT-C_SAMPLE_WDT){data_im_0_out[C_SAMPLE_WDT-1]}}, data_im_0_out} }; 

    always_ff @(posedge clk) begin : m_if_buffer
        if(!rst_n) begin
            for(int i = 0; i < M_IF_BUFFER_SIZE; i++)
                m_if_buffer_unpack[i] <= '0;
        end else begin
            if(m_if_buffer_wr) begin
                for(int i = 0; i < M_IF_BUFFER_SIZE; i++)
                    m_if_buffer_unpack[M_IF_BUFFER_SIZE-1-i] <= outputs_ext_mem_data[VLW_WDT-1 - i*M_TDATA_WDT -: M_TDATA_WDT];
            end else if(m_if_buffer_shift) begin
                for(int i = 0; i < M_IF_BUFFER_SIZE; i++)
                    if(i == 0)
                        m_if_buffer_unpack[i] <= '0;
                    else
                        m_if_buffer_unpack[i] <= m_if_buffer_unpack[i-1];
            end
        end
    end

    assign fifo_in = m_if_buffer_unpack[M_IF_BUFFER_SIZE-1];

    //-------------------------------------------------------------
    //FIFO Write side----------------------------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk) begin : m_wr_fsm_next_state
        if(!rst_n) begin
            m_wr_curr_state   <= M_WR_IDLE;
            m_wr_curr_state_i <= M_WR_IDLE;
        end else begin
            m_wr_next_state = M_WR_IDLE;

            casez(m_wr_curr_state)
                M_WR_IDLE : m_wr_next_state = tx_ready ? M_WR_INIT : M_WR_IDLE; 
                M_WR_INIT : m_wr_next_state = M_WR_FIFO; 
                M_WR_FIFO : m_wr_next_state = m_fifo_wr_done ? M_WR_WAIT : M_WR_FIFO; //everything has been read from memory and buffer is empty
                M_WR_WAIT : m_wr_next_state = m_rd_done ? M_WR_IDLE : M_WR_WAIT; //wait for read fsm to finish
                default : m_wr_next_state = M_WR_IDLE;
            endcase

            m_wr_curr_state   <= m_wr_next_state;
            m_wr_curr_state_i <= m_wr_curr_state;
        end
    end

    assign fifo_full      = fifo_rd_ptr + '1 == fifo_wr_ptr;
    assign fifo_wr_en     = m_if_buffer_valid & !fifo_full & m_wr_curr_state == M_WR_FIFO; 
    assign m_fifo_wr_done = m_if_buffer_done & fifo_wr_ptr == M_FIFO_WR_FINAL & fifo_wr_en;

    always_ff @(posedge clk) begin : m_wr_fifo_ctrl
        if(!rst_n) begin
            fifo_wr_ptr <= '0;
        end else begin
            if(m_wr_curr_state == M_WR_IDLE)
                fifo_wr_ptr <= '0;
            else
                if(fifo_wr_en)
                    fifo_wr_ptr <= fifo_wr_ptr + 1;
                
        end
    end   

    //-------------------------------------------------------------
    //FIFO Read side-----------------------------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk) begin : m_rd_fsm_next_state
        if(!rst_n) begin
            m_rd_curr_state <= M_RD_IDLE;
        end else begin
            m_rd_next_state = M_RD_IDLE;

            casez(m_rd_curr_state)
                M_RD_IDLE       : m_rd_next_state = m_wr_curr_state == M_WR_FIFO ? M_RD_INIT : M_RD_IDLE; //start reading
                M_RD_INIT       : m_rd_next_state = fifo_rd_en ? M_RD_FIFO : M_RD_INIT; //stay in the init state until first read is finished
                M_RD_FIFO       : m_rd_next_state = m_rd_done ? M_RD_DONE : M_RD_FIFO; 
                M_RD_DONE       : m_rd_next_state = M_AXIS_TLAST & M_AXIS_TREADY & M_AXIS_TVALID ? M_RD_IDLE : M_RD_DONE;
                default : m_rd_next_state = M_RD_IDLE;
            endcase

            m_rd_curr_state <= m_rd_next_state;
        end
    end

    assign fifo_empty  = (fifo_wr_ptr + '1  == fifo_rd_ptr | (fifo_wr_ptr == fifo_rd_ptr & fifo_wr_ptr == '0)) & m_wr_curr_state != M_WR_WAIT;
    assign fifo_rd_en  = (m_rd_curr_state == M_RD_INIT & !fifo_empty) | (m_rd_curr_state == M_RD_FIFO & !fifo_empty & M_AXIS_TREADY); //read from the fifo when slave is ready and fifo not empty or when at init state 
    assign m_rd_done   = fifo_rd_ptr == fifo_wr_ptr + '1 & m_wr_curr_state == M_WR_WAIT & fifo_rd_en;

    always_ff @(posedge clk) begin : m_rd_fifo_ctrl
        if(!rst_n) begin
            fifo_rd_ptr <= '0;
        end else begin    

            if(m_rd_curr_state == M_RD_IDLE)
                fifo_rd_ptr <= '0;
            else
                if(fifo_rd_en)
                    fifo_rd_ptr <= fifo_rd_ptr + 1;
        end
    end

    always_ff @(posedge clk) begin : fifo_mem_proc
        if(fifo_rd_en)
            fifo_out <= fifo_mem[fifo_rd_ptr];
        if(fifo_wr_en)
            fifo_mem[fifo_wr_ptr] <= fifo_in;
    end

    //generate tlast & tvalid
    assign m_axis_tlast_i  = m_rd_done;
    assign m_axis_tvalid_i = fifo_rd_en;
    assign M_AXIS_TDATA = fifo_out;

    always_ff @(posedge clk) begin : axis_ctrl_reg //reg tvalid and tlast signals, gate them if they need to be stalled
        if(!rst_n) begin
            M_AXIS_TVALID <= 1'b0;
            M_AXIS_TLAST  <= 1'b0;
        end else begin
            if(!M_AXIS_TVALID | M_AXIS_TREADY) begin
                M_AXIS_TVALID <= m_axis_tvalid_i;
                M_AXIS_TLAST  <= m_axis_tlast_i;
            end
        end
    end

    //-------------------------------------------------------------
    //Status bits--------------------------------------------------
    //-------------------------------------------------------------

    always_comb begin : status_flags
        m_axis_if_busy = m_wr_curr_state != M_WR_IDLE | m_rd_curr_state != M_RD_IDLE;
        tx_done = M_AXIS_TLAST;
    end

    // synthesis translate_off
    //simple immediate assertions
    always @(posedge clk) assert (!(fifo_wr_ptr === fifo_rd_ptr & m_wr_curr_state === M_WR_FIFO & m_rd_curr_state === M_RD_FIFO) | !rst_n) else $error("Write pointer cannot be equal to read pointer (master if)");

    always @(posedge clk) assert (fifo_wr_en === 1'b0 | fifo_full === 1'b0 | !rst_n) else $error("Cannot write to a full fifo (master if)!");

    always @(posedge clk) assert (fifo_rd_en === 1'b0 | fifo_empty === 1'b0 | !rst_n) else $error("Cannot read from an empty fifo (master if)!");

    always @(posedge clk) assert (!(fifo_wr_en === 1'b1 & fifo_rd_en === 1'b1 & fifo_rd_ptr == fifo_wr_ptr) | !rst_n) else $error("Cannot read and write to the same position in fifo!");

    assert property (@(posedge clk) disable iff (!rst_n) (m_rd_curr_state == M_RD_DONE |-> m_wr_curr_state == M_WR_IDLE));

    assert property (@(posedge clk) disable iff (!rst_n) (m_wr_curr_state == M_WR_WAIT |-> m_rd_curr_state == M_RD_FIFO));

    assert property (@(posedge clk) disable iff (!rst_n) (!M_AXIS_TREADY & M_AXIS_TVALID |-> !fifo_rd_en));

    assert property (@(posedge clk) disable iff (!rst_n) (M_AXIS_TREADY & !M_AXIS_TVALID & m_rd_curr_state != M_RD_INIT |-> !fifo_rd_en));

    assert property (@(posedge clk) disable iff (!rst_n) (m_wr_curr_state == M_WR_WAIT |-> m_axis_if_addr == FFT_MEM_SIZE | M_IF_BUFFER_SIZE == 1));

    assert property (@(posedge clk) disable iff (!rst_n) (pop |=> !pop | M_IF_BUFFER_SIZE == 1));

    assert property (@(posedge clk) disable iff (!rst_n) (m_if_buffer_wr |=> !m_if_buffer_wr | M_IF_BUFFER_SIZE == 1));

    // synthesis translate_on



endmodule