function model=buildPlantCode(fidelity)
%BUILDPLANTCODE Generate the original nonlinear plant and sensor blocks as C.
arguments
    fidelity (1,1) string {mustBeMember(fidelity,["high","low"])} = "high"
end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'Betaflight'),fullfile(root,'1_Hover Simulation Work','HoverWorkbench'));
source=fullfile(root,'1_Hover Simulation Work','lin_hover_sim.slx');
load_system(source);
model='hover_plant_sil';
if fidelity=="low", model='hover_linear_sil'; end
destination=fullfile(root,'DesktopSIL','model');
generated=fullfile(root,'DesktopSIL','generated');
if ~isfolder(destination), mkdir(destination); end
if ~isfolder(generated), mkdir(generated); end
if bdIsLoaded(model), close_system(model,0); end
new_system(model);
settings=hover.hoverExample(); settings.sim_fidelity=char(fidelity); variables=hover.buildVariables(settings);
workspace=get_param(model,'ModelWorkspace');
names=fieldnames(variables);
for k=1:numel(names)
    assignin(workspace,names{k},variables.(names{k}));
end
blocks={'Actuator Model','Lin vs NonLin Dynamics','MATLAB Function', ...
    'Gyro Model','Accelerometer Model','Gyro sample','Accelerometer sample', ...
    'Noise Option','Wing Disturbance (Unit Amplitude)'};
for k=1:numel(blocks)
    add_block(['lin_hover_sim/' blocks{k}],[model '/' blocks{k}]);
end
% Explicit tunable noise-power variables prevent the mask's density terms
% from being folded into numeric constants by parameter-expression folding.
assignin(workspace,'sil_gyro_noise_power',ones(3,1)*(variables.gyro.noise_density*pi/180)^2*variables.gyro.BW);
assignin(workspace,'sil_accel_noise_power',ones(3,1)*(variables.accel.noise_density*variables.g)^2*variables.accel.BW);
set_param([model '/Gyro Model/Gyro White Noise'],'Cov','sil_gyro_noise_power');
set_param([model '/Accelerometer Model/Accel White Noise'],'Cov','sil_accel_noise_power');
% Select the original nonlinear branch explicitly in the generated model.
% The source model's strcmp-based selector expects base-workspace evaluation.
if fidelity=="high", linear='false'; nonlinear='true'; else, linear='true'; nonlinear='false'; end
set_param([model '/Lin vs NonLin Dynamics/Linear Simulation'],'VariantControl',linear);
set_param([model '/Lin vs NonLin Dynamics/Non Linear Simulation'],'VariantControl',nonlinear);
add_block('simulink/Sources/In1',[model '/motor_delta'],'PortDimensions','4','SampleTime','Ts');
add_line(model,'motor_delta/1','Actuator Model/1','autorouting','on');
add_line(model,'Actuator Model/1','Lin vs NonLin Dynamics/1','autorouting','on');
add_line(model,'Actuator Model/1','MATLAB Function/2','autorouting','on');
add_line(model,'Lin vs NonLin Dynamics/1','MATLAB Function/1','autorouting','on');
add_line(model,'MATLAB Function/1','Accelerometer Model/1','autorouting','on');
add_line(model,'MATLAB Function/2','Gyro Model/1','autorouting','on');
add_line(model,'Wing Disturbance (Unit Amplitude)/1','Noise Option/1','autorouting','on');
add_line(model,'Noise Option/1','Accelerometer Model/2','autorouting','on');
add_line(model,'Noise Option/1','Gyro Model/2','autorouting','on');
add_line(model,'Gyro Model/1','Gyro sample/1','autorouting','on');
add_line(model,'Accelerometer Model/1','Accelerometer sample/1','autorouting','on');
ports={'true_state','gyro_measured','accel_measured','actuator_delta','gyro_ideal','accel_ideal'};
sources={'Lin vs NonLin Dynamics/1','Gyro sample/1','Accelerometer sample/1','Actuator Model/1','MATLAB Function/2','MATLAB Function/1'};
for k=1:numel(ports)
    add_block('simulink/Sinks/Out1',[model '/' ports{k}],'Port',num2str(k));
    add_line(model,sources{k},[ports{k} '/1'],'autorouting','on');
end
% Only visualization blocks are removed from the copied plant.
scopes=find_system(model,'LookUnderMasks','all','MatchFilter',@Simulink.match.allVariants,'BlockType','Scope');
for k=1:numel(scopes), delete_block(scopes{k}); end
set_param(model,'SystemTargetFile','ert.tlc','TargetLang','C', ...
    'SupportContinuousTime','on','SolverType','Fixed-step','Solver','ode5', ...
    'FixedStep','0.0000625','SolverMode','SingleTasking', ...
    'DefaultParameterBehavior','Tunable','CombineOutputUpdateFcns','off', ...
    'GenerateReport','off','GenCodeOnly','on','GenerateSampleERTMain','off', ...
    'CodeInterfacePackaging','Nonreusable function','CustomSymbolStrUtil',[model '_$N$C'], ...
    'StopTime','1','SaveTime','on','TimeSaveName','tout', ...
    'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset', ...
    'ReturnWorkspaceOutputs','on','SignalLogging','off');
Simulink.BlockDiagram.arrangeSystem(model);
save_system(model,fullfile(destination,[model '.slx']));
old=Simulink.fileGenControl('getConfig');
cleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',old));
Simulink.fileGenControl('set','CacheFolder',fullfile(generated,'cache'), ...
    'CodeGenFolder',generated,'createDir',true);
slbuild(model,'GenerateCodeOnly',true);
fprintf('Generated C plant: %s\n',generated);
end
