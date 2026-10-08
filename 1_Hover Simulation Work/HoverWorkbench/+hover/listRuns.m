function runs = listRuns(rootFolder)
%LISTRUNS Read lightweight run metadata without loading simulation arrays.
arguments
    rootFolder (1,1) string
end
template = struct('ID','','Label','','Created','','Folder','', ...
    'DurationSeconds',0,'SignalCount',0);
runs = repmat(template,0,1);
if ~isfolder(rootFolder), return; end
folders = dir(rootFolder);
folders = folders([folders.isdir]);
for k = 1:numel(folders)
    if startsWith(folders(k).name,'.'), continue; end
    folder = fullfile(rootFolder,folders(k).name);
    metadataFile = fullfile(folder,'metadata.json');
    if ~isfile(metadataFile) || ~isfile(fullfile(folder,'run.mat')), continue; end
    try
        summary = jsondecode(fileread(metadataFile));
        if ~all(isfield(summary, {'ID','Label','Created','DurationSeconds','SignalCount'}))
            continue;
        end
        item = template;
        item.ID = char(summary.ID);
        item.Label = char(summary.Label);
        item.Created = char(summary.Created);
        item.Folder = char(folder);
        item.DurationSeconds = summary.DurationSeconds;
        item.SignalCount = summary.SignalCount;
        runs(end+1,1) = item; %#ok<AGROW>
    catch exception
        warning('hover:UnreadableRunMetadata', 'Skipping %s: %s', ...
            metadataFile, exception.message);
    end
end
if ~isempty(runs)
    [~, order] = sort(string({runs.Created}), 'descend');
    runs = runs(order);
end
end
