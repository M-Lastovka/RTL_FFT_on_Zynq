`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2023 03:18:15 PM
// Design Name: 
// Module Name: tb_macro_def.svh
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: definition of macros
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//path do DUT components
`define dut_path        tb_top.dut_wrapp.block_vip_fft_i.dig_top_0.inst.fft_block
`define dut_mem_path    tb_top.dut_wrapp.block_vip_fft_i.dig_top_0.inst.fft_block.mem.ram_0

//path to AXIS components
`define m_axis_ext_if_path dut_wrapp.block_vip_fft_i.axi4stream_vip_0.inst.IF
`define s_axis_ext_if_path dut_wrapp.block_vip_fft_i.axi4stream_vip_1.inst.IF