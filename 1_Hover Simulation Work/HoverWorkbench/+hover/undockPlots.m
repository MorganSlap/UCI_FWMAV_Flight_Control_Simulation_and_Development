function fig = undockPlots(sourceAxes,windowName)
%UNDOCKPLOTS Independent figure snapshot retaining full samples and zoom.
fig=figure('Name',char(windowName),'NumberTitle','off','WindowStyle','normal');
count=numel(sourceAxes);
if count==1, rows=1; columns=1; else, rows=ceil(count/2); columns=2; end
tiles=tiledlayout(fig,rows,columns,'TileSpacing','compact','Padding','compact');
for k=1:count
    source=sourceAxes(k); ax=nexttile(tiles);
    hold(ax,'on');
    traces=flipud(findobj(source,'Type','line'));
    for j=1:numel(traces)
        trace=traces(j); full=getappdata(trace,'HoverFullSignal');
        if isempty(full), full=struct('Time',trace.XData,'Data',trace.YData); end
        copied=hover.plotSignal(ax,full.Time,full.Data,'DisplayName',trace.DisplayName, ...
            'Color',trace.Color,'LineStyle',trace.LineStyle,'LineWidth',trace.LineWidth);
        copied.UserData=trace.UserData;
    end
    notes=findobj(source.Children,'Type','text');
    if ~isempty(notes), copyobj(notes,ax); end
    title(ax,source.Title.String,'Interpreter','none');
    subtitle(ax,source.Subtitle.String,'Interpreter','none');
    xlabel(ax,source.XLabel.String,'Interpreter','none');
    ylabel(ax,source.YLabel.String,'Interpreter','none'); grid(ax,'on');
    if ~isempty(traces), legend(ax,'show','Interpreter','none','Location','northeast'); end
    hold(ax,'off'); hover.fitPlot(ax);
    ax.XLim=source.XLim; ax.YLim=source.YLim;
end
end
