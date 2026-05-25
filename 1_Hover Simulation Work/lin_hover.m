% linearized eqns about hover
%syms Ixx Ixy Ixz Iyx Iyy Iyz Izx Izy Izz real
%syms pdot qdot rdot dL dM dN
% rotational equations
%I = [Ixx Ixy Ixz; Ixy Iyy Iyz; Ixz Iyz Izz];

%inv(I)*[dL;dM;dN];

%% Quad-Flapper Hover Linear Model (12-state) with First-Guess Stability Derivatives
% Copy/paste into MATLAB. Edit the "USER PARAMETERS" section.
% State: x = [x y z u v w phi theta psi p q r]'


clc, clear all, close all
%% ---------------- USER PARAMETERS (fill these in) ----------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Physical Vehicle and Wing Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
m   = 0.110;        % [kg] mass
I = (1/(1000^3))*[1.94e6 0 0; 0  1.95e6 0; 0 0 3.78e6];  % inertia kg*m^2
Ix  = I(1,1);      % [kg*m^2] inertia about body x
Iy  = I(2,2);      % [kg*m^2] inertia about body y
Iz  = I(3,3);      % [kg*m^2] inertia about body z
S   = 0.11;        % [m] arm length (hinge-to-CG moment arm for thrust)
wing_type = 5*3;   % [in^2] 5x3 wing
% C11 and C12 ARE TAKEN FROM WING TESTING DATA------------------------------------
C11  = 4.58e-4;    % [N / throttle_unit] thrust slope per flapper: Ti = C1*u_i + C2,
C21 = -.562;        
% NOTE: C2 affects trim u0, NOT the linearized B matrix.
% NOTE: For now assume C1i and C2i is same for all 4 flappers

wing_area = pi*(4*wing_type)*0.00064516; % m^2 assume wing sections are quarter elipses and there are 4 wing sections per flapper
                                         % one ellipse per wing A = pi*a*b,
                                         % a*b = 4*wing_type
                                                
Sref = 4*wing_area; % [m^2] total wing reference area (both wings summed or choose your convention)

g   = 9.81;        % [m/s^2]
rho = 1.225;       % [kg/m^3] air density (sea level)

% Choose how you want FIRST-GUESS damping:
use_time_constant_damping = false;

% --- If using time-constant guesses (recommended for PID tuning) ---
tau_p = 0.20;      % [s] roll-rate natural decay time constant guess
tau_q = 0.20;      % [s] pitch-rate decay time constant guess
tau_r = 0.40;      % [s] yaw-rate decay time constant guess

% --- If using equivalent linearization of quadratic drag --- (Im using this)
v_ref = 0.50;      % [m/s] small "hover perturbation" speed for equivalent linearization
w_ref = 0.50;      % [m/s] same idea for vertical
p_ref = 1.00;      % [rad/s] small "hover perturbation" body rate for equivalent linearization
q_ref = 1.00;      % [rad/s]
r_ref = 1.00;      % [rad/s]

% Drag coefficient guesses (tunable knobs)
CDx = 1.0;  CDy = 1.0;  CDz = 1.0;        % translational
CDw = 1.0;                               % rotational (lumped)

% Effective projected areas (tunable knobs)
Ax = 0.50*Sref;     % [m^2] effective frontal area in body x
Ay = 0.50*Sref;     % [m^2] effective side area in body y
Az = 0.35*Sref;     % [m^2] effective area in body z (for vertical damping)

Aomega = 1.00*Sref; % [m^2] effective "swept area" for rotational damping

