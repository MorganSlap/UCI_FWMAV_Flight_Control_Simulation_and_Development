function signals = collectSignals(simOut, variables)
%COLLECTSIGNALS Convert simulation outputs into named scalar time series.
%   Signals retain their own time vectors; no resampling is done except for
%   true-minus-estimated errors. Raw SI state channels and useful display-unit
%   channels coexist. The original outputs remain untouched in the archive.
arguments
    simOut
    variables (1,1) struct = struct()
end
template = struct('Name','','Group','','Unit','','Time',[], ...
    'Data',[],'Key','','Source','');
signals = repmat(template,0,1);
stateKeys = {'x','y','z','u','v','w','phi','theta','psi','p','q','r'};
stateNames = {'x position','y position','z position (down)', ...
    'u velocity','v velocity','w velocity (down)', ...
    'Roll angle','Pitch angle','Yaw angle','Roll rate','Pitch rate','Yaw rate'};
stateUnits = {'m','m','m','m/s','m/s','m/s', ...
    'rad','rad','rad','rad/s','rad/s','rad/s'};
[trueTime,trueData] = readKnown('state_output',12);
[estTime,estData] = readKnown('state_estimate',12);
[controlTime,controlData] = readKnown('controls',4);
[firmwareTime,firmwareData] = readKnown('betaflight_diagnostics',40);
if ~isempty(firmwareData)
    axes={'Roll','Pitch','Yaw'}; terms={'P','I','D','F'};
    if isfield(variables,'bfSim') && isfield(variables,'Xref')
        [commands,commandKeys,commandUnits]=bf.commandSeries(firmwareTime,variables.Xref,variables.bfSim);
        for axis=1:numel(commandKeys)
            add(['command.' commandKeys{axis}],['Requested ' axes{axis}], ...
                'Requested commands',commandUnits{axis},firmwareTime,commands(:,axis), ...
                'Saved Xref + ReferenceSchedule (before native receiver processing)');
        end
    end
    for motor=1:4
        add(sprintf('betaflight.motor%d',motor),sprintf('Firmware motor %d',motor), ...
            'Betaflight motors','us',firmwareTime,firmwareData(:,5+motor),'betaflight_diagnostics');
    end
    for axis=1:3
        name=lower(axes{axis});
        add(['betaflight.receiver_rate.' name],[axes{axis} ' receiver rate'], ...
            'Betaflight receiver','rad/s',firmwareTime,firmwareData(:,15+axis),'betaflight_diagnostics');
        for term=1:4
            add(['betaflight.pid.' name '.' terms{term}],[axes{axis} ' ' terms{term}], ...
                'Betaflight PID','native units',firmwareTime,firmwareData(:,18+4*(axis-1)+term),'betaflight_diagnostics');
        end
        add(['betaflight.pid.' name '.Sum'],[axes{axis} ' PID sum'], ...
            'Betaflight PID','native units',firmwareTime,firmwareData(:,36+axis),'betaflight_diagnostics');
    end
    keys={'armed','arming_disable_flags','flight_mode_flags','gyro_period','pid_period','motor_count'};
    names={'Armed','Arming disable flags','Flight mode flags','Gyro loop period','PID loop period','Motor count'};
    units={'','bitmask','bitmask','us','us',''};
    for k=1:6
        add(['betaflight.' keys{k}],names{k},'Betaflight status',units{k}, ...
            firmwareTime,firmwareData(:,30+k),'betaflight_diagnostics');
    end
end
for k = 1:12
    if ~isempty(trueData)
        add(['state.' stateKeys{k}],stateNames{k},'True state', ...
            stateUnits{k},trueTime,trueData(:,k),'state_output');
    end
    if ~isempty(estData)
        add(['estimate.' stateKeys{k}],['Estimated ' stateNames{k}], ...
            'Estimated state',stateUnits{k},estTime,estData(:,k),'state_estimate');
    end
end
if ~isempty(controlData)
    trim = [];
    if isfield(variables,'u0') && isnumeric(variables.u0) && isscalar(variables.u0)
        trim = variables.u0;
    end
    for k = 1:4
        add(sprintf('control.delta%d',k),sprintf('Delta control %d',k), ...
            'Control','pot units',controlTime,controlData(:,k),'controls');
        if ~isempty(trim)
            add(sprintf('control.pot%d',k),sprintf('Control %d (pot%d)',k,k), ...
                'Control','pot units',controlTime,controlData(:,k)+trim,'controls + u0');
        end
    end
