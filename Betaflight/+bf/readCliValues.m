function values = readCliValues(cliText,schema)
%READCLIVALUES Index scoped CLI assignments once for responsive GUI filtering.
arguments
    cliText {mustBeText}
    schema struct
end
values=containers.Map('KeyType','char','ValueType','char');
scopes=containers.Map('KeyType','char','ValueType','char');
for k=1:numel(schema), scopes(schema(k).Name)=schema(k).Scope; end
current=struct('profile',0,'rateprofile',0,'battery_profile',0);
lines=splitlines(join(string(cliText),newline));
for k=1:numel(lines)
    line=strtrim(char(lines(k)));
    selected=regexp(line,'^(profile|rateprofile|battery_profile)\s+(\d+)\s*$','tokens','once');
    if ~isempty(selected), current.(selected{1})=str2double(selected{2}); continue; end
    if ~isempty(regexp(line,'^defaults(?:\s|$)','once'))
        values=containers.Map('KeyType','char','ValueType','char');
        current=struct('profile',0,'rateprofile',0,'battery_profile',0);
        continue;
    end
    pair=regexp(line,'^set\s+([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*)$','tokens','once');
    if isempty(pair) || ~isKey(scopes,pair{1}), continue; end
    scope=scopes(pair{1}); index=0;
    if ~strcmp(scope,'master'), index=current.(scope); end
    key=sprintf('%s|%s|%d',pair{1},scope,index);
    values(key)=strtrim(pair{2});
end
end
