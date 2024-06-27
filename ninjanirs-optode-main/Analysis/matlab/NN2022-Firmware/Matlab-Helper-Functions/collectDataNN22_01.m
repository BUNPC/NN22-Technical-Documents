% Matlab helper functions for NN22_ControlBoard00
% 
% Initial version: 2023-1-4
% Bernhard Zimmermann - bzim@bu.edu
% Boston University Neurophotonics Center

function [A, Acc, Aux, Accstat, stat] = collectDataNN22_01(stat, ns)

N_DET_PER_BOARD = 8;
N_BYTES_PER_DET = 3;

N_BYTES_TO_READ_PER_DETB = N_DET_PER_BOARD*N_BYTES_PER_DET + 4;
N_BYTES_TO_READ_PER_DETB_STATUS = 18;
N_BYTES_TO_READ_PER_HEADER = 3;
N_BYTES_TO_READ_PER_ACCELEROMETER = 3+7*2+1;
N_BYTES_TO_READ_PER_ACCELEROMETER_STATUS = 20;
N_AUX_ADC = 2;
N_BYTES_PER_AUX = 3;
N_BYTES_TO_READ_PER_AUX = 2+N_BYTES_PER_AUX*N_AUX_ADC;

N_BYTES_TO_READ_PER_CYCLE = N_BYTES_TO_READ_PER_HEADER + N_BYTES_TO_READ_PER_DETB*stat.n_detb_active ...
    + stat.acc_active*N_BYTES_TO_READ_PER_ACCELEROMETER + stat.aux_active*N_BYTES_TO_READ_PER_AUX;

if nargin >= 2
    N_SAMPLES_TO_READ = ns;
else
    N_SAMPLES_TO_READ = 500;
end


OFFSET_ARRAY = 0:N_BYTES_TO_READ_PER_DETB:((stat.n_detb_active-1)*N_BYTES_TO_READ_PER_DETB);
OFFSET_ARRAY_RES = OFFSET_ARRAY + (0:N_BYTES_PER_DET:((N_DET_PER_BOARD-1)*N_BYTES_PER_DET))';
OFFSET_ARRAY_RES = OFFSET_ARRAY_RES(:)';


detsmpcnt = 0;
statecnt = 0;
smpcnt = 1;

A = zeros(N_SAMPLES_TO_READ, stat.nstates, stat.n_detb_active*N_DET_PER_BOARD);
Acc = zeros(N_SAMPLES_TO_READ, stat.nstates, 7);
Aux = zeros(N_SAMPLES_TO_READ, stat.nstates, 1+N_AUX_ADC);
Accstat = zeros(N_SAMPLES_TO_READ, 3);

% Reset program counters 
stat.s.flush();
stat.rst_pca = true;
% stat.rst_detb = true; % not necessary with new FW version
stat = updateStatReg(stat);

% Run
stat.rst_pca = false;
stat.rst_detb = false;
stat = updateStatReg(stat);
pause(0.1);
stat.run = true;
stat = updateStatReg(stat);

if ~stat.rama(statecnt+1,22) % status packet
    % discard first result (not valid)
    read(stat.s, N_BYTES_TO_READ_PER_CYCLE, 'uint8');
end

