function config=calibratedConfig(config,options)
%CALIBRATEDCONFIG Optional ideal bench calibration from simulated sensor bias.
% Only sets the firmware's native integer accelerometer calibration values.
% No attitude/position truth or real-time bias correction enters flight code.
% Disable UseKnownAccelCalibration to use the user's CLI offsets unchanged.
if ~options.UseKnownAccelCalibration, return; end
offsets=round(-options.CalibrationAccelBias(:)*256/9.80665);
schema=bf.parseCliSettings(config.SchemaText);
item=schema(strcmp({schema.Name},'acc_calibration'));
config=bf.setSetting(config,item(1),sprintf('%d,%d,%d,1',offsets),0);
end
