%% script to generate input (time domain) and output data (frequency domain) for the testbench

size_of_fft = 2^12;
max_val = 2^7-1;
N_testcase = 3;
TD = nan(size_of_fft, N_testcase);
FD = nan(size_of_fft, N_testcase);

if log2(size_of_fft) ~= round(log2(size_of_fft))
    printf("Invalid N of samples, must be power of 2\n"); 
end

%% define the input data, each line in file is one time domain vector
x = (1:size_of_fft).';

TD(:,1) = max_val*ones(size_of_fft, 1) + 0*1i;
FD(:,1) = fft(TD(:,1));

TD(:,2) = max_val*cos(2*pi*x/20) + 0*1i;
FD(:,2) = fft(TD(:,2));

TD(:,3) = max_val*(cos(2*pi*x/20) + 1i*sin(2*pi*x/20));
FD(:,3) = fft(TD(:,3));

%% write the testcases to file

% Open the files in write mode
fileID_in = fopen('../sim/fft_tb_data_input.txt', 'wt');
fileID_out = fopen('../sim/fft_tb_data_output.txt', 'wt');

for i = 1:N_testcase
    % Extract the real and imaginary parts of the complex vector
    real_part_in = real(TD(:,i));
    imaginary_part_in = imag(TD(:,i));

    real_part_out = real(FD(:,i));
    imaginary_part_out = imag(FD(:,i));

    % Combine real and imaginary parts into a single row vector
    combined_data_in = [real_part_in, imaginary_part_in];
    combined_data_out = [real_part_out, imaginary_part_out];

    % Write the contents of the combined_data vector to the file in the desired format
    for j = 1:size_of_fft
        fprintf(fileID_in, '%f %f ', combined_data_in(j, 1), combined_data_in(j, 2));
        fprintf(fileID_out, '%f %f ', combined_data_out(j, 1), combined_data_out(j, 2));
    end
    

    fprintf(fileID_in, '\n');
    fprintf(fileID_out, '\n');

end

% Close the files
fclose(fileID_in);
fclose(fileID_out);
