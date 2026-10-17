function validateOptions(options)
%VALIDATEOPTIONS Reject invalid timing and plant boundary configuration early.
validateattributes(options.SampleTime,{'double'},{'real','finite','scalar','positive'});
assert(abs(options.SampleTime-1/4000)<1e-12,'bf:GyroSampleTime', ...
    'The SITL gyro and sensor interface run at 4000 Hz. Keep fs=4000; change pid_process_denom to set the PID/mixer rate.');
validateattributes(options.PidSampleTime,{'double'},{'real','finite','scalar','>=',1/4000,'<=',16/4000});
assert(abs(options.PidSampleTime*4000-round(options.PidSampleTime*4000))<1e-10, ...
    'bf:PidSampleTime','PID period must be a whole multiple of 250 us.');
validateattributes(options.TrimPot,{'double'},{'real','finite','scalar'});
validateattributes(options.InitialState,{'double'},{'real','finite','size',[12 1]});
validateattributes(options.RcRateHz,{'double'},{'real','finite','scalar','positive','<=',2000});
validateattributes(options.WarmupSeconds,{'double'},{'real','finite','scalar','positive'});
validateattributes(options.ArmSettleSeconds,{'double'},{'real','finite','scalar','positive'});
validateattributes(options.SpoolupSeconds,{'double'},{'real','finite','scalar','nonnegative'});
validateattributes(options.Gravity,{'double'},{'real','finite','scalar','positive'});
validateattributes(options.CalibrationGyro,{'double'},{'real','finite','size',[3 1]});
validateattributes(options.CalibrationAccelBias,{'double'},{'real','finite','size',[3 1]});
if isfield(options,'CalibrationGyroNoiseStd')
    validateattributes(options.CalibrationGyroNoiseStd,{'double'},{'real','finite','scalar','nonnegative'});
    validateattributes(options.CalibrationGyroSampleTime,{'double'},{'real','finite','scalar','positive'});
    validateattributes(options.CalibrationSeed,{'double'},{'real','finite','scalar','integer','>=',0,'<=',2^32-1});
end
validateattributes(options.UseKnownAccelCalibration,{'logical','double'},{'scalar','binary'});
validateattributes(options.Timeout,{'double'},{'real','finite','scalar','positive'});
validateattributes(options.ThrottlePWM,{'double'},{'real','finite','scalar','>=',750,'<=',2250});
validateattributes(options.MinThrottlePWM,{'double'},{'real','finite','scalar','>=',750,'<=',2250});
for name={'ReceiverPWM','StartupReceiverPWM'}
    if ~isempty(options.(name{1}))
        validateattributes(options.(name{1}),{'double'}, ...
            {'real','finite','vector','numel',16,'>=',750,'<=',2250});
    end
end
validateattributes(options.NavigationSensors,{'double'},{'real','finite','scalar','integer','>=',0,'<=',7});
assert(isequal(sort(options.MotorOrder(:)),(1:4)'),'bf:MotorOrder','MotorOrder must be a permutation of 1:4.');
assert(ismember(options.CommandMode,{'angle','rate','receiver'}),'bf:CommandMode','Unknown command mode.');
if isfield(options,'ReferenceSchedule') && ~isempty(options.ReferenceSchedule)
    schedule=options.ReferenceSchedule;
    validateattributes(schedule,{'double'},{'real','finite','2d','ncols',4});
    assert(schedule(1,1)>=0 && all(diff(schedule(:,1))>0),'bf:ReferenceTime', ...
        'Command times must be nonnegative and strictly increasing.');
    assert(~strcmp(options.CommandMode,'receiver'),'bf:ReferenceMode', ...
        'Command sequences require Angle or Rate reference mode. Clear the sequence before selecting Raw receiver.');
end
end
