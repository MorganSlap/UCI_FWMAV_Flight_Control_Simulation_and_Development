function report=verifyEstimatorBoundary()
%VERIFYESTIMATORBOUNDARY Independent sensor-sign and calibration fixtures.
% Supported tilt tests use -R'*g; gyro-only tests use zero acceleration so
% accelerometer feedback cannot conceal a gyro sign error. No plant truth
% angle is sent to the estimator. All results come from the native process.
p=bf.paths(); addpath(fullfile(fileparts(p.Root),'1_Hover Simulation Work','HoverWorkbench'));
config=bf.hoverConfig();
tilts=[10 0;-10 0;0 10;0 -10];
measured=zeros(4,2);
rc=[1500;1500;1000;1500;1000;1000;1000*ones(10,1)];
for j=1:4
    client=bf.Client(config); cleanup=onCleanup(@()delete(client));
    e=tilts(j,:)*pi/180;
    a=9.80665*[sin(e(2));-sin(e(1))*cos(e(2));-cos(e(1))*cos(e(2))];
    for k=0:500, response=client.step(k/100,zeros(3,1),a,rc,zeros(12,1),8); end
    measured(j,:)=response(10:11)'*180/pi;
    clear cleanup
end
gyroMeasured=zeros(6,3); gyroExpected=zeros(6,3);
for j=1:6
    axis=ceil(j/2); direction=1-2*mod(j+1,2);
    client=bf.Client(config); cleanup=onCleanup(@()delete(client));
    for k=0:500, client.step(k/100,zeros(3,1),[0;0;-9.80665],rc,zeros(12,1),8); end
    w=zeros(3,1); w(axis)=direction*10*pi/180;
    for k=1:2000, response=client.step(5+k/1000,w,zeros(3,1),rc,zeros(12,1),8); end
    gyroExpected(j,axis)=direction*20;
    gyroMeasured(j,:)=response(10:12)'*180/pi;
    if j==6
        for k=1:250
            response=client.step(7+k/1000,[100;-100;100]*pi/180,zeros(3,1),rc,zeros(12,1),8);
        end
        scaledRate=response(13:15)'*180/pi;
    end
    clear cleanup
end
variables=hover.buildVariables(hover.hoverExample());
offsets=zeros(2,3);
for j=1:2
    options=variables.bfSim;
    if j==1, options.CalibrationGyroNoiseStd=0; end
    client=bf.Client(variables.bfConfig); cleanup=onCleanup(@()delete(client));
    epoch=bf.startup(client,options);
    % Zero test input exposes the learned native offset after filter settling.
    for k=0:1000
        response=client.step(epoch+k*options.SampleTime,zeros(3,1),[0;0;-9.81], ...
            bf.receiverChannels(options),zeros(12,1),8);
    end
    offsets(j,:)=-response(13:15)'*180/pi;
    clear cleanup
end
report=struct('SupportedTiltDegrees',tilts,'SupportedEstimateDegrees',measured, ...
    'GyroOnlyExpectedDegrees',gyroExpected,'GyroOnlyEstimateDegrees',gyroMeasured, ...
    'RequestedRateDegreesPerSecond',[100 -100 100],'MeasuredRateDegreesPerSecond',scaledRate, ...
    'TrueGyroBiasDegreesPerSecond',variables.gyro.bias', ...
    'OldConstantCalibrationDegreesPerSecond',offsets(1,:), ...
    'NoisyCalibrationDegreesPerSecond',offsets(2,:), ...
    'FirmwareBinarySHA256',bf.binaryHash());
report.Passed=max(abs(tilts-measured),[],'all')<0.3 ...
    && max(abs(gyroExpected-gyroMeasured),[],'all')<0.3 ...
    && max(abs(scaledRate-[100 -100 100]))<0.031 ...
    && max(abs(offsets(2,:)-variables.gyro.bias'))<0.01;
folder=fullfile(p.Root,'test-output'); if ~isfolder(folder), mkdir(folder); end
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'estimator-boundary.json'));
disp(report);
assert(report.Passed,'bf:EstimatorBoundary','Sensor sign or native calibration fixture failed.');
end
