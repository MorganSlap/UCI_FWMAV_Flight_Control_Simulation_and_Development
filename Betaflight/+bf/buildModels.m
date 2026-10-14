function buildModels()
%BUILDMODELS Create the firmware reference model and wire existing plant I/O.
% Run on the Betaflight branch. The existing plants, actuator, and loggers
% are retained. Stop on unsaved model edits rather than overwriting them.
p=bf.paths();
plantPath=fullfile(fileparts(p.Root),'1_Hover Simulation Work','lin_hover_sim.slx');
top='lin_hover_sim'; ref='bf_flight_controller';
if bdIsLoaded(top) && strcmp(get_param(top,'Dirty'),'on')
    error('bf:UnsavedModel','Save or discard your unsaved lin_hover_sim edits before rebuilding its firmware boundary.');
end
if bdIsLoaded(ref) && strcmp(get_param(ref,'Dirty'),'on')
    error('bf:UnsavedModel','Save or discard unsaved bf_flight_controller edits before rebuilding.');
end
if bdIsLoaded(ref), close_system(ref,0); end
new_system(ref);
set_param(ref,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','Ts', ...
    'EnableMultiTasking','off','StopTime','t_sim','ModelReferenceNumInstancesAllowed','Single');
inputs={'Gyroscope','Accelerometer','Receiver','True state','Reference command'};
widths=[3 3 16 12 12];
for k=1:5
    add_block('simulink/Sources/In1',[ref '/' inputs{k}], ...
        'Port',num2str(k),'PortDimensions',sprintf('[%d 1]',widths(k)), ...
        'SampleTime','Ts','Position',[35 35+70*k 65 55+70*k]);
end
core=[ref '/Actual Betaflight firmware'];
add_block('simulink/User-Defined Functions/MATLAB System',core, ...
    'System','bf.FlightController','SimulateUsing','Interpreted execution', ...
    'Position',[210 100 450 440]);
set_param(core,'Configuration','bfConfig','Options','bfSim','SampleTime','Ts');
outputs={'Delta pot','Estimated state','Firmware diagnostics'};
for k=1:3
    add_block('simulink/Sinks/Out1',[ref '/' outputs{k}], ...
        'Port',num2str(k),'Position',[540 80+100*k 570 100+100*k]);
    add_line(ref,['Actual Betaflight firmware/' num2str(k)],[outputs{k} '/1']);
end
for k=1:5
    add_line(ref,[inputs{k} '/1'],['Actual Betaflight firmware/' num2str(k)]);
end
annotation=Simulink.Annotation(ref, ...
    ['Pinned upstream Betaflight SITL flight stack, discrete lockstep execution.' newline ...
    'SI sensors -> firmware -> absolute PWM -> delta-pot. No truth attitude bypass.' newline ...
    'Configuration: bfConfig. Timing, calibration and plant adapter: bfSim.']);
annotation.Position=[30 20];
save_system(ref,fullfile(p.Root,[ref '.slx']));

load_system(plantPath);
boundary=[top '/Betaflight Flight Software'];
if getSimulinkBlockHandle(boundary)>0
    save_system(top); return
end
oldController=[top '/Contoller']; oldEstimator=[top '/State Estimation'];
controllerPorts=get_param(oldController,'PortHandles');
estimatorPorts=get_param(oldEstimator,'PortHandles');
controlDest=get_param(get_param(controllerPorts.Outport(1),'Line'),'DstPortHandle');
estimateDest=get_param(get_param(estimatorPorts.Outport(1),'Line'),'DstPortHandle');
estimateDest=estimateDest(estimateDest~=controllerPorts.Inport(2));
controlDest=controlDest(controlDest~=estimatorPorts.Inport(1));
delete_line(get_param(controllerPorts.Outport(1),'Line'));
delete_line(get_param(estimatorPorts.Outport(1),'Line'));
delete_block(oldController); delete_block(oldEstimator);
delete_block([top '/mahoney expects positive g']);
add_block('simulink/Ports & Subsystems/Model',boundary, ...
    'ModelName',ref,'SimulationMode','Normal','Position',[-130 170 110 420]);
sourceNames={'Gyro Model','Accelerometer Model','','Lin vs NonLin Dynamics','Constant'};
holdNames={'Gyro sample','Accelerometer sample','Receiver sample','State sample','Reference sample'};
add_block('simulink/Sources/Constant',[top '/Betaflight receiver channels'], ...
    'Value','bfRc','Position',[-470 265 -350 295]);
sourceNames{3}='Betaflight receiver channels';
for k=1:5
    holdPath=[top '/' holdNames{k}];
    add_block('simulink/Discrete/Zero-Order Hold',holdPath, ...
        'SampleTime','Ts','Position',[-280 140+60*k -220 170+60*k]);
    add_line(top,[sourceNames{k} '/1'],[holdNames{k} '/1'],'autorouting','on');
    add_line(top,[holdNames{k} '/1'],['Betaflight Flight Software/' num2str(k)],'autorouting','on');
end
newPorts=get_param(boundary,'PortHandles');
for k=1:numel(controlDest), add_line(top,newPorts.Outport(1),controlDest(k),'autorouting','on'); end
for k=1:numel(estimateDest), add_line(top,newPorts.Outport(2),estimateDest(k),'autorouting','on'); end
add_block('simulink/Sinks/To Workspace',[top '/Betaflight diagnostics'], ...
    'VariableName','betaflight_diagnostics','SaveFormat','Structure With Time', ...
    'Position',[175 405 320 435]);
add_line(top,'Betaflight Flight Software/3','Betaflight diagnostics/1','autorouting','on');
save_system(top);
end
