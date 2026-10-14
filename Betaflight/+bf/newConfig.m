function config = newConfig(cliText,schemaText,firmware)
%NEWCONFIG Create a data-only firmware configuration, preserving full CLI.
arguments
    cliText {mustBeText} = ''
    schemaText {mustBeText} = ''
    firmware (1,1) struct = struct()
end
config=struct('Format','BetaflightSimulationConfig','SchemaVersion',1, ...
    'CLI',char(join(string(cliText),newline)), ...
    'SchemaText',char(join(string(schemaText),newline)),'Firmware',firmware);
end
