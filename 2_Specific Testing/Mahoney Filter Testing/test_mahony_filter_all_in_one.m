function test_mahony_filter_all_in_one(Kp,Ki)
% test_mahony_filter_all_in_one
%
% Drop this whole file into MATLAB as:
%   test_mahony_filter_all_in_one.m
%
% Then run:
%   test_mahony_filter_all_in_one
%
% This file contains:
%   1. A simple test case
%   2. The Mahony explicit complementary filter
%   3. Helper rotation functions
%
% Inputs to Mahony filter:
%   gyro  = [p; q; r] in rad/s
%   accel = [ax; ay; az] in m/s^2
%   Ts    = sample time in seconds
%
% Output:
%   eul = [roll; pitch; yaw] in radians
%
% Notes:
%   - Roll and pitch are corrected using accelerometer.
%   - Yaw is only gyro-integrated and will drift with accel-only correction.
%   - Bias estimation is enabled through Ki.

clc;
close all;
rng(1);

% Clear persistent variables inside local Mahony filter
clear mahony_explicit_accel_only_local

% -----------------------------
% Simulation settings
% -----------------------------
Ts = 0.001;        % sample time [s]
tf = 30.0;         % final time [s]
t = 0:Ts:tf;
N = length(t);

g = 9.80665;

% LPF cutoff frequency
fc =5;
alpha = 2*pi*fc*Ts/(1+2*pi*fc*Ts);

% -----------------------------
% Truth attitude trajectory
% -----------------------------
roll_truth  = deg2rad(10) * sin(2*pi*0.5*t);
pitch_truth = deg2rad(5)  * sin(2*pi*0.3*t);
yaw_truth   = deg2rad(0)  * t;

% Numerical derivatives of Euler angles
roll_dot  = gradient(roll_truth, Ts);
pitch_dot = gradient(pitch_truth, Ts);
yaw_dot   = gradient(yaw_truth, Ts);

% -----------------------------
% Storage
% -----------------------------
eul_est = zeros(3, N);
gyro_meas = zeros(3, N);
accel_meas = zeros(3, N);
b_hat_est = zeros(3, N);       % estimated gyro bias [rad/s]

% Store true biases and filtered for plotting/reference
gyro_bias_true_hist = zeros(3, N);
accel_bias_true_hist = zeros(3, N);
gyro_filt = zeros(3, N);
accel_filt = zeros(3, N);

% -----------------------------
% Main test loop
% -----------------------------
for k = 1:N
    
    phi   = roll_truth(k);
    theta = pitch_truth(k);
    psi   = yaw_truth(k);

    phi_dot   = roll_dot(k);
    theta_dot = pitch_dot(k);
    psi_dot   = yaw_dot(k);

    % Convert Euler angle rates to body rates [p; q; r]
    %
    % For 3-2-1 yaw-pitch-roll Euler angles:
    %
    % p = phi_dot - psi_dot*sin(theta)
    % q = theta_dot*cos(phi) + psi_dot*sin(phi)*cos(theta)
    % r = -theta_dot*sin(phi) + psi_dot*cos(phi)*cos(theta)

    p = phi_dot - psi_dot*sin(theta);
    q = theta_dot*cos(phi) + psi_dot*sin(phi)*cos(theta);
    r = -theta_dot*sin(phi) + psi_dot*cos(phi)*cos(theta);

    gyro = [p; q; r];

    % Rotation matrix from body to inertial/world frame
    R_B_to_I = eul321_to_R_B_to_I(phi, theta, psi);

    % Gravity vector in inertial frame.
    % This test uses positive z-down convention.
    g_inertial = [0; 0; g];

    % Ideal accelerometer measurement in body frame.
    % Level stationary accel is approximately [0; 0; +g].
    accel = R_B_to_I' * g_inertial;

    % -------------------------------------------------
    % Add sensor noise here
    % -------------------------------------------------

    % Gyro white noise standard deviation
    % Example: 0.5 deg/s converted to rad/s
    gyro_noise_std = deg2rad(0.5);

    % Accel white noise standard deviation
    % Example: 0.05 g converted to m/s^2
    accel_noise_std = 0.05 * g;

    gyro_noisy = gyro + gyro_noise_std * randn(3,1) + deg2rad(4)*sin(2*pi*25*t(k));
    accel_noisy = accel + accel_noise_std * randn(3,1) + 0.1*sin(2*pi*25*t(k));

    % -------------------------------------------------
    % Optional constant sensor biases
    % -------------------------------------------------
    % Important:
    %   - Roll/pitch gyro bias can be corrected by accel feedback.
    %   - Yaw gyro bias cannot be corrected with accel-only measurements.
    %
    % For a bias-estimation test, it is better to keep yaw bias zero first.
    % Then add yaw bias later to verify that yaw drifts as expected.

    gyro_bias = deg2rad([0.1; -0.05; 0.0]);   % rad/s
    accel_bias = 0.02 * g * [1; -0.5; 0.3];   % m/s^2

    % If you want to test yaw drift, use this instead:
    % gyro_bias = deg2rad([0.1; -0.05; 0.2]);

    gyro_noisy = gyro_noisy + gyro_bias;
    accel_noisy = accel_noisy + accel_bias;

    % Save measurements and true bias
    gyro_meas(:, k) = gyro_noisy;
    accel_meas(:, k) = accel_noisy;
    gyro_bias_true_hist(:, k) = gyro_bias;
    accel_bias_true_hist(:, k) = accel_bias;

    % -----------------------------
    % Run separate LPFs before feeding into Mahony
    % -----------------------------
    if k == 1
        gyro_prev = gyro_noisy;
        accel_prev = accel_noisy;
    end
    
    gyro_filt(:, k) = (1 - alpha)*gyro_prev + alpha*gyro_noisy;
    accel_filt(:, k) = (1 - alpha)*accel_prev + alpha*accel_noisy;
    
    gyro_prev = gyro_filt(:, k);
    accel_prev = accel_filt(:, k);

    % Run Mahony filter using noisy measurements
    [eul_est(:, k), b_hat_est(:, k)] = ...
        mahony_explicit_accel_only_local(gyro_filt(:, k), accel_filt(:, k), Ts,Kp, Ki);