% Yaw torque mapping (if unknown, set all zeros and identify later)
% tau_z = k_tau * [ +1 -1 +1 -1 ] * delta_u is a quadrotor-style pattern.
k_tau = 0.00;       % [N*m / throttle_unit] yaw effectiveness slope (set 0 if unknown)
yaw_row = k_tau * [ 1 -1 1 -1 ];   % 1x4

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% set controller sample frequency
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs = 4000; % sample frequency of Flight controller
Ts = 1/fs; %sample time

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% set accel and gyro parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%-----------------------ACCELEROMETER DATA--------------------------------
accel.range = 4;            % [g] double the +/- g value from data sheet
accel.resolution_bits = 16;      % [bits]
accel.resolution_LSB = accel.range*9.81/(2^accel.resolution_bits); % [m/s^2/LSB]
accel.BW = 740;               % [Hz]
accel.LPF_set = 5;           % [Hz] % LPF setting!!!!!!!!!!!!!!!!!!!!!!!!!!!!
accel.alpha = 2*pi*accel.LPF_set*Ts/(1+2*pi*accel.LPF_set*Ts);  % Discrete LPF parameter
accel.tau = 1/(2*pi*accel.BW); % [s]
%-----------------------GYRO DATA--------------------------------
gyro.range = 1000;              % [dps] 
gyro.resolution_bits = 16;      % [bits]
gyro.resolution_LSB = (2*gyro.range/(2^gyro.resolution_bits))*(pi/180); % [rad/s/LSB]
gyro.BW = 751;               % [Hz]
gyro.LPF_set = 5;           % [Hz] % LPF setting!!!!!!!!!!!!!!!!!!!!!!!!!!!!
gyro.alpha = 2*pi*gyro.LPF_set*Ts/(1+2*pi*gyro.LPF_set*Ts);  % Discrete LPF parameter
gyro.tau = 1/(2*pi*gyro.BW); % [s]


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Actuator (Wing) Parameters, used to siulate wing thrust performance
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tau_wing = 0.1/2.2; % wind step response time constant derived from eyeballed rise time

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mahoney Filter Paramters, used to tune state estimator performance, these
% basically change the frequency the estimate oscillates at around a mean.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mahoney.Kp = 0.25; % affects attitude estimate
mahoney.Ki = 0.1; % affects bias estimate

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Noise simulation option
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
noise_true = 1;     % 1 means sensor, thrust, and wing noise will all be simulated
                    % 0 means all noise will be unsimulated, set to zero to
                    % analyze pure controller performance or compare no noise
                    % performance to full noise performance
                   
% these need to be set to zero if noise is not simulated
if ~noise_true
    mahoney.Ki = 0;
    mahoney.Kp = 0;
end


% Set PID values and Strength, for now the vehicle is configured for 
% ANGLE MODE, so strength value matters since it controls the outer PID
% loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set roll PID
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
roll_P = 41;
roll_I = 30;
roll_D = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set pitch PID
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pitch_P = 10;
pitch_I = 15;
pitch_D = 0;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set yaw PID, for now yaw is disabled above (k_tau = 0) since the
% vehicle has no yaw control, ignore these for now
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
yaw_P = 0.001;
yaw_I = 0.001;
yaw_D = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set Angle Mode Strength (0-100)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
strength = 50;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set max pot value (1000-2000) This is analagous to max throttle setting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
max_pot = 1950;

%% -----------------Setup Simulation-------------------------

%{ 
% Discretize KF===========================================================
sys_kf_c = ss(A_kf, B_kf, C_kf, D_kf);
sys_kf_d = c2d(sys_kf_c, Ts, 'zoh');  % Ts = 1/4000

A_kfd = sys_kf_d.A;
B_kfd = sys_kf_d.B;
C_kfd = C_kf;   % unchanged
D_kfd = D_kf;   % unchanged
%}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specify Initial Conditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
X0 = zeros([12,1]);
% Edit the initial state vector X0
X0(1) = 0;       % x position [m]
X0(2) = 0;       % y position [m]
X0(3) = 0;       % z position [m] (down is positive)
X0(4) = 0;       % u velocity [m/s]
X0(5) = 0;       % v velocity [m/s]
X0(6) = 0;       % w velocity [m/s]
X0(7) = 1*pi/180;       % roll angle [rad]
X0(8) = 0*pi/180;       % pitch angle [rad]
X0(9) = 0;       % yaw angle [rad]
X0(10) = 0;      % roll rate [rad/s]
X0(11) = 0;      % pitch rate [rad/s]
X0(12) = 0;      % yaw rate [rad/s]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specify Reference Input (What you command vehcicle to do)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Xref = zeros([12,1]);
% Edit the initial state vector X0
Xref(1) = 0;       % x position [m]
Xref(2) = 0;       % y position [m]
Xref(3) = 0;       % z position [m] (down is positive)
Xref(4) = 0;       % u velocity [m/s]
Xref(5) = 0;       % v velocity [m/s]
Xref(6) = 0;       % w velocity [m/s]
Xref(7) = 0;       % roll angle [rad]
Xref(8) = 0;       % pitch angle [rad]
Xref(9) = 0;       % yaw angle [rad]
Xref(10) = 0;      % roll rate [rad/s]
Xref(11) = 0;      % pitch rate [rad/s]
Xref(12) = 0;      % yaw rate [rad/s]

