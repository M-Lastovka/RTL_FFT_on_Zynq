`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 06/23/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_driver.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench driver
//              
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
///////////////////////////////////////////////////////////////////////////////////

`include "tb_macro_def.svh"

import sim_pckg::*;
import axi_stream_pckg::*;

import axi4stream_vip_pkg::*;
import block_vip_fft_axi4stream_vip_0_0_pkg::*;
import block_vip_fft_axi4stream_vip_1_0_pkg::*;

class tb_driver;

block_vip_fft_axi4stream_vip_0_0_mst_t  m_axis_ext_agent;

function new(block_vip_fft_axi4stream_vip_0_0_mst_t  m_axis_ext_agent);
  this.m_axis_ext_agent = m_axis_ext_agent;  
  $display("Driver object instantiated\n");
endfunction

//frontdoor write through AXIS to weight, bias and activations memories
task frnt_door_mems_write(
  input logic [VLW_WDT-1:0] input_mem_gen[FFT_MEM_SIZE-1:0],
  input bit only_inputs  
);

  axi4stream_transaction wr_transaction;
  logic [S_TDATA_WDT-1:0] axis_word = '0;

  $display("Frontdoor write to FFT started\n");

  $display("Writing new inputs through AXIS\n");
  axis_word = '0;

    for(int i = 0; i < FFT_MEM_SIZE; i++) begin
      axis_word = real_2_fp(input_mem_gen[i]);
      if((i+1) % (S_TDATA_WDT/FP_WORD_WDT) == 0) begin
        wr_transaction = this.m_axis_ext_agent.driver.create_transaction("write transaction");
        SEND_PACKET_FAILURE: assert(wr_transaction.randomize());
        wr_transaction.set_data_beat(axis_word);
        wr_transaction.set_id(INPUT_S_AXIS_ID);  
        if(j == BATCH_SIZE-1 & i == DNN_STRUCT[LAYERS_CNT-1][0]-1)
          wr_transaction.set_last(1);
        else
          wr_transaction.set_last(0);
        this.m_axis_ext_agent.driver.send(wr_transaction);
      end
    end

  $display("New inputs have been written through AXIS\n");

  //check whether inputs have been transmitted correctly through backdoor
  //TODO: compilation guard
  @(`dut_path.inputs_rx_done);
  #1ns;
  for(int i = 0; i < FFT_MEM_SIZE; i++) begin
    if(`activ_mem_path.activ_mem[i] == input_mem_gen[i]) begin
      `verb_filt(VER_HIGH)
        $display("The DUT activations memory : %h at line %3d does match with the TB generated data : %h", `activ_mem_path.activ_mem[i], i, input_mem_gen[i]);  
      `filt_end
    end else begin
      $error("The DUT activations memory : %h at line %3d does not match with the TB generated data : %h", `activ_mem_path.activ_mem[i], i, input_mem_gen[i]);  
    end
  end

  $display("Writing through AXIS is done\n");

endtask


endclass