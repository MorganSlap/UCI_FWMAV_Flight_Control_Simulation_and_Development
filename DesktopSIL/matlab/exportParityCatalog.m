function exportParityCatalog()
%EXPORTPARITYCATALOG Capture actual workbench/firmware schemas and examples.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'Betaflight'),fullfile(root,'1_Hover Simulation Work','HoverWorkbench'));
folder=fullfile(root,'DesktopSIL','catalog'); if ~isfolder(folder), mkdir(folder); end
c=bf.hoverConfig();
writeJSON(fullfile(folder,'firmware_schema.json'),bf.parseCliSettings(c.SchemaText));
writeJSON(fullfile(folder,'workbench_schema.json'),hover.settingsSchema());
writeJSON(fullfile(folder,'script_defaults.json'),hover.defaultSettings());
for kind=["hover","recovery","angle","rate"]
    s=hover.flightExample(kind); v=hover.buildVariables(s);
    writeJSON(fullfile(folder,char(kind+"_settings.json")),s);
    writeJSON(fullfile(folder,char(kind+"_variables.json")),v);
end
end
function writeJSON(path,value)
f=fopen(path,'w'); cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s\n',jsonencode(value,PrettyPrint=true));
end
