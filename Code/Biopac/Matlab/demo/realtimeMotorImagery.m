%%  real time motor imagery application for control of a katana robot
%   Author:         Juri Fedjaev
%   Last modified:  12-05-2017
%   Parameters:
%       numTrials : number of trials to execute
%       robotON : turn on/off robot control

function [retval] = realtimeMotorImagery(numTrials, robotOn)
%% get SVM model file & PCA coefficients
filename = uigetfile;
load(filename);         % 'SVMModel' is the name of the variable
addpath('disp_cue');

%% init robot and get object
addpath('katana')
katana = initKatana;


%%  Parameters for cue experiment
nCh = 3;
cueOn = 1;
T_BLANK  = 2;
T_CUE_ON = 3;
T_CUE    = 2;
T_PERIOD = 8;
DURATION = numTrials * T_PERIOD;




%% ------ initialize & set path and load library --------------------------
mptype = 103;   % 103 for MP36 device (see mpdev.h)
mpmethod = 10;  % communication type 10 for USB
sn = 'auto';    % with 'auto' the first responding MP36 device will be used
%duration = 3;  % recording duration in seconds

libname = 'mpdev';
doth = 'mpdev.h';
dll = ['C:\Program Files (x86)\BIOPAC Systems, Inc\BIOPAC Hardware API 2.2 Education\x64\mpdev.dll'];
dothdir = ['C:\Program Files (x86)\BIOPAC Systems, Inc\BIOPAC Hardware API 2.2 Education\'];

%check if the library is already loaded
if libisloaded(libname)
    calllib(libname, 'disconnectMPDev');
    unloadlibrary(libname);
end

% turn off annoying enum warnings
warning off MATLAB:loadlibrary:enumexists;

% load the biopac library
loadlibrary(dll,strcat(dothdir,doth));
fprintf(1,'\nMPDEV.DLL LOADED!!!\n');
libfunctions(libname, '-full');


%% ------------------------ start Acquisition Daemon ----------------------
% Connect
fprintf(1,'Connecting...\n');

[retval, sn] = calllib(libname,'connectMPDev',mptype,mpmethod,sn);

if ~strcmp(retval,'MPSUCCESS')
    fprintf(1,'Failed to Connect.\n');
    calllib(libname, 'disconnectMPDev');
    return
end
fprintf(1,'Connected\n');

% Configure
fprintf(1,'Setting Sample Rate to 200 Hz\n');
retval = calllib(libname, 'setSampleRate', 5.0);

if ~strcmp(retval,'MPSUCCESS')
    fprintf(1,'Failed to Set Sample Rate.\n');
    calllib(libname, 'disconnectMPDev');
    return
end

fprintf(1,'Sample Rate Set\n');


% set acquisition channels
if nCh == 2
    fprintf(1,'Setting to Acquire on Channels 1 and 2\n');
    aCH = [int32(1),int32(1),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0)];
end
if nCh == 3
    fprintf(1,'Setting to Acquire on Channels 1, 2 and 3\n');
    aCH = [int32(1),int32(1),int32(1),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0),int32(0)];
end


% if mptype is not MP150
if mptype ~= 101
    %then it must be the mp35 (102) or mp36 (103)
    if nCh == 3
        aCH = [int32(1),int32(1),int32(1),int32(0)];
    elseif nCh == 2
        aCH = [int32(1),int32(1),int32(2),int32(0)];
    end
end


[retval, aCH] = calllib(libname, 'setAcqChannels',aCH);
if ~strcmp(retval,'MPSUCCESS')
    fprintf(1,'Failed to Set Acq Channels.\n');
    calllib(libname, 'disconnectMPDev');
    return
end
fprintf(1,'Channels Set\n');

%% ------------------------------------------------------------------
% Outer while loop for number of trials

