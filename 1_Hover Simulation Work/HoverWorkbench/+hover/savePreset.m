function savePreset(filename, settings, options)
%SAVEPRESET Write a versioned, data-only JSON settings preset.
%   hover.savePreset(filename, settings) never executes MATLAB expressions.
arguments
    filename (1,1) string
    settings (1,1) struct
    options (1,1) struct = struct()
end
payload = struct('Format', 'HoverWorkbenchSettings', 'SchemaVersion', 1, ...
    'Created', char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z''')), 'Settings', settings, ...
    'Options', options);
folder = fileparts(filename);
if strlength(folder) == 0, folder = string(pwd); end
if ~isfolder(folder), mkdir(folder); end
temporary = string(tempname(folder)) + ".json";
cleanup = onCleanup(@() removeTemporary(temporary));
writelines(jsonencode(payload, PrettyPrint=true), temporary, Encoding='UTF-8');
[ok, message] = movefile(temporary, filename, 'f');
if ~ok, error('hover:PresetWriteFailed', '%s', message); end
end

function removeTemporary(filename)
if isfile(filename), delete(filename); end
end
