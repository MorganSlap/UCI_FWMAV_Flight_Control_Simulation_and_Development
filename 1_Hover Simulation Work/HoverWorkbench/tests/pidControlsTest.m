classdef pidControlsTest < matlab.unittest.TestCase
    % Verify main-page controls against native configuration and saved presets.
    methods (TestClassSetup)
        function paths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (Test)
        function everyRateGainReachesNativeFirmwareAndPreset(testCase)
            controller=testCase.createController();
            testCase.verifyFalse(controller.ParameterEditors.isKey('firmware.angle_p_gain'));
            controller.UI.Groups.Value='PID'; controller.renderSettings();
            axes={'roll','pitch','yaw'}; terms={'p','i','d','f'};
            values=[101 11 21 31;102 12 22 32;103 13 23 33];
            for axis=1:3
                for term=1:4
                    key=['firmware.' terms{term} '_' axes{axis}];
                    control=controller.ParameterEditors(key);
                    control.Value=values(axis,term); control.ValueChangedFcn(control,[]);
                end
            end
            variables=hover.buildVariables(controller.Settings);
            client=bf.Client(variables.bfConfig); testCase.addTeardown(@()delete(client));
            schema=bf.parseCliSettings(variables.bfConfig.SchemaText);
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            preset=fullfile(folder.Folder,'pid-controls.json');
            hover.savePreset(preset,controller.Settings); loaded=hover.loadPreset(preset);
            for axis=1:3
                for term=1:4
                    name=[terms{term} '_' axes{axis}];
                    item=schema(strcmp({schema.Name},name)); expected=num2str(values(axis,term));
                    testCase.verifyEqual(bf.settingValue(client.EffectiveConfiguration,item(1),0),expected);
                    testCase.verifyEqual(bf.settingValue(loaded.Betaflight.CLI,item(1),0),expected);
                end
            end
            testCase.verifyEmpty(controller.LastError);
        end
        function profileSelectorPreservesOtherProfilesAndSyncsConfigurator(testCase)
            controller=testCase.createController();
            controller.UI.Groups.Value='PID'; controller.renderSettings();
            controller.openFirmware(); controller.FirmwareEditor.Figure.Visible='off';
            profile=controller.UI.PidProfile;
            profile.Value=1; profile.ValueChangedFcn(profile,[]);
            for entry={{'firmware.p_roll',147},{'firmware.angle_p_gain',39}}
                key=entry{1}{1}; value=entry{1}{2}; control=controller.ParameterEditors(key);
                control.Value=value; control.ValueChangedFcn(control,[]);
            end
            testCase.verifyEqual(controller.UI.PidProfile.Value,1);
            config=controller.Settings.Betaflight;
            testCase.verifyEqual(controller.FirmwareEditor.Config.CLI,config.CLI);
            native=bf.cliProfiles(config.CLI);
            testCase.verifyEqual(native.SelectedProfile,1);
            client=bf.Client(config); testCase.addTeardown(@()delete(client));
            schema=bf.parseCliSettings(config.SchemaText);
            names={'p_roll','angle_p_gain'}; old={'133','20'}; updated={'147','39'};
            for k=1:2
                item=schema(strcmp({schema.Name},names{k}));
                testCase.verifyEqual(bf.settingValue(client.EffectiveConfiguration,item(1),0),old{k});
                testCase.verifyEqual(bf.settingValue(client.EffectiveConfiguration,item(1),1),updated{k});
            end
            % An applied change from Configurator must update the main page too.
            item=schema(strcmp({schema.Name},'i_pitch'));
            controller.applyFirmware(bf.setSetting(config,item(1),17,1));
            testCase.verifyEqual(controller.ParameterEditors('firmware.i_pitch').Value,17);
        end
        function searchAndBusyStateUseSameGainControls(testCase)
            controller=testCase.createController();
            controller.UI.SearchSettings.Value='pitch proportional'; controller.renderSettings();
            control=controller.ParameterEditors('firmware.p_pitch');
            control.Value=142; control.ValueChangedFcn(control,[]);
            controller.UI.SearchSettings.Value=''; controller.UI.Groups.Value='PID';
            controller.renderSettings();
            testCase.verifyEqual(controller.ParameterEditors('firmware.p_pitch').Value,142);
            controller.Busy=true; controller.setBusy(true);
            before=controller.Settings.Betaflight.CLI;
            controller.editSetting('firmware.p_pitch',143); controller.selectPidProfile(1);
            testCase.verifyEqual(controller.Settings.Betaflight.CLI,before);
            keys=controller.ParameterEditors.keys;
            for k=1:numel(keys)
                testCase.verifyEqual(controller.ParameterEditors(keys{k}).Enable,matlab.lang.OnOffSwitchState.off);
            end
            controller.Busy=false; controller.setBusy(false);
        end
    end
    methods (Access=private)
        function controller=createController(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app));
            app.UIFigure.Visible='off'; controller=app.Controller;
        end
    end
end
