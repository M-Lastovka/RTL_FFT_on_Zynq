`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Martin Lastovka
// 
// Create Date: 04/22/2023 03:12:03 PM
// Design Name: 
// Module Name: tb_top_unit.sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench for testing the arithmetic units
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

`define verb_filt(verbos_lvl) \
    if(verbos_lvl <= VERBOS_LVL_GLOBAL) begin \

`define filt_end \
    end


module tb_top_unit;

logic        clk = 0;
logic        rst_n;
logic        clk_en;


logic halt_tb = 0;

int transaction_cnt_add = 0;
logic start_add = 0;
logic halt_add = 0;

int transaction_cnt_mult = 0;
logic start_mult = 0;
logic halt_mult = 0;

int transaction_cnt_mac = 0;
logic start_mac = 0;
logic halt_mac = 0;

int transaction_cnt_tanh = 0;
logic start_tanh = 0;
logic halt_tanh = 0;

// Clock generation
always 
#4ns 
if(~halt_tb)
clk = ~clk;

initial begin
  $timeformat(-9, 4, " ns", 14);
end

// Reset generation
initial begin
  clk_en = 1;
  rst_n = 0;
  #50ns rst_n = 1;
end

// Arbiter
always begin
  start_add = 1;
  wait(halt_add);
  start_add = 0;
  start_mult = 1;
  wait(halt_mult);
  start_mult = 0;
  start_mac = 1;
  wait(halt_mac);
  start_mac = 0;
  start_tanh = 1;
  wait(halt_tanh);
  halt_tb = 1;
  wait(0);
end


//-------------------------------------------------------------
//FP ADDER - stimulus generation and monitor-------------------
//-------------------------------------------------------------

logic [FP_WORD_WDT-1:0] op_a_add;
logic [FP_WORD_WDT-1:0] op_b_add;
logic [FP_WORD_WDT-1:0] res_add;

logic overflow_add;
logic zero_res_add;
logic res_subnorm_n_norm_add;
logic [FP_WORD_WDT-1:0] input_patterns_a_add[MAX_ADD_TRANS_CNT-1:0];
logic [FP_WORD_WDT-1:0] input_patterns_b_add[MAX_ADD_TRANS_CNT-1:0];

real op_a_add_b;
real op_b_add_b;
real res_add_b;
real res_add_actual;
real res_add_error;
real res_add_error_max = 0.0;

// Instantiate the DUT
fp_adder dut_add
( .op_a_add(op_a_add), 
  .op_b_add(op_b_add), 
  .clk(clk), 
  .rst_n(rst_n),
  .clk_en(clk_en),  
  .res_add(res_add), 
  .overflow_add(overflow_add),
  .zero_res_add(zero_res_add),
  .res_subnorm_n_norm_add(res_subnorm_n_norm_add)
);

// initial block
initial begin
  for(int i = 0; i < MAX_ADD_TRANS_CNT; i++) begin //fill with random bits
      input_patterns_a_add[i] = $urandom();
      input_patterns_b_add[i] = $urandom();
  end 
  //manually inserted patterns - interesting edge cases
  input_patterns_a_add[0] = '0; //zeros
  input_patterns_b_add[0] = '0;
  input_patterns_a_add[1] = {1'b1, {(FP_EXP_WDT){1'b1}}, {(FP_MANT_WDT){1'b0}}}; //infinity
  input_patterns_b_add[1] = $urandom();
  input_patterns_a_add[2] = $urandom();
  input_patterns_b_add[2] = {1'b1, {(FP_EXP_WDT){1'b1}}, {(FP_MANT_WDT){1'b0}}};
  input_patterns_a_add[3] = '1; //all ones
  input_patterns_b_add[3] = '1;
  input_patterns_a_add[4] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1011_0000_1110}; //positive overflow_add
  input_patterns_b_add[4] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1110_0101_1110};
  input_patterns_a_add[5] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1011_0000_1110}; //negative overflow_add
  input_patterns_b_add[5] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1110_0101_1110};
  input_patterns_a_add[6] = {1'b0, 3'b001, 12'b1110_0001_1110}; 
  input_patterns_b_add[6] = {1'b1, 3'b001, 12'b1110_0000_1100}; //normal to subnormal
  input_patterns_a_add[7] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_add[7] = {1'b0, 3'b000, 12'b1110_0000_1100}; //subnormal to normal
  input_patterns_a_add[8] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_add[8] = {1'b1, 3'b000, 12'b1110_0001_1110}; //zero res
  input_patterns_a_add[8] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_add[8] = {1'b1, 3'b000, 12'b1110_0001_1110}; //underflow
  
end

//fp adder stimulus generation
always_ff @(posedge clk) begin
  if(!rst_n) begin
      op_a_add <= '0;
      op_b_add <= '0;
  end else begin
      if(start_add) begin
        if(transaction_cnt_add < MAX_ADD_TRANS_CNT) begin
          op_a_add <= input_patterns_a_add[transaction_cnt_add];
          op_b_add <= input_patterns_b_add[transaction_cnt_add];
          transaction_cnt_add <= transaction_cnt_add+1;
        end else begin //stop providing stimulus
          halt_add <= 1;
          wait(0);
        end
      end
  end
end

//fp adder monitor
always_ff @(posedge clk) begin
  if(start_add) begin
    if(transaction_cnt_add < MAX_ADD_TRANS_CNT) begin
      op_a_add_b = fp_2_real(op_a_add);
      op_b_add_b = fp_2_real(op_b_add);
      res_add_b  = fp_2_real(res_add);
      res_add_actual = fp_2_real(input_patterns_a_add[transaction_cnt_add-PIPELINE_ADD_STAGE_CNT]) + fp_2_real(input_patterns_b_add[transaction_cnt_add-PIPELINE_ADD_STAGE_CNT]);
      if(transaction_cnt_add > PIPELINE_ADD_STAGE_CNT-1 & ~overflow_add) begin

        `verb_filt(VER_HIGH)
        $display("Time: %t  Inputs: A = %f, B = %f, Result = %f\n", $time, fp_2_real(input_patterns_a_add[transaction_cnt_add-PIPELINE_ADD_STAGE_CNT]),
        fp_2_real(input_patterns_b_add[transaction_cnt_add-PIPELINE_ADD_STAGE_CNT]), res_add_b);
        `filt_end

        res_add_error = 100.0*(res_add_actual - res_add_b)/res_add_actual;

        `verb_filt(VER_HIGH)
        $display("Time: %t  Relative signed error in percent is %f\n", $time, res_add_error);
        `filt_end

        if(abs_r(res_add_error) > abs_r(res_add_error_max))
          res_add_error_max = res_add_error;

      end else if(overflow_add) begin
        if(abs_r(res_add_actual) <= abs_r(2**((2**FP_EXP_WDT-1)-$signed(FP_EXP_BIAS))*(2.0-1.0/(2**FP_MANT_WDT))))
          $error("Result is signalled as an overflow_add, but the actual result : %f is smaller than the maximal representable value: +-%f!\n", res_add_actual, abs_r(2**((2**FP_EXP_WDT-1)-FP_EXP_BIAS)*(2.0-1.0/(2**FP_MANT_WDT))));
        else
          `verb_filt(VER_HIGH)
          $display("Time: %t  Result correctly signalled as an overflow_add! Actual result: %f\n",$time, res_add_actual);
          `filt_end
      end
    end else begin 
      `verb_filt(VER_LOW)
      $display("Time: %t  Testing of fp adder is complete, total of %d input pattern pairs were tested.\n Maximal relative signed error in percent is: %f\n",$time, transaction_cnt_add, res_add_error_max);
      `filt_end
      wait(0);
    end
  end
end




//-------------------------------------------------------------
//FP MULTIPLIER - stimulus generation and monitor--------------
//-------------------------------------------------------------

logic [FP_WORD_WDT-1:0] op_a_mult;
logic [FP_WORD_WDT-1:0] op_b_mult;
logic [FP_WORD_WDT-1:0] res_mult;

logic overflow_mult;
logic underflow_mult;
logic zero_res_mult;
logic res_subnorm_n_norm_mult;
logic [FP_WORD_WDT-1:0] input_patterns_a_mult[MAX_MULT_TRANS_CNT-1:0];
logic [FP_WORD_WDT-1:0] input_patterns_b_mult[MAX_MULT_TRANS_CNT-1:0];

real op_a_mult_b;
real op_b_mult_b;
real res_mult_b;
real res_mult_actual;
real res_mult_error;
real res_mult_error_max = 0.0;

// Instantiate the DUT
fp_mult dut_mult
( .op_a_mult(op_a_mult), 
  .op_b_mult(op_b_mult), 
  .clk(clk), 
  .rst_n(rst_n),
  .clk_en(clk_en),  
  .res_mult(res_mult), 
  .overflow_mult(overflow_mult),
  .underflow_mult(underflow_mult),
  .zero_res_mult(zero_res_mult),
  .res_subnorm_n_norm_mult(res_subnorm_n_norm_mult)
);

// initial block
initial begin
  for(int i = 0; i < MAX_MULT_TRANS_CNT; i++) begin //fill with random bits
      input_patterns_a_mult[i] = $urandom();
      input_patterns_b_mult[i] = $urandom();
  end 
  //manually inserted patterns - interesting edge cases
  input_patterns_a_mult[0] = '0; //zeros
  input_patterns_b_mult[0] = '0;
  input_patterns_a_mult[1] = {1'b1, {(FP_EXP_WDT){1'b1}}, {(FP_MANT_WDT){1'b0}}}; //infinity
  input_patterns_b_mult[1] = $urandom();
  input_patterns_a_mult[2] = $urandom();
  input_patterns_b_mult[2] = {1'b1, {(FP_EXP_WDT){1'b1}}, {(FP_MANT_WDT){1'b0}}};
  input_patterns_a_mult[3] = '1; //all ones
  input_patterns_b_mult[3] = '1;
  input_patterns_a_mult[4] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1011_0000_1110}; //positive overflow_mult
  input_patterns_b_mult[4] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1110_0101_1110};
  input_patterns_a_mult[5] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1011_0000_1110}; //negative overflow_mult
  input_patterns_b_mult[5] = {1'b0, {(FP_EXP_WDT){1'b1}}, 12'b1110_0101_1110};
  input_patterns_a_mult[6] = {1'b0, 3'b001, 12'b1110_0001_1110}; 
  input_patterns_b_mult[6] = {1'b1, 3'b001, 12'b1110_0000_1100}; //normal to subnormal
  input_patterns_a_mult[7] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_mult[7] = {1'b0, 3'b000, 12'b1110_0000_1100}; //subnormal to normal
  input_patterns_a_mult[8] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_mult[8] = {1'b1, 3'b000, 12'b1110_0001_1110}; //zero res
  input_patterns_a_mult[8] = {1'b0, 3'b000, 12'b1110_0001_1110}; 
  input_patterns_b_mult[8] = {1'b1, 3'b000, 12'b1110_0001_1110}; //underflow
  
end

//fp multiplier stimulus generation
always_ff @(posedge clk) begin
  if(!rst_n) begin
      op_a_mult <= '0;
      op_b_mult <= '0;
  end else begin
      if(start_mult) begin
        if(transaction_cnt_mult < MAX_MULT_TRANS_CNT) begin
          op_a_mult <= input_patterns_a_mult[transaction_cnt_mult];
          op_b_mult <= input_patterns_b_mult[transaction_cnt_mult];
          transaction_cnt_mult <= transaction_cnt_mult+1;
        end else begin //stop providing stimulus
          halt_mult <= 1;
          wait(0);
        end
      end
  end
end

//fp multiplier monitor
always_ff @(posedge clk) begin
  if(start_mult) begin
    if(transaction_cnt_mult < MAX_MULT_TRANS_CNT) begin
      op_a_mult_b = fp_2_real(op_a_mult);
      op_b_mult_b = fp_2_real(op_b_mult);
      res_mult_b  = fp_2_real(res_mult);
      res_mult_actual = fp_2_real(input_patterns_a_mult[transaction_cnt_mult-PIPELINE_MULT_STAGE_CNT])*fp_2_real(input_patterns_b_mult[transaction_cnt_mult-PIPELINE_MULT_STAGE_CNT]);
      if(transaction_cnt_mult > PIPELINE_MULT_STAGE_CNT-1 & ~overflow_mult & ~underflow_mult) begin

        `verb_filt(VER_HIGH)
        $display("Time: %t  Inputs: A = %f, B = %f, Result = %f\n",$time, fp_2_real(input_patterns_a_mult[transaction_cnt_mult-PIPELINE_MULT_STAGE_CNT]),
        fp_2_real(input_patterns_b_mult[transaction_cnt_mult-PIPELINE_MULT_STAGE_CNT]), res_mult_b);
        `filt_end

        res_mult_error = 100.0*(res_mult_actual - res_mult_b)/res_mult_actual;

        `verb_filt(VER_HIGH)
        $display("Time: %t  Relative signed error in percent is %f\n",$time, res_mult_error);
        `filt_end

        if(abs_r(res_mult_error) > abs_r(res_mult_error_max))
          res_mult_error_max = res_mult_error;

      end else if(overflow_mult) begin
        if(abs_r(res_mult_actual) <= abs_r(2**((2**FP_EXP_WDT-1)-$signed(FP_EXP_BIAS))*(2.0-1.0/(2**FP_MANT_WDT))))
          $error("Result is signalled as an overflow_mult, but the actual result : %f is smaller than the maximal representable value: +-%f!\n", res_mult_actual, abs_r(2**((2**FP_EXP_WDT-1)-FP_EXP_BIAS)*(2.0-1.0/(2**FP_MANT_WDT))));
        else
          `verb_filt(VER_HIGH)
          $display("Time: %t  Result correctly signalled as an overflow_mult! Actual result: %f\n",$time, res_mult_actual);
          `filt_end
      end else if(underflow_mult) begin
        if(abs_r(res_mult_actual) >= abs_r(2.0**(1-$signed(FP_EXP_BIAS))*(1.0/(2**(FP_MANT_WDT)))) || res_mult_actual == 0.0)
          $error("Result is signalled as an underflow_mult, but the actual result : %f is larger than the minimal representable value: +- %f !\n", res_mult_actual, abs_r(2.0**(1-$signed(FP_EXP_BIAS))*(1.0/(2**(FP_MANT_WDT)))));
        else
          `verb_filt(VER_HIGH)
          $display("Time: %t  Result correctly signalled as an underflow_mult! Actual result: %f\n",$time, res_mult_actual);
          `filt_end
      end
    end else begin 
      `verb_filt(VER_LOW)
      $display("Time: %t  Testing of fp mult is complete, total of %d input pattern pairs were tested.\n Maximal relative signed error in percent is: %f\n",$time, transaction_cnt_mult, res_mult_error_max);
      `filt_end
      wait(0);
    end
  end
end


//-------------------------------------------------------------
//FP MAC - stimulus generation and monitor---------------------
//-------------------------------------------------------------

logic [FP_WORD_WDT-1:0] op_a_mac;
logic [FP_WORD_WDT-1:0] op_b_mac;
logic [FP_WORD_WDT-1:0] op_c_mac;
logic [FP_WORD_WDT-1:0] res_mac;

logic res_inexact_sat_mac;
logic [FP_WORD_WDT-1:0] input_patterns_a_mac[MAX_MAC_TRANS_CNT-1:0];
logic [FP_WORD_WDT-1:0] input_patterns_b_mac[MAX_MAC_TRANS_CNT-1:0];
logic [FP_WORD_WDT-1:0] input_patterns_c_mac[MAX_MAC_TRANS_CNT-1:0];

real op_a_mac_b;
real op_b_mac_b;
real op_c_mac_b;
real res_mac_b;
real res_mac_actual;
real res_mac_error;
real res_mac_error_max = 0.0;

// Instantiate the DUT
fp_mac dut_mac
( .op_a_mac(op_a_mac), 
  .op_b_mac(op_b_mac),
  .op_c_mac(op_c_mac), 
  .clk(clk), 
  .rst_n(rst_n),
  .clk_en(clk_en),  
  .res_mac(res_mac), 
  .res_inexact_sat_mac(res_inexact_sat_mac)
);

// initial block
initial begin
  for(int i = 0; i < MAX_MAC_TRANS_CNT; i++) begin //fill with random bits
      input_patterns_a_mac[i] = $urandom();
      input_patterns_b_mac[i] = $urandom();
      input_patterns_c_mac[i] = $urandom();
  end 
  //manually inserted patterns - interesting edge cases
  
end

//fp mac stimulus generation
always_ff @(posedge clk) begin
  if(!rst_n) begin
      op_a_mac <= '0;
      op_b_mac <= '0;
      op_c_mac <= '0;
  end else begin
      if(start_mac) begin
        if(transaction_cnt_mac < MAX_MAC_TRANS_CNT) begin
          op_a_mac <= input_patterns_a_mac[transaction_cnt_mac];
          op_b_mac <= input_patterns_b_mac[transaction_cnt_mac];
          op_c_mac <= input_patterns_c_mac[transaction_cnt_mac];
          transaction_cnt_mac <= transaction_cnt_mac+1;
        end else begin //stop providing stimulus
          halt_mac <= 1;
          wait(0);
        end
      end
  end
end

//fp mac monitor
always_ff @(posedge clk) begin
  if(start_mac) begin
    if(transaction_cnt_mac < MAX_MAC_TRANS_CNT) begin
      op_a_mac_b = fp_2_real(op_a_mac);
      op_b_mac_b = fp_2_real(op_b_mac);
      op_c_mac_b = fp_2_real(op_c_mac);
      res_mac_b  = fp_2_real(res_mac);
      res_mac_actual = fp_2_real(input_patterns_a_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT])*fp_2_real(input_patterns_b_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]) +
      fp_2_real(input_patterns_c_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]);

      if(transaction_cnt_mac > PIPELINE_MAC_STAGE_CNT-1 & ~res_inexact_sat_mac) begin

        `verb_filt(VER_HIGH)
        $display("Time: %t  Inputs: A = %f, B = %f, C = %f, Result = %f\n",$time, fp_2_real(input_patterns_a_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]),
        fp_2_real(input_patterns_b_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]), fp_2_real(input_patterns_c_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]), res_mac_b);
        `filt_end

        res_mac_error = 100.0*(res_mac_actual - res_mac_b)/res_mac_actual;

        `verb_filt(VER_HIGH)
        $display("Time: %t  Relative signed error in percent is %f\n",$time, res_mac_error);
        `filt_end

        if(abs_r(res_mac_error) > abs_r(res_mac_error_max))
          res_mac_error_max = res_mac_error;

      end else if(res_inexact_sat_mac) begin
        if(res_mac_b*res_mac_actual < 0)
        $error("Result is signalled as inexact, but the saturated value : %f does not sign match the actual value : %f, not possible!\n", res_mult_b, res_mult_actual);
        `verb_filt(VER_MID)
        $display("Time: %t  Inputs: A = %f, B = %f, C = %f, Result: %f is signalled as inexact because of saturation, actual result: %f\n",$time, fp_2_real(input_patterns_a_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]),
          fp_2_real(input_patterns_b_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]), fp_2_real(input_patterns_c_mac[transaction_cnt_mac-PIPELINE_MAC_STAGE_CNT]), res_mac_b, res_mac_actual);
        `filt_end
      end
    end else begin 
      `verb_filt(VER_LOW)
      $display("Time: %t  Testing of fp mac is complete, total of %d input pattern pairs were tested.\n Maximal relative signed error in percent is: %f\n",$time, transaction_cnt_mac, res_mac_error_max);
      `filt_end
      wait(0);
    end
  end
end

//-------------------------------------------------------------
//FP TANH - stimulus generation and monitor---------------------
//-------------------------------------------------------------

logic [FP_WORD_WDT-1:0] op_tanh;
logic [FP_WORD_WDT-1:0] res_tanh;

logic [FP_WORD_WDT-1:0] input_patterns_tanh[MAX_TANH_TRANS_CNT-1:0];

real op_tanh_b;
real res_tanh_b;
real res_tanh_actual;
real res_tanh_error;
real res_tanh_error_max;
real res_tanh_mse = 0.0;

// Instantiate the DUT
fp_tanh dut_tanh
( .op_tanh(op_tanh), 
  .clk(clk), 
  .rst_n(rst_n),
  .clk_en(clk_en),  
  .res_tanh(res_tanh)
  );

// initial block
initial begin
  for(int i = 0; i < MAX_TANH_TRANS_CNT; i++) begin 
      input_patterns_tanh[i] = i;
  end   
end

//fp tanh stimulus generation
always_ff @(posedge clk) begin
  if(!rst_n) begin
      op_tanh <= '0;
  end else begin
      if(start_tanh) begin
        if(transaction_cnt_tanh < MAX_TANH_TRANS_CNT) begin
          op_tanh <= input_patterns_tanh[transaction_cnt_tanh];
          transaction_cnt_tanh <= transaction_cnt_tanh+1;
        end else begin //stop providing stimulus
          halt_tanh <= 1;
          wait(0);
        end
      end
  end
end

//fp tanh monitor
always_ff @(posedge clk) begin
  if(start_tanh) begin
    if(transaction_cnt_tanh < MAX_TANH_TRANS_CNT) begin
      op_tanh_b = fp_2_real(op_tanh);
      res_tanh_b  = fp_2_real(res_tanh);
      res_tanh_actual = $tanh(fp_2_real(input_patterns_tanh[transaction_cnt_tanh-PIPELINE_TANH_STAGE_CNT]));

      if(transaction_cnt_tanh > PIPELINE_TANH_STAGE_CNT-1) begin

        `verb_filt(VER_HIGH)
        $display("Time: %t  Input: %f, Result = %f\n",$time, fp_2_real(input_patterns_tanh[transaction_cnt_tanh-PIPELINE_TANH_STAGE_CNT]), res_tanh_b);
        `filt_end

        res_tanh_error = 100.0*(res_tanh_actual - res_tanh_b)/res_tanh_actual;
        res_tanh_mse = (res_tanh_actual - res_tanh_b)**2 + res_tanh_mse;

        `verb_filt(VER_HIGH)
        $display("Time: %t  Relative signed error in percent is %f\n",$time, res_tanh_error);
        `filt_end

        if(abs_r(res_tanh_error) > abs_r(res_tanh_error_max))
          res_tanh_error_max = res_tanh_error;

      end
    end else begin 
      res_tanh_mse = res_tanh_mse/MAX_TANH_TRANS_CNT;
      `verb_filt(VER_LOW)
      $display("Time: %t  Testing of fp tanh is complete, total of %d input pattern pairs were tested.\n Maximal relative signed error in percent is: %.8ff, MSE is %.8f\n",$time, transaction_cnt_tanh, res_tanh_error_max, res_tanh_mse);
      `filt_end
      wait(0);
    end
  end
end


endmodule