

meanA = zeros(1,8);

for ipl = 1:8
    stat.rama(1,19:21) = bitget(ipl-1,1:3);
    uploadToRAM(stat.s, stat.rama, 'a', false);
    [A, ~, ~, ~, stat] = collectDataNN22_01(stat,400); 
    meanA(ipl) = mean(squeeze(A(:,1,1)-A(:,2,1)));
end

plot(0:7,meanA,'bo');

xlabel('LED power level');
ylabel('Offset (normalized NN22 sig lvl)');


% for saftey set power level back to small
stat.rama(1,19:21) = bitget(1,1:3);
uploadToRAM(stat.s, stat.rama, 'a', false);
    