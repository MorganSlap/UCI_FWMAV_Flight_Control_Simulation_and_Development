function upgradeFlightInterfaces()
%UPGRADEFLIGHTINTERFACES Correct the plant/IMU boundary and sensor noise units.
% Changes are explicit and repeatable; refuses to overwrite unsaved edits.
p=bf.paths(); model='lin_hover_sim';
path=fullfile(fileparts(p.Root),'1_Hover Simulation Work',[model '.slx']);
if bdIsLoaded(model) && strcmp(get_param(model,'Dirty'),'on')
    error('bf:UnsavedModel','Save or discard unsaved model edits before upgrading the sensor interface.');
end
load_system(path);
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',[model '/MATLAB Function']);
names={'rho','CDx','CDy','CDz','Ax','Ay','Az','imu_nonlinear'};
for k=1:numel(names)
    item=chart.find('-isa','Stateflow.Data','Name',names{k});
    if isempty(item), item=Stateflow.Data(chart); item.Name=names{k}; end
    item.Scope='Parameter';
end
chart.Script=sprintf(['function [accel_ideal,gyro_ideal]=ideal_imu_measurements(x,du,m,g,C11,Xu,Yv,Zw,rho,CDx,CDy,CDz,Ax,Ay,Az,imu_nonlinear)\n' ...
    '%%#codegen\n' ...
    '[accel_ideal,gyro_ideal]=bf.idealImu(x,du,m,g,C11,[Xu;Yv;Zw], ...\n' ...
    '    0.5*rho*[CDx*Ax;CDy*Ay;CDz*Az],imu_nonlinear);\n' ...
    'end\n']);
for name={'noise_true','sim_fidelity'}
    old=chart.find('-isa','Stateflow.Data','Name',name{1});
    if ~isempty(old), delete(old); end
end
% Moment arm is a length. The original block accidentally supplied mass.
set_param([model '/Lin vs NonLin Dynamics/Non Linear Simulation/Constant3'],'Value','S');
for kind={'Accel','Gyro'}
    isAccel=strcmp(kind{1},'Accel');
    if isAccel, root=[model '/Accelerometer Model']; variable='accel'; scale='g';
    else, root=[model '/Gyro Model']; variable='gyro'; scale='(pi/180)'; end
    set_param([root '/' kind{1} ' Bias'],'Value',[variable '.bias*' scale], ...
        'SampleTime',['1/' variable '.sample_rate']);
    set_param([root '/' kind{1} ' Noise Scaling'],'Gain',[variable '.vibration*' scale]);
    set_param([root '/' kind{1} ' Sample Rate'],'SampleTime',['1/' variable '.sample_rate']);
    noise=[root '/' kind{1} newline 'White Noise'];
    % Band-Limited White Noise divides its power parameter by sample time.
    % Convert the desired per-sample variance (density^2 * bandwidth) to power.
    power=sprintf('ones(3,1)*(%s.noise_density*%s)^2*%s.BW/%s.sample_rate',variable,scale,variable,variable);
    set_param(noise,'Cov',power,'Ts',['1/' variable '.sample_rate']);
end
save_system(model);
end