% ============================================================

%% ---------------- STABILITY DERIVATIVE FORMULAS ----------------
% Translational damping derivatives (N / (m/s)):
% Using equivalent linearization of quadratic drag:  F = -0.5*rho*CD*A*|v|v
% Linearized about small reference speed v_ref:       F ≈ -(rho*CD*A*v_ref)*v
Xu = rho*CDx*Ax*v_ref;     % [N/(m/s)]
Yv = rho*CDy*Ay*v_ref;     % [N/(m/s)]
Zw = rho*CDz*Az*w_ref;     % [N/(m/s)]

% Rotational damping derivatives (N*m / (rad/s)):
% Two options:
% (A) Time-constant guess:    p_dot = -(Lp/Jx)p  => Lp = Jx/tau_p
% (B) Equivalent linearization of quadratic rotational drag:
%     tau ≈ -0.5*rho*CDw*Aomega*l^3*|p|p  => Lp ≈ rho*CDw*Aomega*l^3*p_ref
if use_time_constant_damping
    Lp = Ix/tau_p;         % [N*m/(rad/s)]
    Mq = Iy/tau_q;         % [N*m/(rad/s)]
    Nr = Iz/tau_r;         % [N*m/(rad/s)]
else
    Lp = rho*CDw*Aomega*S^3*p_ref;   % [N*m/(rad/s)]
    Mq = rho*CDw*Aomega*S^3*q_ref;   % [N*m/(rad/s)]
    Nr = rho*CDw*Aomega*S^3*r_ref;   % [N*m/(rad/s)]
end

%% ---------------- BUILD A MATRIX (12x12) ----------------

% State: [x y z u v w phi theta psi p q r]'
A = zeros(12,12);

% Position kinematics
A(1,4) = 1;   % x_dot = u
A(2,5) = 1;   % y_dot = v
A(3,6) = 1;   % z_dot = w

% Translational dynamics (small angles about hover)
A(4,4) = -Xu/m;     % u_dot
A(4,8) = -g;        % u_dot includes -g*theta

A(5,5) = -Yv/m;     % v_dot
A(5,7) = +g;        % v_dot includes +g*phi

A(6,6) = -Zw/m;     % w_dot

% Attitude kinematics (small angles)
A(7,10) = 1;  % phi_dot = p
A(8,11) = 1;  % theta_dot = q
A(9,12) = 1;  % psi_dot = r

% Rotational dynamics with rate damping
A(10,10) = -Lp/Ix;  % p_dot
A(11,11) = -Mq/Iy;  % q_dot
A(12,12) = -Nr/Iz;  % r_dot

% sysID_data = load("C:\Users\bmatt\Local Documents\UCI_FWMAV_Flight_Control_Simulation_and_Development\6_System ID\quadflapper_ssest_hover_model.mat");
% % Remake A matrix with sysID data
% A(7:12,7:12) = sysID_data.A6c;

%% ---------------- BUILD B MATRIX (12x4) ----------------
% Inputs: delta_u = [delta_u1 delta_u2 delta_u3 delta_u4]'
% u1 = dZ (force), u2 = dL, u3 = dM, u4 = dN
B = zeros(12,4);

% Vertical force from thrust slope (per flapper):
% delta_Fz = -C11*(du1+du2+du3+du4)
B(6,:) = -(C11/m) * [1 1 1 1]; % thrust is in negative z direction

% Roll and pitch moments (common "+" numbering):
% 1 front, 2 right, 3 rear, 4 left
% tau_x = S*(T4 - T2) = S*C11*(du2 - du4)
% tau_y = S*(T1 - T3) = S*C11*(du3 - du1)
B(10,:) = (S*C11/Ix) * [0 -1 0 1];
B(11,:) = (S*C11/Iy) * [1 0 -1 0];

