classdef plotInteractionTest < matlab.unittest.TestCase
    properties
        Figure
        Axes
    end
    methods (TestClassSetup)
        function paths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (TestMethodSetup)
        function figure(testCase)
            testCase.Figure=uifigure('Visible','off');
            testCase.addTeardown(@()delete(testCase.Figure));
            testCase.Axes=uiaxes(uigridlayout(testCase.Figure,[1 1]));
        end
    end
    methods (Test)
        function homeReturnsToFullDuration(testCase)
            time=(0:0.00025:60)';
            trace=hover.plotSignal(testCase.Axes,time,sin(time));
            hover.fitPlot(testCase.Axes);
            zoom(testCase.Axes,4);
            zoom(testCase.Axes,'out');
            drawnow;
            testCase.verifyEqual(testCase.Axes.XLim,[0 60]);
            testCase.verifyEqual(trace.XData([1 end]),[0 60]);
        end
        function overviewRetainsSpikesAndNaNGap(testCase)
            time=(0:720000)'; data=zeros(size(time));
            data(12345)=91; data(551234)=-83; data(390000:390020)=NaN;
            [t,y]=hover.displaySamples(time,data,[0 720000]);
            testCase.verifyLessThanOrEqual(numel(t),4000);
            testCase.verifyTrue(any(y==91)); testCase.verifyTrue(any(y==-83));
            testCase.verifyTrue(any(isnan(y)));
            testCase.verifyEqual(t([1 end]),[0;720000]);
        end
        function zoomRestoresEveryVisibleSample(testCase)
            time=(0:0.00025:60)'; data=sin(2*pi*24*time);
            h=hover.plotSignal(testCase.Axes,time,data);
            hover.fitPlot(testCase.Axes);
            testCase.Axes.XLim=[25 25.01];
            drawnow;
            expected=time>=25 & time<=25.01;
            shown=h.XData>=25 & h.XData<=25.01;
            testCase.verifyEqual(h.XData(shown)',time(expected));
            testCase.verifyEqual(h.YData(shown)',data(expected));
        end
        function defaultsSwitchDurationAndResetHome(testCase)
            axesArray=plotInteractionTest.makeAxes(testCase.Figure);
            hover.defaultPlots(axesArray,plotInteractionTest.record(60));
            testCase.verifyEqual(axesArray(1).XLim,[0 60]);
            hover.defaultPlots(axesArray,plotInteractionTest.record(10));
            zoom(axesArray(1),3); zoom(axesArray(1),'out');
            testCase.verifyEqual(axesArray(1).XLim,[0 10]);
            testCase.verifyEqual(axesArray(7).XLim,[0 10]);
        end
        function undockedPlotIsIndependentAndKeepsDetail(testCase)
            time=(0:0.00025:60)';
            hover.plotSignal(testCase.Axes,time,sin(time),'DisplayName','Original');
            hover.fitPlot(testCase.Axes); testCase.Axes.XLim=[20 21];
            fig=hover.undockPlots(testCase.Axes,'Detached test');
            testCase.addTeardown(@()delete(fig)); fig.Visible='off';
            ax=findobj(fig,'Type','axes');
            testCase.verifyEqual(ax.XLim,[20 21]);
            delete(testCase.Axes);
            zoom(ax,'out'); testCase.verifyEqual(ax.XLim,[0 60]);
            ax.XLim=[25 25.01]; drawnow; line=findobj(ax,'Type','line');
            testCase.verifyGreaterThanOrEqual(numel(line.XData),40);
            testCase.verifyLessThanOrEqual(numel(line.XData),43);
        end
        function explorerRemovesOnlyChosenTrace(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller; controller.ActiveRecord=plotInteractionTest.record(60);
            controller.plotSignals([1 2 3]);
            traces=flipud(findobj(controller.currentAxes(),'Type','line'));
            controller.removePlotSignals(2);
            testCase.verifyTrue(isgraphics(traces(1))); testCase.verifyFalse(isgraphics(traces(2)));
            testCase.verifyTrue(isgraphics(traces(3)));
            testCase.verifyEqual(controller.currentAxes().XLim,[0 60]);
            controller.removePlotSignals([1 2]);
            testCase.verifyEmpty(findobj(controller.currentAxes(),'Type','line'));
        end
        function emptyAndSingleSampleAreSupported(testCase)
            [t,y]=hover.displaySamples([],[],[0 1]);
            testCase.verifyEmpty(t); testCase.verifyEmpty(y);
            hover.plotSignal(testCase.Axes,4,3);
            hover.fitPlot(testCase.Axes);
            testCase.verifyEqual(testCase.Axes.XLim,[3.5 4.5]);
        end
    end
    methods (Static)
        function axesArray=makeAxes(fig)
            grid=uigridlayout(fig,[4 3]); axesArray=gobjects(1,11);
            for k=1:11, axesArray(k)=uiaxes(grid); end
        end
        function record=record(duration)
            time=(0:0.001:duration)'; state=time.*ones(1,12);
            output=struct('state_output',timeseries(state,time), ...
                'state_estimate',timeseries(state*0.9,time), ...
                'controls',timeseries(ones(numel(time),4),time));
            record=struct('ID','plot-fixture','Label','Plot fixture','Variables',struct('bfSim',struct()), ...
                'Signals',hover.collectSignals(output,struct('u0',1800)));
        end
    end
end
