function report=verifyPlants(duration)
%VERIFYPLANTS Run both existing plants with native firmware and check logs.
arguments
    duration (1,1) double {mustBePositive} = 10
end
p=bf.paths();
folder=fullfile(p.Root,'test-output');
if ~isfolder(folder), mkdir(folder); end
modelPath=fullfile(fileparts(p.Root),'1_Hover Simulation Work','lin_hover_sim.slx');
addpath(fullfile(fileparts(modelPath),'HoverWorkbench'));
report=struct([]);
for fidelity={'high','low'}
    settings=hover.defaultSettings(); settings.sim_fidelity=fidelity{1}; settings.t_sim=duration;
    [input,variables]=hover.makeSimulationInput(settings,modelPath);
    started=tic; output=sim(input); seconds=toc(started);
    signals=hover.collectSignals(output,variables);
    state=squeeze(output.state_output.signals.values);
    diagnostic=squeeze(output.betaflight_diagnostics.signals.values)';
    assert(size(state,2)==12 && size(diagnostic,2)==40,'Unexpected output shape.');
    assert(all(isfinite(state),'all') && all(isfinite(diagnostic),'all'),'Nonfinite plant or firmware output.');
    assert(all(diagnostic(:,31)==1),'Firmware disarmed during the hover run.');
    assert(all(diagnostic(:,34)==250) && all(diagnostic(:,35)==1e6*variables.bfSim.PidSampleTime),'Incorrect firmware loop rates.');
    assert(all(diagnostic(:,36)==4),'Incorrect motor count.');
    assert(all(diagnostic(:,6:9)>=1000 & diagnostic(:,6:9)<=1950,'all'),'Motor output outside configured limits.');
    assert(abs(output.tout(end)-duration)<1e-9,'Simulation ended early.');
    entry=struct('Fidelity',fidelity{1},'SimulatedSeconds',duration,'WallSeconds',seconds, ...
        'Samples',size(diagnostic,1),'SignalCount',numel(signals), ...
        'FinalEulerDegrees',state(end,7:9)*180/pi, ...
        'PeakEulerDegrees',max(abs(state(:,7:9)),[],1)*180/pi,'InterfacePassed',true, ...
        'HoverStable',max(abs(state(:,7:8)),[],'all')<30*pi/180);
    record=hover.saveRun(fullfile(folder,'runs'),settings,variables,output, ...
        struct('Label',['Betaflight verification - ' fidelity{1}],'Verification',entry));
    loaded=hover.loadRun(record.Folder);
    assert(isequal(loaded.Settings.Betaflight,settings.Betaflight),'Saved firmware configuration differs.');
    assert(numel(loaded.Signals)==numel(signals),'Saved signal count differs.');
    entry.RunFolder=record.Folder;
    report=[report;entry]; %#ok<AGROW>
    writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'plant-verification.json'));
    assert(entry.HoverStable,'Hover preset exceeded 30 degrees roll/pitch.');
    fprintf('%s plant passed: %.1f s simulated, %.1f s elapsed, Euler %s deg\n', ...
        entry.Fidelity,duration,seconds,mat2str(entry.FinalEulerDegrees,5));
end
end
