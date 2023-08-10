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

import sim_pckg::*;
import axi_stream_pckg::*;

import axi4stream_vip_pkg::*;
import block_vip_fft_axi4stream_vip_0_0_pkg::*;
import block_vip_fft_axi4stream_vip_1_0_pkg::*;

class tb_monitor;

block_vip_fft_axi4stream_vip_1_0_slv_t  s_axis_ext_agent;

function new(block_vip_fft_axi4stream_vip_1_0_slv_t  s_axis_ext_agent);
    this.s_axis_ext_agent = s_axis_ext_agent;
    $display("Monitor object instantiated\n");
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
    real data_packet_pack_re;
    real data_packet_pack_im;
    int packet_cnt = 0;
    int mem_line = 0;
    
    $display("Receiving AXI stream data from the DUT has started");
    
    do begin

      this.s_axis_ext_agent.monitor.item_collected_port.get(s_axis_monitor_trans);
      s_axis_monitor_trans.get_data(data_packet_unpack);
      data_packet_pack_re = $itor($signed(unpacked_to_packed(data_packet_unpack)));

      this.s_axis_ext_agent.monitor.item_collected_port.get(s_axis_monitor_trans);
      s_axis_monitor_trans.get_data(data_packet_unpack);
      data_packet_pack_im = $itor($signed(unpacked_to_packed(data_packet_unpack)));

      set_mem(output_mem_dut, packet_cnt, data_packet_pack_re, data_packet_pack_im);

      packet_cnt++;
        
    end while (!s_axis_monitor_trans.get_last()); 

    $display("Receiving of AXI stream data from the DUT is finished");

    assert(packet_cnt == FFT_MEM_SIZE) else $fatal("Number of received AXI data stream packets: %d does not match target: %d!", packet_cnt, FFT_MEM_SIZE);
    
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