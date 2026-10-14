function report=verifyModes()
%VERIFYMODES Exercise custom AUX logic through the actual referenced model.
% Checks two-condition AND modes, linked modes and raw-receiver HORIZON.
p=bf.paths(); modelFolder=fullfile(fileparts(p.Root),'1_Hover Simulation Work');
addpath(fullfile(modelFolder,'HoverWorkbench'));
report=struct([]);
for test=1:3
    settings=hover.defaultSettings(); settings.sim_fidelity='low'; settings.t_sim=0.1;
    % Two AND conditions are required for ARM. ANGLE or HORIZON uses AUX 2.
    mode=min(test,2);
    commands=sprintf('aux 0 0 0 1700 2100 1 0\naux 1 0 2 1700 2100 1 0\naux 2 %d 1 1700 2100 0 0',mode);
    if test==3
        mode=1;
        commands=sprintf(['aux 0 0 0 1700 2100 1 0\naux 1 0 2 1700 2100 1 0\n' ...
            'aux 2 13 1 1700 2100 0 0\naux 3 1 0 900 900 0 13']);
    end
    [~,settings.Betaflight]=bf.commandSection(settings.Betaflight,{'aux'},commands);
    settings.FirmwareAdapter.CommandMode='receiver';
    variables=hover.buildVariables(settings);
    active=variables.bfRc; active(7)=1900; active(6)=1900;
    disarmed=active; disarmed([3 5 7])=[1000;1000;1000];
    settings.FirmwareAdapter.ReceiverPWM=active;
    settings.FirmwareAdapter.StartupReceiverPWM=disarmed;
    if mode==1, settings.FirmwareAdapter.CommandMode='angle'; end
    [input,~]=hover.makeSimulationInput(settings,fullfile(modelFolder,'lin_hover_sim.slx'));
    output=sim(input); values=squeeze(output.betaflight_diagnostics.signals.values)';
    assert(all(values(:,31)==1),'AND-mode receiver channels did not arm the native firmware.');
    assert(all(bitand(uint32(values(:,33)),uint32(2^(mode-1)))~=0),'Requested native flight mode was not active.');
    entry=struct('Mode',mode,'ArmingLogic','AND on AUX 1 and AUX 3', ...
        'FlightModeFlag',2^(mode-1),'LinkedToBeeper',test==3,'SimulatedSeconds',0.1,'Passed',true);
    report=[report;entry]; %#ok<AGROW>
end
folder=fullfile(p.Root,'test-output');
writelines(jsonencode(report,PrettyPrint=true),fullfile(folder,'mode-verification.json'));
end
