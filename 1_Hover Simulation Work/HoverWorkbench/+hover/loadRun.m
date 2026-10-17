function record = loadRun(folder)
%LOADRUN Load a complete run archive (including original SimulationOutput).
arguments
    folder (1,1) string
end
if isfile(folder)
    filename = folder;
    folder = string(fileparts(filename));
else
    filename = fullfile(folder, 'run.mat');
end
saved = load(filename, 'record');
if ~isfield(saved, 'record') || ~isstruct(saved.record) || ...
        ~isscalar(saved.record) || ...
        ~all(isfield(saved.record, {'SchemaVersion','ID','Settings','Signals','Output'})) || ...
        ~isequal(saved.record.SchemaVersion,1)
    error('hover:InvalidRun', 'The file is not a supported Hover Workbench run archive.');
end
record = saved.record;
gravity=9.81;
if isfield(record,'Variables') && isfield(record.Variables,'g'), gravity=record.Variables.g; end
record.Signals=hover.addImuSignals(record.Signals,gravity);
record.Folder = char(folder); % Archives remain portable after moving folders.
end
