function [fig,metrics]=plotImuNoise(output,variables)
%PLOTIMUNOISE Inspect measured-minus-ideal IMU signals on their own time grids.
fig=figure('Name','Simulated IMU noise','Color','w','Position',[100 80 1200 750]);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
state='OFF'; if variables.noise_true, state='ON'; end
title(layout,sprintf('Simulated IMU noise %s | seed %d',state,variables.seed));
subtitle(layout,'Raw sensor error includes bias, white noise, vibration and sample/quantization effects.');
metrics=struct();
for k=1:2
    kinds={'accel','gyro'}; kind=kinds{k};
    measured=output.logsout.getElement(['imu_' kind '_measured']).Values;
    ideal=output.logsout.getElement(['imu_' kind '_ideal']).Values;
    t=measured.Time;
    data=valuesByTime(measured);
    truth=valuesByTime(ideal);
    error=data-interp1(ideal.Time,truth,t,'previous','extrap');
    if k==1, unit='m/s^2'; label='Accelerometer'; factor=1;
    else, unit='deg/s'; label='Gyroscope'; factor=180/pi; end
    error=error*factor;
    metrics.([kind 'ErrorRms'])=sqrt(mean(error.^2));
    metrics.([kind 'ErrorStd'])=std(error);
    metrics.([kind 'Units'])=unit;
    for row=1:2
        ax=nexttile(layout,k+2*(row-1));
        if row==1, index=unique(round(linspace(1,numel(t),min(10000,numel(t)))));
        else, index=find(t>=max(0,t(end)-0.5)); end
        plot(ax,t(index),error(index,:),'LineWidth',0.8);
        grid(ax,'on'); xlabel(ax,'Time (s)'); ylabel(ax,unit);
        legend(ax,{'X','Y','Z'},'Location','best');
        if row==1, title(ax,[label ': measured - ideal']);
        else, title(ax,[label ': final 0.5 s']); end
        xlim(ax,[t(index(1)) t(index(end))]);
    end
end
end

function data=valuesByTime(signal)
% Logged column-vector signals store time last: 3-by-1-by-N.
raw=signal.Data; count=numel(signal.Time);
if count>1 && ~ismatrix(raw) && size(raw,ndims(raw))==count
    raw=permute(raw,[ndims(raw) 1:ndims(raw)-1]);
elseif count>1 && size(raw,1)~=count && size(raw,2)==count
    raw=raw';
end
data=reshape(raw,count,3);
end