while smpcnt <= N_SAMPLES_TO_READ
    
    % read and check sample header sent by FPGA
    raw = read(stat.s, N_BYTES_TO_READ_PER_HEADER, 'uint8');
    if raw(1) ~= 254
        disp('Sample header error');
    end
    statecnt_rd = (raw(2)+raw(3)*256);
    if statecnt_rd ~= mod(statecnt+1, stat.nstates+stat.nstatusstates)
        disp(['State count error. rd=' num2str(statecnt_rd) ' ex=' num2str(mod(statecnt+1, stat.nstates+stat.nstatusstates))]);
    end
    statecnt = statecnt_rd;

    % read the auxiliary data if active
    if stat.aux_active
        raw = read(stat.s, N_BYTES_TO_READ_PER_AUX, 'uint8');
        if raw(1) ~= 250
            disp('Aux header error');
        end
        % store aux digital inputs
        Aux(smpcnt,1+mod(statecnt-1,stat.nstates),1) = raw(2);
        % calculate aux analog input voltages
        valaux = zeros(1,N_AUX_ADC);
        for ii = 1:N_BYTES_PER_DET
            valaux = valaux + 256^(ii-1)*raw((ii+2):N_BYTES_PER_AUX:end);
        end
        % store the analog data
        Aux(smpcnt,1+mod(statecnt-1,stat.nstates),2:end) = valaux.*3.3/(stat.n_smp+1)/((2^12)-1); 
    end

    if stat.n_detb_active>0 && stat.rama(statecnt+1,22) % status packet
        raw = read(stat.s, N_BYTES_TO_READ_PER_DETB_STATUS*stat.n_detb_active, 'uint8');
    elseif stat.n_detb_active>0 % data packet
        % read, check and store data sent by detector boards
        raw = read(stat.s, N_BYTES_TO_READ_PER_DETB*stat.n_detb_active, 'uint8');
        if any(raw(1+OFFSET_ARRAY) ~= 253)
            disp('Det board header 1 error');
        end
        if any(raw(2+OFFSET_ARRAY) ~= 252)
            disp('Det board header 2 error');
        end
        if any(raw(3+OFFSET_ARRAY) ~= mod(detsmpcnt+1, 256)) && smpcnt ~= 1
            disp('Det board sample counter error');
        end
        detsmpcnt = raw(3);
        val = zeros(1,stat.n_detb_active*N_DET_PER_BOARD);
        for ii = 1:N_BYTES_PER_DET
            val = val + 256^(ii-1)*raw(3 + ii + OFFSET_ARRAY_RES);
        end
        % two's complement conversion & inversion so that we normally have 
        % positive numbers
        val = (val > 2^23-1).*2^24 - val;
        
        % store the result
        % (scaling from 0 to 1, where 1 is ADC full scale, which is slightly
        % larger than detector full scale)
        % (to convert to Volts, multiply with 8.2*2.5=20.5)
        A(smpcnt,1+mod(statecnt-1,stat.nstates),:) = val./stat.n_smp/((2^15)-1);
    end

    % read accelerometer / IMU data if active
    if stat.rama(statecnt+1,22) % status packet
        raw = read(stat.s, N_BYTES_TO_READ_PER_ACCELEROMETER_STATUS, 'uint8');
        if raw(1) ~= 237
            disp('Accel status header 1 error');
        end
        if raw(2) ~= 236
            disp('Accel status header 2 error');
        end
        % to-do: check accel sample number raw(3) for missing samples
        % to-do: read unique ID
        % to-do: read temperature
        Accstat(smpcnt, 2) = (raw(16) + 256*raw(17)) /2^12*3.3*(10+47)/10;
        % to-do: read acc connected
        
    elseif stat.acc_active
        raw = read(stat.s, N_BYTES_TO_READ_PER_ACCELEROMETER, 'uint8');
        if raw(1) ~= 249
            disp('Accel header 1 error');
        end
        if raw(2) ~= 248
            disp('Accel header 2 error');
        end
        % to-do: check accel sample number raw(3) for missing samples
        valacc = raw(4:2:(end-1)) + 256.*raw(5:2:(end-1));
        % two's complement conversion
        valacc = valacc - (valacc > 2^15-1).*2^16;

        % apply scaling
        valacc(1) = valacc(1)/256 + 25; % Temperature
        valacc(2:4) = valacc(2:4)*stat.gyrofs./(2^15-1);
        valacc(5:7) = valacc(5:7)*stat.accfs./(2^15-1);
        
        % store the data
        Acc(smpcnt,1+mod(statecnt-1,stat.nstates),:) = valacc;
    end
    
    if statecnt == 0
        smpcnt = smpcnt +1;
    end
end

stat.run = false;
stat = updateStatReg(stat);
pause(0.025);



