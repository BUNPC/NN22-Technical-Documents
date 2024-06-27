%% RAM A

stat.rama = zeros(1024,32);
stat.nstates = 8;

% Example using only one wavelength and power setting of source 1
% Used e.g. for filter wheel tests
for ii = 1:8
    stat.rama(ii,1:3) = bitget(ii-1,1:3); % select LED row
    stat.rama(ii,10) = 1; % select LED column
    stat.rama(ii,19:21) = bitget(7,1:3); % power level med
end


%stat.rama(1,22) = 1; %transmit status during this state
stat.rama(stat.nstates:end,27) = 1; % mark sequence end