for i_trial=1:numTrials
    %% Download and Plot samples in realtime
    numRead = 0;
    numValuesToRead = 200*nCh; %collect 1 second worth of data points per iteration
    remaining = T_PERIOD*200*nCh; % collect samples with 200 Hz per Channel for #duration
    tbuff(1:numValuesToRead) = double(0); %initialize the correct amount of data
    bval = 0;
    offset = 1;
    X = 0;
    class_res = 0;
    
    % start to acquire
    fprintf(1,'Start Acquisition Daemon\n');
    retval = calllib(libname, 'startMPAcqDaemon');
    if ~strcmp(retval,'MPSUCCESS')
        fprintf(1,'Failed to Start Acquisition Daemon.\n');
        calllib(libname, 'disconnectMPDev');
        return
    end
    
    fprintf(1,'Start Acquisition for %f seconds. \n', T_PERIOD);
    retval = calllib(libname, 'startAcquisition');
    if ~strcmp(retval,'MPSUCCESS')
        fprintf(1,'Failed to Start Acquisition.\n');
        calllib(libname, 'disconnectMPDev');
        return
    end
    
    % launch timers
    CLASS = randi([0 1], 1,1); % generate random class, values 1 (right) or 0 (left cue)
    launchTimers(CLASS, DURATION, T_PERIOD, T_BLANK, T_CUE_ON, T_CUE);
    % loop until there is still some data to acquire
    tic
    while(remaining > 0)
        if numValuesToRead > remaining
            numValuesToRead = remaining;
        end
        [retval, tbuff, numRead]  = calllib(libname, 'receiveMPData',tbuff, numValuesToRead, numRead);
        if ~strcmp(retval,'MPSUCCESS')
            fprintf(1,'Failed to receive MP data.\n');
            calllib(libname, 'disconnectMPDev');
            return
        else
            buff(offset:offset+double(numRead(1))-1) = tbuff(1:double(numRead(1)));
            % Process
            len = length(buff);
            ch1data = buff(1:nCh:len);
            ch2data = buff(2:nCh:len);
            if nCh == 3
                ch3data = buff(3:nCh:len);
            end
            X(1:len) = (1:len);
            drawnow % for cue display
        end
        offset = offset + double(numValuesToRead);
        remaining = remaining-double(numValuesToRead);
    end %while-loop
    t_dur = toc;
    fprintf(1, 'Acquired data for %f seconds.\n', t_dur);
    
    % save data
    if nCh == 2
        ch1 = ch1data;
        ch2 = ch2data;
        X = [ch1', ch2'];   % merge data in Matrix X for return value
    end
    if nCh == 3
        ch1 = ch1data;
        ch2 = ch2data;
        ch3 = ch3data;
        X = [ch1', ch2', ch3'];   % merge data in Matrix X for return value
    end
    delete(timerfind)
    
    % pre-processing and apply SVM
    %     size(X)
    class_res = classifyWithSVM(X, SVMModel, pca_coeff);
    if class_res == 1
        fprintf(1,'RIGHT HAND MOTOR IMAGERY DETECTED!\n');
        fprintf(1,'MOVING ROBOT ARM TO THE RIGHT!\n');
        katanaRight(katana);
    else
        fprintf(1,'LEFT HAND MOTOR IMAGERY DETECTED!\n');
        fprintf(1,'MOVING ROBOT ARM TO THE LEFT!\n');
        katanaLeft(katana);
    end
    %     pause(5)
    katanaCenter(katana); % restore initial robot arm position
    %     pause(3)
    close all
    retval = calllib(libname, 'stopAcquisition');
    if ~strcmp(retval,'MPSUCCESS')
        fprintf(1,'Failed to Stop\n');
        calllib(libname, 'disconnectMPDev');
        return
    end
    pause(2)
    
end % end for-loop over numTrials

%% stop acquisition && unload library
fprintf(1,'Stop Acquisition\n');

retval = calllib(libname, 'stopAcquisition');
if ~strcmp(retval,'MPSUCCESS')
    fprintf(1,'Failed to Stop\n');
    calllib(libname, 'disconnectMPDev');
    return
end

% disconnect
fprintf(1,'Disconnecting...\n')
retval = calllib(libname, 'disconnectMPDev');

unloadlibrary(libname);
close all


end