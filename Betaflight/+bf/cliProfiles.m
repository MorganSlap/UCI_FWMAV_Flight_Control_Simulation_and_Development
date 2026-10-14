function profiles = cliProfiles(cliText,schema)
%CLIPROFILES Find observed profile indexes; never invent firmware capacities.
arguments
    cliText {mustBeText}
    schema struct = bf.parseCliSettings('')
end
profiles=struct('profile',[],'rateprofile',[],'battery_profile',[], ...
    'SelectedProfile',0,'SelectedRateprofile',0,'SelectedBatteryprofile',0);
names={'profile','rateprofile','battery_profile'};
selected={'SelectedProfile','SelectedRateprofile','SelectedBatteryprofile'};
lines=splitlines(join(string(cliText),newline));
for k=1:numel(names)
    name=names{k}; indexes=[];
    for j=1:numel(lines)
        token=regexp(strtrim(char(lines(j))),['^' name '\s+(\d+)\s*$'],'tokens','once');
        if ~isempty(token)
            index=str2double(token{1}); indexes(end+1)=index; %#ok<AGROW>
            profiles.(selected{k})=index;
        end
    end
    if ~isempty(schema)
        indexes=[indexes [schema(strcmp({schema.Scope},name)).Index]]; %#ok<AGROW>
    end
    profiles.(name)=unique(indexes,'stable');
end
end
