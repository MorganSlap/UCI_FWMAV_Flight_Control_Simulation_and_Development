function signals=addImuSignals(signals,gravity)
%ADDIMUSIGNALS Friendly raw sensor channels, before firmware calibration/LPF.
if nargin<2, gravity=9.81; end
original=signals;
axes={'X','Y','Z'};
for sensor={'gyro','accel'}
    kind=sensor{1};
    if strcmp(kind,'gyro')
        group='Raw gyroscope'; unit='rad/s'; displayUnit='deg/s'; factor=180/pi;
    else
        group='Raw accelerometer'; unit='m/s^2'; displayUnit='g'; factor=1/gravity;
    end
    for axis=1:3
        key=sprintf('logged.logsout.imu_%s_measured.%d',kind,axis);
        index=find(strcmp({original.Key},key),1);
        if isempty(index), continue; end
        item=original(index); item.Group=group; item.Unit=unit;
        item.Name=sprintf('Raw %s %s (before firmware filters)',kind,axes{axis});
        item.Key=sprintf('sensor.%s.raw.%s',kind,lower(axes{axis}));
        append(item);
        item.Key=['display.' item.Key]; item.Data=item.Data*factor; item.Unit=displayUnit;
        item.Name=[item.Name ' (' displayUnit ')'];
        append(item);
    end
end
    function append(item)
        if ~any(strcmp({signals.Key},item.Key)), signals(end+1,1)=item; end
    end
end
