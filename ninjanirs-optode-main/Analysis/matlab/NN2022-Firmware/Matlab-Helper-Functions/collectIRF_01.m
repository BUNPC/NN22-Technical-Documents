% Matlab helper functions for NN22_ControlBoard00
% 
% Initial version: 2023-2-14
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center

function [ym, ys, t, stat] = collectIRF_01(stat)

DET_N = 1;

spos_set = 2:5:960;
n_smp_per_spos = 100;

t = zeros(1,length(spos_set)*2);
ym = zeros(1,length(t));
ys = zeros(1,length(t));

% main clock divider
% determines period of 'B' state
stat.clk_div = 24;
t_bstate = stat.clk_div*8/96e6;

% RAM A
stat.rama = zeros(1024,32);
% We only need one on and one off state for this
stat.rama(1,1:3) = bitget(0,1:3); % select LED row
stat.rama(1,6) = 1; % select LED column
stat.rama(1,19:21) = bitget(1,1:3); % power level med

stat.rama((stat.nstates+0):end,27) = 1; % mark sequence end

uploadToRAM(stat.s, stat.rama, 'a', false);
stat.nstatusstates = 0;

for is = 1:length(spos_set)

    disp(['Sampling position ' num2str(spos_set(is))]);
    stat.ramb = genSingleSampleRAMB(spos_set(is));
    uploadToRAM(stat.s, stat.ramb, 'b', true);
    [A, Acc, Aux, Accstat, stat] = collectDataNN22_01(stat,n_smp_per_spos);

    % get on state samples
    t(is) = spos_set(is)*t_bstate;
    ym(:,is) = mean(A(:,1,DET_N));
    ys(:,is) = std(A(:,1,DET_N));
    % get off state samples
    t(is+length(spos_set)) = (spos_set(is)+1000)*t_bstate;
    ym(:,is+length(spos_set)) = mean(A(:,2,DET_N));
    ys(:,is+length(spos_set)) = std(A(:,2,DET_N));
end 



function ramb = genSingleSampleRAMB(spos)
% Generate RAM B contents to sample only at a single timepoint specified by
% spos
%
% Initial version: 2023-2-14
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center

ramb = zeros(1024,32);

n_state_b = 1000; % number of used RAM B states
n_detb = 16; % number of detector boards
n_end_cyc = 10; %  end cycle pulse period in # of RAM B states
n_bsel_holdoff = 1; % holdoff between different selected detector board uart transmissions

if spos < 2 || spos >= (n_state_b-3*n_end_cyc)
    disp("spos out of range, will result in invalid results");
end

% write end cycle bits
ramb((n_state_b-n_end_cyc):n_state_b,9) = 1; 

% write adc sampling bits
% ADC has 1 sample latency; first bit triggers sampling, second reads out
% sample
ramb(spos, 10) = 1;
ramb(n_state_b-2*n_end_cyc, 10) = 1;


% data transmission management
ni_bsel = 60;
si = 3;
ramb(si-1,8) = 1; % transmit program counter A
for ii = 1:n_detb
    ramb(si:(si+ni_bsel-1), 1:4) = repmat(bitget(ii-1, 1:4 ,'uint8'),ni_bsel,1);
    ramb((si+2):(si+ni_bsel-1), 6) = 1;
    si = si + ni_bsel + n_bsel_holdoff;
end

ramb(n_state_b:end,18) = 1; % mark sequence end
