classdef angularControlsTest < matlab.unittest.TestCase
    % Exercise degree inputs through UI callbacks, saved settings and firmware.
    properties (TestParameter)
        State = struct('initial',struct('Key','X0','Page','Initial conditions'), ...
            'reference',struct('Key','Xref','Page','Reference command'))
        DragKey = {'p_ref','q_ref','r_ref'}
        Mode = {'angle','rate'}
    end
    methods (TestClassSetup)
        function paths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (Test)
        function stateEditUsesRadiansInSimulationAndPreset(testCase,State)
            controller=testCase.createController();
            controller.UI.Groups.Value=State.Page; controller.renderSettings();
            control=controller.ParameterEditors(State.Key);
            displayed=[1;-2;3;-4;5;-6;30;-45;180;90;-60;15];
            expected=[1;-2;3;-4;5;-6;pi/6;-pi/4;pi;pi/2;-pi/3;pi/12];
            control.Data=displayed; control.CellEditCallback(control,struct('Error',[]));
            variables=hover.buildVariables(controller.Settings);
            testCase.verifyEqual(variables.(State.Key),expected,'AbsTol',1e-12);
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path=fullfile(folder.Folder,'degree-inputs.json');
            hover.savePreset(path,controller.Settings);
            controller.Settings=hover.loadPreset(path); controller.renderSettings();
            testCase.verifyEqual(controller.Settings.(State.Key),expected,'AbsTol',1e-12);
            testCase.verifyEqual(controller.ParameterEditors(State.Key).Data,displayed,'AbsTol',1e-12);
            testCase.verifyTrue(contains(controller.ParameterEditors(State.Key).RowName{7},'deg'));
        end
        function aerodynamicRateUsesDegreesInEditor(testCase,DragKey)
            controller=testCase.createController();
            controller.UI.Groups.Value='Aerodynamic damping'; controller.renderSettings();
            control=controller.ParameterEditors(DragKey);
            testCase.verifyEqual(control.Value,180/pi,'AbsTol',1e-12);
            control.Value=90; control.ValueChangedFcn(control,[]);
            variables=hover.buildVariables(controller.Settings);
            testCase.verifyEqual(variables.(DragKey),pi/2,'AbsTol',1e-12);
            controller.renderSettings();
            testCase.verifyEqual(controller.ParameterEditors(DragKey).Value,90,'AbsTol',1e-12);
        end
        function sequenceKeepsSecondsAndConvertsAngles(testCase,Mode)
            controller=testCase.createController();
            controller.Settings.FirmwareAdapter.CommandMode=Mode;
            controller.UI.Groups.Value='Run setup'; controller.renderSettings();
            displayed=[0 0 0 0;2 30 -45 90];
            control=controller.UI.Sequence;
            control.Data=displayed; control.CellEditCallback(control,[]);
            variables=hover.buildVariables(controller.Settings);
            testCase.verifyEqual(variables.bfSim.ReferenceSchedule, ...
                [0 0 0 0;2 pi/6 -pi/4 pi/2],'AbsTol',1e-12);
            testCase.verifyEqual(controller.UI.Sequence.Data,displayed,'AbsTol',1e-12);
        end
        function angleGainReachesNativeFirmware(testCase)
            controller=testCase.createController();
            controller.UI.Groups.Value='PID'; controller.renderSettings();
            control=controller.ParameterEditors('firmware.angle_p_gain');
            control.Value=37; control.ValueChangedFcn(control,[]);
            variables=hover.buildVariables(controller.Settings);
            client=bf.Client(variables.bfConfig); testCase.addTeardown(@()delete(client));
            schema=bf.parseCliSettings(variables.bfConfig.SchemaText);
            item=schema(strcmp({schema.Name},'angle_p_gain'));
            testCase.verifyEqual(bf.settingValue(client.EffectiveConfiguration,item(1),0),'37');
            testCase.verifyEmpty(controller.LastError);
        end
        function angleGainEditsSelectedProfileAndSyncsConfigurator(testCase)
            controller=testCase.createController();
            controller.applyFirmware(bf.selectProfile(controller.Settings.Betaflight,'profile',1));
            controller.openFirmware(); controller.FirmwareEditor.Figure.Visible='off';
            controller.UI.Groups.Value='PID'; controller.renderSettings();
            control=controller.ParameterEditors('firmware.angle_p_gain');
            control.Value=38; control.ValueChangedFcn(control,[]);
            schema=bf.parseCliSettings(controller.Settings.Betaflight.SchemaText);
            item=schema(strcmp({schema.Name},'angle_p_gain'));
            testCase.verifyEqual(bf.settingValue(controller.Settings.Betaflight.CLI,item(1),1),'38');
            testCase.verifyEqual(bf.settingValue(controller.Settings.Betaflight.CLI,item(1),0),'20');
            testCase.verifyEqual(controller.ParameterEditors('firmware.angle_p_gain').Value,38);
            testCase.verifyEqual(controller.FirmwareEditor.Config.CLI,controller.Settings.Betaflight.CLI);
        end
        function gyroDegreeInputsAreNotConvertedAgain(testCase)
            controller=testCase.createController();
            controller.UI.Groups.Value='Sensors and estimator'; controller.renderSettings();
            control=controller.ParameterEditors('gyro.vibration');
            control.Value=4; control.ValueChangedFcn(control,[]);
            variables=hover.buildVariables(controller.Settings);
            testCase.verifyEqual(variables.gyro.vibration,4,'AbsTol',1e-12);
            testCase.verifyFalse(controller.ParameterEditors.isKey('firmware.angle_p_gain'));
        end
    end
    methods (Access=private)
        function controller=createController(testCase)
            app=HoverWorkbench; testCase.addTeardown(@()delete(app));
            app.UIFigure.Visible='off'; controller=app.Controller;
        end
    end
end
