function tests = configurationTest
%CONFIGURATIONTEST Data-only parser and CLI round-trip contract checks.
tests=functiontests(localfunctions);
end

function testFirmwareGetFormats(testCase)
schema=bf.parseCliSettings(fixtureSchema());
testCase.verifyNumElements(schema,4);
testCase.verifyEqual(schema(1).Minimum,-200);
testCase.verifyEqual(schema(1).Maximum,200);
testCase.verifyEqual(schema(1).Scope,'profile');
testCase.verifyEqual(schema(1).Index,0);
testCase.verifyEqual(schema(2).Choices,{'OFF','ON'});
testCase.verifyEqual(schema(3).ArrayLength,3);
testCase.verifyEqual(schema(4).LengthMaximum,16);
testCase.verifyEqual(schema(1).Default,'20');
end

function testScopedEditPreservesOtherProfileAndCommands(testCase)
schema=bf.parseCliSettings(fixtureSchema());
cli=join(["defaults nosave";"mixer CUSTOM";"aux 0 0 0 1700 2100 0"; ...
    "profile 0";"set test_gain = 25";"profile 1";"set test_gain = 35";"profile 0";"save"],newline);
config=bf.newConfig(cli,fixtureSchema());

changed=bf.setSetting(config,schema(1),'42',1);

testCase.verifyEqual(bf.settingValue(changed.CLI,schema(1),0),'25');
testCase.verifyEqual(bf.settingValue(changed.CLI,schema(1),1),'42');
testCase.verifyTrue(contains(changed.CLI,'mixer CUSTOM'));
testCase.verifyTrue(contains(changed.CLI,'aux 0 0 0 1700 2100 0'));
profiles=bf.cliProfiles(changed.CLI,schema);
testCase.verifyEqual(profiles.SelectedProfile,0);
end

function testMissingScopedValueInsertedBeforeSaveAndRestoresSelection(testCase)
schema=bf.parseCliSettings(fixtureSchema());
config=bf.newConfig(sprintf('profile 0\nset test_gain = 25\nsave'),fixtureSchema());

changed=bf.setSetting(config,schema(1),'42',1);

testCase.verifyTrue(endsWith(strtrim(string(changed.CLI)),'save'));
testCase.verifyEqual(bf.settingValue(changed.CLI,schema(1),1),'42');
profiles=bf.cliProfiles(changed.CLI,schema);
testCase.verifyEqual(profiles.SelectedProfile,0);
end

function testInvalidIntegerAndArrayAreRejected(testCase)
schema=bf.parseCliSettings(fixtureSchema());
testCase.verifyError(@()bf.validateSettingValue(schema(1),'201'),'bf:InvalidValue');
testCase.verifyError(@()bf.validateSettingValue(schema(1),'1.5'),'bf:InvalidValue');
testCase.verifyError(@()bf.validateSettingValue(schema(3),'1,2'),'bf:InvalidValue');
testCase.verifyEqual(bf.validateSettingValue(schema(2),'on'),'ON');
end

function testJSONAndCliRoundTrips(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
jsonPath=fullfile(fixture.Folder,'config.json'); cliPath=fullfile(fixture.Folder,'config.cli');
config=bf.newConfig(sprintf('profile 0\nset test_gain = 41\nsave'),fixtureSchema(),struct('Commit','test-build'));

bf.saveConfig(jsonPath,config); bf.saveConfig(cliPath,config);
loaded=bf.loadConfig(jsonPath);
cliLoaded=bf.loadConfig(cliPath,config.SchemaText,config.Firmware);

testCase.verifyEqual(loaded,config);
testCase.verifyEqual(strtrim(cliLoaded.CLI),strtrim(config.CLI));
end

function testCommandEditorPreservesUnrelatedSettings(testCase)
config=bf.newConfig(sprintf('mixer CUSTOM\naux 0 0 0 1700 2100 0\nprofile 0\nset test_gain = 41\nsave'));

[~,changed]=bf.commandSection(config,{'aux'},'aux 0 0 1 1800 2100 0');

testCase.verifyTrue(contains(changed.CLI,'aux 0 0 1 1800 2100 0'));
testCase.verifyFalse(contains(changed.CLI,'aux 0 0 0 1700 2100 0'));
testCase.verifyTrue(contains(changed.CLI,'set test_gain = 41'));
testCase.verifyTrue(contains(changed.CLI,'mixer CUSTOM'));
end

function text=fixtureSchema()
% Synthetic names intentionally do not imply firmware feature availability.
text=join(["test_gain = 25";"profile 0";"Allowed range: -200 - 200";"Default value: 20"; ...
    "";"test_switch = OFF";"Allowed values: OFF, ON"; ...
    "";"test_array = 1,2,3";"Array length: 3"; ...
    "";"test_name = -";"String length: 0 - 16"],newline);
end

function testCapturedBatteryProfiles(testCase)
config=bf.defaultConfig(); schema=bf.parseCliSettings(config.SchemaText);
battery=schema(strcmp({schema.Scope},'battery_profile'));
testCase.verifyNotEmpty(battery);
profiles=bf.cliProfiles(config.CLI,schema);
testCase.verifyGreaterThanOrEqual(numel(profiles.battery_profile),2);
item=battery(1);
before=bf.settingValue(config.CLI,item,0);
changed=bf.setSetting(config,item,before,1);
testCase.verifyEqual(bf.settingValue(changed.CLI,item,1),before);
testCase.verifyEqual(bf.settingValue(changed.CLI,item,0),before);
end

function testReceiverMappingAndModes(testCase)
config=bf.hoverConfig();
[~,config]=bf.commandSection(config,{'map'},'map TAER1234');
[~,config]=bf.commandSection(config,{'aux'},sprintf('aux 0 0 2 1700 2100 0 0\naux 1 1 3 1700 2100 0 0'));
options=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),config);
channels=bf.receiverChannels(options);
testCase.verifyEqual(channels(1),options.ThrottlePWM);
testCase.verifyEqual(channels(2:4),1500*ones(3,1));
testCase.verifyEqual(channels(7:8),1900*ones(2,1));
end