end

% calac error norm
norm_error = norm(rad2deg(eul_est(1, :) - roll_truth)) + norm(rad2deg(eul_est(2, :) - pitch_truth));
%{
% -----------------------------
% Plot results
% -----------------------------
figure;
plot(t, rad2deg(roll_truth), 'LineWidth', 1.5);
hold on;
plot(t, rad2deg(eul_est(1, :)), '--', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Roll [deg]');
legend('Truth', 'Mahony Estimate');
title('Roll Estimate');

figure;
plot(t, rad2deg(pitch_truth), 'LineWidth', 1.5);
hold on;
plot(t, rad2deg(eul_est(2, :)), '--', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Pitch [deg]');
legend('Truth', 'Mahony Estimate');
title('Pitch Estimate');

figure;
plot(t, rad2deg(yaw_truth), 'LineWidth', 1.5);
hold on;
plot(t, rad2deg(eul_est(3, :)), '--', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Yaw [deg]');
legend('Truth', 'Mahony Estimate');
title('Yaw Estimate');

figure;
plot(t, rad2deg(eul_est(1, :) - roll_truth), 'LineWidth', 1.5);
hold on;
plot(t, rad2deg(eul_est(2, :) - pitch_truth), 'LineWidth', 1.5);
plot(t, rad2deg(eul_est(3, :) - yaw_truth), 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Error [deg]');
legend('Roll Error', 'Pitch Error', 'Yaw Error');
title('Mahony Attitude Error');

figure;
plot(t, gyro_meas(1, :), 'LineWidth', 1.2);
hold on;
plot(t, gyro_meas(2, :), 'LineWidth', 1.2);
plot(t, gyro_meas(3, :), 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Body Rate [rad/s]');
legend('p', 'q', 'r');
title('Generated Gyro Measurement');

figure;
plot(t, accel_meas(1, :), 'LineWidth', 1.2);
hold on;
plot(t, accel_meas(2, :), 'LineWidth', 1.2);
plot(t, accel_meas(3, :), 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Accel [m/s^2]');
legend('a_x', 'a_y', 'a_z');
title('Generated Accelerometer Measurement');

% -----------------------------
% Bias estimate plot
% -----------------------------
figure;
plot(t, rad2deg(b_hat_est(1, :)), 'LineWidth', 1.5);
hold on;
plot(t, rad2deg(b_hat_est(2, :)), 'LineWidth', 1.5);
plot(t, rad2deg(b_hat_est(3, :)), 'LineWidth', 1.5);

plot(t, rad2deg(gyro_bias_true_hist(1, :)), '--', 'LineWidth', 1.2);
plot(t, rad2deg(gyro_bias_true_hist(2, :)), '--', 'LineWidth', 1.2);
plot(t, rad2deg(gyro_bias_true_hist(3, :)), '--', 'LineWidth', 1.2);

grid on;
xlabel('Time [s]');
ylabel('Gyro Bias [deg/s]');
legend( ...
    'b_p estimate', ...
    'b_q estimate', ...
    'b_r estimate', ...
    'b_p true', ...
    'b_q true', ...
    'b_r true');
title('Mahony Estimated Gyro Bias');

% -----------------------------
% Filtered gyro measurement plot
% -----------------------------
figure;
plot(t, gyro_filt(1, :), 'LineWidth', 1.2);
hold on;
plot(t, gyro_filt(2, :), 'LineWidth', 1.2);
plot(t, gyro_filt(3, :), 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Filtered Body Rate [rad/s]');
legend('p filt', 'q filt', 'r filt');
title('Filtered Gyro Measurement');

% -----------------------------
% Filtered accelerometer measurement plot
% -----------------------------
figure;
plot(t, accel_filt(1, :), 'LineWidth', 1.2);
hold on;
plot(t, accel_filt(2, :), 'LineWidth', 1.2);
plot(t, accel_filt(3, :), 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Filtered Accel [m/s^2]');
legend('a_x filt', 'a_y filt', 'a_z filt');
title('Filtered Accelerometer Measurement');
%}
end


function [eul, b_hat_out] = mahony_explicit_accel_only_local(gyro, accel, Ts,Kp,Ki)
% mahony_explicit_accel_only_local
%
% Mahony explicit complementary filter using gyro + accelerometer only.
%
% Inputs:
%   gyro  = [p; q; r] body rates in rad/s
%   accel = [ax; ay; az] accelerometer measurement
%   Ts    = sample time [s]
%
% Outputs:
%   eul       = [roll; pitch; yaw] in radians
%   b_hat_out = estimated gyro bias [rad/s]
%
% Notes:
%   - Roll and pitch are corrected using accelerometer.
%   - Yaw is only gyro-integrated and will drift in real data.
%   - This assumes level stationary accel is approximately [0; 0; +g].

persistent q b_hat initialized

if isempty(initialized)
    q = [1; 0; 0; 0];      % quaternion [qw; qx; qy; qz]
    b_hat = [0; 0; 0];     % estimated gyro bias
    initialized = true;
end


% Measurement correction
omega_mes = [0; 0; 0];

accNorm = sqrt(accel(1)^2 + accel(2)^2 + accel(3)^2);

if accNorm > 1e-9

    % Measured gravity direction in body frame
    v = accel / accNorm;

    qw = q(1);
    qx = q(2);
    qy = q(3);
    qz = q(4);

    % Estimated gravity direction in body frame from current attitude
    v_hat = [ ...
        2*(qx*qz - qw*qy);
        2*(qw*qx + qy*qz);
        qw*qw - qx*qx - qy*qy + qz*qz ];

    % Mahony explicit complementary filter innovation
    omega_mes = cross(v, v_hat);

    % If this test diverges instead of converging, flip the sign:
    % omega_mes = cross(v_hat, v);

end

% -----------------------------
% Bias estimate update
% -----------------------------
% This estimates gyro bias in the observable directions.
% With accel-only correction, yaw bias is not observable.
b_hat = b_hat - Ki*omega_mes*Ts;

% Corrected gyro
omega = gyro - b_hat + Kp*omega_mes;

% -----------------------------
% Quaternion propagation
% -----------------------------
qw = q(1);
qx = q(2);
qy = q(3);
qz = q(4);

p = omega(1);
qrate = omega(2);
r = omega(3);

qdot = 0.5 * [ ...
    -qx*p - qy*qrate - qz*r;
     qw*p + qy*r     - qz*qrate;
     qw*qrate - qx*r + qz*p;
     qw*r + qx*qrate - qy*p ];

q = q + qdot*Ts;

% Normalize quaternion
q = q / sqrt(q(1)^2 + q(2)^2 + q(3)^2 + q(4)^2);

% -----------------------------
% Quaternion to Euler angles
% -----------------------------
qw = q(1);
qx = q(2);
qy = q(3);
qz = q(4);

roll = atan2( ...
    2*(qw*qx + qy*qz), ...
    1 - 2*(qx*qx + qy*qy) );

sinPitch = 2*(qw*qy - qz*qx);

if sinPitch > 1
    sinPitch = 1;
elseif sinPitch < -1
    sinPitch = -1;
end

pitch = asin(sinPitch);

yaw = atan2( ...
    2*(qw*qz + qx*qy), ...
    1 - 2*(qy*qy + qz*qz) );

eul = [roll; pitch; yaw];

% Output estimated gyro bias
b_hat_out = b_hat;

end


function R = eul321_to_R_B_to_I(phi, theta, psi)
% eul321_to_R_B_to_I
%
% Rotation matrix from body frame to inertial frame for 3-2-1 Euler angles.
%
% phi   = roll
% theta = pitch
% psi   = yaw

cphi = cos(phi);
sphi = sin(phi);

cth = cos(theta);
sth = sin(theta);

cpsi = cos(psi);
spsi = sin(psi);

R = [ ...
    cpsi*cth, cpsi*sth*sphi - spsi*cphi, cpsi*sth*cphi + spsi*sphi;
    spsi*cth, spsi*sth*sphi + cpsi*cphi, spsi*sth*cphi - cpsi*sphi;
       -sth,                 cth*sphi,                 cth*cphi ];

end

%===================== LPF Function ===========================
function xlpf = lpf(x,alpha)

persistent prevx firstrun

if isempty(firstrun)
    prevx = x;
    firstrun = 1;
end

xlpf = (1-alpha)*prevx + alpha*x;

prevx = xlpf;

end