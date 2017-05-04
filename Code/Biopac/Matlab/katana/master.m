%% This is a script for the Zurich Katana Robot 
%  Author:  Juri Fedjaev
%  Last modified:   04/05/17

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
katana.fakeCalibration(int32(6),int32(0))   % needed to make gripper work

%% move arm
katana.moveMotAndWait(ax1, min+100)


