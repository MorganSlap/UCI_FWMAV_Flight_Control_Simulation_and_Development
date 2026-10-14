function value = settingValue(cliText,item,index,values)
%SETTINGVALUE Read the final value for one scoped setting from a CLI script.
arguments
    cliText {mustBeText}
    item (1,1) struct
    index (1,1) double = 0
    values = []
end
value=item.Default;
if index==item.Index || strcmp(item.Scope,'master'), value=item.Value; end
if isa(values,'containers.Map')
    if strcmp(item.Scope,'master'), index=0; end
    key=sprintf('%s|%s|%d',item.Name,item.Scope,index);
    if isKey(values,key), value=values(key); end
    return;
end
current=struct('profile',0,'rateprofile',0,'battery_profile',0);
lines=splitlines(join(string(cliText),newline));
for k=1:numel(lines)
    line=strtrim(char(lines(k)));
    selected=regexp(line,'^(profile|rateprofile|battery_profile)\s+(\d+)\s*$','tokens','once');
    if ~isempty(selected), current.(selected{1})=str2double(selected{2}); continue; end
    if ~isempty(regexp(line,'^defaults(?:\s|$)','once'))
        value=item.Default;
        current=struct('profile',0,'rateprofile',0,'battery_profile',0);
        continue;
    end
    pair=regexp(line,'^set\s+([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*)$','tokens','once');
    if isempty(pair) || ~strcmp(pair{1},item.Name), continue; end
    if strcmp(item.Scope,'master') || current.(item.Scope)==index
        value=strtrim(pair{2});
    end
end
end
