function enableImuLogging()
%ENABLEIMULOGGING Save ideal and measured IMU signals for noise diagnostics.
p=bf.paths(); model='lin_hover_sim';
load_system(fullfile(fileparts(p.Root),'1_Hover Simulation Work',[model '.slx']));
sources={'MATLAB Function',1,'imu_accel_ideal';'MATLAB Function',2,'imu_gyro_ideal'; ...
    'Accelerometer Model',1,'imu_accel_measured';'Gyro Model',1,'imu_gyro_measured'};
for k=1:size(sources,1)
    ports=get_param([model '/' sources{k,1}],'PortHandles');
    set_param(ports.Outport(sources{k,2}),'DataLogging','on', ...
        'DataLoggingNameMode','Custom','DataLoggingName',sources{k,3});
end
set_param(model,'SignalLogging','on','SignalLoggingName','logsout');
save_system(model);
end
