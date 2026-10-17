function settings = upgradeSettings(settings)
%UPGRADESETTINGS Supply newly exposed sensor defaults in older saved settings.
% Fill only these added fields; missing original inputs still fail validation.
keys={'accel.sample_rate','accel.noise_density','accel.bias','accel.vibration', ...
    'gyro.sample_rate','gyro.noise_density','gyro.bias','gyro.vibration'};
schema=hover.settingsSchema();
if ~isfield(settings,'drag_enabled'), settings.drag_enabled=true; end
for k=1:numel(keys)
    parts=strsplit(keys{k},'.');
    if isfield(settings,parts{1}) && ~isfield(settings.(parts{1}),parts{2})
        item=schema(strcmp({schema.Key},keys{k}));
        settings.(parts{1}).(parts{2})=item.Default;
    end
end
end
