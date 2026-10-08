function theme = workbenchTheme()
%WORKBENCHTHEME Betaflight-inspired chrome on MATLAB's native light theme.
theme.primary = [245 184 27]/255;
theme.onPrimary = [30 32 35]/255;
theme.secondary = [43 46 50]/255;
theme.onSecondary = [235 237 239]/255;
theme.muted = [99 105 113]/255;
theme.border = [213 217 223]/255;
theme.card = [1 1 1];
theme.canvas = [240 242 245]/255;
theme.error = [190 48 45]/255;
theme.success = [43 132 84]/255;
theme.warning = [177 112 0]/255;
theme.plotColors = orderedcolors('gem');
end
