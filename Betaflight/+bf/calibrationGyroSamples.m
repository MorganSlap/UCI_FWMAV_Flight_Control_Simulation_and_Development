function samples=calibrationGyroSamples(options,time)
%CALIBRATIONGYROSAMPLES Stationary gyro with the flight sensor's white noise.
% Native firmware averages quantized ADC readings to estimate the offset.
% A constant, already-rounded startup bias gives the wrong mean when flight
% noise spans ADC bins. Generate noise before quantization, at sensor rate.
% Match the model's common-axis noise; use a local stream, leaving rng alone.
time=time(:)';
samples=repmat(options.CalibrationGyro(:),1,numel(time));
if isempty(time) || ~isfield(options,'CalibrationGyroNoiseStd') || options.CalibrationGyroNoiseStd==0
    return
end
index=floor((time+1e-12)/options.CalibrationGyroSampleTime)+1;
stream=RandStream('mt19937ar','Seed',options.CalibrationSeed);
noise=options.CalibrationGyroNoiseStd*randn(stream,1,max(index));
samples=samples+noise(index);
end
