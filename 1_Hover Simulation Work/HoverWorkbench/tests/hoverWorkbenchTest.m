function tests = hoverWorkbenchTest
%HOVERWORKBENCHTEST Public API regression tests; no simulation is required.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
workbenchFolder = fileparts(fileparts(mfilename('fullpath')));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(workbenchFolder));
testCase.TestData.WorkbenchFolder = workbenchFolder;
testCase.TestData.ScriptPath = fullfile(fileparts(workbenchFolder),'lin_hover.m');
end

function testDefaultVariablesMatchOriginalInitialization(testCase)
% Evaluate the original source in a private function scope. The original
% file is never edited, and clear/simulation/plot statements are not run.
expected = originalInitialization(testCase.TestData.ScriptPath);
actual = hover.buildVariables(hover.defaultSettings());
verifyStructFields(testCase,actual,expected,'variables');
end

function testControllerFrequencyRecomputesSensorCoefficients(testCase)
settings = hover.defaultSettings();
settings.fs = 2000;
settings.accel.LPF_set = 11;
settings.gyro.LPF_set = 17;

variables = hover.buildVariables(settings);

testCase.verifyEqual(variables.Ts,0.0005,AbsTol=1e-15);
testCase.verifyEqual(variables.accel.alpha, ...
    (2*pi*11/2000)/(1+2*pi*11/2000),AbsTol=1e-14);
testCase.verifyEqual(variables.gyro.alpha, ...
    (2*pi*17/2000)/(1+2*pi*17/2000),AbsTol=1e-14);
end

function testWingAreaChangeReachesDampingAndDynamics(testCase)
settings = hover.defaultSettings();
baseline = hover.buildVariables(settings);
settings.wing_type = 2*settings.wing_type;

actual = hover.buildVariables(settings);

testCase.verifyEqual(actual.Aref,2*baseline.Aref,AbsTol=1e-14);
testCase.verifyEqual(actual.Xu,2*baseline.Xu,AbsTol=1e-14);
testCase.verifyEqual(actual.Lp,2*baseline.Lp,AbsTol=1e-14);
testCase.verifyEqual(actual.A(4,4),2*baseline.A(4,4),AbsTol=1e-14);
testCase.verifyEqual(actual.A(10,10),2*baseline.A(10,10),AbsTol=1e-14);
end

function testTimeConstantDampingUsesSelectedDecayTimes(testCase)
settings = hover.defaultSettings();
settings.use_time_constant_damping = true;
settings.tau_p = 0.12;
settings.tau_q = 0.3;
settings.tau_r = 0.7;

actual = hover.buildVariables(settings);

testCase.verifyEqual(diag(actual.A(10:12,10:12)), ...
    -1./[0.12;0.3;0.7],AbsTol=1e-13);
end

function testNoiseOffPreservesScriptEstimatorOverride(testCase)
settings = hover.defaultSettings();
settings.noise_true = false;
settings.mahoney.Kp = 0.8;
settings.mahoney.Ki = 0.3;

actual = hover.buildVariables(settings);
notices = hover.validateSettings(settings);

testCase.verifyEqual(actual.mahoney,struct('Kp',0.25,'Ki',0));
testCase.verifyEqual(settings.mahoney,struct('Kp',0.8,'Ki',0.3));
testCase.verifyTrue(any(contains(notices,'Noise is off')));
end

function testZeroControllerFrequencyIsRejected(testCase)
settings = hover.defaultSettings();
settings.fs = 0;
testCase.verifyError(@() hover.buildVariables(settings),'hover:InvalidSetting');
end

function testNonfiniteGainIsRejected(testCase)
settings = hover.defaultSettings();
settings.roll_P = NaN;
testCase.verifyError(@() hover.validateSettings(settings),'hover:InvalidSetting');
end

function testWrongStateOrientationIsRejected(testCase)
settings = hover.defaultSettings();
settings.X0 = settings.X0.';
testCase.verifyError(@() hover.validateSettings(settings),'hover:InvalidSetting');
end

function testAsymmetricInertiaIsRejected(testCase)
settings = hover.defaultSettings();
settings.I(1,2) = 0.0001;
testCase.verifyError(@() hover.validateSettings(settings),'hover:InvalidInertia');
end

