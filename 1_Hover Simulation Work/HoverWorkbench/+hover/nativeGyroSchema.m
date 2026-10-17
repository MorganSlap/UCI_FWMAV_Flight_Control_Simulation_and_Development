function schema=nativeGyroSchema(config)
%NATIVEGYROSCHEMA Common active gyro filters; constraints come from firmware.
native=bf.parseCliSettings(config.SchemaText);
names={'simplified_gyro_filter','gyro_lpf1_type','gyro_lpf1_static_hz', ...
    'gyro_lpf1_dyn_min_hz','gyro_lpf1_dyn_max_hz','gyro_lpf2_static_hz','gyro_calib_noise_limit'};
labels={'Native simplified filter tuning','Native gyro LPF1 type','Native gyro LPF1 static cutoff', ...
    'Native dynamic LPF minimum (0 = off)','Native dynamic LPF maximum','Native gyro LPF2 cutoff (0 = off)', ...
    'Native calibration movement threshold'};
schema=repmat(hover.nativeAttitudeSchema(),1,0);
for k=1:numel(names)
    item=native(strcmp({native.Name},names{k})); item=item(1);
    kind='number'; value=str2double(item.Value); choices={}; unit='Hz';
    if strcmp(item.Type,'choice'), kind='choice'; choices=item.Choices; value=item.Value; unit=''; end
    if strcmp(names{k},'gyro_calib_noise_limit'), unit='ADC counts'; end
    schema(end+1)=struct('Key',['firmware.' names{k}],'Label',labels{k}, ...
        'Group','Sensors and estimator','Unit',unit,'Default',value,'Kind',kind,'Choices',{choices}, ...
        'Help',[item.Constraint ' Changes the actual native firmware configuration.']); %#ok<AGROW>
end
end
