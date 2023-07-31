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
`define w_mem_path tb_top.dut_wrapp.block_vip_fft_i.dig_top_wrapper_0.inst.dut.weights_mem 
`define activ_mem_path tb_top.dut_wrapp.block_vip_fft_i.dig_top_wrapper_0.inst.dut.activ_mem
`define dut_path tb_top.dut_wrapp.block_vip_fft_i.dig_top_wrapper_0.inst.dut

//path to AXIS components
`define m_axis_ext_if_path dut_wrapp.block_vip_fft_i.axi4stream_vip_0.inst.IF
`define s_axis_ext_if_path dut_wrapp.block_vip_fft_i.axi4stream_vip_1.inst.IF