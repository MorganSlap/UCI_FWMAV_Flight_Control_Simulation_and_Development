function writeCli(config,path)
%WRITECLI Write the exact saved CLI configuration for the firmware adapter.
% The host adapter is responsible for running the firmware's CLI parser and
% reporting rejected commands. This function does not execute the document.
arguments
    config (1,1) struct
    path (1,1) string
end
bf.validateConfig(config);
folder=fileparts(path);
if strlength(folder)>0 && ~isfolder(folder), mkdir(folder); end
writelines(config.CLI,path,Encoding='UTF-8');
end
