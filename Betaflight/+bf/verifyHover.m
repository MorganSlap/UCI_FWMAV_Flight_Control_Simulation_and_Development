function [report,record,fig]=verifyHover(kind,fidelity,noiseEnabled,seed)
%VERIFYHOVER Run and archive a default case with explicit flight criteria.
arguments
    kind (1,1) string {mustBeMember(kind,["level","recovery"])} = "level"
    fidelity (1,1) string {mustBeMember(fidelity,["high","low"])} = "high"
    noiseEnabled (1,1) logical = true
    seed (1,1) double {mustBeInteger,mustBeNonnegative} = 23341
end
p=bf.paths(); modelPath=fullfile(fileparts(p.Root),'1_Hover Simulation Work','lin_hover_sim.slx');
addpath(fullfile(fileparts(modelPath),'HoverWorkbench'));
settings=hover.hoverExample(kind); settings.sim_fidelity=char(fidelity);
settings.noise_true=noiseEnabled; settings.seed=seed;
[input,variables]=hover.makeSimulationInput(settings,modelPath);
assert(variables.bfSim.NavigationSensors==0,'The example must not use navigation measurements.');
started=tic; output=sim(input); elapsed=toc(started);
report=bf.hoverMetrics(output,variables);
report.Case=char(kind); report.Fidelity=char(fidelity); report.WallSeconds=elapsed;
report.NavigationMeasurements=false; report.NoiseEnabled=settings.noise_true; report.Seed=settings.seed;
report.CorrectedFlightInterfaces=bf.flightInterfacesReady();
report.FirmwareBinarySHA256=hover.fileHash(p.Binary);
report.Criteria=struct('FinalRollPitchDegrees',1,'PeakLevelRollPitchDegrees',1, ...
    'PeakRecoveryRollPitchDegrees',6,'LevelHeightDriftMetres',0.35, ...
    'LevelDownSpeedMetresPerSecond',0.08,'LevelHorizontalDisplacementMetres',1);
report.ThrottleReceiverMicroseconds=variables.bfSim.ThrottlePWM;
report.Passed=report.AllFinite && report.ArmedThroughout && report.AngleModeThroughout ...
    && report.SimulatedSeconds==settings.t_sim ...
    && all(abs(report.FinalEulerDegrees(1:2))<1) ...
    && all(report.EstimatorRmsDegrees(1:2)<1) ...
    && report.MotorCommandRange(1)>=1000 && report.MotorCommandRange(2)<=1950;
if kind=="level"
    report.Passed=report.Passed && all(report.PeakEulerDegrees(1:2)<1) ...
        && abs(report.AltitudeChangeMetres)<0.35 ...
        && report.PeakDownSpeedMetresPerSecond<0.08 ...
        && report.PeakHorizontalDisplacementMetres<1;
else
    report.Passed=report.Passed && all(report.PeakEulerDegrees(1:2)<6) ...
        && isfinite(report.AttitudeSettledWithinOneDegreeSeconds);
end
report.Interpretation='Calm-air IMU-only attitude control at fixed throttle; no altitude or position hold.';
if ~report.CorrectedFlightInterfaces
    report.Interpretation=[report.Interpretation ' Existing sensor model retained; specific-force/noise corrections are pending.'];
end
noiseLabel='noise-off'; if noiseEnabled, noiseLabel='noise-on'; end
label=sprintf('IMU-only %s / %s plant / %s',kind,fidelity,noiseLabel);
record=hover.saveRun(fullfile(p.Root,'test-output','runs'),settings,variables,output, ...
    struct('Label',label,'DefaultPlots',true,'Verification',report,'ModelSHA256',hover.fileHash(modelPath)));
report.RunFolder=record.Folder;
folder=fullfile(p.Root,'test-output');
base=fullfile(folder,sprintf('hover-%s-%s-%s-seed%d',kind,fidelity,noiseLabel,seed));
writelines(jsonencode(report,PrettyPrint=true),[base '.json']);
fig=bf.plotHover(output,variables,label);
exportgraphics(fig,[base '.png'],'Resolution',150);
assert(report.Passed,'bf:HoverVerification','Flight criteria failed. Inspect the saved run and report.');
disp(report);
end