% Yaw moment (mechanism-dependent). If unknown, leave as zeros and identify.
B(12,:) = (1/Iz) * yaw_row;

% % Remake B matrix with sysID data
% B(7:12,:) = sysID_data.B6c;

MMA=[1  0  1 1
     1 -1  0 -1
     1  0  -1 1
     1  1  0 -1];

%MMA = eye(4);


%% -------------------- Build C and D Matrices-------------------------------
% Outputs: y = [ax_meas ay_meas az_meas p q r]'

C = zeros(6,12);
D = zeros(6,4);

% Start from v_dot = A(4:6,:)*x + B(4:6,:)*u
C(1:3,:) = A(4:6,:);
D(1:3,:) = B(4:6,:);

% Convert inertial accel -> specific force by subtracting g expressed in body
% z down, small angles: g_b ≈ [-g*theta; +g*phi; +g]
% so add +g*theta to row1, add -g*phi to row2, and subtract g from row3 (bias)
C(1,8) = C(1,8) + g;    % ax = u_dot + g*theta
C(2,7) = C(2,7) - g;    % ay = v_dot - g*phi

% az includes a constant -g term (since z is down). That's a bias term.
% State-space C/D can't represent constants, so handle it by adding a Bias block in Simulink.
% y3 = w_dot - g  -> implement "-g" as a constant added after the SS block.

% Gyro outputs
C(4:6,10:12) = eye(3);
% D(4:6,:) already zero



%% ---------------- DISPLAY RESULTS ----------------
disp('--- First-guess stability derivatives ---');
fprintf('Xu = %.4g N/(m/s)\n', Xu);
fprintf('Yv = %.4g N/(m/s)\n', Yv);
fprintf('Zw = %.4g N/(m/s)\n', Zw);
fprintf('Lp = %.4g N*m/(rad/s)\n', Lp);
fprintf('Mq = %.4g N*m/(rad/s)\n', Mq);
fprintf('Nr = %.4g N*m/(rad/s)\n', Nr);

disp('--- A matrix ---');
disp(A);

disp('--- B matrix ---');
disp(B);

%% ---------------- OPTIONAL: helper to get hover trim throttle u0 ----------------
% If each flapper thrust is Ti = C1*u + C2, then hover condition:
%4*(C1*u0 + C2) = m*g  =>  
u0 = (m*g/4 - C21)/C11; %FEEDFORWARD Term
% (This affects feedforward, not A/B.)
% C2 = ???; % [N] intercept per flapper from your thrust fit
% u0 = (m*g/4 - C2)/C1;
% fprintf('Hover trim per-flapper u0 = %.4g throttle_unit\n', u0);

%% ---------------- Design LQR Hover Controller ----------------
%{
% State: X = [x y z u v w phi theta psi p q r]'
% x,y,z are in N,E,D coordinates, z in body frame is downward as well
rnkCo = rank(ctrb(A,B))

[Abar,Bbar,Cbar,T,k] = ctrbf(A,B,C);

uc_size = 12-rnkCo
Auc = Abar(1:uc_size,1:uc_size);
Ac = Abar(uc_size+1:end,uc_size+1:end);
Bc = Bbar(uc_size+1:end,:);
Cc = Cbar(:,uc_size+1:end);

% define Q and R for LQR
Q = 10000*eye(12);  % State weighting matrix
R = 10*eye(4);        % Input weighting scalar
K = lqr(A,B,Q,R);
%Kaug1 = [zeros([4,2]),Kaug];
%K = Kaug1/inv(T)
% Closed loop system!
sysCl = ss((A-B*K),B,C,D);
% solve for Kr
Kdc = dcgain(sysCl);
Kdc(4:12,:) = ones([9,4]);
scaleGain = 1./Kdc;
% topHalf = Kdc(1:3,:);
% scaledGain = 1./diag(topHalf);
% Kr = 1./Kdc;
% Kr(4:6,:)=1;
% 
% Kr = [1;1;1;scaledGain(1);scaledGain(2);scaledGain(3)];
%}