function testNonpositiveInertiaIsRejected(testCase)
settings = hover.defaultSettings();
settings.I(3,3) = 0;
testCase.verifyError(@() hover.validateSettings(settings),'hover:InvalidInertia');
end

function testMissingSettingIsRejected(testCase)
settings = rmfield(hover.defaultSettings(),'t_sim');
testCase.verifyError(@() hover.validateSettings(settings),'hover:MissingSetting');
end

function testPresetRoundTripPreservesCustomMatricesAndNestedSettings(testCase)
folder = temporaryFolder(testCase);
filename = fullfile(folder,'custom.json');
settings = hover.defaultSettings();
settings.fs = 3200;
settings.I(1,2) = 1e-5;
settings.I(2,1) = 1e-5;
settings.X0 = (1:12).'/100;
settings.Xref = (12:-1:1).'/200;
settings.gyro.LPF_set = 23;
settings.noise_true = false;
settings.sim_fidelity = 'low';
options = struct('DefaultPlots',false);

hover.savePreset(filename,settings,options);
[actual,actualOptions] = hover.loadPreset(filename);

verifyStructFields(testCase,actual,settings,'settings');
testCase.verifyEqual(hover.buildVariables(actual),hover.buildVariables(settings));
testCase.verifyEqual(actualOptions,options);
end

function testFuturePresetVersionIsRejected(testCase)
folder = temporaryFolder(testCase);
filename = fullfile(folder,'unsupported.json');
payload = struct('Format','HoverWorkbenchSettings','SchemaVersion',2, ...
    'Settings',hover.defaultSettings());
writelines(jsonencode(payload),filename);

testCase.verifyError(@() hover.loadPreset(filename),'hover:InvalidPreset');
end

function testSignalsNormalizeBothModelArrayOrientations(testCase)
[output,expected] = syntheticOutput();
variables = hover.buildVariables(hover.defaultSettings());

signals = hover.collectSignals(output,variables);
truth = oneSignal(signals,'state.phi');
estimate = oneSignal(signals,'estimate.phi');
delta = oneSignal(signals,'control.delta1');
pot = oneSignal(signals,'control.pot1');
altitude = oneSignal(signals,'derived.altitude');
errorSignal = oneSignal(signals,'error.phi');

testCase.verifyEqual(truth.Time,expected.TrueTime,AbsTol=1e-14);
testCase.verifyEqual(truth.Data,expected.TrueValues(:,7),AbsTol=1e-14);
testCase.verifyEqual(estimate.Time,expected.EstimateTime,AbsTol=1e-14);
testCase.verifyEqual(estimate.Data,expected.EstimateValues(:,7),AbsTol=1e-14);
testCase.verifyEqual(delta.Data,expected.ControlValues(:,1),AbsTol=1e-14);
testCase.verifyEqual(pot.Data,expected.ControlValues(:,1)+variables.u0,AbsTol=1e-12);
testCase.verifyEqual(altitude.Data,-expected.TrueValues(:,3),AbsTol=1e-14);
testCase.verifyEqual(errorSignal.Time,expected.EstimateTime,AbsTol=1e-14);
testCase.verifyEqual(errorSignal.Data,repmat(0.01,3,1),AbsTol=1e-12);
testCase.verifyEqual(truth.Unit,'rad');
end

function testMalformedSignalShapeIsRejected(testCase)
output = struct('state_output',struct('time',(0:4).', ...
    'signals',struct('values',zeros(2,3))));
variables = hover.buildVariables(hover.defaultSettings());
testCase.verifyError(@() hover.collectSignals(output,variables),'hover:SignalShape');
end

function testMatrixSignalWithTwelveSamplesKeepsTimeLast(testCase)
time=(0:11).';
expected=reshape(1:144,12,12);
output=struct('state_estimate',struct('time',time, ...
    'signals',struct('values',permute(expected,[2 3 1]),'dimensions',[12 1])));
signals=hover.collectSignals(output);
roll=oneSignal(signals,'estimate.phi');
testCase.verifyEqual(roll.Data,expected(:,7));
end

