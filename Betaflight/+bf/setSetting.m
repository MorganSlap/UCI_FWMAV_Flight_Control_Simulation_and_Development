function config = setSetting(config,item,value,index)
%SETSETTING Update one profile value while preserving every other CLI line.
arguments
    config (1,1) struct
    item (1,1) struct
    value
    index (1,1) double = 0
end
bf.validateConfig(config);
value=bf.validateSettingValue(item,value);
if index<0 || index~=fix(index), error('bf:InvalidProfile','Profile index must be a nonnegative integer.'); end
lines=splitlines(string(config.CLI));
current=struct('profile',0,'rateprofile',0,'battery_profile',0);
location=[];
for k=1:numel(lines)
    line=strtrim(char(lines(k)));
    selected=regexp(line,'^(profile|rateprofile|battery_profile)\s+(\d+)\s*$','tokens','once');
    if ~isempty(selected), current.(selected{1})=str2double(selected{2}); continue; end
    if ~isempty(regexp(line,'^defaults(?:\s|$)','once'))
        location=[];
        current=struct('profile',0,'rateprofile',0,'battery_profile',0);
        continue;
    end
    pair=regexp(line,'^set\s+([A-Za-z][A-Za-z0-9_]*)\s*=','tokens','once');
    if ~isempty(pair) && strcmp(pair{1},item.Name) && ...
            (strcmp(item.Scope,'master') || current.(item.Scope)==index)
        location=k;
    end
end
assignment=string(sprintf('set %s = %s',item.Name,value));
if ~isempty(location)
    lines(location)=assignment;
else
    added=assignment;
    if ~strcmp(item.Scope,'master')
        added=[string(sprintf('%s %d',item.Scope,index)); assignment; ...
            string(sprintf('%s %d',item.Scope,current.(item.Scope)))];
    end
    lines=insertBeforeExit(lines,added);
end
config.CLI=char(join(lines,newline));
end

function lines=insertBeforeExit(lines,added)
stop=find(~cellfun('isempty',regexp(cellstr(strtrim(lines)),'^(save|exit)(\s|$)','once')),1,'first');
if isempty(stop), stop=numel(lines)+1; end
lines=[lines(1:stop-1);added;lines(stop:end)];
end
