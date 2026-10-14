function settings = defaultSettings()
%DEFAULTSETTINGS Editable defaults reviewed against lin_hover.m on 2026-10-08.
% This function deliberately does not run lin_hover.m: that script clears
% MATLAB, runs a simulation and creates figures. Derived values are rebuilt
% by hover.buildVariables from these independently stored editable inputs.

schema = hover.settingsSchema();
settings = struct();
for k = 1:numel(schema)
    path = strsplit(schema(k).Key,'.');
    settings = setfield(settings,path{:},schema(k).Default); %#ok<SFLD>
end
addpath(fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'Betaflight'));
settings.CDx=0; settings.CDy=0; settings.CDz=0; settings.CDw=0;
settings.Betaflight=bf.hoverConfig(settings.max_pot);
settings.FirmwareAdapter=struct();
end
