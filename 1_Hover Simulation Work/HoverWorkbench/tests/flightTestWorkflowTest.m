classdef flightTestWorkflowTest < matlab.unittest.TestCase
    % Commands, saved inputs and analysis use the same units and time basis.
    methods (TestClassSetup)
        function addPaths(testCase)
            folder=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(fileparts(folder)),'Betaflight')));
        end
    end
    methods (Test)
        function examplesPreserveOriginalAerodynamicDamping(testCase)
            for kind=["hover","recovery","angle","rate"]
                settings=hover.flightExample(kind);
                testCase.verifyEqual([settings.CDx settings.CDy settings.CDz settings.CDw],ones(1,4));
                variables=hover.buildVariables(settings);
                testCase.verifyGreaterThan([variables.Xu variables.Yv variables.Zw ...
                    variables.Lp variables.Mq variables.Nr],zeros(1,6));
            end
        end
        function noisyExamplesUseConvertedPlainPi(testCase)
            for kind=["level","recovery"]
                settings=hover.hoverExample(kind);
                v=hover.buildVariables(settings);
                schema=bf.parseCliSettings(v.bfConfig.SchemaText);
                names={'p_roll','i_roll','d_roll','f_roll', ...
                    'p_pitch','i_pitch','d_pitch','f_pitch', ...
                    'iterm_relax','anti_gravity_gain','d_max_roll', ...
                    'd_max_pitch','tpa_rate','tpa_low_rate','angle_feedforward', ...
                    'acc_lpf_hz','imu_dcm_kp','imu_dcm_ki'};
                expected={'133','4','0','0','134','4','0','0', ...
                    'OFF','0','0','0','0','0','0','5','2500','0'};
                for k=1:numel(names)
                    item=schema(strcmp({schema.Name},names{k}));
                    testCase.verifyEqual(bf.settingValue(v.bfConfig.CLI,item(1)),expected{k});
                end
                testCase.verifyTrue(settings.noise_true);
                testCase.verifyEqual(v.bfSim.NavigationSensors,0);
                testCase.verifyFalse(contains(v.bfConfig.CLI,'feature ANTI_GRAVITY'));
            end
        end
        function shippedExamplesMatchTheirBuilders(testCase)
            p=bf.paths();
            kinds={'hover','recovery','angle','rate'};
            files={'imu-only-hover','attitude-recovery','angle-pulses','rate-doublets'};
            for k=1:numel(kinds)
                settings=hover.loadPreset(fullfile(p.Root,'presets',[files{k} '.json']));
                testCase.verifyEqual(hover.buildVariables(settings), ...
                    hover.buildVariables(hover.flightExample(kinds{k})));
            end
        end
        function holdsBeforeAtAndAfterBoundary(testCase)
            v=hover.buildVariables(hover.flightExample('angle'));
            v.bfSim.ReferenceSchedule=[2 3 -2 1;4 0 0 0];
            v.bfSim.ReferenceSchedule(:,2:4)=v.bfSim.ReferenceSchedule(:,2:4)*pi/180;
            reference=(1:12)'/100;
            before=bf.commandReference(reference,1.999,v.bfSim);
            at=bf.commandReference(reference,2,v.bfSim);
            after=bf.commandReference(reference,3.5,v.bfSim);
            ended=bf.commandReference(reference,10,v.bfSim);
            testCase.verifyEqual(before,reference);
            testCase.verifyEqual(at([7 8 12]),[3;-2;1]*pi/180,'AbsTol',1e-14);
            testCase.verifyEqual(after,at);
            testCase.verifyEqual(ended([7 8 12]),zeros(3,1));
            testCase.verifyEqual(at(1:6),reference(1:6));
            testCase.verifyEqual(at(9:11),reference(9:11));
        end
        function rateCommandsUseRatesOnly(testCase)
            v=hover.buildVariables(hover.flightExample('rate'));
            reference=ones(12,1);
            actual=bf.commandReference(reference,3,v.bfSim);
            [values,keys,units]=bf.commandSeries([0;2;3;4],reference,v.bfSim);
            testCase.verifyEqual(actual(1:9),ones(9,1));
            testCase.verifyEqual(actual(10:12),[-15;0;0]*pi/180,'AbsTol',1e-14);
            testCase.verifyEqual(values,[0 0 0;15 0 0;-15 0 0;0 0 0],'AbsTol',1e-12);
            testCase.verifyEqual(keys,{'p','q','r'});
            testCase.verifyEqual(units,{'deg/s','deg/s','deg/s'});
        end
        function duplicateTimesRejected(testCase)
            v=hover.buildVariables(hover.flightExample('angle'));
            v.bfSim.ReferenceSchedule=[0 0 0 0;0 1 0 0];
            testCase.verifyError(@()bf.validateOptions(v.bfSim),'bf:ReferenceTime');
        end
        function rawReceiverCannotSilentlyIgnoreSequence(testCase)
            v=hover.buildVariables(hover.flightExample('angle'));
            v.bfSim.CommandMode='receiver';
            testCase.verifyError(@()bf.validateOptions(v.bfSim),'bf:ReferenceMode');
        end
        function legacyOptionsPreserveReference(testCase)
            v=hover.buildVariables(hover.hoverExample());
            options=rmfield(v.bfSim,'ReferenceSchedule');
            testCase.verifyEqual(bf.commandReference((1:12)',4,options),(1:12)');
            testCase.verifyEmpty(v.bfSim.ReferenceSchedule);
        end
        function sequenceSurvivesPresetRoundTrip(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path=fullfile(fixture.Folder,'flight.json');
            settings=hover.flightExample('angle');
            hover.savePreset(path,settings);
            actual=hover.loadPreset(path);
            testCase.verifyEqual(hover.buildVariables(actual),hover.buildVariables(settings));
        end
        function commandsArchivedInDisplayUnits(testCase)
            v=hover.buildVariables(hover.flightExample('angle'));
            time=[0;1.99;2;3;4;6;8;10];
            output=struct('betaflight_diagnostics',struct('time',time, ...
                'signals',struct('values',zeros(numel(time),40),'dimensions',40)));
            signals=hover.collectSignals(output,v);
            roll=signals(strcmp({signals.Key},'command.phi'));
            pitch=signals(strcmp({signals.Key},'command.theta'));
            testCase.verifyEqual(roll.Data,[0;0;3;3;0;0;0;0],'AbsTol',1e-12);
            testCase.verifyEqual(pitch.Data,[0;0;0;0;0;-3;0;0],'AbsTol',1e-12);
            testCase.verifyEqual(roll.Unit,'deg');
        end
        function altitudeRateUsesInertialVerticalVelocity(testCase)
            x=zeros(2,12); x(:,4)=2; x(:,8)=pi/6;
            output=struct('state_output',struct('time',[0;1], ...
                'signals',struct('values',x,'dimensions',12)));
            signals=hover.collectSignals(output);
            signal=signals(strcmp({signals.Key},'derived.altitude_rate'));
            testCase.verifyEqual(signal.Data,ones(2,1),'AbsTol',1e-12);
        end
        function angularErrorWrapsAtHeadingBoundary(testCase)
            x=zeros(2,12); x(:,9)=179*pi/180;
            estimate=x; estimate(:,9)=-179*pi/180;
            output=struct('state_output',struct('time',[0;1], ...
                'signals',struct('values',x,'dimensions',12)), ...
                'state_estimate',struct('time',[0;1], ...
                'signals',struct('values',estimate,'dimensions',12)));
            signals=hover.collectSignals(output);
            signal=signals(strcmp({signals.Key},'display.error.psi'));
            testCase.verifyEqual(signal.Data,[-2;-2],'AbsTol',1e-12);
        end
        function linearAltitudeRateUsesLinearPositionEquation(testCase)
            x=zeros(2,12); x(:,4)=2; x(:,6)=0.3; x(:,8)=pi/6;
            output=struct('state_output',struct('time',[0;1], ...
                'signals',struct('values',x,'dimensions',12)));
            signals=hover.collectSignals(output,struct('sim_fidelity','low'));
            signal=signals(strcmp({signals.Key},'derived.altitude_rate'));
            testCase.verifyEqual(signal.Data,[-0.3;-0.3],'AbsTol',1e-12);
        end
    end
end
