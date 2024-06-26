% Matlab helper functions for NN22_ControlBoard00
% 
% Initial version: 2023-1-2
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center

function stat = updateStatReg(stat, skipreadback)

if nargin < 2
    skipreadback = true;
end

stat.sreg = zeros(1,32);

stat.sreg(24) = stat.vn22clk_en;
stat.sreg(23) = stat.vn3p4_en;
stat.sreg(22) = stat.vn22_en;
stat.sreg(21) = stat.v9p0_en;
stat.sreg(20) = stat.v5p1src_en;
stat.sreg(19) = stat.v5p1rpi_off;
stat.sreg(18) = stat.v5p1b23_en;
stat.sreg(17) = stat.v5p1b01_en;
stat.sreg(9:16) = bitget(stat.clk_div-1, 1:8, 'uint8');
stat.sreg(7) = stat.rst_ram;
stat.sreg(6) = stat.rst_pca;
stat.sreg(2:5) = stat.rst_detb;
stat.sreg(1) = stat.run;

uploadToStatReg(stat.s, stat.sreg, skipreadback);