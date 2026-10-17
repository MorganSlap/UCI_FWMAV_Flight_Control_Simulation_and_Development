function fitPlot(ax,timeLimits)
%FITPLOT Full-data limits, also the baseline for Home/Restore view.
if nargin<2, timeLimits=[]; end
lines=findobj(ax,'Type','line'); ranges=zeros(0,4);
for k=1:numel(lines)
    source=getappdata(lines(k),'HoverFullSignal');
    if ~isempty(source)
        if ~isempty(source.Bounds), ranges(end+1,:)=source.Bounds; end %#ok<AGROW>
    else
        t=lines(k).XData; y=lines(k).YData; good=isfinite(t)&isfinite(y);
        if any(good), ranges(end+1,:)=[min(t(good)) max(t(good)) min(y(good)) max(y(good))]; end %#ok<AGROW>
    end
end
if isempty(timeLimits)
    if isempty(ranges), timeLimits=[0 1];
    else, timeLimits=[min(ranges(:,1)) max(ranges(:,2))]; end
end
if timeLimits(1)==timeLimits(2), timeLimits=timeLimits+[-0.5 0.5]; end
ax.XLim=timeLimits;
if ~isempty(ranges)
    low=min(ranges(:,3)); high=max(ranges(:,4));
    padding=max((high-low)*0.05,max(abs([low high]))*1e-6);
    if padding==0, padding=0.05; end
    ax.YLim=[low-padding high+padding];
else
    ax.YLim=[0 1];
end
hover.refreshPlot(ax);
zoom(ax,'reset');
end
