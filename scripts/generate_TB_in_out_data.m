%% script to generate input (time domain) and output data (frequency domain) for the testbench

size_of_fft = 2^12;
max_val = 2^7-1;

if log2(size_of_fft) ~= round(log2(size_of_fft))
    printf("Invalid N of samples, must be power of 2\n"); 
end

%% define the input data, each line in file is one time domain vector
x = 1:size_of_fft;

td_1 = max_val*cos(2*pi*x/20);

fd_1 = fft(td_1);