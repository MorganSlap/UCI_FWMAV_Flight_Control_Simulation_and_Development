classdef flightAnalysisPlotTest < matlab.unittest.TestCase
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
        function canvas(testCase)
            testCase.Figure=uifigure('Visible','off');
            testCase.addTeardown(@()delete(testCase.Figure));
            tiles=tiledlayout(testCase.Figure,3,2);
            testCase.Axes=arrayfun(@(~)uiaxes(tiles),1:6);
        end
    end
    methods (Test)
        function angleModeDrawsAllSixPanelsAndCorrectErrors(testCase)
            record=flightAnalysisPlotTest.fixture('angle');
            result=hover.plotFlightAnalysis(record,1,testCase.Axes);
            testCase.verifyEqual(arrayfun(@(ax)numel(findobj(ax,'Type','line')),testCase.Axes),[3 2 1 5 5 1]);
            testCase.verifyEqual(result.TrackingRms,2,'AbsTol',1e-12);
            testCase.verifyEqual(result.EstimatorRmsDegrees,1,'AbsTol',1e-12);
            testCase.verifySubstring(testCase.Axes(2).Title.String,'angular rate');
            testCase.verifyEqual(testCase.Axes(2).YLabel.String,'deg/s');
            raw=findobj(testCase.Axes(6),'Type','line'); source=getappdata(raw,'HoverFullSignal');
            testCase.verifyEqual(source.Data,0.5*ones(size(source.Data)),'AbsTol',1e-12);
            requested=findobj(testCase.Axes(1),'Type','line','DisplayName','Requested command');
            testCase.verifyEqual(requested.LineStyle,'--');
        end
        function rateModeShowsRateTrackingAndComplementaryAttitude(testCase)
            result=hover.plotFlightAnalysis(flightAnalysisPlotTest.fixture('rate'),1,testCase.Axes);
            testCase.verifyEqual(result.TrackingRms,1,'AbsTol',1e-12);
            testCase.verifyEqual(result.TrackingQuantity,'rate');
            testCase.verifyEqual(testCase.Axes(1).YLabel.String,'deg/s');
            testCase.verifyEqual(testCase.Axes(2).YLabel.String,'deg');
            testCase.verifySubstring(testCase.Axes(2).Title.String,'attitude estimate');
        end
        function yawInAngleModeIsRateTracking(testCase)
            result=hover.plotFlightAnalysis(flightAnalysisPlotTest.fixture('angle'),3,testCase.Axes);
            testCase.verifyEqual(result.TrackingQuantity,'rate');
            testCase.verifySubstring(testCase.Axes(1).Title.String,'Yaw rate');
        end
        function receiverModeUsesLoggedNativeRateCommand(testCase)
            result=hover.plotFlightAnalysis(flightAnalysisPlotTest.fixture('receiver'),1,testCase.Axes);
            testCase.verifyEqual(result.CommandSource,'Native receiver rate');
            testCase.verifyEqual(result.TrackingRms,1,'AbsTol',1e-12);
        end
        function legacyRunShowsMissingLogNotesInsteadOfFailing(testCase)
            record=flightAnalysisPlotTest.fixture('angle');
            record.Signals=record.Signals(~startsWith({record.Signals.Key},{'logged.','sensor.','display.sensor.','betaflight.'}));
            result=hover.plotFlightAnalysis(record,1,testCase.Axes);
            testCase.verifyEqual(result.TrackingRms,2,'AbsTol',1e-12);
            testCase.verifyEmpty(findobj(testCase.Axes(6),'Type','line'));
            testCase.verifyNotEmpty(findobj(testCase.Axes(6),'Type','text','String','Raw IMU signals were not logged'));
            testCase.verifyEqual(testCase.Axes(6).XLim,[0 2]);
        end
        function homeAndDetachedPlotsKeepAllSamplesAndExplanations(testCase)
            hover.plotFlightAnalysis(flightAnalysisPlotTest.fixture('angle'),1,testCase.Axes);
            zoom(testCase.Axes(1),5); zoom(testCase.Axes(1),'out'); drawnow;
            testCase.verifyEqual(testCase.Axes(1).XLim,[0 2]);
            fig=hover.undockPlots(testCase.Axes(1),'Flight analysis test');
            testCase.addTeardown(@()delete(fig)); fig.Visible='off'; ax=findobj(fig,'Type','axes');
            testCase.verifyEqual(ax.Subtitle.String,testCase.Axes(1).Subtitle.String);
            testCase.verifyNumElements(findobj(ax,'Type','line'),3);
        end
        function appCallbackCannotSilentlyLeaveAnEmptyAnalysis(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller; controller.ActiveRecord=flightAnalysisPlotTest.fixture('angle');
            controller.drawFlightAnalysis();
            testCase.verifyEmpty(controller.LastAnalysisError);
            testCase.verifyFalse(startsWith(controller.UI.FlightSummary.Text,'Analysis unavailable'));
            testCase.verifyTrue(all(arrayfun(@(ax)~isempty(findobj(ax,'Type','line')),controller.UI.FlightAxes)));
            controller.UI.FlightAxis.Value=2;
            controller.UI.FlightAxis.ValueChangedFcn(controller.UI.FlightAxis,[]);
            testCase.verifyEmpty(controller.LastAnalysisError);
            testCase.verifySubstring(controller.UI.FlightSummary.Text,'Pitch angle tracking');
        end
    end
    methods (Static)
        function record=fixture(mode)
            time=(0:0.00025:2)'; n=numel(time); truth=zeros(n,12); estimate=truth;
            truth(:,7)=2*pi/180; estimate(:,7)=pi/180;
            truth(:,10)=3*pi/180; estimate(:,10)=2*pi/180;
            diagnostic=zeros(n,40); diagnostic(:,6:9)=repmat(1800:1803,n,1);
            diagnostic(:,16)=4*pi/180; diagnostic(:,19:30)=repmat(1:12,n,1);
            diagnostic(:,37:39)=repmat([10 26 42],n,1);
            logs=Simulink.SimulationData.Dataset;
            logs=logs.addElement(timeseries(truth(:,10:12),time),'imu_gyro_ideal');
            logs=logs.addElement(timeseries(truth(:,10:12)+0.5*pi/180,time),'imu_gyro_measured');
            output=struct('state_output',timeseries(truth,time),'state_estimate',timeseries(estimate,time), ...
                'betaflight_diagnostics',timeseries(diagnostic,time),'logsout',logs);
            reference=zeros(12,1); reference(10)=4*pi/180;
            variables=struct('Xref',reference,'u0',1816.1, ...
                'bfSim',struct('CommandMode',mode,'ReferenceSchedule',zeros(0,4)));
            record=struct('Label','Flight analysis fixture','Variables',variables, ...
                'Signals',hover.collectSignals(output,variables));
        end
    end
end
