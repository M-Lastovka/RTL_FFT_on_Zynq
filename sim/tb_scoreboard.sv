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


import fp_pckg::*;
import dnn_pckg::*;
import sim_pckg::*;
import axi_stream_pckg::*;

class tb_scoreboard;

bit bckdoor_n_frntdoor;
real acc_mn_sqr_err;

function new(bit bckdoor_n_frntdoor);
    this.bckdoor_n_frntdoor = bckdoor_n_frntdoor;
    $display("Scoreboard object instantiated. %sdoor access is set\n", bckdoor_n_frntdoor ? "back" : "front");
    this.acc_mn_sqr_err = 0.0;
endfunction

//computes the reference solution from the inputs sent to DUT, compares them to
//the DUT results, reports MSE
function automatic void compare_res(logic [VLW_WDT-1:0] input_mem_dut[INPUT_MEM_SIZE-1:0], 
                                    logic [VLW_WDT-1:0] w_weight_mem_dut[WEIGHT_MEM_SIZE-1:0],
                                    logic [FP_WORD_WDT-1:0] b_bias_mem_dut[BIAS_MEM_SIZE-1:0],
                                    logic [VLW_WDT-1:0] activ_mem_dut[ACTIV_MEM_SIZE-1:0],
                                    logic [VLW_WDT-1:0] output_mem_dut[FFT_MEM_SIZE-1:0]);

    real ref_res_in[MAX_COL_S][BATCH_SIZE]; //here store the reference input
    real ref_res_out[MAX_COL_S][BATCH_SIZE]; //here store the reference solution

    real sqr_err = 0.0;
    real mn_sqr_err = 0.0;

    //clear the ref. out matrix
    for(int i = 0; i < MAX_COL_S; i++)
        for(int j = 0; j < BATCH_SIZE; j++)
            ref_res_out[i][j] = 0.0;

    //load the ref. in matrix
    for(int i = 0; i < MAX_COL_S; i++)
        for(int j = 0; j < BATCH_SIZE; j++)
            if(i < DNN_STRUCT[LAYERS_CNT-1][0])
                ref_res_in[i][j] = fp_2_real(get_input_mat(i,j,input_mem_dut));
            else
                ref_res_in[i][j] = 0.0;

    //compute the reference solution
    for(int layer_i = 0; layer_i < LAYERS_CNT; layer_i++) begin //foreach layer
        for(int i = 0; i < DNN_STRUCT[LAYERS_CNT-1-layer_i][1]; i++) begin //foreach row
            for(int j = 0; j < BATCH_SIZE; j++) begin //foreach column
                for(int l = 0; l < DNN_STRUCT[LAYERS_CNT-1-layer_i][0]; l++) begin  //compute dot product
                    ref_res_out[i][j] = ref_res_out[i][j] + 
                    ref_res_in[l][j]*fp_2_real(get_w_mat(i,l,layer_i,w_weight_mem_dut));
                end
                //add bias
                ref_res_out[i][j] = ref_res_out[i][j] + fp_2_real(get_b_vect(i, layer_i, b_bias_mem_dut));
                `verb_filt(VER_HIGH)
                $display("Bias vector entry[%3d], layer %1d: %.8f", i+1,layer_i+1,
                    fp_2_real(get_b_vect(i, layer_i, b_bias_mem_dut)));
                `filt_end
                //activation function
                casez(ACTIV_FNC_CFG_LAYERS[LAYERS_CNT-1-layer_i])
                    ACTIV_FNC_IDENTITY  : ref_res_out[i][j] = ref_res_out[i][j];
                    ACTIV_FNC_RELU      : ref_res_out[i][j] = ref_res_out[i][j] < 0.0 ? 0.0 : ref_res_out[i][j];
                    ACTIV_FNC_TANH      : ref_res_out[i][j] = $tanh(ref_res_out[i][j]);
                    default             : ref_res_out[i][j] = ref_res_out[i][j];
                endcase
            end
        end
        //copy results memory to inputs and reset outputs
        for(int i = 0; i < MAX_COL_S; i++) begin
            for(int j = 0; j < BATCH_SIZE; j++) begin
                ref_res_in[i][j] = ref_res_out[i][j];
                ref_res_out[i][j] = 0.0;
            end
        end
        //compare intermediate results
        if(this.bckdoor_n_frntdoor) begin
            for(int i = 0; i < DNN_STRUCT[LAYERS_CNT-1-layer_i][1]; i++) begin //foreach row
                for(int j = 0; j < BATCH_SIZE; j++) begin //foreach column
                    `verb_filt(VER_LOW)
                    sqr_err = (fp_2_real(get_act_mat(i,j,layer_i+1,activ_mem_dut)) - ref_res_in[i][j])**2;
                    $display("@ layer %1d: DUT result @[%3d][%3d]: %.8f; Reference result @[%3d][%3d]: %.8f; Squared sqr_err %.8f\n",
                    layer_i+1, i+1, j+1, fp_2_real(get_act_mat(i,j,layer_i+1,activ_mem_dut)),i+1, j+1, ref_res_in[i][j],sqr_err);
                    `filt_end
                end
            end
        end
    end

    //final comparison
    if(this.bckdoor_n_frntdoor) begin //backdoor access
        for(int i = 0; i < DNN_STRUCT[0][1]; i++) begin //foreach row
            for(int j = 0; j < BATCH_SIZE; j++) begin //foreach column
                sqr_err = (fp_2_real(get_act_mat(i,j,LAYERS_CNT,activ_mem_dut)) - ref_res_in[i][j])**2;
                mn_sqr_err = mn_sqr_err + sqr_err;
                `verb_filt(VER_MID)
                $display("Final DUT result @[%3d][%3d]: %.8f; Reference result @[%3d][%3d]: %.8f; Squared error %.8f\n",
                    i+1, j+1, fp_2_real(get_act_mat(i,j,LAYERS_CNT,activ_mem_dut)),i+1, j+1, ref_res_in[i][j], sqr_err);
                `filt_end
            end
        end
    end else begin
        for(int i = 0; i < DNN_STRUCT[0][1]; i++) begin //foreach row
            for(int j = 0; j < BATCH_SIZE; j++) begin //foreach column
                sqr_err = (fp_2_real(get_output_mat(i,j,output_mem_dut)) - ref_res_in[i][j])**2;
                mn_sqr_err = mn_sqr_err + sqr_err;
                `verb_filt(VER_MID)
                $display("Final DUT result @[%3d][%3d]: %.8f; Reference result @[%3d][%3d]: %.8f; Squared error %.8f\n",
                    i+1, j+1, fp_2_real(get_output_mat(i,j,output_mem_dut)),i+1, j+1, ref_res_in[i][j], sqr_err);
                `filt_end
            end
        end
    end
    mn_sqr_err = mn_sqr_err/(BATCH_SIZE*DNN_STRUCT[0][1]);
    `verb_filt(VER_MID)
    $display("Final inference MSE: %.8f\n", mn_sqr_err);
    `filt_end
    if(mn_sqr_err > 0.01)
        $warning("MSE seems too high (but this depends on inputs and nonlinearity used)\n");
    
    this.acc_mn_sqr_err = acc_mn_sqr_err + mn_sqr_err;

endfunction

endclass