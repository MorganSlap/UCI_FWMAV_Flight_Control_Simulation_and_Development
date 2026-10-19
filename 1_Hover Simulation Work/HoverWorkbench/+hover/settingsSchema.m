function schema = settingsSchema()
%SETTINGSSCHEMA Editable inputs from lin_hover.m, with units and UI metadata.
% Derived matrices, filter coefficients, trim and stability derivatives are
% rebuilt by hover.buildVariables. No initialization script is executed.
% Defaults remain in stored/simulation units. Unit describes the UI; angular
% display conversion is handled by hover.angularInputValue.

schema = struct('Key',{},'Label',{},'Group',{},'Unit',{},'Default',{}, ...
    'Kind',{},'Choices',{},'Help',{});

add('sim_fidelity','Dynamics fidelity','Simulation','','high','choice', ...
    {'high','low'},'high: nonlinear dynamics; low: linearized hover dynamics.');
add('t_sim','Simulation duration','Simulation','s',10);
add('fs','Sensor sampling frequency','Simulation','Hz',4000,'number',{}, ...
    'The SITL build samples sensors at 4000 Hz. Set the PID/mixer divider in Betaflight Configurator; sensor sampling remains at 4000 Hz.');
add('noise_true','Enable simulated noise','Simulation','',true,'logical',{}, ...
    'Enables sensor noise, bias, vibration and wing uncertainty. Physical specific force remains active in either setting.');
add('seed','Noise seed','Simulation','',23341,'number',{}, ...
    'Use the same seed for repeatable comparisons. Integer from 0 through 2^32-1.');
add('drag_enabled','Enable aerodynamic drag','Simulation','',true,'logical',{}, ...
    'Disabled: run variables CDx, CDy, CDz and CDw are all zero. Your entered coefficients are retained for re-enabling drag.');

add('roll_P','Roll P','Rate controller','',0.022);
add('roll_I','Roll I','Rate controller','',0.005);
add('roll_D','Roll D','Rate controller','',0);
defaultInertia = (1/(1000^3))*[1.94e6 0 0;0 1.95e6 0;0 0 3.78e6];
add('pitch_P','Pitch P','Rate controller','',0.022*defaultInertia(2,2)/defaultInertia(1,1),'number',{}, ...
    'Default uses the script inertia ratio Iy/Ix. Editable independently thereafter.');
add('pitch_I','Pitch I','Rate controller','',0.005*defaultInertia(2,2)/defaultInertia(1,1),'number',{}, ...
    'Default uses the script inertia ratio Iy/Ix. Editable independently thereafter.');
add('pitch_D','Pitch D','Rate controller','',0);
add('yaw_P','Yaw P','Rate controller','',0.001);
add('yaw_I','Yaw I','Rate controller','',0.001);
add('yaw_D','Yaw D','Rate controller','',0);
add('strength','Angle mode strength','Rate controller','%',50,'number',{}, ...
    'Outer attitude-loop strength, from 0 to 100.');
add('max_pot','Maximum throttle','Rate controller','pot',1950,'number',{}, ...
    'Maximum pot value, from 1000 to 2000.');

add('m','Vehicle mass','Vehicle and wings','kg',0.110);
add('I','Inertia tensor','Vehicle and wings','kg m^2', ...
    defaultInertia,'matrix',{}, ...
    'Symmetric positive definite 3-by-3 body inertia tensor. Diagonal entries define Ix, Iy, Iz.');
add('S','Thrust moment arm','Vehicle and wings','m',0.11);
add('wing_type','Wing size product','Vehicle and wings','in^2',15,'number',{}, ...
    'The script uses 5*3. Per-flapper wing area = pi*(4*wing_type)*0.00064516.');
add('C11','Thrust slope','Vehicle and wings','N/pot',4.58e-4);
add('C21','Thrust intercept','Vehicle and wings','N',-0.562);
add('tau_wing','Wing time constant','Vehicle and wings','s',0.1/2.2);
add('k_tau','Yaw effectiveness','Vehicle and wings','N m/pot',0,'number',{}, ...
    'Yaw torque row = k_tau*[1 -1 1 -1]. Zero disables yaw authority.');
add('MMA','Mixer matrix','Vehicle and wings','', ...
    [1 0 1 1;1 -1 0 -1;1 0 -1 1;1 1 0 -1],'matrix',{}, ...
    'The active 4-by-4 MMA assignment in lin_hover.m. Rows correspond to the four actuators.');

add('g','Gravity','Environment','m/s^2',9.81);
add('rho','Air density','Environment','kg/m^3',1.225);

add('use_time_constant_damping','Use decay-time damping','Aerodynamic damping','',false,'logical',{}, ...
    'Enabled: use inertia/tau for rate damping. Disabled: use equivalent quadratic drag.');
