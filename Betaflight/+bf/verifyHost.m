function report=verifyHost()
%VERIFYHOST Exercise actual firmware calibration, I/O, reset and failsafe.
config=bf.hoverConfig();
[first,a]=runTrace(config);
[second,b]=runTrace(config,'matlab');
assert(isequal(first,second),'Fresh firmware processes produced different results for identical inputs.');
schema=bf.parseCliSettings(config.SchemaText);
changed=bf.setSetting(config,schema(strcmp({schema.Name},'p_roll')),'20',0);
[higherP,c]=runTrace(changed);
assert(abs(higherP(end,19)/first(end,19)-2)<1e-5,'Native P term did not follow configured gain.');
changed=bf.setSetting(config,schema(strcmp({schema.Name},'f_roll')),'100',0);
[withF,d]=runTrace(changed);
assert(all(first(:,22)==0),'F was enabled in the zero-feedforward preset.');
assert(max(abs(withF(:,22)))>0.01,'Native feedforward did not respond to receiver setpoint changes.');
yaw=verifyYaw(config,schema);
report=struct('Passed',true,'ReplayExactlyEqual',true,'Runs',[a b c d], ...
    'PGainRatio',higherP(end,19)/first(end,19), ...
    'PeakFeedforward',max(abs(withF(:,22))),'Yaw',yaw);
p=bf.paths(); folder=fullfile(p.Root,'test-output');
if ~isfolder(folder), mkdir(folder); end
save(fullfile(folder,'host-traces.mat'),'first','second','higherP','withF','report');
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'host-verification.json'));
disp(report);
end

function summary=verifyYaw(config,schema)
config=bf.setSetting(config,schema(strcmp({schema.Name},'p_yaw')),'10',0);
client=bf.Client(config); cleanup=onCleanup(@()delete(client));
x=zeros(12,1); rc=[1500;1500;1000;1500;1000;1000;1000*ones(10,1)];
for k=0:500, client.step(k/100,zeros(3,1),[0;0;-9.80665],rc,x,8); end
rc(5)=2000;
for k=501:530, client.step(k/100,zeros(3,1),[0;0;-9.80665],rc,x,8); end
rc(3)=1858; reference=zeros(12,1); reference(12)=20*pi/180;
for k=1:100
    response=client.step(5.3+k/100,[0;0;10*pi/180],[0;0;-9.80665],rc,x,40,reference);
end
assert(abs(response(12)-10*pi/180)<pi/180,'Euler yaw sign disagrees with positive FRD yaw rate.');
assert(response(6)>response(7) && response(8)>response(9),'Yaw motor pattern does not match the linear plant.');
summary=struct('HeadingDegrees',response(12)*180/pi,'MotorPatternCorrect',true);
end

function [trace,summary]=runTrace(config,transport)
if nargin<2, transport='java'; end
client=bf.Client(config,5,transport); cleanup=onCleanup(@()delete(client));
x=zeros(12,1); x(7:8)=[5;-3]*pi/180;
acc=9.80665*[sin(x(8));-sin(x(7))*cos(x(8));-cos(x(7))*cos(x(8))];
rc=[1500;1500;1000;1500;1000;1000;1000*ones(10,1)];
for k=0:500
    response=client.step(k/100,zeros(3,1),acc,rc,x,8);
end
assert(response(31)==0 && response(32)==0,'Calibration or arming preconditions failed.');
assert(max(abs(response(10:11)-x(7:8)))<pi/180,'Accelerometer attitude signs or convergence are incorrect.');
rc(5)=2000;
for k=501:530, response=client.step(k/100,zeros(3,1),acc,rc,x,8); end
assert(response(31)==1 && response(36)==4,'Native receiver arming failed.');
assert(response(34)==250 && response(35)==250,'Unexpected native gyro/PID period.');
rc(3)=1858;
reference=zeros(12,1); reference(10:12)=[30;-20;10]*pi/180;
gyro=[0.1;0.2;-0.3];
trace=zeros(80,40);
for k=1:80
    response=client.step(5.3+k/100,gyro,acc,rc,x,40,reference);
    trace(k,:)=response';
end
assert(max(abs(response(13:15)-gyro))<0.002,'Gyroscope FRD scaling/sign conversion failed.');
assert(max(abs(response(16:18)-reference(10:12)))<2*pi/180,'Native rate inversion or receiver smoothing failed.');
assert(response(9)>response(7),'Positive roll correction must increase left relative to right.');
assert(response(6)<response(8),'Negative pitch correction must decrease front relative to rear.');
assert(all(response(6:9)>=1055 & response(6:9)<=1950),'Native mixer limits failed.');
assert(all(trace(:,31)==1),'Firmware unexpectedly disarmed.');
% A new sample time with no receiver-frame flag lets native RX failsafe run.
for k=1:400
    response=client.step(6.1+k/100,zeros(3,1),acc,rc,x,0);
end
assert(response(31)==0,'Missing receiver frames did not trigger native failsafe/disarm.');
assert(all(response(6:9)==1000),'Disarmed output is not the configured min_command.');
summary=struct('Armed',true,'GyroAndMotorSigns',true,'NativeFailsafe',true, ...
    'NativeLoopPeriodMicroseconds',250,'Transport',transport,'RuntimeFolder',client.Folder);
end
