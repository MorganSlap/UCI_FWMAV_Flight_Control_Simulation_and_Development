function [settings, options] = loadPreset(filename)
%LOADPRESET Read a Hover Workbench JSON preset without evaluating code.
arguments
    filename (1,1) string
end
payload = jsondecode(fileread(filename));
if ~isstruct(payload) || ~isscalar(payload) || ...
        ~all(isfield(payload, {'Format','SchemaVersion','Settings'})) || ...
        ~strcmp(payload.Format, 'HoverWorkbenchSettings') || ...
        ~isequal(payload.SchemaVersion, 1) || ...
        ~isstruct(payload.Settings) || ~isscalar(payload.Settings)
    error('hover:InvalidPreset', ...
        'This file is not a supported Hover Workbench settings preset.');
end
settings = hover.upgradeSettings(payload.Settings);
options = struct();
if isfield(payload,'Options')
    if ~isstruct(payload.Options) || ~isscalar(payload.Options)
        error('hover:InvalidPreset','Preset options must be a JSON object.');
    end
    options = payload.Options;
    if isfield(options,'DefaultPlots') && ~((islogical(options.DefaultPlots) || ...
            isnumeric(options.DefaultPlots)) && isscalar(options.DefaultPlots) && ...
            ismember(options.DefaultPlots,[0 1]))
        error('hover:InvalidPreset','DefaultPlots must be true or false.');
    end
    if isfield(options,'RunLabel') && ~(ischar(options.RunLabel) || ...
            (isstring(options.RunLabel) && isscalar(options.RunLabel)))
        error('hover:InvalidPreset','RunLabel must be text.');
    end
end
end
