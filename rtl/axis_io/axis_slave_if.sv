`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/19/2023 10:28:00 PM
// Design Name: 
// Module Name: axis_slave_if
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI slave interface, implementing a FIFO and a buffer to convert 
//              the AXI data stream of width S_TDATA_WDT to internal memory representation
//              of width VLW_WDT, where S_TDATA_WDT <= VLW_WDT 
//              biases then have to be zero padded
//              
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_stream_pckg::*;

module axis_slave_if(

    //clocks and resets
    input  clk,
    input  rst_n,

    //AXI stream slave interface
    input  logic [S_TDATA_WDT-1:0] S_AXIS_TDATA,
    input  logic S_AXIS_TLAST,
    input  logic S_AXIS_TVALID,	
    output logic S_AXIS_TREADY,
    
    //activations memory interface
    output  logic [C_FFT_SIZE_LOG2-1:0]  s_axis_if_addr,
    output  logic [C_SAMPLE_WDT-1:0]     data_re_0_in,
    output  logic [C_SAMPLE_WDT-1:0]     data_im_0_in,

    //control
    output  logic push,
    input   logic comp_busy,
    input   logic m_axis_if_busy,
    output  logic rx_done,
    output  logic s_axis_if_busy

    );

    logic s_axis_tready_i;

    //write side
    logic fifo_full;
    logic fifo_wr_en;
    logic [S_FIFO_ADDR_WDT-1:0] fifo_wr_ptr;

    //read side
    logic fifo_empty;
    logic fifo_rd_en;
    logic [S_FIFO_ADDR_WDT-1:0] fifo_rd_ptr;

    logic [S_TDATA_WDT-1:0] fifo_mem[S_FIFO_SIZE];
    logic [S_TDATA_WDT-1:0] fifo_out;
    logic [S_TDATA_WDT-1:0] fifo_in;

    logic s_fifo_rd_done;
    logic fifo_rd_en_i;
    logic fifo_rd_en_ii;
    logic skid_buffer_en;

    logic [$clog2(S_IF_BUFFER_SIZE):0] s_if_buffer_cnt;
    logic [S_TDATA_WDT-1:0] s_if_buffer_unpack[S_IF_BUFFER_SIZE-1:0];
    logic s_axis_tvalid_i;
    logic s_axis_tlast_i;
    logic s_buff_tlast;
    logic s_buff_tvalid;

    logic [S_IF_ADDR_WDT-1:0] addr_mem;

    logic [S_TDATA_WDT-1:0] s_buff_tdata;

    typedef enum {
        S_WR_IDLE,
        S_WR_FIFO,
        S_WR_WAIT
    } s_wr_state; //write side FSM

    typedef enum {
        S_RD_IDLE,
        S_RD_FIFO,
        S_RD_DONE
    } s_rd_state; //read side FSM

    s_wr_state s_wr_curr_state;
    s_wr_state s_wr_next_state;
    s_rd_state s_rd_curr_state;
    s_rd_state s_rd_curr_state_i;
    s_rd_state s_rd_next_state;

    //-------------------------------------------------------------
    //FIFO Write side----------------------------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk) begin : s_wr_fsm_next_state
        if(!rst_n) begin
            s_wr_curr_state <= S_WR_IDLE;
        end else begin
            s_wr_next_state = S_WR_IDLE;

            casez(s_wr_curr_state)
                S_WR_IDLE : s_wr_next_state = s_axis_tvalid_i & !comp_busy & !m_axis_if_busy ? S_WR_FIFO : S_WR_IDLE; 
                S_WR_FIFO : s_wr_next_state = s_axis_tlast_i & s_axis_tvalid_i ? S_WR_WAIT : S_WR_FIFO; //start writing
                S_WR_WAIT : s_wr_next_state = s_fifo_rd_done ? S_WR_IDLE : S_WR_WAIT; //wait for read fsm to finish
                default : s_wr_next_state = S_WR_IDLE;
            endcase

            s_wr_curr_state <= s_wr_next_state;
        end
    end

    assign s_axis_tready_i = s_wr_curr_state == S_WR_FIFO & !fifo_full;
    assign skid_buffer_en  = !s_axis_tready_i & S_AXIS_TREADY;

    always_ff @(posedge clk) begin : skid_buffer
        if(!rst_n) begin
            S_AXIS_TREADY  <= 1'b0;
            s_buff_tdata   <= '0;
            s_buff_tvalid  <= 1'b0;
            s_buff_tlast   <= 1'b0;
        end else begin
            S_AXIS_TREADY <= s_axis_tready_i;
            //on a stall, save data to buffer
            if(skid_buffer_en) begin
                s_buff_tdata  <= S_AXIS_TDATA;
                s_buff_tvalid <= S_AXIS_TVALID;
                s_buff_tlast  <= S_AXIS_TLAST;
            end
        end
    end

    always_comb begin : skid_mux
        //read the skid buffer if we're recovering from a stall, else read interface signal
        fifo_in         = (s_axis_tready_i & !S_AXIS_TREADY) ? s_buff_tdata : S_AXIS_TDATA;
        s_axis_tvalid_i = (s_axis_tready_i & !S_AXIS_TREADY) ? s_buff_tvalid : S_AXIS_TVALID;
        s_axis_tlast_i  = (s_axis_tready_i & !S_AXIS_TREADY) ? s_buff_tlast  : S_AXIS_TLAST; 
    end

    assign fifo_wr_en = s_axis_tready_i & s_axis_tvalid_i;
    assign fifo_full  = fifo_rd_ptr + '1 == fifo_wr_ptr;

    always_ff @(posedge clk) begin : s_wr_fifo_ctrl
        if(!rst_n) begin
            fifo_wr_ptr <= '0;
        end else begin
            if(s_wr_curr_state == S_WR_IDLE)
                fifo_wr_ptr <= '0;
            else
                if(fifo_wr_en)
                    fifo_wr_ptr <= fifo_wr_ptr + 1;
        end
    end

    //-------------------------------------------------------------
    //FIFO Read side-----------------------------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk) begin : s_rd_fsm_next_state
        if(!rst_n) begin
            s_rd_curr_state   <= S_RD_IDLE;
            s_rd_curr_state_i <= S_RD_IDLE;
        end else begin
            s_rd_next_state = S_RD_IDLE;

            casez(s_rd_curr_state)
                S_RD_IDLE : s_rd_next_state = s_wr_curr_state != S_WR_IDLE ? S_RD_FIFO : S_RD_IDLE; //start reading
                S_RD_FIFO : s_rd_next_state = s_fifo_rd_done ? S_RD_DONE : S_RD_FIFO; 
                S_RD_DONE : s_rd_next_state = push & !fifo_rd_en_i ? S_RD_IDLE : S_RD_DONE; //wait till the if buffer fills out
                default : s_rd_next_state = S_RD_IDLE;
            endcase

            s_rd_curr_state   <= s_rd_next_state;
            s_rd_curr_state_i <= s_rd_curr_state;
        end
    end

    assign fifo_empty  = ( fifo_wr_ptr + '1  == fifo_rd_ptr | (fifo_wr_ptr == fifo_rd_ptr & fifo_wr_ptr == '0)) & s_wr_curr_state != S_WR_WAIT;
    assign fifo_rd_en  = s_rd_curr_state == S_RD_FIFO & !fifo_empty; 
    assign s_fifo_rd_done   = fifo_rd_ptr == fifo_wr_ptr + '1 & s_wr_curr_state == S_WR_WAIT & fifo_rd_en;

    always_ff @(posedge clk) begin : s_rd_fifo_ctrl
        if(!rst_n) begin
            fifo_rd_ptr <= '0;
        end else begin
            if(s_wr_curr_state == S_WR_IDLE)
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

    //-------------------------------------------------------------
    //BUFFER FOR WRITING TO MEMORY---------------------------------
    //-------------------------------------------------------------

    //decode & mux the transaction based on 
    always_comb begin : trans_decode
        s_axis_if_addr          = addr_mem;
        data_re_0_in            = s_if_buffer_unpack[1];
        data_im_0_in            = s_if_buffer_unpack[0];
        rx_done                 = s_rd_curr_state == S_RD_IDLE & s_rd_curr_state_i == S_RD_DONE;
        s_axis_if_busy          = s_wr_curr_state != S_WR_IDLE | s_rd_curr_state != S_RD_IDLE;
    end

    always_ff @(posedge clk) begin : s_if_buffer_ctrl
        if(!rst_n) begin
            fifo_rd_en_i      <= 1'b0;
            fifo_rd_en_ii     <= 1'b0;
            s_if_buffer_cnt   <= '0;
        end else begin
            if(s_rd_curr_state != S_RD_IDLE) begin
                fifo_rd_en_i  <= fifo_rd_en;
                fifo_rd_en_ii <= fifo_rd_en_i;
                if(fifo_rd_en_i)
                    if(s_if_buffer_cnt == S_IF_BUFFER_SIZE)
                        s_if_buffer_cnt <= 1;
                    else
                        s_if_buffer_cnt <= s_if_buffer_cnt + 1;    
            end else begin
                fifo_rd_en_i    <= 1'b0;
                fifo_rd_en_ii     <= 1'b0;
                s_if_buffer_cnt   <= '0;
            end 
        end
    end
    
    assign push = s_if_buffer_cnt == S_IF_BUFFER_SIZE & fifo_rd_en_ii ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin : addr_gen
        if(!rst_n) begin
            addr_mem <= '0;
        end else begin
            if(push & s_rd_curr_state != S_RD_IDLE)
                addr_mem <= addr_mem + 1;
            else if(s_rd_curr_state == S_RD_IDLE)
                addr_mem <= '0;
        end
    end

    always_ff @(posedge clk) begin : slave_if_buffer
        if(!rst_n) begin
            for(int i = 0; i < S_IF_BUFFER_SIZE; i++)
                s_if_buffer_unpack[i] <= '0;
        end else begin
            if(fifo_rd_en_i) begin
                for(int i = 0; i < S_IF_BUFFER_SIZE; i++)
                    if(i == 0)
                        s_if_buffer_unpack[i] <= fifo_out;
                    else
                        s_if_buffer_unpack[i] <= s_if_buffer_unpack[i-1];
            end
        end
    end

    // synthesis translate_off
    //simple immediate assertions
    always @(posedge clk) assert (!(fifo_wr_ptr === fifo_rd_ptr & s_wr_curr_state === S_WR_FIFO & s_rd_curr_state === S_RD_FIFO) | (fifo_wr_ptr == fifo_rd_ptr & fifo_wr_ptr == '0) | !rst_n) else $error("Write pointer cannot be equal to read pointer (slave if)");

    always @(posedge clk) assert (fifo_wr_en === 1'b0 | fifo_full === 1'b0 | !rst_n) else $error("Cannot write to a full fifo (slave if)!");

    always @(posedge clk) assert (fifo_rd_en === 1'b0 | fifo_empty === 1'b0 | !rst_n) else $error("Cannot read from an empty fifo (slave if)!");

    always @(posedge clk) assert (!(fifo_wr_en === 1'b1 & fifo_rd_en === 1'b1 & fifo_rd_ptr == fifo_wr_ptr) | !rst_n) else $error("Cannot read and write to the same position in fifo!");

    assert property (@(posedge clk) disable iff (!rst_n) (s_rd_curr_state == S_RD_DONE |-> s_wr_curr_state == S_WR_IDLE));

    assert property (@(posedge clk) disable iff (!rst_n) (s_wr_curr_state == S_WR_WAIT |-> s_rd_curr_state == S_RD_FIFO));

    assert property (@(posedge clk) disable iff (!rst_n) (S_AXIS_TREADY & S_AXIS_TVALID |-> fifo_wr_en^skid_buffer_en));
    
    assert property (@(posedge clk) disable iff (!rst_n) (s_fifo_rd_done |-> ##[1:3] addr_mem === FFT_MEM_SIZE-1));
    
    // synthesis translate_on



endmodule