function testPidDividerKeepsGyroAtFourKhz(testCase)
config=bf.hoverConfig(); schema=bf.parseCliSettings(config.SchemaText);
config=bf.setSetting(config,schema(strcmp({schema.Name},'pid_process_denom')),'4');
options=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),config);
bf.validateOptions(options);
testCase.verifyEqual(options.SampleTime,1/4000);
testCase.verifyEqual(options.PidSampleTime,1/1000);
options.SampleTime=1/1000;
testCase.verifyError(@()bf.validateOptions(options),'bf:GyroSampleTime');
end

function testReceiverEndpointsAndMidRc(testCase)
config=bf.hoverConfig(); schema=bf.parseCliSettings(config.SchemaText);
config=bf.setSetting(config,schema(strcmp({schema.Name},'mid_rc')),'1520');
[~,config]=bf.commandSection(config,{'rxrange'}, ...
    sprintf('rxrange 0 900 2100\nrxrange 1 950 2050\nrxrange 2 1000 2000\nrxrange 3 900 2100'));
options=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),config);
channels=bf.receiverChannels(options); warmup=bf.startupChannels(options);
testCase.verifyEqual(channels([1 2 4]),[1524;1522;1520]);
testCase.verifyEqual(warmup(3),900);
testCase.verifyEqual(warmup(5),1000);
baseline=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),bf.hoverConfig());
testCase.verifyEqual(channels(3),900+1.2*(baseline.ThrottlePWM-1000),AbsTol=1e-10);
[~,config]=bf.commandSection(config,{'rxrange'},sprintf('rxrange 0 900 2100\nrxrange reset'));
testCase.verifyEqual(bf.receiverLayout(config).Ranges,repmat([1000 2000],4,1));
end

function testCustomReceiverPreservesAuxAndStartupPulses(testCase)
options=bf.simulationOptions(struct('Ts',1/4000,'u0',1800,'X0',zeros(12,1)),bf.hoverConfig());
options.ReceiverPWM=bf.receiverChannels(options); options.ReceiverPWM(7:8)=1800;
options.StartupReceiverPWM=options.ReceiverPWM; options.StartupReceiverPWM([3 5 7])=1000;
bf.validateOptions(options);
testCase.verifyEqual(bf.receiverChannels(options),options.ReceiverPWM);
testCase.verifyEqual(bf.startupChannels(options),options.StartupReceiverPWM);
armed=bf.startupChannels(options,true);
testCase.verifyEqual(armed(3),options.MinThrottlePWM);
testCase.verifyEqual(armed([5 7 8]),[1900;1800;1800]);
end

function testLaterAuxAssignmentReplacesEarlierRange(testCase)
config=bf.hoverConfig();
[~,config]=bf.commandSection(config,{'aux'},sprintf(['aux 0 0 0 1700 2100 0 0\n' ...
    'aux 0 0 0 900 900 0 0\naux 1 0 2 1700 2100 0 0\naux 2 1 3 1700 2100 0 0']));
layout=bf.receiverLayout(config);
testCase.verifyEqual(layout.Arm,7);
testCase.verifyEqual(layout.Angle,8);
end
