function config = selectProfile(config,scope,index)
%SELECTPROFILE Select a firmware profile after applying all profile values.
arguments
    config (1,1) struct
    scope (1,1) string {mustBeMember(scope,["profile","rateprofile","battery_profile"])}
    index (1,1) double {mustBeInteger,mustBeNonnegative}
end
bf.validateConfig(config);
lines=splitlines(string(config.CLI));
stop=find(~cellfun('isempty',regexp(cellstr(strtrim(lines)),'^(save|exit)(\s|$)','once')),1,'first');
if isempty(stop), stop=numel(lines)+1; end
added=sprintf('%s %d',scope,index);
config.CLI=char(join([lines(1:stop-1);string(added);lines(stop:end)],newline));
end
