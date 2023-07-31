`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 04/22/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_generator.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench generator - generates the input data to the DUT, either from a file, or at random
//              
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

class tb_generator;

bit data_is_sine;
bit data_is_const;

function new( bit data_is_sine, bit data_is_const);
    this.data_is_sine = data_is_sine;
    this.data_is_const = data_is_const;
    $display("Generator object instantiated\n");
endfunction

function automatic void input_data_set(ref logic [VLW_WDT-1:0] inputs_mem_gen[FFT_MEM_SIZE-1:0], 
                                       ref logic [VLW_WDT-1:0] outputs_mem_gen[FFT_MEM_SIZE-1:0], 
                                       int line_num);
    int fd;
    real temp_re;
    real temp_im;
    int scan_r;
    string line;
    
    $display("Generating inputs by reading from a file\n");
    fd = $fopen("benchmark_data_input.txt", "r");
    assert(fd) else $fatal("File for generating inputs could not be read, exiting!");


    //first read all the lines before that line
    repeat(line_num)
        $fgets(line, fd);

    //now read the desired line
    for(int i = 0; i < FFT_MEM_SIZE; i++) begin
        if(!$feof(fd)) begin
            scan_r = $fscanf(fd, "%f ", temp_re);
            scan_r = $fscanf(fd, "%f ", temp_im);
            set_mem(inputs_mem_gen, i, temp_re, temp_im);
        end
    end
    
    $fclose(fd);     
    
    $display("Generating outputs by reading from a file\n");
    fd = $fopen("benchmark_data_output.txt", "r");
    assert(fd) else $fatal("File for generating outputs could not be read, exiting!");

    //first read all the lines before that line
    repeat(line_num)
        $fgets(line, fd);

    //now read the desired line
    for(int i = 0; i < FFT_MEM_SIZE; i++) begin
        if(!$feof(fd)) begin
            scan_r = $fscanf(fd, "%f ", temp_re);
            scan_r = $fscanf(fd, "%f ", temp_im);
            set_mem(outputs_mem_gen, i, temp_re, temp_im);
        end
    end
    
    $fclose(fd);     

endfunction

endclass