%% ============================================================
%  REDUCED KALMAN FILTER — Orientation Estimator
%  State: x_kf = [phi, theta, p, q]'   (4 states)
%  Meas:  y_kf = [p_gyro, q_gyro, ax_accel, ay_accel]'  (4 meas)
% ============================================================

% --- A matrix (4x4) ---
% Dynamics:
%   phi_dot   = p
%   theta_dot = q
%   p_dot     = -(Lp/Ix)*p   (aerodynamic damping from your linearization)
%   q_dot     = -(Mq/Iy)*q

% A_kf = [ 0,  0,          1,          0;       % phi_dot   = p
%          0,  0,          0,          1;       % theta_dot = q
%          0,  0,  -Lp/Ix,             0;       % p_dot     = damping on p
%          0,  0,          0,  -Mq/Iy  ];      % q_dot     = damping on q

% --- B matrix (4x4) ---
% Maps the 4 flapper delta-throttle inputs to the KF states.
% Only p and q states are driven by control (phi and theta are pure kinematics).
% This allows the KF to account for known control-induced angular accelerations.
%
% From your original B rows 10 and 11:
%   B(10,:) = (S*C11/Ix) * [0 -1  0  1]
%   B(11,:) = (S*C11/Iy) * [1  0 -1  0]

% B_kf = [ 0,               0,             0,              0;
%          0,               0,             0,              0;
%          (S*C11/Ix)*[0   -1   0   1];
%          (S*C11/Iy)*[1    0  -1   0] ];

% NOTE: If you choose NOT to feed control inputs into the KF (simpler, common
% in practice), set B_kf = zeros(4,4) and lump control torques into Q.
% This is usually fine if your controller is slow relative to KF bandwidth.

%--- C matrix (4x4) ---
% Maps KF states [phi, theta, p, q] to measurements [p_gyro, q_gyro, ax, ay].
%
% Gyro directly measures body rates:
%   p_gyro = p
%   q_gyro = q
%
% Accelerometer quasi-static tilt model (assumes low translational accel):
%   ax_accel = -g * theta   (forward tilt tilts accel negative x)
%   ay_accel = +g * phi     (right roll tilts accel positive y)
%
%           phi   theta    p    q
% C_kf = [    0,    0,      1,   0;    % p_gyro   = p
%              0,    0,      0,   1;    % q_gyro   = q
%              0,   -g,      0,   0;    % ax_accel = -g*theta
%              g,    0,      0,   0  ]; % ay_accel = +g*phi



%--- D matrix (4x4) ---
% No direct feedthrough from inputs to measurements in this sensor model.
%D_kf = zeros(4, 4);



%============================================================
%  NOISE MATRICES — Starting Guesses
% ============================================================

% --- Q: Process Noise Covariance (4x4, diagonal starting point) ---
%
% Q represents uncertainty in your DYNAMICS MODEL (unmodeled forces,
% aerodynamic gust, model error in Lp/Mq, etc.).
%
% Tuning philosophy:
%   - Larger Q  -> KF trusts measurements more, responds faster, noisier output
%   - Smaller Q -> KF trusts model more, smoother output, slower response
%
% Row/col order: [phi, theta, p, q]
%
% phi, theta: kinematic states driven by integrating p,q.
%   Process noise here is small — the kinematics are exact.
%   sigma_phi = sigma_theta ~ 0.005 rad (0.3 deg of model drift)
%
% p, q: damping model (Lp, Mq) is a rough first-guess, so give these more room.
%   sigma_p = sigma_q ~ 0.1 rad/s of unmodeled angular acceleration uncertainty

% sigma_phi   = 0.005;   % [rad]
% sigma_theta = 0.005;   % [rad]
% sigma_p     = 0.10;    % [rad/s]
% sigma_q     = 0.10;    % [rad/s]

% Q_kf = diag([sigma_phi^2, sigma_theta^2, sigma_p^2, sigma_q^2]);

% --- R: Measurement Noise Covariance (4x4, diagonal starting point) ---
%
% R represents sensor noise from your BMI270 datasheet parameters.
%
% GYRO noise:
%   BMI270 noise density ~ 0.007 dps/sqrt(Hz)
%   At your fs = 4000 Hz (before LPF), noise std:
%   sigma_gyro_raw = 0.007 * sqrt(4000) * (pi/180) ~ 0.025 rad/s
%   After your 100 Hz digital LPF (alpha = gyro_alpha), effective BW ~ 100 Hz:
%   sigma_gyro_lpf = 0.007 * sqrt(100) * (pi/180) ~ 0.006 rad/s
%   Use ~2x the LPF value for margin:
%sigma_gyro  = 0.05;   % [rad/s]

