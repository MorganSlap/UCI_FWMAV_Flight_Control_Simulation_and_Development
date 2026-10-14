function settings = hoverExample(kind)
%HOVEREXAMPLE Reproducible IMU-only, trimmed-throttle flight examples.
% No altitude, position or heading measurement is supplied to the firmware.
% The throttle was measured against the pinned firmware and stock plant;
% re-trim it after changing mass, thrust coefficients or firmware endpoints.
arguments
    kind (1,1) string {mustBeMember(kind,["level","recovery"])} = "level"
end
settings=hover.defaultSettings();
settings.t_sim=10;
settings.sim_fidelity='high';
settings.noise_true=true;
settings.X0=zeros(12,1);
settings.Xref=zeros(12,1);
settings.FirmwareAdapter=struct('ThrottlePWM',1859,'NavigationSensors',0,'UseKnownAccelCalibration',true, ...
    'CommandMode','angle','SpoolupSeconds',1);
schema=bf.parseCliSettings(settings.Betaflight.SchemaText);
item=schema(strcmp({schema.Name},'imu_dcm_kp'));
settings.Betaflight=bf.setSetting(settings.Betaflight,item(1),'250',0);
if kind=="recovery"
    settings.X0(7:8)=[5;-3]*pi/180;
end
end
