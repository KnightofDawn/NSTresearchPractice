%% This is a script for the Zurich Katana Robot 
%  Author:  Juri Fedjaev
%  Last modified:   04/05/17
function katana = initKatana

clear, clc, close all

%% need to explicitly specify int32 data type for python interface
min = int32(0);
max = int32(30500); 
ax1 = int32(1);
ax2 = int32(2);
ax3 = int32(3);
ax4 = int32(4);
ax5 = int32(5);
ax6 = int32(6); % axis 6 is the gripper

%% initialize SOAP object 
katana = py.KatanaSoap.KatanaSoap();

%% initialize robot arm & calibrate
katana.calibrate();
katana.moveMotAndWait(ax6, min)
katana.fakeCalibration(ax6, min)   % needed to make gripper work
%katana.fakeCalibration(ax2, 0.5*max)    % make axis 2 work in both directions
pause(10)

%% initialize working position - ports (ethernet, USB, ...) facing door
katana.moveMotAndWait(ax1, 0.5*max) % correct: choose values in range of [0.3, 0.6]
katana.moveMotAndWait(ax2, -max/2) % correct; axis 2 needs negativ values
katana.moveMotAndWait(ax3, -0.75*max) % correct; axis 3 needs negativ values   
katana.moveMotAndWait(ax4, max/3)   % correct
katana.moveMotAndWait(ax5, max)
pause(10)
%% 

