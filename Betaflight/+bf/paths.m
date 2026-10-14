function p = paths()
%PATHS Paths relative to the checked-in integration, never a global install.
root=fileparts(fileparts(mfilename('fullpath')));
p=struct('Root',root,'Binary',fullfile(root,'build','betaflight_simulink.exe'), ...
    'Runtime',fullfile(root,'runtime'),'ToolchainBin',fullfile(root,'toolchain','cygwin','bin'));
end
