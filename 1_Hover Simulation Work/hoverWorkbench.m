function app = hoverWorkbench
%HOVERWORKBENCH Open the hover settings, simulation, and analysis app.
%   APP = HOVERWORKBENCH returns the App Designer app. On the Betaflight
%   branch, use its firmware configuration button. See HoverWorkbench/README.md.
appFolder = fullfile(fileparts(mfilename('fullpath')), 'HoverWorkbench');
addpath(appFolder);
app = HoverWorkbench;
end
