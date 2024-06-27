% Matlab helper functions for NN22_ControlBoard00
% 
% Initial version: 2023-2-15
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center

% optical powers for cal (@760nm NIRx) for new filter wheel
pw1 = [3150 2580 2072 1744 1523 1265 1099 532 348 117 27 6.87];
pw2 = [3150 1753 1523 1266 1101 531 347 124 27.2 6.96 1.82 0.929];

% store actual ODs
set1 = log10(pw1(1)./pw1);
set2 = log10(pw2(1)./pw2);

fposset1=[1 2 4 7 9 10 12];
fposset2=[1];

clear t;
clear yms;
clear yss;
clear ods;

% reset filter wheels
fprintf(fw2,'%s\r',['pos=' num2str(fposset2(1))]);
fprintf(fw1,'%s\r',['pos=' num2str(fposset1(1))]);
pause(1);

rind = 1;

for fpos2=fposset2
    fprintf(fw2,'%s\r',['pos=' num2str(fpos2)]);
    for fpos1=fposset1
        fprintf(fw1,'%s\r',['pos=' num2str(fpos1)]);
        pause(4);

        ods(rind) = set1(fpos1) + set2(fpos2);
        disp(['fw1=' num2str(fpos1) ' fw2=' num2str(fpos2) ' od=' num2str(ods(rind))]);
        
        [ym, ys, t, stat] = collectIRF_01(stat);

        yms(rind,:) = ym;
        yss(rind,:) = ys;

        rind = rind +1;
        pause(0.1);

    end
end

%%
% save('.\meas\20230215\IRF_set_07_saturation_with_offset.mat','yms','yss','ods','stat');

%% plot it
figure(10);
plot(t,yms,'.-');
xlabel('Time [s]'); 
ylabel('Digital Level');
title('on off');
grid on;
hold on;
% legend(arrayfun(@(x) ['od=' num2str(x,2)], ods, 'UniformOutput', false));

figure(11);
plot(t(1:(length(t)/2)),yms(:,1:(length(t)/2))-yms(:,((length(t)/2)+1):end),'.-');
xlabel('Time [s]'); 
ylabel('Digital Level');
title('(on-off)');
grid on;
hold on;

figure(20);
plot(t,yss,'.-');
xlabel('Time [s]'); 
ylabel('Digital Level');
title('Std(on off)');
grid on;
hold on;

