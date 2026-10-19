function schema=nativeAngleSchema(config)
%NATIVEANGLESCHEMA PID-page control for the native outer attitude loop.
native=bf.parseCliSettings(config.SchemaText);
item=native(strcmp({native.Name},'angle_p_gain'));
if isempty(item), error('hover:MissingNativeSetting','Firmware does not expose angle_p_gain.'); end
schema=struct('Key','firmware.angle_p_gain','Label','ANGLE mode P gain', ...
    'Group','PID','Unit','native','Default',str2double(item(1).Default), ...
    'Kind','number','Choices',{{}},'Help',[item(1).Constraint ...
    ' Native angle_p_gain in the selected PID profile. Converts roll/pitch angle error to a rate target in ANGLE mode. Separate from rate P and estimator Kp.']);
end
