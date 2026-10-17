classdef attitudeControlsTest < matlab.unittest.TestCase
    % The controls must change saved/native firmware values, not legacy fields.
    methods (TestClassSetup)
        function paths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (Test)
        function defaultFiltersReachActualFirmware(testCase)
            variables=hover.buildVariables(hover.defaultSettings());
            config=variables.bfConfig;
            client=bf.Client(config); cleanup=onCleanup(@()delete(client));
            schema=bf.parseCliSettings(config.SchemaText);
            names={'simplified_gyro_filter','gyro_lpf1_type','gyro_lpf1_static_hz', ...
                'gyro_lpf1_dyn_min_hz','gyro_lpf2_static_hz','acc_lpf_hz'};
            expected={'OFF','PT1','5','0','0','5'};
            for k=1:numel(names)
                item=schema(strcmp({schema.Name},names{k}));
                testCase.verifyEqual(bf.settingValue(client.EffectiveConfiguration,item(1)),expected{k});
            end
        end
        function physicalGainsReachActualFirmware(testCase)
            config=hover.hoverExample().Betaflight;
            [~,config]=hover.nativeAttitudeValue(config,'acc_lpf_hz',8);
            [~,config]=hover.nativeAttitudeValue(config,'imu_dcm_kp',0.2);
            [~,config]=hover.nativeAttitudeValue(config,'imu_dcm_ki',0.025);
            client=bf.Client(config); cleanup=onCleanup(@()delete(client));
            native=config; native.CLI=client.EffectiveConfiguration;
            testCase.verifyEqual(hover.nativeAttitudeValue(native,'acc_lpf_hz'),8);
            testCase.verifyEqual(hover.nativeAttitudeValue(native,'imu_dcm_kp'),0.2);
            testCase.verifyEqual(hover.nativeAttitudeValue(native,'imu_dcm_ki'),0.025);
        end
        function unsupportedGainPrecisionIsRejected(testCase)
            config=hover.hoverExample().Betaflight;
            testCase.verifyError(@()hover.nativeAttitudeValue(config,'imu_dcm_kp',0.00001),'hover:NativeSettingResolution');
            testCase.verifyError(@()hover.nativeAttitudeValue(config,'acc_lpf_hz',5.5),'hover:NativeSettingResolution');
            testCase.verifyError(@()hover.nativeAttitudeValue(config,'imu_dcm_kp',7),'bf:InvalidValue');
        end
        function savedPresetKeepsNativeValuesIndependentOfLegacyFields(testCase)
            settings=hover.hoverExample();
            [~,settings.Betaflight]=hover.nativeAttitudeValue(settings.Betaflight,'acc_lpf_hz',8);
            settings.accel.LPF_set=3;
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path=fullfile(folder.Folder,'native-filter.json');
            hover.savePreset(path,settings); loaded=hover.loadPreset(path);
            testCase.verifyEqual(hover.nativeAttitudeValue(loaded.Betaflight,'acc_lpf_hz'),8);
            testCase.verifyEqual(loaded.accel.LPF_set,3);
        end
        function guiCallbackUpdatesNativeFilterAndHidesInactiveFields(testCase)
            app=HoverWorkbench; cleanup=onCleanup(@()delete(app));
            app.UIFigure.Visible='off'; controller=app.Controller;
            controller.UI.Groups.Value='Attitude estimator'; controller.renderSettings();
            control=controller.ParameterEditors('native.acc_lpf_hz');
            control.Value=8; control.ValueChangedFcn(control,[]);
            testCase.verifyEqual(hover.nativeAttitudeValue(controller.Settings.Betaflight,'acc_lpf_hz'),8);
            testCase.verifyEqual(controller.ParameterEditors('native.acc_lpf_hz').Value,8);
            controller.UI.Groups.Value='Sensors and estimator'; controller.renderSettings();
            testCase.verifyFalse(controller.ParameterEditors.isKey('accel.LPF_set'));
            testCase.verifyFalse(controller.ParameterEditors.isKey('gyro.LPF_set'));
        end
    end
end