add('tau_p','Roll decay time','Aerodynamic damping','s',0.20);
add('tau_q','Pitch decay time','Aerodynamic damping','s',0.20);
add('tau_r','Yaw decay time','Aerodynamic damping','s',0.40);
add('v_ref','Horizontal reference speed','Aerodynamic damping','m/s',0.50);
add('w_ref','Vertical reference speed','Aerodynamic damping','m/s',0.50);
add('p_ref','Roll reference rate','Aerodynamic damping','deg/s',1);
add('q_ref','Pitch reference rate','Aerodynamic damping','deg/s',1);
add('r_ref','Yaw reference rate','Aerodynamic damping','deg/s',1);
add('CDx','Body x drag coefficient','Aerodynamic damping','',1);
add('CDy','Body y drag coefficient','Aerodynamic damping','',1);
add('CDz','Body z drag coefficient','Aerodynamic damping','',1);
add('CDw','Rotational drag coefficient','Aerodynamic damping','',1);
add('AxFactor','Frontal area / Aref','Aerodynamic damping','',0.50,'number',{}, ...
    'Ax = this fraction * Aref; recomputed when wing size changes.');
add('AyFactor','Side area / Aref','Aerodynamic damping','',0.50,'number',{}, ...
    'Ay = this fraction * Aref; recomputed when wing size changes.');
add('AzFactor','Vertical area / Aref','Aerodynamic damping','',0.35,'number',{}, ...
    'Az = this fraction * Aref; recomputed when wing size changes.');
add('AomegaFactor','Swept area / Aref','Aerodynamic damping','',1,'number',{}, ...
    'Aomega = this fraction * Aref; recomputed when wing size changes.');

add('accel.range','Accelerometer total range','Sensors and estimator','g',4,'number',{}, ...
    'The script specifies twice the +/- accelerometer range. Conversion preserves its 9.81 factor.');
add('accel.resolution_bits','Accelerometer resolution','Sensors and estimator','bits',16);
add('accel.BW','Accelerometer bandwidth','Sensors and estimator','Hz',740);
add('accel.LPF_set','Accelerometer LPF cutoff','Sensors and estimator','Hz',5);
add('accel.sample_rate','Accelerometer output rate','Sensors and estimator','Hz',1600);
add('accel.noise_density','Accelerometer noise density','Sensors and estimator','g/sqrt(Hz)',0.00016);
add('accel.bias','Accelerometer bias [x y z]','Sensors and estimator','g',0.02*ones(3,1),'matrix');
add('accel.vibration','Accelerometer wing vibration','Sensors and estimator','g',0.1);
add('gyro.range','Gyroscope +/- range','Sensors and estimator','deg/s',1000);
add('gyro.resolution_bits','Gyroscope resolution','Sensors and estimator','bits',16);
add('gyro.BW','Gyroscope bandwidth','Sensors and estimator','Hz',751);
add('gyro.LPF_set','Gyroscope LPF cutoff','Sensors and estimator','Hz',5);
add('gyro.sample_rate','Gyroscope output rate','Sensors and estimator','Hz',3200);
add('gyro.noise_density','Gyroscope noise density','Sensors and estimator','deg/s/sqrt(Hz)',0.007);
add('gyro.bias','Gyroscope bias [x y z]','Sensors and estimator','deg/s',0.5*ones(3,1),'matrix');
add('gyro.vibration','Gyroscope wing vibration','Sensors and estimator','deg/s',3.7);
add('mahoney.Kp','Mahoney proportional gain','Sensors and estimator','',0.25,'number',{}, ...
    'Used when noise is enabled. Noise-off behavior is fixed to 0.25, matching lin_hover.m.');
add('mahoney.Ki','Mahoney integral gain','Sensors and estimator','',0.05,'number',{}, ...
    'Used when noise is enabled. Noise-off behavior is fixed to 0, matching lin_hover.m.');

x0 = zeros(12,1);
x0(7) = 5*pi/180;
stateHelp = ['12-by-1 state order: x, y, z, u, v, w, phi, theta, psi, p, q, r. ' ...
    'Enter position in m, velocity in m/s, angles in deg and rates in deg/s. ' ...
    'Angular entries convert to radians for storage and simulation. z and w are positive down.'];
add('X0','Initial state','Initial conditions','m, m/s, deg, deg/s',x0,'matrix',{},stateHelp);
add('Xref','Reference state','Reference command','m, m/s, deg, deg/s',zeros(12,1),'matrix',{},stateHelp);

    function add(key,label,group,unit,value,kind,choices,helpText)
        if nargin < 6, kind = 'number'; end
        if nargin < 7, choices = {}; end
        if nargin < 8, helpText = ''; end
        schema(end+1) = struct('Key',key,'Label',label,'Group',group, ...
            'Unit',unit,'Default',value,'Kind',kind,'Choices',{choices}, ...
            'Help',helpText);
    end
end
