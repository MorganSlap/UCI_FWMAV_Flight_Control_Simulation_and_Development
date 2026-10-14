function report=verifyPlantReplay(duration,divider)
%VERIFYPLANTREPLAY Check complete Simulink exchanges against fresh firmware.
% Includes stationary calibration, arming, then both original plant variants.
% Traces contain only configuration and numeric I/O, never source or models.
arguments
    duration (1,1) double {mustBePositive} = 1
    divider (1,1) double {mustBeInteger,mustBePositive,mustBeLessThanOrEqual(divider,16)} = 4
end
p=bf.paths(); modelFolder=fullfile(fileparts(p.Root),'1_Hover Simulation Work');
addpath(fullfile(modelFolder,'HoverWorkbench'));
folder=tempname(fullfile(p.Root,'test-output')); mkdir(folder);
report=struct([]);
for fidelity={'high','low'}
    settings=hover.defaultSettings(); settings.sim_fidelity=fidelity{1}; settings.t_sim=duration;
    schema=bf.parseCliSettings(settings.Betaflight.SchemaText);
    settings.Betaflight=bf.setSetting(settings.Betaflight, ...
        schema(strcmp({schema.Name},'pid_process_denom')),num2str(divider));
    path=fullfile(folder,[fidelity{1} '.bin']);
    settings.FirmwareAdapter.TraceFile=path;
    [input,variables]=hover.makeSimulationInput(settings,fullfile(modelFolder,'lin_hover_sim.slx'));
    output=sim(input);
    diagnostic=squeeze(output.betaflight_diagnostics.signals.values)';
    assert(all(diagnostic(:,34)==250) && all(diagnostic(:,35)==250*divider),'Incorrect loop rates.');
    assert(all(diagnostic(:,31)==1) && all(isfinite(diagnostic),'all'),'Firmware interface failed.');
    assert(size(diagnostic,1)==round(duration*4000)+1,'Sensor interface did not sample at 4 kHz.');
    replay=bf.replayTrace(path);
    % Cross-transport comparison is performed on a complete plant trace too.
    if strcmp(fidelity{1},'low'), alternate=bf.replayTrace(path,'matlab');
    else, alternate=struct(); end
    metadata=struct('Label',['Native replay - ' fidelity{1}],'Replay',replay);
    record=hover.saveRun(fullfile(folder,'runs'),settings,variables,output,metadata);
    loaded=hover.loadRun(record.Folder);
    assert(isequaln(loaded.Variables.bfSim,variables.bfSim),'Saved adapter settings differ.');
    entry=struct('Fidelity',fidelity{1},'SimulatedSeconds',duration,'Divider',divider, ...
        'GyroHz',4000,'PidAndMixerHz',4000/divider,'Replay',replay, ...
        'AlternateTransportReplay',alternate,'RunFolder',record.Folder,'Passed',true);
    report=[report;entry]; %#ok<AGROW>
    writelines(jsonencode(report,PrettyPrint=true),fullfile(p.Root,'test-output','plant-replay-verification.json'));
    fprintf('%s plant replay: %d exchanges exactly equal, gyro 4000 Hz / PID %.4g Hz.\n', ...
        fidelity{1},replay.Exchanges,4000/divider);
end
end
