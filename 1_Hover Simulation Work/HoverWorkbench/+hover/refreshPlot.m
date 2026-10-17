function refreshPlot(ax)
%REFRESHPLOT Update existing lines when the visible time interval changes.
if ~isgraphics(ax) || isequal(getappdata(ax,'HoverRefreshing'),true), return; end
setappdata(ax,'HoverRefreshing',true);
cleanup=onCleanup(@()release(ax));
limits=ax.XLim;
lines=findobj(ax,'Type','line');
for k=1:numel(lines)
    source=getappdata(lines(k),'HoverFullSignal');
    if isempty(source), continue; end
    if isequal(getappdata(lines(k),'HoverViewport'),limits), continue; end
    [time,data]=hover.displaySamples(source.Time,source.Data,limits);
    set(lines(k),'XData',time,'YData',data);
    setappdata(lines(k),'HoverViewport',limits);
end
end

function release(ax)
if isgraphics(ax), setappdata(ax,'HoverRefreshing',false); end
end
