`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2023 03:18:15 PM
// Design Name: 
// Module Name: axi_stream_pckg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: package defining AXI stream interfaces
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


package axi_stream_pckg;

//FFT TODO: make this more robust
parameter VLW_WDT         = 64; 
parameter C_FFT_SIZE_LOG2 = 12;
parameter FFT_MEM_SIZE = 2**C_FFT_SIZE_LOG2;
parameter OUTPUT_MEM_OFFSET = 0;
parameter C_SAMPLE_WDT    = 24;

//AXI SLAVE

parameter S_TDATA_WDT = 32;    
parameter S_FIFO_SIZE = 16;    
parameter S_FIFO_ADDR_WDT = $clog2(S_FIFO_SIZE);
parameter S_IF_BUFFER_SIZE = VLW_WDT/S_TDATA_WDT;
parameter S_IF_ADDR_WDT = C_FFT_SIZE_LOG2; 

//AXI MASTER

parameter M_TDATA_WDT = 32;    
parameter M_FIFO_SIZE = 16;    
parameter M_FIFO_ADDR_WDT = $clog2(S_FIFO_SIZE);
parameter M_IF_BUFFER_SIZE = VLW_WDT/M_TDATA_WDT;

parameter M_PACKET_CNT = FFT_MEM_SIZE*(VLW_WDT/M_TDATA_WDT);
parameter M_FIFO_WR_FINAL = ((M_PACKET_CNT % M_FIFO_SIZE)-1) == -1 ? M_FIFO_SIZE-1 : ((M_PACKET_CNT % M_FIFO_SIZE)-1); //value at which the fifo_wr_ptr should stop

function automatic void set_mem(ref logic [VLW_WDT-1:0] inputs_mem[FFT_MEM_SIZE-1:0], int index, real re, real im);
    assert(index < FFT_MEM_SIZE) else $fatal("Index %d out of range! Aborting simulation!", index);
    inputs_mem[index][VLW_WDT-1 -: VLW_WDT/2] = $rtoi(re);
    inputs_mem[index][0 +: VLW_WDT/2] = $rtoi(im);
endfunction

function automatic real get_mem(ref logic [VLW_WDT-1:0] outputs_mem[FFT_MEM_SIZE-1:0], int index, logic re_n_im);
    assert(index < FFT_MEM_SIZE) else $fatal("Index %d out of range! Aborting simulation!", index);
    if(re_n_im)
        return $itor($signed(outputs_mem[index][VLW_WDT-1 -: VLW_WDT/2]));
    else
        return $itor($signed(outputs_mem[index][0 +: VLW_WDT/2]));
endfunction

endpackage