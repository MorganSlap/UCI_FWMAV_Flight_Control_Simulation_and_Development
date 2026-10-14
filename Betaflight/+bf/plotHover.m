function fig=plotHover(output,variables,label)
%PLOTHOVER Plot flight evidence, including true height only for analysis.
arguments
    output
    variables (1,1) struct
    label (1,1) string = "IMU-only flight"
end
t=output.state_output.time; x=output.state_output.signals.values;
td=output.betaflight_diagnostics.time;
d=squeeze(output.betaflight_diagnostics.signals.values)';
% Display at most 5000 points per curve; metrics always use every sample.
i=unique(round(linspace(1,numel(t),min(5000,numel(t)))));
j=unique(round(linspace(1,numel(td),min(5000,numel(td)))));
fig=figure('Name',char(label),'Color','w','Position',[100 80 1200 800]);
layout=tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
title(layout,label,'FontWeight','bold','Interpreter','none');
noiseLabel='OFF'; if variables.noise_true, noiseLabel='ON'; end
subtitle(layout,sprintf('Noise %s (seed %d) | Fixed throttle; IMU only. Position/height are analysis signals.',noiseLabel,variables.seed));
colors=[0.09 0.38 0.62;0.91 0.55 0.08;0.30 0.58 0.40;0.56 0.32 0.66];
for axis=1:2
    ax=nexttile(layout); colororder(ax,colors);
    plot(ax,t(i),x(i,6+axis)*180/pi,'LineWidth',1.5); hold(ax,'on');
    plot(ax,td(j),d(j,9+axis)*180/pi,'--','LineWidth',1.1);
    yline(ax,variables.Xref(6+axis)*180/pi,':','Reference');
    names={'Roll','Pitch'}; title(ax,names{axis}); ylabel(ax,'deg');
    legend(ax,{'True','Firmware estimate'},'Location','best');
end
ax=nexttile(layout); colororder(ax,colors);
plot(ax,t(i),x(i,10:12)*180/pi,'LineWidth',1.1);
title(ax,'True body rates'); ylabel(ax,'deg/s'); legend(ax,{'p','q','r'},'Location','best');
ax=nexttile(layout); colororder(ax,colors);
plot(ax,td(j),d(j,6:9),'LineWidth',1.1); hold(ax,'on');
yline(ax,variables.u0,'k:','Plant hover trim');
title(ax,'Native motor output'); ylabel(ax,'PWM / pot command');
legend(ax,{'Front','Right','Rear','Left'},'Location','best');
ax=nexttile(layout); colororder(ax,colors);
plot(ax,t(i),x(1,3)-x(i,3),'LineWidth',1.5); title(ax,'Height change (truth, no feedback)'); ylabel(ax,'m, up positive');
ax=nexttile(layout); colororder(ax,colors);
plot(ax,t(i),x(i,1:2)-x(1,1:2),'LineWidth',1.3); title(ax,'Horizontal displacement (truth)'); ylabel(ax,'m');
legend(ax,{'North','East'},'Location','best');
axesList=findall(fig,'Type','axes');
for k=1:numel(axesList)
    ax=axesList(k); grid(ax,'on'); xlabel(ax,'Time (s)'); xlim(ax,[t(1) t(end)]);
end
linkaxes(axesList,'x');
end