% ACCELEROMETER noise (as tilt sensor):
%   BMI270 noise density ~ 180 ug/sqrt(Hz)
%   At 10 Hz LPF setting (accel.LPF_set = 10):
%   sigma_accel_lpf = 180e-6 * 9.81 * sqrt(10) ~ 0.0056 m/s^2
%   But in vibration-heavy flapping environment, multiply by ~5-10x:
%sigma_accel = 1;    % [m/s^2]  (conservative for flapping platform)

% NOTE: The accelerometer noise is DOMINATED by vibration from flapping wings,
% NOT electronics noise. You will likely need to increase sigma_accel
% significantly after flight tests. Start at 0.05 and increase if the KF
% angle estimate is too jittery.

%R_kf = diag([sigma_gyro^2,  sigma_gyro^2, ...
             %sigma_accel^2, sigma_accel^2]);

% --- N: Cross-correlation (usually zero) ---
%N_kf = zeros(4, 4);

%============================================================
%  DISPLAY
% ============================================================
% fprintf('\n--- Reduced KF A matrix (4x4) ---\n');  disp(A_kf);
% fprintf('--- Reduced KF B matrix (4x4) ---\n');    disp(B_kf);
% fprintf('--- Reduced KF C matrix (4x4) ---\n');    disp(C_kf);
% fprintf('\n--- Q (process noise) ---\n');            disp(Q_kf);
% fprintf('--- R (measurement noise) ---\n');         disp(R_kf);




%  INITIAL STATE AND COVARIANCE FOR SIMULINK BLOCK
% ============================================================
%x_kf0   = [X0(7); X0(8); X0(10); X0(11)];  % [phi0, theta0, p0, q0]
%P_kf0   = diag([0.01, 0.01, 0.1, 0.1]);     % initial uncertainty

%% USE sys ID A B and C Matrices
sysID = load("C:\Users\bmatt\Local Documents\UCI_FWMAV_Flight_Control_Simulation_and_Development\6_System ID\quadflapper_ssest_hover_model.mat");
A = sysID.A12_est;
B = sysID.B12_est;

%% RUN SIMULATION
simstruct = sim('lin_hover_sim.slx');


%% extracting variables for plot
% extract state
state = simstruct.get("state_output");
assignin('base','outX',state);
time = outX.time;
XVec = squeeze(outX.signals.values);

% extract controls
controls = simstruct.get("controls");
assignin('base','controls',controls);
ctrl_time = controls.time;
ctrl_vec = squeeze(controls.signals.values);

% extract state estimate
state_est = simstruct.get("state_estimate");
assignin('base','out_est_state',state_est);
XEst = squeeze(out_est_state.signals.values).';

% Extract each column of true state according to the state convention
x = XVec(:, 1);   % x position    [m]
y = XVec(:, 2);   % y position    [m]
z = XVec(:, 3);   % z position    [m] (down is positive)
u = XVec(:, 4);   % u velocity    [m/s]
v = XVec(:, 5);   % v velocity    [m/s]
w = XVec(:, 6);   % w velocity    [m/s] (down is positive)
phi = XVec(:, 7); % roll angle    [rad]
theta = XVec(:, 8); % pitch angle [rad]
psi = XVec(:, 9); % yaw angle     [rad]
p = XVec(:, 10);  % roll rate     [rad/s]
q = XVec(:, 11);  % pitch rate    [rad/s]
r = XVec(:, 12);  % yaw rate      [rad/s]

% Extract control inputs (add feedforward term)
pot1 = ctrl_vec(:, 1) +u0;  % Control input 1
pot2 = ctrl_vec(:, 2) +u0 ; % Control input 2
pot3 = ctrl_vec(:, 3) +u0;  % Control input 3
pot4 = ctrl_vec(:, 4) +u0;  % Control input 4

