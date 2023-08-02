`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 04/22/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_top.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench top
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
`include "tb_driver.sv"
`include "tb_generator.sv"
`include "tb_scoreboard.sv"
`include "tb_monitor.sv"

import sim_pckg::*;
import axi_stream_pckg::*;

import axi4stream_vip_pkg::*;
import block_vip_fft_axi4stream_vip_0_0_pkg::*;
import block_vip_fft_axi4stream_vip_1_0_pkg::*;

module tb_top;

logic        clk = 0;
logic        rst_n = 0;
logic        clk_en;

bit halt_tb = 0;

//generated data for the DUT
logic [VLW_WDT-1:0] input_mem_gen[FFT_MEM_SIZE-1:0];
logic [VLW_WDT-1:0] output_mem_gen[FFT_MEM_SIZE-1:0];
logic [VLW_WDT-1:0] output_mem_dut[FFT_MEM_SIZE-1:0];

//generator and monitor objects
tb_generator    generator;
tb_monitor      monitor;
tb_driver       driver;
tb_scoreboard   scoreboard;

//external (to DUT) axi stream master and slaves objects
block_vip_fft_axi4stream_vip_1_0_slv_t  s_axis_ext_agent;
block_vip_fft_axi4stream_vip_0_0_mst_t  m_axis_ext_agent;

// Clock generation
always 
#1.5ns 
if(~halt_tb)
clk = ~clk;

initial begin
  $timeformat(-9, 4, " ns", 14);
end

// Reset generation
initial begin
  clk_en = 1;
  rst_n = 0;
  #100ns rst_n = 1;
end

initial begin

  int line_num = 1;

  m_axis_ext_agent = new("m_axis_ext_agent", `m_axis_ext_if_path);
  m_axis_ext_agent.start_master();

  s_axis_ext_agent = new("s_axis_ext_agent", `s_axis_ext_if_path);
  s_axis_ext_agent.start_slave();

  monitor = new(.s_axis_ext_agent(s_axis_ext_agent));
  scoreboard = new();
  generator = new(.f_name_inputs("fft_tb_data_input.txt"), .f_name_outputs("fft_tb_data_output.txt"));
  driver = new(.m_axis_ext_agent(m_axis_ext_agent));

    for(int k = 0; k < MAX_TRANS_CNT; k++) begin

      generator.input_data_set(input_mem_gen, output_mem_gen, line_num);

      //write to memories (through AXIS)
      driver.frnt_door_mems_write(input_mem_gen);

      monitor.s_gen_tready();

      monitor.frnt_door_get_data(output_mem_dut);

      scoreboard.compare_res(output_mem_dut, output_mem_gen);

    end

    $display("Testcase finished, total MSE across all inferences: %.8f", scoreboard.acc_mn_sqr_err/MAX_TRANS_CNT);

    halt_tb = 1;
end

block_vip_fft_wrapper dut_wrapp
(
    .clk(clk),
    .rst_n(rst_n)
);


endmodule