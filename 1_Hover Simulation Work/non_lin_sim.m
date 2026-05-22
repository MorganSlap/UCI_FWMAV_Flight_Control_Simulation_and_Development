function sdot = quadflapper6DOF(t,s)
% s is 12 states consisting of
% [N;E;D;u;v;w;phi;theta;psi;p;q;r]

% extract states
N = s(1);
E = s(2);
D = s(3);
u = s(4);
v = s(5);
w = s(6);
phi = s(7);
theta = s(8);
psi = s(9);
p = s(10);
q = s(11);
r = s(12);

% ---------------- USER PARAMETERS (fill these in) ----------------
m   = 0.110;        % [kg] mass
I = (1/(1000^3))*[1.94e6 0 0; 0 3.78e6 0; 0 0 1.95e6];  % inertia kg*m^2
Ix  = I(1,1);      % [kg*m^2] inertia about body x
Iy  = I(2,2);      % [kg*m^2] inertia about body y
Iz  = I(3,3);      % [kg*m^2] inertia about body z
S   = 0.11;        % [m] arm length (hinge-to-CG moment arm for thrust)
wing_type = 5*3;   % [in^2] 5x3 wing
C11  = 4.58e-4;    % [N / throttle_unit] thrust slope per flapper: Ti = C1*u_i + C2
C21 = -.562;        
% NOTE: C2 affects trim u0, NOT the linearized B matrix.
% NOTE: For now assume C1i and C2i is same for all 4 flappers

wing_area = pi*(4*wing_type)*0.00064516; % m^2 assume wing sections are quarter elipses and there are 4 wing sections per flapper
                                         % one ellipse per wing A = pi*a*b,
                                         % a*b = 4*wing_type
                                                
Sref = 4*wing_area; % [m^2] total wing reference area (both wings summed or choose your convention)

g   = 9.81;        % [m/s^2]
rho = 1.225;       % [kg/m^3] air density (sea level)
g_vec = g* [0;0;1];

% Choose how you want FIRST-GUESS damping:
use_time_constant_damping = false;

% --- If using time-constant guesses (recommended for PID tuning) ---
tau_p = 0.20;      % [s] roll-rate natural decay time constant guess
tau_q = 0.20;      % [s] pitch-rate decay time constant guess
tau_r = 0.40;      % [s] yaw-rate decay time constant guess

% --- If using equivalent linearization of quadratic drag ---
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

% ---------------- STABILITY DERIVATIVE FORMULAS ----------------
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

% create current rotation matrix
eul = [psi,theta,phi];
rotm = eul2rotm(eul,'ZYX');

% define forces and moments
T1 = C11*u(1)
X = .5*rho*u*abs(u)*CDx*Ax ;
Y = .5*rho*v*abs(v)*CDx*Ay;
Z = .5*rho*w*abs(w)*CDx*Az;

L = 0;
M = 0;
N = 0;

% define EOMs
v_body = [u;v;w;]
w_body = [p;q;r]
NED_dot = rotm*v_body;
uvw_dot = (1/m)*( cross(v_body,w_body) + [X;Y;Z] + rotm*g_vec);

end