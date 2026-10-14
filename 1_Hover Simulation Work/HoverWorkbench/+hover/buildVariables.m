function variables = buildVariables(settings)
%BUILDVARIABLES Pure initialization equivalent to active lin_hover.m formulas.
% No base-workspace writes, model changes, simulation, or plotting occurs.
% All editable settings must be present; use hover.defaultSettings first.
arguments
    settings (1,1) struct
end
settings=hover.upgradeSettings(settings);
hover.validateSettings(settings);

% Copy exactly the independent variables that the original script defines.
names = {'m','I','S','wing_type','C11','C21','g','rho', ...
    'use_time_constant_damping','tau_p','tau_q','tau_r','v_ref','w_ref', ...
    'p_ref','q_ref','r_ref','CDx','CDy','CDz','CDw','k_tau','fs', ...
    'accel','gyro','tau_wing','mahoney','noise_true','seed', ...
    'roll_P','roll_I','roll_D','pitch_P','pitch_I','pitch_D', ...
    'yaw_P','yaw_I','yaw_D','strength','max_pot','X0','Xref', ...
    'MMA','sim_fidelity','t_sim'};
variables = struct();
for k = 1:numel(names)
    variables.(names{k}) = settings.(names{k});
end
% The original model uses a numeric noise switch and char variant selector.
variables.noise_true = double(settings.noise_true);
variables.sim_fidelity = char(settings.sim_fidelity);
variables.imu_nonlinear = strcmp(settings.sim_fidelity,'high');
v = variables;
v.Ix = v.I(1,1);
v.Iy = v.I(2,2);
v.Iz = v.I(3,3);
v.wing_area = pi*(4*v.wing_type)*0.00064516;
v.Aref = 4*v.wing_area;
v.Ax = settings.AxFactor*v.Aref;
v.Ay = settings.AyFactor*v.Aref;
v.Az = settings.AzFactor*v.Aref;
v.Aomega = settings.AomegaFactor*v.Aref;
v.yaw_row = v.k_tau*[1 -1 1 -1];
v.Ts = 1/v.fs;

v.accel.resolution_LSB = v.accel.range*9.81/(2^v.accel.resolution_bits);
v.accel.alpha = 2*pi*v.accel.LPF_set*v.Ts/(1+2*pi*v.accel.LPF_set*v.Ts);
v.accel.tau = 1/(2*pi*v.accel.BW);
v.gyro.resolution_LSB = (2*v.gyro.range/(2^v.gyro.resolution_bits))*(pi/180);
v.gyro.alpha = 2*pi*v.gyro.LPF_set*v.Ts/(1+2*pi*v.gyro.LPF_set*v.Ts);
v.gyro.tau = 1/(2*pi*v.gyro.BW);
if ~v.noise_true
    v.mahoney.Kp = 0.25;
    v.mahoney.Ki = 0;
end

v.Xu = v.rho*v.CDx*v.Ax*v.v_ref;
v.Yv = v.rho*v.CDy*v.Ay*v.v_ref;
v.Zw = v.rho*v.CDz*v.Az*v.w_ref;
if v.use_time_constant_damping
    v.Lp = v.Ix/v.tau_p;
    v.Mq = v.Iy/v.tau_q;
    v.Nr = v.Iz/v.tau_r;
else
    v.Lp = v.rho*v.CDw*v.Aomega*v.S^3*v.p_ref;
    v.Mq = v.rho*v.CDw*v.Aomega*v.S^3*v.q_ref;
    v.Nr = v.rho*v.CDw*v.Aomega*v.S^3*v.r_ref;
end

v.A = zeros(12,12);
v.A(1,4) = 1; v.A(2,5) = 1; v.A(3,6) = 1;
v.A(4,4) = -v.Xu/v.m; v.A(4,8) = -v.g;
v.A(5,5) = -v.Yv/v.m; v.A(5,7) = v.g;
v.A(6,6) = -v.Zw/v.m;
v.A(7,10) = 1; v.A(8,11) = 1; v.A(9,12) = 1;
v.A(10,10) = -v.Lp/v.Ix;
v.A(11,11) = -v.Mq/v.Iy;
v.A(12,12) = -v.Nr/v.Iz;

v.B = zeros(12,4);
v.B(6,:) = -(v.C11/v.m)*[1 1 1 1];
v.B(10,:) = (v.S*v.C11/v.Ix)*[0 -1 0 1];
v.B(11,:) = (v.S*v.C11/v.Iy)*[1 0 -1 0];
v.B(12,:) = (1/v.Iz)*v.yaw_row;
v.C = zeros(6,12);
v.D = zeros(6,4);
v.C(1:3,:) = v.A(4:6,:);
v.D(1:3,:) = v.B(4:6,:);
v.C(1,8) = v.C(1,8)+v.g;
v.C(2,7) = v.C(2,7)-v.g;
v.C(4:6,10:12) = eye(3);
v.u0 = (v.m*v.g/4-v.C21)/v.C11;
if isfield(settings,'Betaflight')
    v.bfConfig=settings.Betaflight;
else
    v.bfConfig=bf.hoverConfig(settings.max_pot);
end
v.bfSim=bf.simulationOptions(v,v.bfConfig);
if isfield(settings,'FirmwareAdapter')
    adapterNames=fieldnames(settings.FirmwareAdapter);
    for k=1:numel(adapterNames)
        name=adapterNames{k};
        if ~isfield(v.bfSim,name), error('bf:AdapterSetting','Unknown adapter setting: %s',name); end
        v.bfSim.(name)=settings.FirmwareAdapter.(name);
    end
end
bf.validateOptions(v.bfSim);
v.bfConfig=bf.calibratedConfig(v.bfConfig,v.bfSim);
v.bfRc=bf.receiverChannels(v.bfSim);
variables = v;
end
