`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 04/22/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_monitor.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench monitor - receives the AXI Stream from the DUT
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

import fp_pckg::*;
import dnn_pckg::*;
import sim_pckg::*;
import axi_stream_pckg::*;

import axi4stream_vip_pkg::*;
import block_vip_fft_axi4stream_vip_0_0_pkg::*;
import block_vip_fft_axi4stream_vip_1_0_pkg::*;

class tb_monitor;

bit bckdoor_n_frntdoor;
block_vip_fft_axi4stream_vip_1_0_slv_t  s_axis_ext_agent;

function new(bit bckdoor_n_frntdoor, block_vip_fft_axi4stream_vip_1_0_slv_t  s_axis_ext_agent);
    this.bckdoor_n_frntdoor = bckdoor_n_frntdoor;
    this.s_axis_ext_agent = s_axis_ext_agent;
    $display("Monitor object instantiated. %s access is set\n", bckdoor_n_frntdoor ? "backdoor" : "frontdoor");
endfunction

task s_gen_tready();
    axi4stream_ready_gen ready_gen;
    xil_axi4stream_ready_gen_policy_t tready_policy;

    std::randomize(tready_policy);
    $display("Randomizing AXI slave agent TREADY generation, ready policy: %s\n", tready_policy.name());
    ready_gen = this.s_axis_ext_agent.driver.create_ready("ready_gen");
    ready_gen.set_ready_policy(tready_policy);
    if(tready_policy != XIL_AXI4STREAM_READY_GEN_NO_BACKPRESSURE) begin
      ready_gen.set_low_time($urandom_range(1,10));
      ready_gen.set_high_time($urandom_range(1,10));
    end
    this.s_axis_ext_agent.driver.send_tready(ready_gen);
endtask

task frnt_door_get_data(ref logic [VLW_WDT-1:0] output_mem_dut[FFT_MEM_SIZE-1:0]);
    axi4stream_monitor_transaction  s_axis_monitor_trans;
    logic[7:0] data_packet_unpack[M_TDATA_WDT/8];
    logic[M_TDATA_WDT-1:0] data_packet_pack;
    int packet_cnt = 0;
    int mem_line = 0;
    
    $display("Receiving AXI stream data from the DUT has started");
    
    do begin

      this.s_axis_ext_agent.monitor.item_collected_port.get(s_axis_monitor_trans);
      s_axis_monitor_trans.get_data(data_packet_unpack);
      data_packet_pack = unpacked_to_packed(data_packet_unpack);
      output_mem_dut[packet_cnt/(PU_WIND_SIZE/(M_TDATA_WDT/FP_WORD_WDT))][(packet_cnt % (PU_WIND_SIZE/(M_TDATA_WDT/FP_WORD_WDT)))*M_TDATA_WDT +: M_TDATA_WDT] = data_packet_pack;
      packet_cnt++;
      `verb_filt(VER_HIGH)
      $display("AXI stream data packet received! Data: %h", data_packet_pack);
      `filt_end
        
    end while (!s_axis_monitor_trans.get_last()); 

    $display("Receiving of AXI stream data from the DUT is finished");

    if(packet_cnt != FFT_MEM_SIZE*(VLW_WDT/M_TDATA_WDT))
        $fatal("Number of received AXI data stream packets: %d does not match targer: %d!",packet_cnt, FFT_MEM_SIZE*(VLW_WDT/M_TDATA_WDT));
    
endtask

task bck_door_get_data(ref logic [VLW_WDT-1:0] activ_mem_bckdoor[ACTIV_MEM_SIZE-1:0], 
                       ref logic [VLW_WDT-1:0] output_mem_dut[FFT_MEM_SIZE-1:0]);
    
    $display("Reading the computed output through backdoor");

    @(`dut_path.comp_done);
    
    #10ns;  

    activ_mem_bckdoor = `activ_mem_path.activ_mem;

    #10ns;

    for(int j = 0; j < BATCH_SIZE; j++) begin
      for(int i = 0; i < DNN_STRUCT[0][1]; i++) begin
        set_output_mat(i,j,fp_2_real(get_act_mat(i,j,LAYERS_CNT,activ_mem_bckdoor)),output_mem_dut);
      end
    end
    
endtask


function logic[M_TDATA_WDT-1:0] unpacked_to_packed(logic [7:0] unpacked_array[]);
  logic[M_TDATA_WDT-1:0] packed_array;
  int i;
  
  // Convert unpacked array to packed array
  for (i = 0; i < unpacked_array.size(); i++)
    packed_array[i * 8 +: 8] = unpacked_array[i];
  
  return packed_array;
endfunction

endclass