function testAdditionalDatasetSignalsAreDiscoverable(testCase)
time = [0;0.2;0.4];
values = [2 3;4 5;6 7];
logged = timeseries(values,time);
logged.DataInfo.Units = 'N';
dataset = Simulink.SimulationData.Dataset;
dataset = dataset.addElement(logged,'Wing force');

signals = hover.collectSignals(struct('logsout',dataset));
first = oneSignal(signals,'logged.logsout.WingForce.1');
second = oneSignal(signals,'logged.logsout.WingForce.2');

testCase.verifyEqual(first.Time,time,AbsTol=1e-14);
testCase.verifyEqual(first.Data,values(:,1),AbsTol=1e-14);
testCase.verifyEqual(second.Data,values(:,2),AbsTol=1e-14);
testCase.verifyEqual(first.Unit,'N');
end

function testRunArchiveRetainsOutputSettingsAndProvenance(testCase)
folder = temporaryFolder(testCase);
settings = hover.defaultSettings();
settings.roll_P = 0.031;
variables = hover.buildVariables(settings);
output = syntheticOutput();
metadata = struct('Label','Tuning trial','Notes','Expected settings retained', ...
    'Model','lin_hover_sim','ElapsedSeconds',1.25,'DefaultPlots',false, ...
    'ScriptPath',testCase.TestData.ScriptPath);

saved = hover.saveRun(folder,settings,variables,output,metadata);
actual = hover.loadRun(saved.Folder);
listed = hover.listRuns(folder);
[preset,options] = hover.loadPreset(fullfile(saved.Folder,'settings.json'));

testCase.verifyEqual(actual.Settings,settings);
testCase.verifyEqual(actual.Variables,variables);
testCase.verifyEqual(actual.Output,output);
verifyStructFields(testCase,actual.Metadata,metadata,'metadata');
testCase.verifyEqual(actual.Signals,saved.Signals);
verifyStructFields(testCase,preset,settings,'archived settings');
testCase.verifyEqual(options.DefaultPlots,false);
testCase.verifyFalse(isfield(actual.Metadata,'SourceSnapshots'));
testCase.verifyNumElements(listed,1);
testCase.verifyEqual(listed.ID,saved.ID);
testCase.verifyEqual(listed.Label,metadata.Label);
testCase.verifyEqual(listed.DurationSeconds,0.4,AbsTol=1e-14);
testCase.verifyEqual(listed.SignalCount,numel(saved.Signals));
testCase.verifyTrue(isfile(fullfile(saved.Folder,'metadata.json')));
end

function testNewArchivesContainOnlySettingsDataAndMetadata(testCase)
folder = temporaryFolder(testCase);
settings = hover.defaultSettings();
variables = hover.buildVariables(settings);
output = syntheticOutput();
modelPath = fullfile(fileparts(testCase.TestData.ScriptPath),'lin_hover_sim.slx');
testCase.assertTrue(isfile(modelPath));
testCase.assertTrue(isfile(testCase.TestData.ScriptPath));
metadata = struct('Label','Data-only archive','ModelPath',modelPath, ...
    'ScriptPath',testCase.TestData.ScriptPath,'ModelSHA256','test-model-hash', ...
    'ScriptSHA256','test-script-hash','SourceScript','legacy source text', ...
    'SourceSnapshots',struct('Model','model.slx','Script','lin_hover.m'));

saved = hover.saveRun(folder,settings,variables,output,metadata);
actual = hover.loadRun(saved.Folder);
files = dir(saved.Folder);
files = files(~[files.isdir]);
summary = jsondecode(fileread(fullfile(saved.Folder,'metadata.json')));

testCase.verifyEqual(sort(string({files.name})), ...
    sort(["settings.json" "metadata.json" "run.mat"]));
testCase.verifyEmpty(dir(fullfile(saved.Folder,'**','*.slx')));
testCase.verifyEmpty(dir(fullfile(saved.Folder,'**','*.m')));
testCase.verifyEqual(actual.Settings,settings);
testCase.verifyEqual(actual.Variables,variables);
testCase.verifyEqual(actual.Output,output);
testCase.verifyEqual(actual.Signals,hover.collectSignals(output,variables));
testCase.verifyEqual(actual.Metadata.ModelPath,modelPath);
testCase.verifyEqual(actual.Metadata.ScriptPath,testCase.TestData.ScriptPath);
testCase.verifyEqual(actual.Metadata.ModelSHA256,metadata.ModelSHA256);
testCase.verifyEqual(actual.Metadata.ScriptSHA256,metadata.ScriptSHA256);
testCase.verifyFalse(any(isfield(actual.Metadata,{'SourceScript','SourceSnapshots'})));
testCase.verifyFalse(any(isfield(summary.Metadata,{'SourceScript','SourceSnapshots'})));
end

