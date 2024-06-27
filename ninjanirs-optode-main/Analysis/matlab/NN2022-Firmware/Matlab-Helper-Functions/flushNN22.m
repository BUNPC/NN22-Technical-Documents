% Matlab helper functions for NN22_ControlBoard00
% 
% Initial version: 2023-3-4
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center
%
% This function will flush serial data from all microcontrollers and the
% FPGA

function stat = flushNN22(stat)


% make sure system is not running
stat.run = false;
stat = updateStatReg(stat);
pause(0.1);

% Reset program counters 
stat.s.flush();
stat.rst_pca = true;
stat.rst_detb = ones(1,4);
stat.rst_ram = true; % reset external ram
stat = updateStatReg(stat);

pause(0.1);
stat.rst_pca = false;
stat.rst_ram = false;
for ii = 1:4
    stat.rst_detb(ii) = 0;
    stat = updateStatReg(stat);
    pause(0.5);
end
pause(0.5);

% Redundant: also run a bit without sampling
% (flush data out of tx buffers in all microcontrollers)
ramb_tmp = stat.ramb;
ramb_tmp(:,[9 10]) = 0; % reprog RAM B
uploadToRAM(stat.s, ramb_tmp, 'b', false);
stat.run = true;
stat = updateStatReg(stat);
pause(0.1);
stat.run = false;
stat = updateStatReg(stat);
pause(0.1);
stat.s.flush();
pause(0.2);
stat.s.flush();

% Restore RAM B
uploadToRAM(stat.s, stat.ramb, 'b', false);
