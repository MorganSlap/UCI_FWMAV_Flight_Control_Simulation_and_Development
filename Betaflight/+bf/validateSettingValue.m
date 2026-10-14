function value = validateSettingValue(item,value)
%VALIDATESETTINGVALUE Enforce constraints reported by the actual firmware.
if ~((ischar(value) && (isrow(value)||isempty(value))) || ...
        (isstring(value)&&isscalar(value)) || (isnumeric(value)&&isscalar(value)))
    error('bf:InvalidValue','Enter one setting value as text or a numeric scalar.');
end
value=strtrim(char(string(value)));
if contains(value,{newline,char(13)})
    error('bf:InvalidValue','A setting value must fit on one CLI line.');
end
switch item.Type
    case 'integer'
        number=str2double(value);
        if ~isscalar(number) || ~isfinite(number) || fix(number)~=number || ...
                number<item.Minimum || number>item.Maximum
            error('bf:InvalidValue','%s requires an integer from %g to %g.',item.Name,item.Minimum,item.Maximum);
        end
        value=sprintf('%.0f',number);
    case 'choice'
        match=find(strcmpi(value,item.Choices),1);
        if isempty(match)
            error('bf:InvalidValue','%s accepts: %s.',item.Name,strjoin(item.Choices,', '));
        end
        value=item.Choices{match};
    case 'array'
        parts=strtrim(split(string(value),','));
        numbers=str2double(parts);
        if numel(numbers)~=item.ArrayLength || any(~isfinite(numbers)) || any(fix(numbers)~=numbers)
            error('bf:InvalidValue','%s requires %d comma-separated integers.',item.Name,item.ArrayLength);
        end
        value=char(join(compose('%.0f',numbers),', '));
    otherwise
        % Betaflight uses '-' to represent an empty string in CLI output.
        if isempty(value) || strcmp(value,'-'), value='-'; return; end
        count=strlength(string(value));
        if (~isnan(item.LengthMinimum) && count<item.LengthMinimum) || ...
                (~isnan(item.LengthMaximum) && count>item.LengthMaximum)
            error('bf:InvalidValue','%s requires a string length from %g to %g.',item.Name,item.LengthMinimum,item.LengthMaximum);
        end
end
end
