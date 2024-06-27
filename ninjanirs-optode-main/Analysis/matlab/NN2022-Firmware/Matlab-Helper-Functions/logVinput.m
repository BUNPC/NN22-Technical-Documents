% logging battery voltage to establish charge/voltage curve

if ~exist("stat","var")
    stat = initStat();
else
    stat = initStat(stat);
end


fname = string(datetime('now','TimeZone','local','Format','yyyy-MM-dd_HHmmss'));
fname = strcat(fname, ".csv");
fid = fopen(fname,'w');

tstep = 2;
is = 1;

tic;

while is < 500
    telapsed = toc;
    if telapsed>(is*tstep)
        [~, ~, ~, Accstat, stat] = collectDataNN22_01(stat, 100);
        tn = datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm:ss.S');
        volts = mean(Accstat(2:(end-1),2));
        resstring = sprintf("%s, %5.0fs, %6.3fV\n",tn, telapsed, volts);
        fprintf(resstring);
        fprintf(fid, resstring);
        is = is+1;
    end
    pause(0.1);
end

fclose(fid);