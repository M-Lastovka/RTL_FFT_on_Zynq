%% script to generate a twiddle factor ROM for FPGA implementation

size_of_fft = 2^3;
dft_wdt = 48;
scale_const_log2 = dft_wdt/2-1; %determines how many bits to the left do we shift the twiddle factors
block_wdt = 4;         %number of twiddle factors per line

if log2(size_of_fft) ~= round(log2(size_of_fft))
    printf("Invalid N of samples, must be power of 2\n"); 
end
    
if mod(32,2) ~= 0
    printf("Sample size must be even\n");
end
    
if scale_const_log2 > dft_wdt/2
    printf("Invalid scale_const_log2 value\n");
end

    
%%generate twiddle factor LUT
    
    fileID = fopen(strcat('fft_twiddle_LUT',string(log2(size_of_fft)),'_',string(dft_wdt/2),'b.vhd'), 'w');

    %function definition
    temp = '';
    temp = strcat(temp, '----------------------------------------------------------------------------------\n');
    temp = strcat(temp, '-- Create Date: 08/17/2021 05:27:38 PM:\n');
    temp = strcat(temp, '-- Module Name: fft_twiddle_LUT - rtl\n');
    temp = strcat(temp, '-- Description: LUT for roots of unity, a.k.a twiddle factors\n');
    temp = strcat(temp, '-- Dependencies: dig_top_pckg \n');
    temp = strcat(temp, '-- Additional Comments: This code is auto-generated, do NOT edit manually! \n');
    temp = strcat(temp, '----------------------------------------------------------------------------------\n\n\n');
    
    temp = strcat(temp, 'LIBRARY IEEE;\n');
    temp = strcat(temp, 'USE IEEE.STD_LOGIC_1164.ALL;\n');
    temp = strcat(temp, 'use IEEE.NUMERIC_STD.ALL;\n');
    temp = strcat(temp, 'LIBRARY xil_defaultlib;\n');
    temp = strcat(temp, 'USE xil_defaultlib.dig_top_pckg.ALL;\n\n\n');
    
    temp = strcat(temp, 'ENTITY fft_twiddle_LUT IS\n');
    temp = strcat(temp, '    PORT (\n');
    temp = strcat(temp, '           sys_clk_in     : IN  std_logic;\n');
    temp = strcat(temp, '           addr_twiddle   : IN  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);\n');
    temp = strcat(temp, '           twiddle_en     : IN  std_logic;\n');
    temp = strcat(temp, '           twiddle_re     : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);\n');
    temp = strcat(temp, '           twiddle_im     : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0)\n');
    temp = strcat(temp, '           );\n');
    temp = strcat(temp, 'END fft_twiddle_LUT;\n\n\n');
    
    temp = strcat(temp, 'ARCHITECTURE rtl OF fft_twiddle_LUT IS\n\n');
    temp = strcat(temp, 'TYPE lut_mem_space IS ARRAY (0 TO 2**(C_FFT_SIZE_LOG2-1)-1) OF std_logic_vector(C_DFT_WDT-1 DOWNTO 0);\n');
    temp = strcat(temp, 'CONSTANT C_TWIDDLE_LUT : lut_mem_space := (\n  ');
    
    fprintf(fileID, temp);
    temp = '';
    
    break_index = 0;
    temp_re = 0;
    temp_im = 0;
    temp_re_bin = 0;
    temp_im_bin = 0;
    padding_str = '0';
    
    for index = 1:size_of_fft/2 
        break_index = break_index + 1;
        
        %real part
        temp_re = (real(exp((-1i*2*pi()/size_of_fft)*(index-1))))*2^(scale_const_log2-1);        
        %check and sign adjust
        if temp_re >= 0
            %no need to change
            temp_re_bin = dec2bin(floor(temp_re));
            temp_re_bin = strcat('0',temp_re_bin);
            padding_str = '0';
        else
            %do 2's complement
            temp_re_bin = dec2bin(floor(abs(temp_re)));
            temp_re_bin = strcat('0',temp_re_bin);
            padding_str = '1';
            c1=not(temp_re_bin-'0');   % one's complement
            c2=false;
            inc=true;
            for k=numel(c1):-1:1
              c2(1,k)=xor(inc,c1(k));  % c2 is two's complement
              carry=inc & c1(k);
              inc=carry;              
            end
            temp_re_bin = char(c2+'0');
        end
        
        %sign extension
        temp_re_bin = strcat(repmat(padding_str,1,dft_wdt/2 - length(temp_re_bin)), temp_re_bin);
        
        %imaginary part
        temp_im = (imag(exp((-1i*2*pi()/size_of_fft)*(index-1))))*2^(scale_const_log2-1);        
        %check and sign adjust
        if temp_im >= 0
            %no need to change
            temp_im_bin = dec2bin(floor(temp_im));
            temp_im_bin = strcat('0',temp_im_bin);
            padding_str = '0';
        else
            %do 2's complement
            temp_im_bin = dec2bin(floor(abs(temp_im)));
            temp_im_bin = strcat('0',temp_im_bin);
            padding_str = '1';
            c1=not(temp_im_bin-'0');   % one's complement
            c2=false;
            inc=true;
            for k=numel(c1):-1:1
              c2(1,k)=xor(inc,c1(k));  % c2 is two's complement
              carry=inc & c1(k);
              inc=carry;              
            end
            temp_im_bin = char(c2+'0');
        end
        
        %sign extension
        temp_im_bin = strcat(repmat(padding_str,1,dft_wdt/2 - length(temp_im_bin)), temp_im_bin);
        
        if index == size_of_fft/2
            fprintf(fileID, strcat('"',temp_re_bin,temp_im_bin,'" '));
        else
            fprintf(fileID, strcat('"',temp_re_bin,temp_im_bin,'", '));
        end
        
        if  break_index == block_wdt
            fprintf(fileID,'\n');   %so that it looks more block-like
            break_index = 0;
        end
    end
    
    temp = strcat(temp, ');\n');
    temp = strcat(temp, 'BEGIN\n\n');
    temp = strcat(temp, 'rom_proc : PROCESS(sys_clk_in)\n');
    temp = strcat(temp, 'BEGIN\n\n');
    temp = strcat(temp, 'IF (rising_edge(sys_clk_in)) THEN\n');
    temp = strcat(temp,'  IF (twiddle_en = ''1'') THEN\n');
    temp = strcat(temp,'    twiddle_re <= C_TWIDDLE_LUT(to_integer(unsigned(addr_twiddle)))(C_DFT_WDT-1 DOWNTO C_DFT_WDT/2);\n');
    temp = strcat(temp,'    twiddle_im <= C_TWIDDLE_LUT(to_integer(unsigned(addr_twiddle)))(C_DFT_WDT/2-1 DOWNTO 0);\n');
    temp = strcat(temp,'  END IF;\n');
    temp = strcat(temp,'END IF;\n\n');
    temp = strcat(temp, 'END PROCESS rom_proc;\n\n');
    temp = strcat(temp, 'END rtl;\n');
    
    fprintf(fileID, temp);
    fclose(fileID);
    
    
