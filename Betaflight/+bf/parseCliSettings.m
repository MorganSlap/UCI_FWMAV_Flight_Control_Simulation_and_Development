function schema = parseCliSettings(text)
%PARSECLISETTINGS Parse the compiled firmware's CLI `get` response.
% No setting names or firmware limits are synthesized. Profile markers refer
% to the preceding setting, matching Betaflight's cliGet implementation.
arguments
    text {mustBeText}
end
template = struct('Name','','Value','','Default','','Scope','master', ...
    'Index',0,'Type','text','Minimum',NaN,'Maximum',NaN, ...
    'Choices',{{}},'ArrayLength',NaN,'LengthMinimum',NaN, ...
    'LengthMaximum',NaN,'Constraint','','Group','Other');
schema = repmat(template,0,1);
lines = splitlines(join(string(text),newline));
for k = 1:numel(lines)
    line = strtrim(char(lines(k)));
    assignment = regexp(line,'^(?:#\s*)?([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*)$','tokens','once');
    if ~isempty(assignment)
        item = template;
        item.Name = assignment{1}; item.Value = strtrim(assignment{2});
        item.Default = item.Value;
        item.Group = classify(item.Name);
        schema(end+1,1) = item; %#ok<AGROW>
        continue;
    end
    if isempty(schema), continue; end
    range = regexp(line,'^Allowed range:\s*(-?[\d.]+)\s*-\s*(-?[\d.]+)','tokens','once');
    choices = regexp(line,'^Allowed values:\s*(.*)$','tokens','once');
    count = regexp(line,'^Array length:\s*(\d+)','tokens','once');
    lengthRange = regexp(line,'^String length:\s*(\d+)\s*-\s*(\d+)','tokens','once');
    profile = regexp(line,'^(?:#\s*)?(profile|rateprofile|battery_profile)\s+(\d+)','tokens','once');
    defaultValue = regexp(line,'^Default value:\s*(.*)$','tokens','once');
    if ~isempty(range)
        schema(end).Type='integer';
        schema(end).Minimum=str2double(range{1}); schema(end).Maximum=str2double(range{2});
        schema(end).Constraint=line;
    elseif ~isempty(choices)
        schema(end).Type='choice';
        schema(end).Choices=cellstr(strtrim(split(string(choices{1}),','))).';
        schema(end).Constraint=line;
    elseif ~isempty(count)
        schema(end).Type='array'; schema(end).ArrayLength=str2double(count{1});
        schema(end).Constraint=line;
    elseif ~isempty(lengthRange)
        schema(end).Type='text';
        schema(end).LengthMinimum=str2double(lengthRange{1});
        schema(end).LengthMaximum=str2double(lengthRange{2});
        schema(end).Constraint=line;
    elseif ~isempty(profile)
        schema(end).Scope=profile{1}; schema(end).Index=str2double(profile{2});
    elseif ~isempty(defaultValue)
        schema(end).Default=strtrim(defaultValue{1});
    end
end
if ~isempty(schema)
    keys=string({schema.Name})+"|"+string({schema.Scope})+"|"+string([schema.Index]);
    [~,keep]=unique(keys,'stable'); schema=schema(keep);
end
end

function group=classify(name)
if ~isempty(regexp(name,'^(p_|i_|d_|f_|d_max|feedforward|iterm|anti_gravity|pid_|simplified_|tpa_|angle_|horizon_)','once'))
    group='PID and feedforward';
elseif contains(name,{'filter','lpf','notch','rpm_filter','dyn_notch'})
    group='Filters';
elseif contains(name,{'rate','expo','rc_smoothing','rc_interpolation'})
    group='Rates and smoothing';
elseif startsWith(name,{'rx_','serialrx','sbus','ibus','spektrum','crsf','mid_rc','min_check','max_check','failsafe','deadband','yaw_deadband'})
    group='Receiver and failsafe';
elseif startsWith(name,{'motor','dshot','servo','min_throttle','max_throttle','min_command','throttle','yaw_motors','mixer'})
    group='Motors and mixer';
elseif startsWith(name,{'gyro','acc_','align_','imu_'})
    group='Sensors and attitude';
elseif startsWith(name,{'vbat','battery','current','ibata','vbat','vtx','osd','beeper','led'})
    group='Power and peripherals';
else
    group='Other';
end
end
