function [simInput, variables] = makeSimulationInput(settings, modelPath)
%MAKESIMULATIONINPUT Apply an isolated set of run variables and stop time.
% SimulationInput restores model parameters after execution. This function
% never writes to the base workspace and never saves or edits the model.
arguments
    settings (1,1) struct
    modelPath {mustBeTextScalar}
end
variables = hover.buildVariables(settings);
modelPath = char(modelPath);
[modelFolder,modelName,extension] = fileparts(modelPath);
if isempty(modelName) || (~isempty(extension) && ~strcmpi(extension,'.slx') && ~strcmpi(extension,'.mdl'))
    error('hover:InvalidModel','Supply a Simulink model name or a .slx/.mdl file path.');
end
if ~isempty(modelFolder) && ~isfile(modelPath)
    error('hover:MissingModel','Model file does not exist: %s',modelPath);
end
% Loading by full path avoids requiring the GUI caller to change directories.
load_system(modelPath);
simInput = Simulink.SimulationInput(modelName);
names = fieldnames(variables);
for k = 1:numel(names)
    simInput = simInput.setVariable(names{k},variables.(names{k}));
end
simInput = simInput.setModelParameter('StopTime',sprintf('%.17g',settings.t_sim), ...
    'ReturnWorkspaceOutputs','on');
end
