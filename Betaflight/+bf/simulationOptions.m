function options = simulationOptions(variables,config)
%SIMULATIONOPTIONS Physical adapter settings, separate from firmware settings.
arguments
    variables (1,1) struct
    config (1,1) struct = bf.hoverConfig()
end
options=struct('SampleTime',variables.Ts,'TrimPot',variables.u0, ...
    'InitialState',variables.X0,'WarmupSeconds',5,'ArmSettleSeconds',0.3,'SpoolupSeconds',1, ...
    'Timeout',5,'NavigationSensors',0,'RcRateHz',100,'UseKnownAccelCalibration',false, ...
    'CommandMode','angle','ThrottlePWM',variables.u0, ...
    'MotorOrder',[1 2 3 4],'TraceFile','', ...
    'ReceiverPWM',[],'StartupReceiverPWM',[]);
options.ReceiverLayout=bf.receiverLayout(config);
options.CalibrationGyro=zeros(3,1); options.CalibrationAccelBias=zeros(3,1);
options.Gravity=9.81;
if isfield(variables,'g'), options.Gravity=variables.g; end
if isfield(variables,'noise_true') && variables.noise_true
    if isfield(variables,'gyro') && isfield(variables.gyro,'bias')
        options.CalibrationGyro=variables.gyro.bias(:)*pi/180;
    end
    if isfield(variables,'accel') && isfield(variables.accel,'bias')
        options.CalibrationAccelBias=variables.accel.bias(:)*options.Gravity;
    end
end
% Approximate the inverse PWM endpoints and default linear throttle curve.
% Native integer receiver/throttle arithmetic leaves a trim error; the hover
% example uses a separately measured receiver pulse. Nonlinear curves and
% output-limit changes require re-trimming against the native firmware.
schema=bf.parseCliSettings(config.SchemaText);
item=schema(strcmp({schema.Name},'pid_process_denom'));
options.PidSampleTime=str2double(bf.settingValue(config.CLI,item(1),0))/4000;
names={'min_command','motor_idle','max_throttle','min_check'};
v=zeros(1,4);
for k=1:4
    item=schema(strcmp({schema.Name},names{k}));
    v(k)=str2double(bf.settingValue(config.CLI,item(1),0));
end
low=v(1)+0.1*v(2);
options.ThrottlePWM=v(4)+(2000-v(4))*(variables.u0-low)/(v(3)-low);
if options.ThrottlePWM<1000 || options.ThrottlePWM>2000
    error('bf:TrimRange','Hover trim is outside the configured motor range.');
end
% rxrange is applied by native firmware before throttle and arming checks.
range=options.ReceiverLayout.Ranges(4,:);
options.MinThrottlePWM=range(1);
options.ThrottlePWM=range(1)+(options.ThrottlePWM-1000)*diff(range)/1000;
end
