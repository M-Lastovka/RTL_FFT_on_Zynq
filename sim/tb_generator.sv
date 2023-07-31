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

bit data_src_tb_nfile;
bit data_is_sine;
bit data_is_const;

function new(bit data_src_tb_nfile, bit data_is_sine, bit data_is_const);
    this.data_src_tb_nfile = data_src_tb_nfile;
    this.data_is_sine = data_is_sine;
    this.data_is_const = data_is_const;
    $display("Generator object instantiated\n");
endfunction

function automatic void input_data_set(ref logic [VLW_WDT-1:0] inputs_mem_gen[FFT_MEM_SIZE-1:0]);
    int fd;
    real temp;
    int scan_r;
    string line;
    int line_num;
    if(this.data_src_tb_nfile) begin
        $display("Generating the inputs in testbench\n");

        for(int i = 0; i < FFT_MEM_SIZE; i++) begin
            if(this.data_is_sine)
                set_input_data(inputs_mem_gen, i, (2**7-1)*$sine(i*2.0*$acos(-1)/440.0));
            else if(this.data_is_cont)
                set_input_data(inputs_mem_gen, i, (2**7-1));
            else
        end
    end else begin
        $display("Generating inputs reading from a file\n");
        fd = $fopen("benchmark_data_input.txt", "r");
        assert(fd) else $fatal("File for generating inputs could not be read, exiting!");

        line_num = 0; //read from a line

        //first read all the lines before that line
        repeat(line_num)
            $fgets(line, fd);

        //now read the desired line
        for(int i = 0; i < FFT_MEM_SIZE; i++) begin
            if(!$feof(fd)) begin
                scan_r = $fscanf(fd, "%f ", temp);
                set_input_data(inputs_mem_gen, i, temp);
            end
        end
        
        $fclose(fd);
        
    end

endfunction

endclass