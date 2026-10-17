function lineHandle = plotSignal(ax,time,data,varargin)
%PLOTSIGNAL Keep full samples in memory, bound the rendered point count.
time=double(time(:)); data=double(data(:));
% Updating viewport data must never feed back into automatic axis limits.
% Low-level line also avoids plot/newplot resetting limits and callbacks.
ax.XLimMode='manual'; ax.YLimMode='manual';
lineHandle=line(ax,NaN,NaN,varargin{:});
finiteData=data(isfinite(data));
bounds=[];
if ~isempty(time) && ~isempty(finiteData)
    bounds=[time(1),time(end),min(finiteData),max(finiteData)];
end
setappdata(lineHandle,'HoverFullSignal',struct('Time',time,'Data',data,'Bounds',bounds));
% Ruler callback also fires for Home, unlike an axes XLim PostSet listener.
ax.XAxis.LimitsChangedFcn=@(~,~)hover.refreshPlot(ax);
hover.refreshPlot(ax);
end
