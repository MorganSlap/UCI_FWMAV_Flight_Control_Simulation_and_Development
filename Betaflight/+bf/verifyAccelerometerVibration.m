function report=verifyAccelerometerVibration()
%VERIFYACCELEROMETERVIBRATION Isolate native attitude bias from zero-mean vibration.
% A constrained level fixture feeds perfect gyro and 24 Hz acceleration at the
% physical sensor rate. Motors do not move the fixture. No attitude truth is
% supplied to the estimator. Only upstream filter settings and input axes vary.
p=bf.paths(); addpath(fullfile(fileparts(p.Root),'1_Hover Simulation Work','HoverWorkbench'));
settings=hover.hoverExample(); settings.noise_true=false;
variables=hover.buildVariables(settings); options=variables.bfSim;
schema=bf.parseCliSettings(variables.bfConfig.SchemaText);
cutoffs=[25 5 25 25]; axes=[1 1 1;1 1 1;1 1 0;0 0 1];
labels={'all-axes-25Hz','all-axes-5Hz','horizontal-only-25Hz','vertical-only-25Hz'};
caseTemplate=struct('Name','','CutoffHz',0,'VibrationAxes',zeros(1,3), ...
    'MeanEstimatedEulerDegrees',zeros(1,3),'FinalEstimatedEulerDegrees',zeros(1,3), ...
    'PeakToPeakEulerDegrees',zeros(1,3));
report=struct('FirmwareBinarySHA256',bf.binaryHash(),'FrequencyHz',24, ...
    'AmplitudeG',0.1,'Cases',repmat(caseTemplate,1,numel(cutoffs)));
for caseIndex=1:numel(cutoffs)
    config=variables.bfConfig;
    values={'acc_lpf_hz',num2str(cutoffs(caseIndex));'imu_dcm_kp','2500';'imu_dcm_ki','0'};
    for k=1:size(values,1)
        item=schema(strcmp({schema.Name},values{k,1}));
        config=bf.setSetting(config,item(1),values{k,2},0);
    end
    client=bf.Client(config); cleanup=onCleanup(@()delete(client));
    epoch=bf.startup(client,options); rc=bf.receiverChannels(options);
    time=(0:options.SampleTime:25)'; angle=zeros(numel(time),3);
    for k=1:numel(time)
        sampledTime=floor(time(k)*settings.accel.sample_rate+1e-8)/settings.accel.sample_rate;
        a=[0;0;-options.Gravity]+axes(caseIndex,:)'*(0.1*options.Gravity*sin(2*pi*24*sampledTime));
        flags=16+8*(mod(k-1,round(1/(options.RcRateHz*options.SampleTime)))==0);
        response=client.step(epoch+time(k),zeros(3,1),a,rc,zeros(12,1),flags,zeros(12,1));
        angle(k,:)=response(10:12)'*180/pi;
    end
    late=time>=20;
    report.Cases(caseIndex)=struct('Name',labels{caseIndex},'CutoffHz',cutoffs(caseIndex), ...
        'VibrationAxes',axes(caseIndex,:),'MeanEstimatedEulerDegrees',mean(angle(late,:)), ...
        'FinalEstimatedEulerDegrees',angle(end,:),'PeakToPeakEulerDegrees',max(angle(late,:))-min(angle(late,:)));
    clear cleanup
    writelines(jsonencode(report,PrettyPrint=true),fullfile(p.Root,'test-output','accelerometer-vibration.json'));
    disp(report.Cases(caseIndex));
end
report.Passed=max(abs(report.Cases(1).MeanEstimatedEulerDegrees(1:2)))>0.08 ...
    && max(abs(report.Cases(2).MeanEstimatedEulerDegrees(1:2)))<0.05 ...
    && max(abs(report.Cases(3).MeanEstimatedEulerDegrees(1:2)))<0.05 ...
    && max(abs(report.Cases(4).MeanEstimatedEulerDegrees(1:2)))<0.05;
writelines(jsonencode(report,PrettyPrint=true),fullfile(p.Root,'test-output','accelerometer-vibration.json'));
assert(report.Passed,'bf:VibrationFixture','Unexpected vibration fixture result; inspect saved measurements.');
end
