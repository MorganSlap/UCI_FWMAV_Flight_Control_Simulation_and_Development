classdef workbenchStabilityTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (Test)
        function appDeletionDisposesControllerAndTimer(testCase)
            app=HoverWorkbench; controller=app.Controller; progress=controller.PollTimer;
            delete(app);
            testCase.verifyFalse(isvalid(controller));
            testCase.verifyFalse(isvalid(progress));
        end
        function figureDeletionDisposesControllerAndTimer(testCase)
            app=HoverWorkbench; controller=app.Controller; progress=controller.PollTimer;
            delete(app.UIFigure);
            testCase.verifyFalse(isvalid(controller));
            testCase.verifyFalse(isvalid(progress));
        end
        function repeatedSignalSelectionDoesNotDuplicateData(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller; controller.ActiveRecord=plotInteractionTest.record(10);
            controller.plotSignals([1 2]); controller.plotSignals([1 2 1]);
            testCase.verifyNumElements(findobj(controller.currentAxes(),'Type','line'),2);
            controller.UI.PlotMode.Value='Replace active plot'; controller.plotSignals(3);
            testCase.verifyNumElements(findobj(controller.currentAxes(),'Type','line'),1);
            testCase.verifyEmpty(controller.LastError);
        end
        function staleTreeSelectionDoesNotBreakPlotting(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller; controller.ActiveRecord=plotInteractionTest.record(10);
            controller.plotSignals(100000); controller.plotSignals(1);
            testCase.verifyNumElements(findobj(controller.currentAxes(),'Type','line'),1);
            testCase.verifyEmpty(controller.LastError);
        end
        function majorRunControlsShareOnePage(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller;
            testCase.verifyEqual(controller.UI.Groups.Value,'Run setup');
            testCase.verifyTrue(all(isKey(controller.ParameterEditors,{'t_sim','sim_fidelity','noise_true','seed','drag_enabled'})));
            testCase.verifyTrue(isvalid(controller.UI.Example));
            testCase.verifyFalse(any(ismember({controller.Schema.Key},{'use_time_constant_damping','tau_p','tau_q','tau_r'})));
        end
        function sensorCardsExposeActiveNativeFilters(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            controller=app.Controller; controller.UI.Groups.Value='Sensors and estimator'; controller.renderSettings();
            testCase.verifyTrue(all(isKey(controller.ParameterEditors,{'gyro.noise_density','accel.noise_density', ...
                'firmware.gyro_lpf1_static_hz','firmware.gyro_lpf1_dyn_min_hz','native.acc_lpf_hz'})));
            controller.editSetting('firmware.gyro_lpf1_dyn_min_hz',0);
            controller.editSetting('firmware.gyro_lpf1_static_hz',5);
            testCase.verifyEqual(controller.ParameterEditors('firmware.gyro_lpf1_static_hz').Value,5);
            testCase.verifyEqual(controller.ParameterEditors('firmware.gyro_lpf1_dyn_min_hz').Value,0);
            testCase.verifyEmpty(controller.LastError);
        end
        function dragSwitchZerosEveryDragTermAndRestoresCoefficients(testCase)
            settings=hover.defaultSettings(); settings.drag_enabled=false; settings.use_time_constant_damping=true;
            off=hover.buildVariables(settings);
            testCase.verifyEqual([off.CDx off.CDy off.CDz off.CDw off.Xu off.Yv off.Zw off.Lp off.Mq off.Nr],zeros(1,10));
            settings.drag_enabled=true; settings.use_time_constant_damping=false;
            on=hover.buildVariables(settings);
            testCase.verifyEqual([on.CDx on.CDy on.CDz on.CDw],[1 1 1 1]);
            testCase.verifyGreaterThan(on.Lp,0);
        end
        function rawSensorChannelsKeepUnitsAndExactSamples(testCase)
            output=workbenchStabilityTest.rawFixture();
            signals=hover.collectSignals(output,struct('g',9.81));
            gyro=signals(strcmp({signals.Key},'display.sensor.gyro.raw.x'));
            accel=signals(strcmp({signals.Key},'display.sensor.accel.raw.z'));
            testCase.verifyEqual(gyro.Data,[180;360]);
            testCase.verifyEqual(gyro.Unit,'deg/s');
            testCase.verifyEqual(accel.Data,[-1;-2]);
            testCase.verifyEqual(accel.Unit,'g');
            testCase.verifyEqual(hover.addImuSignals(signals),signals);
        end
        function calibrationUsesRestoredNoisePower(testCase)
            settings=hover.hoverExample(); v=hover.buildVariables(settings);
            testCase.verifyEqual(v.bfSim.CalibrationGyroNoiseStd, ...
                settings.gyro.noise_density*pi/180*sqrt(settings.gyro.BW*settings.gyro.sample_rate),'RelTol',1e-12);
            settings.noise_true=false; v=hover.buildVariables(settings);
            testCase.verifyEqual(v.bfSim.CalibrationGyroNoiseStd,0);
        end
        function plotUpdatesPreserveManualLimits(testCase)
            fig=uifigure('Visible','off'); testCase.addTeardown(@()delete(fig)); ax=uiaxes(fig);
            time=(0:0.00025:10)'; hover.plotSignal(ax,time,sin(time)); hover.fitPlot(ax);
            ax.XLim=[2 3]; drawnow; hover.refreshPlot(ax); drawnow;
            testCase.verifyEqual(ax.XLim,[2 3]);
            testCase.verifyEqual(ax.XLimMode,'manual');
            cla(ax); drawnow; hover.plotSignal(ax,time,cos(time)); hover.fitPlot(ax); drawnow;
            testCase.verifyEqual(ax.XLim,[0 10]);
        end
    end
    methods (Static)
        function output=rawFixture()
            logs=Simulink.SimulationData.Dataset;
            logs=logs.addElement(timeseries([pi pi pi;2*pi 2*pi 2*pi],[0;1]),'imu_gyro_measured');
            logs=logs.addElement(timeseries([0 0 -9.81;0 0 -19.62],[0;1]),'imu_accel_measured');
            output=struct('logsout',logs);
        end
    end
end
