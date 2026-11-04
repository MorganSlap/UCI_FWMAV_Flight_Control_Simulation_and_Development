function exportDesktopDefaults()
%EXPORTDESKTOPDEFAULTS Export native CLI and physical defaults; no source edits.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'Betaflight'),fullfile(root,'1_Hover Simulation Work','HoverWorkbench'));
s=hover.hoverExample(); v=hover.buildVariables(s);
c=struct('version',1,'name','Noisy trimmed hover','duration',10,'realtime',false, ...
    'throttle',v.bfSim.ThrottlePWM,'command_mode','angle','noise',true,'drag',true, ...
    'warmup',5,'arm_settle',0.3,'spoolup',1,'log_hz',4000,'timing_profile','BMI270', ...
    'initial',zeros(1,12),'reference',zeros(1,12),'reference_time',0, ...
    'seed',v.seed,'known_accel_calibration',true);
names={'m','g','S','rho','C11','C21','Ax','Ay','Az','Aomega','CDx','CDy','CDz','CDw','tau_wing'};
for k=1:numel(names), c.plant.(names{k})=v.(names{k}); end
c.plant.inertia=[v.Ix v.Iy v.Iz];
c.gyro=struct('density',v.gyro.noise_density,'bandwidth',v.gyro.BW, ...
    'bias',v.gyro.bias(:)','vibration',v.gyro.vibration,'sample_rate',3200);
c.accel=struct('density',v.accel.noise_density,'bandwidth',v.accel.BW, ...
    'bias',v.accel.bias(:)','vibration',v.accel.vibration,'sample_rate',800);
c.firmware_cli=v.bfConfig.CLI;
c.firmware_commit='c78d9e7bd24ef60f4324dffde11df26c53d4f29f';
c.receiver_flight=bf.receiverChannels(v.bfSim)';
c.receiver_disarmed=bf.startupChannels(v.bfSim,false)';
c.receiver_armed=bf.startupChannels(v.bfSim,true)';
c.throttle_channel=v.bfSim.ReceiverLayout.Throttle;
c.angle_channel=v.bfSim.ReceiverLayout.Angle;
c.angle_on=v.bfSim.ReceiverLayout.AngleOn;
c.angle_off=v.bfSim.ReceiverLayout.AngleOff;
folder=fullfile(root,'DesktopSIL','presets'); if ~isfolder(folder), mkdir(folder); end
writeJSON(fullfile(folder,'noisy_hover.json'),c);
c.name='Noisy roll recovery'; c.initial(7:8)=[5 -3];
writeJSON(fullfile(folder,'noisy_recovery.json'),c);
end

function writeJSON(path,value)
f=fopen(path,'w'); cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s\n',jsonencode(value,PrettyPrint=true));
end
