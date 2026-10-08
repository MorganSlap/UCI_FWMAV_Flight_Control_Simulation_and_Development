function defaultPlots(axesArray, record)
%DEFAULTPLOTS Render the four plots from lin_hover.m into supplied UI axes.
% State units, down-to-altitude signs, trim offsets and estimation error
% convention match the initialization script; signal time bases are preserved.
if numel(axesArray) ~= 4
    error('hover:PlotAxes','Provide four axes for the default plots.');
end
signals = record.Signals;
colors = lines(6);
titles = {'True states and rates','Absolute control inputs', ...
    'Estimated attitude and rates','Attitude and rate estimation error'};
ylabels = {'Position [m], velocity [m/s], angle [deg], rate [deg/s]', ...
    'Pot value','Angle [deg], rate [deg/s]','True - estimated [deg, deg/s]'};
for k = 1:4
    cla(axesArray(k));
    hold(axesArray(k),'on');
end
keys = {'x','y','z','u','v','w','phi','theta','psi','p','q','r'};
names = {'x position [m]','y position [m]','Altitude [m]', ...
    'u velocity [m/s]','v velocity [m/s]','Altitude rate [m/s]', ...
    'Roll angle [deg]','Pitch angle [deg]','Yaw angle [deg]', ...
    'Roll rate [deg/s]','Pitch rate [deg/s]','Yaw rate [deg/s]'};
factors = [1 1 -1 1 1 -1 repmat(180/pi,1,6)];
colorIndices = [1 2 3 1 2 3 4 5 6 4 5 6];
for k = 1:12
    style = '-';
    if ismember(k,[4:6 10:12]), style = '--'; end
    drawSignal(axesArray(1),['state.' keys{k}],names{k}, ...
        factors(k),style,colors(colorIndices(k),:));
end
for k = 1:4
    drawSignal(axesArray(2),sprintf('control.pot%d',k), ...
        sprintf('Control %d (pot%d)',k,k),1,'-',colors(k,:));
end
for k = 7:12
    style = '-';
    if k >= 10, style = '--'; end
    drawSignal(axesArray(3),['estimate.' keys{k}],names{k}, ...
        180/pi,style,colors(colorIndices(k),:));
    drawSignal(axesArray(4),['error.' keys{k}], ...
        strrep(names{k},' [',' error ['),180/pi,style,colors(colorIndices(k),:));
end
for k = 1:4
    ax = axesArray(k);
    title(ax,titles{k},'Interpreter','none');
    xlabel(ax,'Time [s]');
    ylabel(ax,ylabels{k});
    grid(ax,'on');
    if ~isempty(findobj(ax,'Type','line'))
        legend(ax,'show','Location','best','FontSize',9,'Interpreter','none');
    else
        text(ax,0.5,0.5,'No matching signals in this run', ...
            'Units','normalized','HorizontalAlignment','center');
    end
    hold(ax,'off');
end

    function drawSignal(ax,key,label,factor,style,color)
        index = find(strcmp({signals.Key},key),1);
        if isempty(index), return; end
        signal = signals(index);
        plot(ax,signal.Time,signal.Data*factor,style, ...
            'LineWidth',1.25,'DisplayName',label,'Color',color);
    end
end
