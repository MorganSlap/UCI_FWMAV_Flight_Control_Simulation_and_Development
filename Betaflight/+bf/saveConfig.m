function saveConfig(filename,config)
%SAVECONFIG Save versioned JSON or a directly reusable full CLI document.
arguments
    filename (1,1) string
    config (1,1) struct
end
bf.validateConfig(config);
[folder,~,extension]=fileparts(filename);
if ~ismember(lower(extension),[".json",".cli",".txt"])
    error('bf:ConfigExtension','Choose .json or .cli for the configuration.');
end
if strlength(folder)==0, folder=string(pwd); end
if ~isfolder(folder), mkdir(folder); end
temporary=string(tempname(folder));
cleanup=onCleanup(@() removeTemporary(temporary));
if strcmpi(extension,'.json')
    text=jsonencode(config,PrettyPrint=true);
else
    text=config.CLI;
end
writelines(text,temporary,Encoding='UTF-8');
[ok,message]=movefile(temporary,filename,'f');
if ~ok, error('bf:ConfigWriteFailed','%s',message); end
end

function removeTemporary(filename)
if isfile(filename), delete(filename); end
end
