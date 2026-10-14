function report=verifyEstimator()
%VERIFYESTIMATOR Test native gyro calibration, rotation tracking and isolation.
% This is a sensor fixture for a rotating, externally supported IMU. Its
% gravity vector must not be confused with free-flight specific force.
[first,truth,calibration]=runRotation(false);
[second,~,~]=runRotation(true);
error=atan2(sin(first(:,10:12)-truth),cos(first(:,10:12)-truth))*180/pi;
report=struct('StationaryFilteredGyroDegreesPerSecond',calibration(13:15)'*180/pi, ...
    'EulerRmsErrorDegrees',sqrt(mean(error.^2)), ...
    'EulerPeakErrorDegrees',max(abs(error)), ...
    'TruthStateIgnoredExactly',isequal(first,second),'Passed',false);
report.Passed=all(abs(report.StationaryFilteredGyroDegreesPerSecond)<0.05) ...
    && all(report.EulerRmsErrorDegrees<1) && report.TruthStateIgnoredExactly;
p=bf.paths(); folder=fullfile(p.Root,'test-output');
if ~isfolder(folder), mkdir(folder); end
save(fullfile(folder,'estimator-rotation.mat'),'first','truth','calibration','report');
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'estimator-verification.json'));
assert(report.Passed,'bf:EstimatorVerification','Native calibration, estimator or truth isolation check failed.');
disp(report);
end

function [trace,truth,calibration]=runRotation(changeTruth)
client=bf.Client(bf.hoverConfig()); cleanup=onCleanup(@()delete(client));
rc=[1500;1500;1000;1500;1000;1000;1000*ones(10,1)];
bias=[0.5;-0.4;0.3]*pi/180; x=zeros(12,1);
for k=0:500
    calibration=client.step(k/100,bias,gravity([5;-3;0]*pi/180),rc,x,8);
end
dt=0.001; time=(dt:dt:4)'; truth=zeros(numel(time),3); trace=zeros(numel(time),40);
for k=1:numel(time)
    t=time(k);
    e=[5+8*sin(0.8*t);-3+6*sin(0.6*t);20*sin(0.25*t)]*pi/180;
    rate=[6.4*cos(0.8*t);3.6*cos(0.6*t);5*cos(0.25*t)]*pi/180;
    body=[rate(1)-rate(3)*sin(e(2)); ...
        rate(2)*cos(e(1))+rate(3)*sin(e(1))*cos(e(2)); ...
        -rate(2)*sin(e(1))+rate(3)*cos(e(1))*cos(e(2))];
    if changeTruth, x=[100;200;-300;7;8;9;-0.2;0.4;-0.6;1;2;3]; end
    response=client.step(5+t,body+bias,gravity(e),rc,x,8);
    trace(k,:)=response'; truth(k,:)=e';
end
end

function force=gravity(e)
force=9.81*[sin(e(2));-sin(e(1))*cos(e(2));-cos(e(1))*cos(e(2))];
end
