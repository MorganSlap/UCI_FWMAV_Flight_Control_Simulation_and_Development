function report=verifyTiming()
%VERIFYTIMING Exercise native loop dividers and every supported rate curve.
% Sensors arrive at 4 kHz in all cases; the real scheduler must gate PID and
% motor updates independently. Non-default map/ranges and yaw reversal are
% exercised through the same reference inversion used by the Simulink block.
base=bf.hoverConfig(); schema=bf.parseCliSettings(base.SchemaText);
dividers=1:16;
types={'BETAFLIGHT','RACEFLIGHT','KISS','ACTUAL','QUICK'};
report=struct([]);
for test=1:numel(dividers)
    ratesType=types{1+mod(test-1,numel(types))};
    config=bf.setSetting(base,schema(strcmp({schema.Name},'pid_process_denom')),num2str(dividers(test)));
    config=bf.setSetting(config,schema(strcmp({schema.Name},'rates_type')),ratesType,1);
    config=bf.selectProfile(config,'rateprofile',1);
    config=bf.setSetting(config,schema(strcmp({schema.Name},'yaw_control_reversed')),'ON');
    [~,config]=bf.commandSection(config,{'map'},'map TAER4321');
    [~,config]=bf.commandSection(config,{'rxrange'}, ...
        sprintf('rxrange 0 900 2100\nrxrange 1 950 2050\nrxrange 2 1000 2000\nrxrange 3 900 2100'));
    options=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),config);
    options.CommandMode='rate'; bf.validateOptions(options);
    rc=bf.receiverChannels(options); layout=options.ReceiverLayout;
    rc(layout.Throttle)=options.MinThrottlePWM; rc(layout.Arm)=layout.ArmOff;
    client=bf.Client(config); cleanup=onCleanup(@()delete(client));
    state=zeros(12,1); acceleration=[0;0;-9.80665];
    for k=0:500, client.step(k/100,zeros(3,1),acceleration,rc,state,8); end
    rc(layout.Arm)=layout.ArmOn;
    for k=501:530, response=client.step(k/100,zeros(3,1),acceleration,rc,state,8); end
    assert(response(31)==1,'Native firmware did not arm (disable mask %.0f).',response(32));
    rc(layout.Throttle)=options.ThrottlePWM;
    reference=zeros(12,1); reference(10:12)=[30;-20;10]*pi/180;
    trace=zeros(2000,40);
    for k=1:size(trace,1)
        gyro=[0.02+k*0.0001;0;0];
        flags=32+8*double(mod(k-1,40)==0);
        trace(k,:)=client.step(5.3+k/4000,gyro,acceleration,rc,state,flags,reference)';
    end
    assert(all(trace(:,34)==250) && all(trace(:,35)==250*dividers(test)), ...
        'Native gyro/PID periods disagree with configured divider.');
    assert(all(trace(:,31)==1),'Native firmware disarmed during timing test.');
    assert(max(abs(trace(end,16:18)'-reference(10:12)))<2*pi/180, ...
        'Rate curve, channel map, endpoint calibration or yaw reversal inversion failed.');
    tail=trace(1001:end,:);
    updates=find(diff(tail(:,19))~=0);
    motorUpdates=find(any(diff(tail(:,6:9))~=0,2));
    assert(numel(updates)>0.9*(size(tail,1)-1)/dividers(test), ...
        'Too few native PID updates for the requested frequency.');
    assert(all(mod(diff(updates),dividers(test))==0),'PID changed outside its native task cadence.');
    assert(all(ismember(motorUpdates,updates)),'Motor output changed outside the native PID/mixer task.');
    entry=struct('Divider',dividers(test),'GyroHz',4000,'PidAndMixerHz',4000/dividers(test), ...
        'RatesType',ratesType,'RateProfile',1,'NativePidUpdates',numel(updates), ...
        'NativeMotorUpdates',numel(motorUpdates),'RemappedReceiverPassed',true,'Passed',true);
    report=[report;entry]; %#ok<AGROW>
    fprintf('Divider %d, %s rates: %d PID and %d motor updates in the checked interval.\n', ...
        entry.Divider,entry.RatesType,entry.NativePidUpdates,entry.NativeMotorUpdates);
    clear cleanup
end
folder=fullfile(bf.paths().Root,'test-output');
if ~isfolder(folder), mkdir(folder); end
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'timing-verification.json'));
end
