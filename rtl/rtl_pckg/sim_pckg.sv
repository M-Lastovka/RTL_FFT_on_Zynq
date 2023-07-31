`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2023 03:18:15 PM
// Design Name: 
// Module Name: sim_pckg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: package defining functions and parameters for TB
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "dnn_macro_def.svh"

package sim_pckg;


//define max number of tested FFTs
parameter MAX_TRANS_CNT = 500; //generated by setup_dnn_proj.py, do not edit manually 

endpackage