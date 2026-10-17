classdef calibrationTest < matlab.unittest.TestCase
    methods (Test)
        function reproducibleWithoutChangingGlobalRandomState(testCase)
            options=fixture(); state=rng;
            first=bf.calibrationGyroSamples(options,0:1/4000:5);
            second=bf.calibrationGyroSamples(options,0:1/4000:5);
            testCase.verifyEqual(first,second);
            testCase.verifyEqual(rng,state);
            options.CalibrationSeed=options.CalibrationSeed+1;
            testCase.verifyNotEqual(first,bf.calibrationGyroSamples(options,0:1/4000:5));
        end
        function noiseIsHeldAtPhysicalSensorRate(testCase)
            options=fixture();
            result=bf.calibrationGyroSamples(options,[0 0.00025 0.0003125 0.0005]);
            testCase.verifyEqual(result(:,1),result(:,2));
            testCase.verifyEqual(result(:,3),result(:,4));
            testCase.verifyNotEqual(result(:,1),result(:,3));
            testCase.verifyEqual(result(1,:),result(2,:));
        end
        function disabledNoiseAndLegacyOptionsAreConstant(testCase)
            options=fixture(); options.CalibrationGyroNoiseStd=0;
            expected=repmat(options.CalibrationGyro,1,3);
            testCase.verifyEqual(bf.calibrationGyroSamples(options,[0 1 2]),expected);
            options=rmfield(options,{'CalibrationGyroNoiseStd','CalibrationGyroSampleTime','CalibrationSeed'});
            testCase.verifyEqual(bf.calibrationGyroSamples(options,[0 1 2]),expected);
        end
        function sensorStatisticsPreserveMeanBeforeAdc(testCase)
            options=fixture();
            result=bf.calibrationGyroSamples(options,0:options.CalibrationGyroSampleTime:60);
            testCase.verifyEqual(mean(result,2),options.CalibrationGyro,'AbsTol',options.CalibrationGyroNoiseStd/100);
            testCase.verifyEqual(std(result,0,2),repmat(options.CalibrationGyroNoiseStd,3,1), ...
                'RelTol',0.01);
            % Unlike a constant sample, quantized noisy data retains a
            % fractional mean offset that the native calibrator can learn.
            adc=round(result*180/pi*16.384);
            testCase.verifyEqual(mean(adc,2)/16.384,options.CalibrationGyro*180/pi,'AbsTol',0.002);
        end
    end
end

function options=fixture()
options=struct('CalibrationGyro',0.5*pi/180*ones(3,1), ...
    'CalibrationGyroNoiseStd',0.007*pi/180*sqrt(751), ...
    'CalibrationGyroSampleTime',1/3200,'CalibrationSeed',23341);
end
