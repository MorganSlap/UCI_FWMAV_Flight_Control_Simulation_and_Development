function config = defaultConfig(rootFolder)
%DEFAULTCONFIG Load the actual compiled firmware's captured configuration.
% Captures are made by the host build workflow, not fabricated by this app.
arguments
    rootFolder (1,1) string = string(fileparts(fileparts(mfilename('fullpath'))))
end
folder=fullfile(rootFolder,'configuration');
schemaFile=fullfile(folder,'settings-get.txt');
cliFile=fullfile(folder,'firmware-defaults.cli');
schemaText=''; cliText=''; firmware=struct();
if isfile(schemaFile), schemaText=fileread(schemaFile); end
if isfile(cliFile), cliText=fileread(cliFile); end
metadataFile=fullfile(folder,'firmware.json');
if isfile(metadataFile), firmware=jsondecode(fileread(metadataFile)); end
config=bf.newConfig(cliText,schemaText,firmware);
end
