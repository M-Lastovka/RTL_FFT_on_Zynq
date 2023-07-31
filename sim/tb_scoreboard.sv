`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 04/22/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_scoreboard.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench scoreboard - gets the inputs to the DUT, 
//              computes the reference solution, compares it to DUT
//              
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
///////////////////////////////////////////////////////////////////////////////////


import sim_pckg::*;
import axi_stream_pckg::*;

class tb_scoreboard;

real acc_mn_sqr_err;

function new();
    $display("Scoreboard object instantiated\n");
    this.acc_mn_sqr_err = 0.0;
endfunction

//computes the reference solution from the inputs sent to DUT, compares them to
//the DUT results, reports MSE
function automatic void compare_res(logic [VLW_WDT-1:0] output_mem_dut[FFT_MEM_SIZE-1:0], 
                                    logic [VLW_WDT-1:0] output_mem_ref[FFT_MEM_SIZE-1:0]);

    real sqr_err = 0.0;
    real mn_sqr_err = 0.0;

    for(int i = 0; i < FFT_MEM_SIZE; i++) begin
        sqr_err = (get_mem(output_mem_dut, i, "re") - get_mem(output_mem_ref, i, "re"))**2 + (get_mem(output_mem_dut, i, "im") - get_mem(output_mem_ref, i, "im"))**2;
        $display("@ index %2d DUT: %f + j*%f; REF: %f + j*%f, squared error: %f", i, 
            get_mem(output_mem_dut, i, "re"), get_mem(output_mem_dut, i, "im"), get_mem(output_mem_ref, i, "re"), get_mem(output_mem_ref, i, "im"), sqr_err);
        mn_sqr_err += sqr_err;
    end
    mn_sqr_err = sqr_err/FFT_MEM_SIZE;
    $display("Total MSE in this batch: %f", mn_sqr_err);

endfunction

endclass