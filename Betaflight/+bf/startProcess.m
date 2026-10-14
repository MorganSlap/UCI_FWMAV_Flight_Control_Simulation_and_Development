function process = startProcess(argumentsList,workingFolder,logPath)
%STARTPROCESS Launch the isolated firmware with redirected output.
arguments
    argumentsList (1,:) cell
    workingFolder {mustBeTextScalar}
    logPath {mustBeTextScalar}
end
p=bf.paths();
if ~isfile(p.Binary)
    error('bf:MissingFirmware','Build the pinned firmware first: %s',p.Binary);
end
command=[{p.Binary},argumentsList];
builder=java.lang.ProcessBuilder(command);
builder.directory(java.io.File(char(workingFolder)));
builder.redirectErrorStream(true);
builder.redirectOutput(java.io.File(char(logPath)));
environment=builder.environment();
environment.put('PATH',[p.ToolchainBin pathsep char(environment.get('PATH'))]);
process=builder.start();
end
