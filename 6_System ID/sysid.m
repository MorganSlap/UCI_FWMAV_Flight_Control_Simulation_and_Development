%% tom foollery

clc; close all;

filename = 'flight 4-10-26 Blackbox Data.xlsx';
gyro_data = readmatrix(filename,'Range','V2:X31949');

% theoretical output for the "torque" 
setpoint_data = readmatrix(filename,'Range','P2:S31949');

motor_data = readmatrix(filename, 'Range','AE2:AH31949');

% this is the summed "torque" that the controller spits out. not too sure
% about the units unfortunately
pitching_data = readmatrix(filename, 'Range','AR2:AR31949');

pitch_rate = gyro_data(:,2); 
roll_rate = gyro_data(:,1);
yaw_rate = gyro_data(:,3);

pitch_setpoint = setpoint_data(:,2); 
roll_setpoint = setpoint_data(:,1);
%% time scale + sampling rate

start = 0;
final = size(pitch_rate);
final = final(1)-1;

sampling_time = 493;                   %us seconds
samping_rate = 1/(sampling_time*1e-6); % hz
Ts = sampling_time*1e-6; % seconds

time = start:final;
time = time * sampling_time* 1e-6; % 493 us is the sample index of beta flight



%% plots
% these are the periods where the flight starts to do some swing maneuvers
chops = [4.64,5.6,6.8,8.5,8.7,9.8];

figure
plot(time, pitch_rate);
xlabel('time (s)')
ylabel('pitch rate (deg/s)')
title('pitch rate vs time (Unfiltered)')
hold on 
for i = 1:3
    xline(chops(2*i-1), '--r', 'LineWidth', 2,'Label','section start') 
    xline(chops(2*i), '--r', 'LineWidth', 2,'Label','section end')
end
hold off

% plot of setpoint during the flight

% figure
% plot(time, pitch_setpoint);
% xlabel('time (s)')
% ylabel('setpoint')
% title('pitch setpoint vs time')
% hold on 
% for i = 1:3
%     xline(chops(2*i-1), '--r', 'LineWidth', 2,'Label','section start') 
%     xline(chops(2*i), '--r', 'LineWidth', 2,'Label','section end')
% end
% hold off

% plot of the torque output over the flight time
figure
plot(time, pitching_data);
xlabel('time (s)')
ylabel('control output')
title('control output vs time')
hold on 
plot(time,pitch_setpoint,'r')
legend('control output','setpoint','','','','','','')
for i = 1:3
    xline(chops(2*i-1), '--k', 'LineWidth', 2,'Label','maneuver start') 
    xline(chops(2*i), '--k', 'LineWidth', 2,'Label','maneuver end')
end

hold off

%% ================================================================= %%
% left over code from initial data assessment
% =================================================================== %
% figure
% plot(time, roll_setpoint);
% xlabel('time (us)')
% ylabel('setpoint')
% title('roll setpoint vs time')

% figure
% plot(time, motor_data(:,1));
% hold on 
% plot(time, motor_data(:,2));
% plot(time, motor_data(:,3));
% plot(time, motor_data(:,4));
% xlabel('time (us)')
% ylabel('motor output')
% legend('motor 0','motor 1','motor 2','motor 3')
%%

%% filtering

% data recorded from the black box was kinda noise so i filtered it to the
% frequency of the wings

Fs = samping_rate;   % sampling frequency
y_filt = lowpass(pitch_rate, 20, Fs);

figure
plot(time, y_filt);
xlabel('time (s)')
ylabel('pitch rate (deg/s)')
title('pitch rate vs time (Filtered)')

c_filt = lowpass(pitching_data,20,Fs);
figure
plot(time,c_filt)
xlabel('time (s)')
ylabel('control input')
title('control vs time (filtered)')

%% segmentation of data

% choose segment
idx = time > chops(1) & time < chops(2);
p_seg1 = pitch_setpoint(idx);
u_seg1 = c_filt(idx);
y_seg1 = y_filt(idx);

idx = time > chops(3) & time < chops(4);
p_seg2 = pitch_setpoint(idx);
u_seg2 = c_filt(idx);
y_seg2 = y_filt(idx);

idx = time > chops(5) & time < chops(6);
p_seg3 = pitch_setpoint(idx);
u_seg3 = c_filt(idx);
y_seg3 = y_filt(idx);

% part 1

% I used detrend in an earlier version to further filter the data but I was
% worried thaht it was remocing to much dynamics but i forgot to remove the
% name

p1_detrend = p_seg1;
u1_detrend = u_seg1;
y1_detrend = y_seg1;

% data_set  = iddata(y1_detrend,p1_detrend,Ts);



data_axis = iddata(y1_detrend,u1_detrend,Ts);

% ID with a second order transfer function

% sys_set  = ssest(data_set,2);
sys_axis = ssest(data_axis,2);
%
% figure 
% compare(data_set,sys_set)

figure
compare(data_axis,sys_axis)

% these were attempts of the yaw and pitch
% part 2

u2_detrend = u_seg2;
y2_detrend = y_seg2;

data_axis2 = iddata(y2_detrend,u2_detrend,Ts);

sys_axis = ssest(data_axis2,2);

%part 3

u3_detrend = u_seg3;
y3_detrend = y_seg3;

data_axis3 = iddata(y3_detrend,u3_detrend,Ts);

sys_axis3 = ssest(data_axis3,3);

%% comparing different order fits
% this is pitching moment

sys1 = ssest(data_axis,1);
sys2 = ssest(data_axis,2);
sys3 = ssest(data_axis,3);

figure
compare(data_axis,sys1,sys2,sys3)



sys_region2 = ssest(data_axis2,2);

sys_region3 = ssest(data_axis3,2);

figure
compare(data_axis2,sys_region2)

figure
compare(data_axis3,sys_region3)

% just a check of stability
pzmap(sys2)
grid on
