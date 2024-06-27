%%
stat = initStat();

%%
stat = flushNN22(stat);
uploadToRAM(stat.s, stat.rama, 'a', false);
uploadToRAM(stat.s, stat.ramb, 'b', false);


%%

fw1 = serialport('COM4',115200);
fw2 = serialport('COM3',115200);
