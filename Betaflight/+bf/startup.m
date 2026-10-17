function [epoch,response]=startup(client,options)
%STARTUP Calibrate and arm native firmware using sensor-rate IMU samples.
% The supported, stationary fixture precedes free flight. It supplies gravity
% and sensor bias/noise, never an estimator quaternion or true attitude reset.
bf.validateOptions(options);
dt=options.SampleTime;
warmCount=ceil(options.WarmupSeconds/dt);
armCount=ceil(options.ArmSettleSeconds/dt);
spoolCount=ceil(options.SpoolupSeconds/dt);
lastTick=warmCount+armCount+spoolCount;
time=(0:lastTick)*dt;
gyro=bf.calibrationGyroSamples(options,time);
x=options.InitialState;
a=options.Gravity*[sin(x(8));-sin(x(7))*cos(x(8));-cos(x(7))*cos(x(8))] ...
    +options.CalibrationAccelBias;
reference=zeros(12,1); reference(7:8)=x(7:8);
disarmed=bf.startupChannels(options,false);
armed=bf.startupChannels(options,true);
flight=bf.receiverChannels(options);
lastFrame=-1;
for tick=0:lastTick
    flags=options.NavigationSensors;
    frame=floor((time(tick+1)+1e-10)*options.RcRateHz);
    % Force a receiver frame at phase transitions, even for unusual timing.
    if frame~=lastFrame || tick==warmCount+1 || tick==warmCount+armCount+1
        flags=flags+8; lastFrame=frame;
    end
    if tick<=warmCount
        rc=disarmed;
    elseif tick<=warmCount+armCount
        rc=armed;
    else
        rc=flight;
        if strcmp(options.CommandMode,'angle'), flags=flags+16; end
        if strcmp(options.CommandMode,'rate'), flags=flags+32; end
    end
    response=client.step(time(tick+1),gyro(:,tick+1),a,rc,x,flags,reference);
    if tick==warmCount && response(31)~=0
        error('bf:CalibrationArmed','Calibration receiver pulses activated ARM. Check the disarmed receiver column.');
    end
    if tick==warmCount+armCount
        checkArmed(response,options,client.Folder);
    end
end
if response(31)~=1, error('bf:SpoolupDisarmed','Firmware disarmed during throttle settling.'); end
epoch=(lastTick+1)*dt;
end

function checkArmed(response,options,folder)
if response(31)~=1
    error('bf:NotArmed','Betaflight did not arm after calibration (disable mask %.0f). Firmware log: %s',response(32),folder);
end
if strcmp(options.CommandMode,'angle') && ~bitand(uint32(response(33)),uint32(1))
    error('bf:AngleNotActive','ANGLE mode did not activate. Check AUX ranges or receiver pulses.');
end
if strcmp(options.CommandMode,'rate') && bitand(uint32(response(33)),uint32(3))
    error('bf:RateModeActive','ANGLE or HORIZON is active with a rate reference. Check receiver pulses.');
end
if response(36)~=4, error('bf:MotorCount','The current plant requires a four-motor mixer.'); end
if response(34)~=250 || abs(response(35)*1e-6-options.PidSampleTime)>1e-10
    error('bf:LoopRate','Native gyro/PID periods disagree with the requested configuration (%.0f/%.0f us).',response(34),response(35));
end
end