end
if ~isempty(trueData)
    add('derived.altitude','Altitude','Derived','m',trueTime,-trueData(:,3),'state_output');
    downSpeed=-sin(trueData(:,8)).*trueData(:,4) ...
        +sin(trueData(:,7)).*cos(trueData(:,8)).*trueData(:,5) ...
        +cos(trueData(:,7)).*cos(trueData(:,8)).*trueData(:,6);
    if isfield(variables,'sim_fidelity') && strcmp(variables.sim_fidelity,'low')
        % The hover-linearized position equation is directly zdot = w.
        downSpeed=trueData(:,6);
    end
    add('derived.altitude_rate','Altitude rate','Derived','m/s',trueTime,-downSpeed,'state_output (body to NED velocity)');
    addDegrees(trueTime,trueData,'state','True', 'state_output');
end
if ~isempty(estData)
    addDegrees(estTime,estData,'estimate','Estimated','state_estimate');
end
if ~isempty(trueData) && ~isempty(estData)
    [uniqueTime,indices] = unique(trueTime,'last');
    if numel(uniqueTime) == 1
        trueOnEst = repmat(trueData(indices,:),numel(estTime),1);
    else
        trueOnEst = interp1(uniqueTime,trueData(indices,:),estTime,'linear','extrap');
    end
    errorData = trueOnEst-estData;
    errorData(:,7:9)=atan2(sin(errorData(:,7:9)),cos(errorData(:,7:9)));
    for k = 1:12
        add(['error.' stateKeys{k}],[stateNames{k} ' error'], ...
            'Estimation error',stateUnits{k},estTime,errorData(:,k), ...
            'state_output - state_estimate');
    end
    addDegrees(estTime,errorData,'error','Error','state_output - state_estimate');
end

% Additional To Workspace outputs and signal-logging datasets are browsable
% without editing the app. Buses and vector-valued signals are expanded.
outputNames = namesOf(simOut);
skipNames = {'state_output','state_estimate','controls','tout', ...
    'SimulationMetadata','ErrorMessage','betaflight_diagnostics'};
fallbackTime = getMember(simOut,'tout');
for k = 1:numel(outputNames)
    name = char(outputNames{k});
    if ismember(name,skipNames), continue; end
    value = getMember(simOut,name);
    try
        visit(value,name,['logged.' name],fallbackTime);
    catch exception
        warning('hover:UnrecognizedSignal', ...
            'Could not normalize %s; raw output is preserved: %s',name,exception.message);
    end
end

