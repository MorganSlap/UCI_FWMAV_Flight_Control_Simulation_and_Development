function defaultPlots(axesArray, record, indices)
%DEFAULTPLOTS Plot selected quantities with peak-preserving overview rendering.
% Preserve each signal's timestamps. Position uses altitude=-z; velocity is
% body-frame u/v/w, with w positive down (not inertial altitude rate).
specs = hover.defaultPlotSpec();
if nargin<3, indices=1:numel(specs); end
if numel(axesArray) ~= numel(specs)
    error('hover:PlotAxes','Provide %d axes for the default plots.',numel(specs));
end
signals = record.Signals;
nativeFirmware = any(startsWith({signals.Key},'betaflight.')) || ...
    (isfield(record,'Variables') && isfield(record.Variables,'bfSim'));
colors = lines(4);
starts=arrayfun(@(s)min(s.Time),signals,'UniformOutput',false);
stops=arrayfun(@(s)max(s.Time),signals,'UniformOutput',false);
timeLimits=[min([starts{:}]) max([stops{:}])];
if isempty(timeLimits), timeLimits=[0 1]; end
for k = indices
    ax = axesArray(k);
    spec = specs(k);
    cla(ax);
    legend(ax,'off');
    title(ax,spec.Title,'Interpreter','none');
    xlabel(ax,'Time [s]');
    ylabel(ax,spec.YLabel);
    grid(ax,'on');
    hold(ax,'on');
    if nativeFirmware && spec.UnavailableForNative
        % The native adapter reserves these channels as zeros; they are not
        % position/velocity estimates and must not be drawn as measurements.
        text(ax,0.5,0.5,{'Not available in this run', ...
            'The native adapter does not output', ...
            'position or velocity estimates.'}, ...
            'Units','normalized','HorizontalAlignment','center');
    else
        for component = 1:numel(spec.Keys)
            index = find(strcmp({signals.Key},spec.Keys{component}),1);
            if isempty(index), continue; end
            signal = signals(index);
            hover.plotSignal(ax,signal.Time,signal.Data*spec.Factors(component), ...
                'LineWidth',1.0,'DisplayName',spec.Labels{component}, ...
                'Color',colors(component,:));
        end
        if ~isempty(findobj(ax,'Type','line'))
            legend(ax,'show','Location','northeast','FontSize',9,'Interpreter','none');
        else
            text(ax,0.5,0.5,'No matching signals in this run', ...
                'Units','normalized','HorizontalAlignment','center');
        end
    end
    hold(ax,'off');
    hover.fitPlot(ax,timeLimits);
end
end
