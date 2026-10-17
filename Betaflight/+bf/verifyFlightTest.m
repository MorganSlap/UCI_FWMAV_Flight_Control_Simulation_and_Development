function [report,record]=verifyFlightTest(kind,fidelity,capture)
%VERIFYFLIGHTTEST Run a changing command through the plant and native firmware.
% Criteria establish adapter operation and bounded flight, not tuned tracking.
arguments
    kind (1,1) string {mustBeMember(kind,["angle","rate"])} = "angle"
    fidelity (1,1) string {mustBeMember(fidelity,["high","low"])} = "high"
    capture (1,1) logical = false
end
p=bf.paths(); modelPath=fullfile(fileparts(p.Root),'1_Hover Simulation Work','lin_hover_sim.slx');
workbench=fullfile(fileparts(modelPath),'HoverWorkbench'); addpath(workbench);
settings=hover.flightExample(kind); settings.sim_fidelity=char(fidelity);
folder=fullfile(p.Root,'test-output'); if ~isfolder(folder), mkdir(folder); end
if capture, settings.FirmwareAdapter.TraceFile=[tempname(folder) '.bin']; end
[input,variables]=hover.makeSimulationInput(settings,modelPath);
started=tic; output=sim(input); elapsed=toc(started);
report=bf.hoverMetrics(output,variables); report.Case=char(kind); report.Fidelity=char(fidelity);
report.WallSeconds=elapsed; report.FirmwareBinarySHA256=bf.binaryHash();
report.CommandScheduleSI=variables.bfSim.ReferenceSchedule;
report.Criteria=struct('PeakRollPitchDegrees',30,'FiniteAndArmed',true, ...
    'CommandMagnitudeToleranceRadians',1e-12);
d=squeeze(output.betaflight_diagnostics.signals.values)';
modeFlags=bitand(uint32(d(:,33)),uint32(3));
if kind=="angle", modeCorrect=all(bitand(modeFlags,uint32(1))~=0);
else, modeCorrect=all(modeFlags==0); end
report.Passed=report.AllFinite && report.ArmedThroughout && modeCorrect ...
    && report.SimulatedSeconds==settings.t_sim && all(report.PeakEulerDegrees(1:2)<30) ...
    && report.MotorCommandRange(1)>=1000 && report.MotorCommandRange(2)<=1950;
report.Interpretation='Changing-reference integration check with unchanged starting PID gains; not a tuned tracking acceptance test.';
record=hover.saveRun(fullfile(workbench,'data'),settings,variables,output, ...
    struct('Label',sprintf('%s tuning example / %s plant',kind,fidelity), ...
    'DefaultPlots',true,'Verification',report,'ModelSHA256',hover.fileHash(modelPath)));
reloaded=hover.loadRun(record.Folder);
assert(isequal(reloaded.Settings.FirmwareAdapter.ReferenceSchedule,settings.FirmwareAdapter.ReferenceSchedule));
assert(nnz(startsWith({record.Signals.Key},'command.'))==3);
report.RunFolder=record.Folder;
fig=figure('Visible','off','Position',[100 100 1400 1000]); cleanup=onCleanup(@()close(fig));
tiles=tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
axesHandles=gobjects(1,6);
for k=1:6, axesHandles(k)=nexttile(tiles); end
report.RollAnalysis=hover.plotFlightAnalysis(record,1,axesHandles);
title(tiles,sprintf('%s commands | %s plant | Noise ON | seed %d',upper(kind),fidelity,settings.seed));
exportgraphics(fig,fullfile(folder,sprintf('flight-%s-%s.png',kind,fidelity)),'Resolution',120);
report.PitchAnalysis=hover.plotFlightAnalysis(record,2,axesHandles);
if capture
    path=variables.bfSim.TraceFile;
    fid=fopen(path,'r','ieee-le'); fileCleanup=onCleanup(@()fclose(fid));
    trace=fread(fid,[92 Inf],'double')'; clear fileCleanup
    % Diagnostics time is rewritten to plant time after startup, so the final
    % N trace packets correspond exactly to the N logged controller samples.
    n=numel(output.betaflight_diagnostics.time); request=trace(end-n+1:end,1:52);
    time=output.betaflight_diagnostics.time;
    [command,keys]=bf.commandSeries(time,variables.Xref,variables.bfSim);
    if kind=="angle", columns=[47 48 52]; else, columns=50:52; end
    report.TraceCommandMaxErrorRadians=max(abs(request(:,columns)-command*pi/180),[],'all');
    assert(report.TraceCommandMaxErrorRadians<1e-12,'bf:CommandTrace','Saved command differs from the command sent to firmware.');
    report.TraceCommandKeys=keys;
    report.Replay=bf.replayTrace(path);
end
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,sprintf('flight-%s-%s.json',kind,fidelity)));
assert(report.Passed,'bf:FlightTest','Flight integration criteria failed; see the saved data.');
disp(report);
end
