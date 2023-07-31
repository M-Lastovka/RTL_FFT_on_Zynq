//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.1 (win64) Build 3247384 Thu Jun 10 19:36:33 MDT 2021
//Date        : Mon Jul 31 08:45:19 2023
//Host        : DESKTOP-2Q64EM4 running 64-bit major release  (build 9200)
//Command     : generate_target block_vip_fft_wrapper.bd
//Design      : block_vip_fft_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module block_vip_fft_wrapper
   (clk,
    rst_n);
  input clk;
  input rst_n;

  wire clk;
  wire rst_n;

  block_vip_fft block_vip_fft_i
       (.clk(clk),
        .rst_n(rst_n));
endmodule