function testRepeatedLabelsNeverOverwriteRuns(testCase)
folder = temporaryFolder(testCase);
settings = hover.defaultSettings();
variables = hover.buildVariables(settings);
output = syntheticOutput();
metadata = struct('Label','Same label');

first = hover.saveRun(folder,settings,variables,output,metadata);
second = hover.saveRun(folder,settings,variables,output,metadata);
runs = hover.listRuns(folder);

testCase.verifyNotEqual(first.ID,second.ID);
testCase.verifyNotEqual(first.Folder,second.Folder);
testCase.verifyNumElements(runs,2);
testCase.verifyTrue(isfile(fullfile(first.Folder,'run.mat')));
testCase.verifyTrue(isfile(fullfile(second.Folder,'run.mat')));
end

function testIncompleteRunFoldersAreNotListed(testCase)
folder = temporaryFolder(testCase);
mkdir(fullfile(folder,'.pending_test'));
mkdir(fullfile(folder,'unfinished'));
writelines('{}',fullfile(folder,'unfinished','metadata.json'));

testCase.verifyEmpty(hover.listRuns(folder));
end

function folder = temporaryFolder(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder = fixture.Folder;
end

function signal = oneSignal(signals,key)
signal = signals(strcmp({signals.Key},key));
assert(isscalar(signal),'hover:TestSignalMissing', ...
    'Expected exactly one signal with key %s.',key);
end

function [output,expected] = syntheticOutput()
trueTime = (0:0.1:0.4).';
estimateTime = [0;0.2;0.4];
trueValues = (1:12)+trueTime*(1:12);
estimateValues = (1:12)+estimateTime*(1:12)-0.01;
controlValues = [1 2 3 4;5 6 7 8;9 10 11 12];
output = struct();
output.state_output = struct('time',trueTime, ...
    'signals',struct('values',trueValues,'dimensions',12));
output.state_estimate = struct('time',estimateTime, ...
    'signals',struct('values',permute(estimateValues,[2 3 1]),'dimensions',[12 1]));
output.controls = struct('time',estimateTime, ...
    'signals',struct('values',controlValues,'dimensions',4));
expected = struct('TrueTime',trueTime,'TrueValues',trueValues, ...
    'EstimateTime',estimateTime,'EstimateValues',estimateValues, ...
    'ControlValues',controlValues);
end

function reference = originalInitialization(test_scriptPath)
% This function is intentionally isolated from the base workspace. All
% helper names use test_ so they are excluded from the captured variables.
test_source = fileread(test_scriptPath);
test_stop = regexp(test_source,'(?m)^simstruct\s*=\s*sim\(','start','once');
assert(~isempty(test_stop),'hover:TestScriptBoundary', ...
    'Could not locate the initialization/simulation boundary in lin_hover.m.');
test_source = test_source(1:test_stop-1);
test_source = regexprep(test_source, ...
    '(?m)^clc,\s*clear all,\s*close all[^\r\n]*','');
test_capture = evalc(test_source); %#ok<NASGU>
test_names = who;
test_names = test_names(~startsWith(test_names,'test_'));
reference = struct();
for test_k = 1:numel(test_names)
    reference.(test_names{test_k}) = eval(test_names{test_k});
end
end

function verifyStructFields(testCase,actual,expected,label)
names = fieldnames(expected);
testCase.assertTrue(all(isfield(actual,names)), ...
    sprintf('%s is missing expected fields.',label));
for k = 1:numel(names)
    name = names{k};
    qualifiedName = [label '.' name];
    if isstruct(expected.(name))
        verifyStructFields(testCase,actual.(name),expected.(name),qualifiedName);
    elseif isnumeric(expected.(name))
        testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-12);
    else
        testCase.verifyEqual(actual.(name),expected.(name),qualifiedName);
    end
end
end