gravity=9.81;
if isfield(variables,'g'), gravity=variables.g; end
signals=hover.addImuSignals(signals,gravity);

    function [time,data] = readKnown(name,width)
        value = getMember(simOut,name);
        time = []; data = [];
        if isempty(value), return; end
        [time,data] = unpack(value,[]);
        if ~isempty(data) && size(data,2) ~= width
            error('hover:SignalShape', ...
                '%s has %d components; this model expects %d.',name,size(data,2),width);
        end
    end

    function add(key,name,group,unit,time,data,source)
        item = template;
        item.Name = char(name);
        item.Group = char(group);
        item.Unit = char(unit);
        item.Time = time(:);
        item.Data = data(:);
        item.Key = char(key);
        item.Source = char(source);
        originalKey = item.Key;
        suffix = 2;
        while any(strcmp({signals.Key},item.Key))
            item.Key = sprintf('%s_%d',originalKey,suffix);
            suffix = suffix+1;
        end
        signals(end+1,1) = item;
    end

    function addDegrees(time,data,prefix,label,source)
        for component = 7:12
            if component <= 9, unit = 'deg'; else, unit = 'deg/s'; end
            add(['display.' prefix '.' stateKeys{component}], ...
                [label ' ' stateNames{component} ' (degrees)'], ...
                'Display units',unit,time,data(:,component)*180/pi,source);
        end
    end

    function visit(value,name,key,timeHint)
        if isa(value,'Simulink.SimulationData.Dataset')
            for elementIndex = 1:value.numElements
                element = value.getElement(elementIndex);
                elementName = '';
                if isprop(element,'Name'), elementName = char(element.Name); end
                if isempty(elementName), elementName = sprintf('Signal %d',elementIndex); end
                visit(element,[name '/' elementName], ...
                    [key '.' matlab.lang.makeValidName(elementName)],timeHint);
            end
        elseif isa(value,'Simulink.SimulationData.Signal') || ...
                isa(value,'Simulink.SimulationData.State')
            visit(value.Values,name,key,timeHint);
        elseif isa(value,'timeseries') || istimetable(value) || ...
                (isstruct(value) && isfield(value,'time') && isfield(value,'signals')) || ...
                ((isnumeric(value) || islogical(value)) && ~isempty(timeHint))
            [time,data,unit] = unpack(value,timeHint);
            if isempty(unit) && startsWith(key,'logged.logsout.imu_accel_'), unit='m/s^2'; end
            if isempty(unit) && startsWith(key,'logged.logsout.imu_gyro_'), unit='rad/s'; end
            for component = 1:size(data,2)
                componentName = name;
                componentKey = key;
                if size(data,2) > 1
                    componentName = sprintf('%s [%d]',name,component);
                    componentKey = sprintf('%s.%d',key,component);
                end
                add(componentKey,componentName,'Logged',unit,time,data(:,component),name);
            end
        elseif isstruct(value) && isscalar(value)
            fields = fieldnames(value);
            for fieldIndex = 1:numel(fields)
                field = fields{fieldIndex};
                visit(value.(field),[name '/' field],[key '.' field],timeHint);
            end
        end
    end
end

function names = namesOf(value)
if isa(value,'Simulink.SimulationOutput')
    names = who(value);
elseif isstruct(value)
    names = fieldnames(value);
else
    names = {};
end
end

function value = getMember(container,name)
value = [];
if isa(container,'Simulink.SimulationOutput')
    if any(strcmp(who(container),name)), value = container.get(name); end
elseif isstruct(container) && isfield(container,name)
    value = container.(name);
end
end

function [time,data,unit] = unpack(value,timeHint)
unit = '';
if isa(value,'timeseries')
    time = value.Time;
    rawData = value.Data;
    if ~isempty(value.DataInfo.Units), unit = char(value.DataInfo.Units); end
elseif istimetable(value)
    rowTimes = value.Properties.RowTimes;
    if isdatetime(rowTimes), time = seconds(rowTimes-rowTimes(1));
    else, time = seconds(rowTimes); end
    rawData = value.Variables;
elseif isstruct(value) && isfield(value,'time') && isfield(value,'signals')
    time = value.time;
    data = [];
    for k = 1:numel(value.signals)
        data = [data orient(value.signals(k).values,numel(time))]; %#ok<AGROW>
    end
    time = double(time(:));
    return;
else
    time = timeHint;
    rawData = value;
end
time = double(time(:));
data = orient(rawData,numel(time));
end

function data = orient(rawData,nTime)
if isempty(rawData) || nTime == 0, data = []; return; end
if ~(isnumeric(rawData) || islogical(rawData))
    error('hover:SignalShape','Only numeric or logical time series are supported.');
end
shape = size(rawData);
if nTime == 1
    data = reshape(rawData,1,[]);
elseif numel(shape)>2 && shape(end)==nTime
    % Simulink matrix-valued Structure With Time stores time last. This
    % remains true when sample count happens to equal a signal dimension.
    rawData=permute(rawData,[ndims(rawData),1:ndims(rawData)-1]);
    data=reshape(rawData,nTime,[]);
elseif shape(1) == nTime
    data = reshape(rawData,nTime,[]);
else
    timeDimension = find(shape == nTime,1,'last');
    if isempty(timeDimension)
        error('hover:SignalShape','No data dimension matches the %d timestamps.',nTime);
    end
    dimensions = 1:ndims(rawData);
    dimensions(timeDimension) = [];
    rawData = permute(rawData,[timeDimension dimensions]);
    data = reshape(rawData,nTime,[]);
end
end
