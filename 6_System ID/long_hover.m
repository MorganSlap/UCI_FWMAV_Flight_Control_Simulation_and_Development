%% longitudinal hover
clc;
start = 0;
final = size(pitch_rate);
final = final(1)-1;

sampling_time = 493; %us seconds
samping_rate = 1/(sampling_time*1e-6); % hz
Ts = sampling_time*1e-6; % seconds

time = start:final;
time = time * sampling_time* 1e-6; % 493 us is the sample index of beta flight
%% flight data importing
filename = 'flight 4-10-26 Blackbox Data.xlsx';
gyro_data = readmatrix(filename,'Range','V2:X31949');

setpoint_data = readmatrix(filename,'Range','P2:S31949');

motor_data = readmatrix(filename, 'Range','AE2:AH31949');

pitching_data = readmatrix(filename, 'Range','AR2:AR31949');

pitch_rate = gyro_data(:,2); 
roll_rate = gyro_data(:,1);
yaw_rate = gyro_data(:,3);

pitch_setpoint = setpoint_data(:,2); 
roll_setpoint = setpoint_data(:,1);

%% state space creation
% just looking at longitudinal dynamics
g = 9.81;

Mq = -0.069175;
Lp = -0.069175;
Zw = -0.396042;
Xu = -0.322571;
Yv = -0.322571;
Nr = -0.007774;

m   = 0.110;        % [kg] mass
I = (1/(1000^3))*[1.94e6 0 0; 0  1.95e6 0; 0 0 3.78e6]; % inertia kg*m^2
Ix  = I(1,1);      % [kg*m^2] inertia about body x
Iy  = I(2,2);      % [kg*m^2] inertia about body y
Iz  = I(3,3);      % [kg*m^2] inertia about body z

Xw = 0;
U0 = 0;
Zu = 0;
Mw = 0;
Mu = 0;

A_long = zeros(4,4);

A_long(1,1) = Xu/m; 
A_long(1,2) = Xw/m;
A_long(1,4) = -g;

A_long(2,1) = Zu/m; 
A_long(2,2) = Zw/m;
A_long(2,3) = U0;

A_long(3,1) = Mu; 
A_long(3,2) = Mw;
A_long(3,3) = Mq/Iy;

A_long(4,1) = 0; 
A_long(4,2) = 0; 
A_long(4,3) = 1; 
A_long(4,4) = 0;

B_long =[0, 0, 0, 0
        -0.0042, -0.0042, -0.0042, -0.0042
         0.0258, 0, -0.0258, 0
         0, 0, 0, 0];
% collapsed the B matrix to use the commands

B_pitch = B_long(:,1) - B_long(:,3);

C_q = [0 0 1 0];

D = 0;

%% closed loop transfer function

[num,den] = ss2tf(A_long, B_pitch,C_q,D);

G_pitch = tf(num,den);

s = tf('s');

Kp = 20;   % replace with Betaflight pitch P
Ki = 0;   % start with 0 first
Kd = 0;   % add later

% so im not super about the units for setpoint but without scaling the 
% response is super small, w/ the scale its matches
kscale = 60; 


C = kscale*(Kp + Ki/s + Kd*s);

T = feedback(C * G_pitch,1);

%% Q dynamics only

A_q = A_long([1,2,3], [1,2,3]);
B_q = B_pitch([1,2,3],:);
C_q = [0 0 1];
D_q = 0;

[num,den] = ss2tf(A_q,B_q,C_q,D_q);
Gq_pitch = tf(num,den); 
T_q = feedback(C*Gq_pitch,1);


%% flight sim

q_sim = lsim(T,pitch_setpoint, time);

Fs = samping_rate;   % sampling frequency
y_filt = lowpass(pitch_rate, 20, Fs);

figure
plot(time, y_filt);
hold on
plot(time,q_sim,'r')
legend('measured q (filtered)','simulated_q','setpoint')
xlabel('time (s)')
ylabel('pitch rate (deg/s)')
title('pitch rate vs time')

% q pitch

qsolo_sim = lsim(T_q,pitch_setpoint, time);

figure
plot(time, y_filt);
hold on
plot(time,qsolo_sim,'r')
legend('measured q (filtered)','simulated_q')
xlabel('time (s)')
ylabel('pitch rate (deg/s)')
title('pitch rate vs time (q only)')

% use the pole command to check the poles of the different transfer
% functions
a = 100* abs((36.5-40)/40);

fprintf('percent error of the clossest pole is %f\n ',a)

%%

c_filt = lowpass(pitching_data,20,Fs);
qcontrol_sim = lsim(T_q,c_filt, time);

figure
plot(time, y_filt);
hold on
plot(time,qcontrol_sim,'r')
legend('measured q (filtered)','simulated_q')
xlabel('time (s)')
ylabel('pitch rate (deg/s)')
title('pitch rate vs time (c_input)')


