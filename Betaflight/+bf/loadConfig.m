function config = loadConfig(filename,schemaText,firmware)
%LOADCONFIG Load configuration data only; no CLI/MATLAB commands are run.
arguments
    filename (1,1) string
    schemaText {mustBeText} = ''
    firmware (1,1) struct = struct()
end
[~,~,extension]=fileparts(filename);
text=fileread(filename);
if strcmpi(extension,'.json')
    config=jsondecode(text);
else
    config=bf.newConfig(text,schemaText,firmware);
end
bf.validateConfig(config);
end
