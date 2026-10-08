function app = hoverWorkbench
%HOVERWORKBENCH Open the hover settings, simulation, and analysis app.
%   APP = HOVERWORKBENCH returns the App Designer app. The existing model and
%   initialization script are never edited. See HoverWorkbench/README.md.
appFolder = fullfile(fileparts(mfilename('fullpath')), 'HoverWorkbench');
addpath(appFolder);
app = HoverWorkbench;
end