% Extract each column of X_Est according to the state convention
x_est = XEst(:, 1);   % x position    [m]
y_est = XEst(:, 2);   % y position    [m]
z_est = XEst(:, 3);   % z position    [m] (down is positive)
u_est = XEst(:, 4);   % u velocity    [m/s]
v_est = XEst(:, 5);   % v velocity    [m/s]
w_est = XEst(:, 6);   % w velocity    [m/s] (down is positive)
phi_est = XEst(:, 7); % roll angle    [rad]
theta_est = XEst(:, 8); % pitch angle [rad]
psi_est = XEst(:, 9); % yaw angle     [rad]
p_est = XEst(:, 10);  % roll rate     [rad/s]
q_est = XEst(:, 11);  % pitch rate    [rad/s]
r_est = XEst(:, 12);  % yaw rate      [rad/s]


%% Plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot True States
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NEW FIGURE---------------------------------------------------------------
figure(1);
subplot(2,1,1);
hold on;
% Define colors for solid and dotted lines
solidColors = lines(6);  % Generate 6 distinct colors for solid lines
dottedColors = lines(6);  % Generate 6 distinct colors for dotted lines

% Plot positions with solid lines
plot(time, x, 'LineWidth', 1.7, 'DisplayName', 'x Position [m]', 'Color', solidColors(1,:));
plot(time, y, 'LineWidth', 1.7, 'DisplayName', 'y Position [m]', 'Color', solidColors(2,:));
plot(time, -z, 'LineWidth', 1.7, 'DisplayName', 'z Altitude [m]', 'Color', solidColors(3,:));
% Plot velocities with dotted lines
plot(time, u, '--', 'LineWidth', 1.7, 'DisplayName', 'u Velocity [m/s]', 'Color', dottedColors(1,:));
plot(time, v, '--', 'LineWidth', 1.7, 'DisplayName', 'v Velocity [m/s]', 'Color', dottedColors(2,:));
plot(time, -w, '--', 'LineWidth', 1.7, 'DisplayName', 'altitude rate [m/s]', 'Color', dottedColors(3,:));

