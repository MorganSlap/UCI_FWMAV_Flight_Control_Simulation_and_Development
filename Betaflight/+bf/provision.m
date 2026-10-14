function effectiveText = provision(config,workingFolder)
%PROVISION Validate and load settings using Betaflight's own CLI parser.
arguments
    config (1,1) struct
    workingFolder {mustBeTextScalar}
end
if ~isfolder(workingFolder), mkdir(workingFolder); end
cliPath=fullfile(workingFolder,'configuration.cli');
% Dump before save captures the effective, firmware-normalized settings.
text=regexprep(config.CLI,'(?m)^\s*save\s*$','');
text=[text newline 'dump all' newline 'save' newline];
writelines(text,cliPath);
logPath=fullfile(workingFolder,'configuration.log');
process=bf.startProcess({'--config','configuration.cli'},workingFolder,logPath);
cleanup=onCleanup(@()stopProcess(process));
started=tic;
while process.isAlive()
    if toc(started)>45, error('bf:ConfigTimeout','Firmware configuration timed out. See %s',logPath); end
    pause(0.02);
end
effectiveText=fileread(logPath);
if process.exitValue()~=0 || contains(effectiveText,'###ERROR') || contains(effectiveText,'prepareSave failed')
    error('bf:InvalidFirmwareConfig','Betaflight rejected the configuration. See %s\n%s', ...
        logPath,extractErrors(effectiveText));
end
end

function stopProcess(process)
if process.isAlive(), process.destroyForcibly(); end
end
function text=extractErrors(output)
lines=splitlines(string(output));
errors=lines(contains(lines,'ERROR')|contains(lines,'failed')|contains(lines,'INVALID'));
text=char(join(errors,newline));
end
