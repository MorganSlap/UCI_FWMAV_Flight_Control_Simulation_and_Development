function record = saveRun(rootFolder, settings, variables, simOut, metadata)
%SAVERUN Archive settings, simulation data and lightweight provenance.
% Each run has its own folder. The metadata file is written last, so the
% library only discovers completely written runs. No previous run is replaced.
% Model/script paths and hashes are metadata only; source files are not copied.
arguments
    rootFolder (1,1) string
    settings (1,1) struct
    variables (1,1) struct
    simOut
    metadata (1,1) struct = struct()
end
if ~isfolder(rootFolder), mkdir(rootFolder); end
[~, folderAttributes] = fileattrib(rootFolder);
rootFolder = string(folderAttributes.Name);
nowUTC = datetime('now','TimeZone','UTC');
created = char(string(nowUTC, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
stamp = char(string(nowUTC, 'yyyyMMdd''T''HHmmssSSS'));
[~, suffix] = fileparts(tempname(rootFolder));
id = [stamp '_' suffix];
finalFolder = fullfile(rootFolder, id);
stagingFolder = fullfile(rootFolder, ['.pending_' id]);
mkdir(stagingFolder);
label = id;
if isfield(metadata, 'Label') && strlength(string(metadata.Label)) > 0
    label = char(string(metadata.Label));
end
try
    signals = hover.collectSignals(simOut, variables);
catch exception
    % An unfamiliar/partial output should not prevent saving the raw run.
    signals = hover.collectSignals(struct(),struct());
    metadata.SignalNormalizationError = exception.message;
    warning('hover:SignalNormalizationFailed', ...
        'Raw data will be archived, but signal normalization failed: %s',exception.message);
end
% Ignore source-copy fields supplied by older callers. Historical archives
% keep their original fields and files; loadRun still accepts them unchanged.
sourceCopyFields = intersect(fieldnames(metadata), {'SourceSnapshots','SourceScript'});
if ~isempty(sourceCopyFields), metadata = rmfield(metadata, sourceCopyFields); end
record = struct('SchemaVersion', 1, 'ID', id, 'Label', label, ...
    'Created', created, 'Folder', char(finalFolder), 'Settings', settings, ...
    'Variables', variables, 'Signals', signals, 'Output', simOut, ...
    'Metadata', metadata);
save(fullfile(stagingFolder, 'run.mat'), 'record', '-v7.3');
presetOptions = struct();
if isfield(metadata,'DefaultPlots'), presetOptions.DefaultPlots = metadata.DefaultPlots; end
hover.savePreset(fullfile(stagingFolder, 'settings.json'), settings, presetOptions);
summary = struct('SchemaVersion', 1, 'ID', id, 'Label', label, ...
    'Created', created, 'DurationSeconds', durationFromSignals(signals), ...
    'SignalCount', numel(signals), 'Metadata', metadata);
writelines(jsonencode(summary, PrettyPrint=true), ...
    fullfile(stagingFolder, 'metadata.json'), Encoding='UTF-8');
[ok, message] = movefile(stagingFolder, finalFolder);
if ~ok
    error('hover:RunSaveFailed', ...
        'Could not finalize the run archive: %s. Data remains in %s.', ...
        message, stagingFolder);
end
end

function duration = durationFromSignals(signals)
duration = 0;
for k = 1:numel(signals)
    if ~isempty(signals(k).Time)
        duration = max(duration, max(signals(k).Time) - min(signals(k).Time));
    end
end
end