% Plot roll, pitch, and yaw angles with solid lines
plot(time, phi*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Roll Angle [deg]', 'Color', solidColors(4,:));
plot(time, theta*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Pitch Angle [deg]', 'Color', solidColors(5,:));
plot(time, psi*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Yaw Angle [deg]', 'Color', solidColors(6,:));
% Plot rates with dotted lines
plot(time, p*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Roll Rate [deg/s]', 'Color', dottedColors(4,:));
plot(time, q*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Pitch Rate [deg/s]', 'Color', dottedColors(5,:));
plot(time, r*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Yaw Rate [deg/s]', 'Color', dottedColors(6,:));

% Configure legend and labels
legend('show');
xlabel('Time [s]');
ylabel('States and Rates');
title('States and Rates Over Time');
grid on;
hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot Controls
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subplot(2,1,2);
hold on;
% Plot control inputs with solid lines
plot(ctrl_time, pot1, 'LineWidth', 1.7, 'DisplayName', 'Control Input 1 (pot1)');
plot(ctrl_time, pot2, 'LineWidth', 1.7, 'DisplayName', 'Control Input 2 (pot2)');
plot(ctrl_time, pot3, 'LineWidth', 1.7, 'DisplayName', 'Control Input 3 (pot3)');
plot(ctrl_time, pot4, 'LineWidth', 1.7, 'DisplayName', 'Control Input 4 (pot4)');

% Configure legend and labels
legend('show');
xlabel('Time [s]');
ylabel('Control Inputs');
title('Control Inputs Over Time');
grid on;
hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot Estimated States
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% NOTE: current positions and velocities are currently unmeasured and unestimated

% NEW FIGURE---------------------------------------------------------------
figure(2);       
subplot(2,1,1);
hold on;
% Define colors for solid and dotted lines
solidColors = lines(6);  % Generate 6 distinct colors for solid lines
dottedColors = lines(6);  % Generate 6 distinct colors for dotted lines

% Plot positions with solid lines
% plot(out_est_state.time, x_est, 'LineWidth', 1.7, 'DisplayName', 'x Position [m]', 'Color', solidColors(1,:));
% plot(out_est_state.time, y_est, 'LineWidth', 1.7, 'DisplayName', 'y Position [m]', 'Color', solidColors(2,:));
% plot(out_est_state.time, -z_est, 'LineWidth', 1.7, 'DisplayName', 'z Altitude [m]', 'Color', solidColors(3,:));
% % Plot velocities with dotted lines
% plot(out_est_state.time, u_est, '--', 'LineWidth', 1.7, 'DisplayName', 'u Velocity [m/s]', 'Color', dottedColors(1,:));
% plot(out_est_state.time, v_est, '--', 'LineWidth', 1.7, 'DisplayName', 'v Velocity [m/s]', 'Color', dottedColors(2,:));
% plot(out_est_state.time, -w_est, '--', 'LineWidth', 1.7, 'DisplayName', 'altitude rate [m/s]', 'Color', dottedColors(3,:));

% Plot roll, pitch, and yaw angles with solid lines, CONVERT TO DEGREES AND DEG/S
plot(out_est_state.time, phi_est*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Roll Angle [deg]', 'Color', solidColors(4,:));
plot(out_est_state.time, theta_est*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Pitch Angle [deg]', 'Color', solidColors(5,:));
plot(out_est_state.time, psi_est*180/pi, 'LineWidth', 1.7, 'DisplayName', 'Yaw Angle [deg]', 'Color', solidColors(6,:));
% Plot rates with dotted lines
plot(out_est_state.time, p_est*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Roll Rate [deg/s]', 'Color', dottedColors(4,:));
plot(out_est_state.time, q_est*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Pitch Rate [deg/s]', 'Color', dottedColors(5,:));
plot(out_est_state.time, r_est*180/pi, '--', 'LineWidth', 1.7, 'DisplayName', 'Yaw Rate [deg/s]', 'Color', dottedColors(6,:));

% Configure legend and labels
legend('show');
xlabel('Time [s]');
ylabel('Estimated States and Rates');
title('Estimated States and Rates Over Time');
grid on;
hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot Error between true and estimated states (True - Est)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot Error between true and estimated states (True - Est)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

subplot(2,1,2);
hold on;

% Use the estimator time as the common time base because it is shorter
t_est = out_est_state.time;
t_true = outX.time;

% Interpolate true attitude and rates onto estimator time vector
phi_true_i   = interp1(t_true, phi,   t_est, 'linear', 'extrap');
theta_true_i = interp1(t_true, theta, t_est, 'linear', 'extrap');
psi_true_i   = interp1(t_true, psi,   t_est, 'linear', 'extrap');

p_true_i = interp1(t_true, p, t_est, 'linear', 'extrap');
q_true_i = interp1(t_true, q, t_est, 'linear', 'extrap');
r_true_i = interp1(t_true, r, t_est, 'linear', 'extrap');

% Compute attitude and rate error: True - Estimate
phi_err   = phi_true_i   - phi_est;
theta_err = theta_true_i - theta_est;
psi_err   = psi_true_i   - psi_est;

p_err = p_true_i - p_est;
q_err = q_true_i - q_est;
r_err = r_true_i - r_est;

% Plot attitude errors with solid lines, converted to deg
plot(t_est, phi_err*180/pi, ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Roll Error [deg]', ...
    'Color', solidColors(4,:));

plot(t_est, theta_err*180/pi, ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Pitch Error [deg]', ...
    'Color', solidColors(5,:));

plot(t_est, psi_err*180/pi, ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Yaw Error [deg]', ...
    'Color', solidColors(6,:));

% Plot rate errors with dotted lines, converted to deg/s
plot(t_est, p_err*180/pi, '--', ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Roll Rate Error [deg/s]', ...
    'Color', dottedColors(4,:));

plot(t_est, q_err*180/pi, '--', ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Pitch Rate Error [deg/s]', ...
    'Color', dottedColors(5,:));

plot(t_est, r_err*180/pi, '--', ...
    'LineWidth', 1.7, ...
    'DisplayName', 'Yaw Rate Error [deg/s]', ...
    'Color', dottedColors(6,:));

% Configure legend and labels
legend('show');
xlabel('Time [s]');
ylabel('True - Estimated Error');
title('Attitude and Rate Estimation Error Over Time');
grid on;
hold off;