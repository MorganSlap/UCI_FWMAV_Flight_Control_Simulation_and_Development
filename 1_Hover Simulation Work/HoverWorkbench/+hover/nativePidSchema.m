function schema=nativePidSchema(config)
%NATIVEPIDSCHEMA Rate gains and tuning mode from the compiled firmware catalog.
native=bf.parseCliSettings(config.SchemaText);
schema=hover.nativeAngleSchema(config);
axes={'roll','pitch','yaw'};
terms={'p','i','d','f'};
labels={'proportional P','integral I','derivative D','feedforward F'};
for axis=1:numel(axes)
    for term=1:numel(terms)
        name=[terms{term} '_' axes{axis}];
        add(name,[upper(axes{axis}(1)) axes{axis}(2:end) ' ' labels{term}]);
    end
end
add('simplified_pids_mode','Simplified PID tuning');

    function add(name,label)
        item=native(strcmp({native.Name},name));
        if isempty(item), error('hover:MissingNativeSetting','Firmware does not expose %s.',name); end
        item=item(1); kind='number'; value=str2double(item.Default); choices={}; unit='native';
        if strcmp(item.Type,'choice')
            kind='choice'; value=item.Default; choices=item.Choices; unit='';
        end
        schema(end+1)=struct('Key',['firmware.' name],'Label',label, ...
            'Group','PID','Unit',unit,'Default',value,'Kind',kind,'Choices',{choices}, ...
            'Help',[item.Constraint ' Native Betaflight setting in the selected PID profile.']);
    end
end
