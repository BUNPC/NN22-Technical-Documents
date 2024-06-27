%% Data adjustment for plotting
[odss, ids] = sort(ods);
amps = mean(R(ids,:),2);
ampsoff = mean(Roff(ids,:),2);
ampson = mean(Ron(ids,:),2);


%% Plotting
sigdark = sqrt(mean(amps(end-25:end).^2));
p = polyfit(odss(1:400),log10(amps(1:400)'),1)
odintersect = ((log10(sigdark)-p(2))/p(1))

figure(2);
semilogy(odss,abs(amps)-sigdark,'.');
hold on;
plot([odss(end), odintersect-0.5], sigdark.*[1 1],'Color',0.7*ones(1,3));
plot([odss(1) odintersect+0.5],[amps(1) 10^(p(1).*(odintersect+0.5)+p(2))],'Color',0.7*ones(1,3));
text(odintersect,sigdark,['\leftarrow NEP = ' num2str((pref*10^-odintersect)*1e15, 3) ' fW']);
ylabel('Digital level [a.u.]');
xlabel('Optical density');
grid on;