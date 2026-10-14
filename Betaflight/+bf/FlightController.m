classdef FlightController < matlab.System
    %FLIGHTCONTROLLER Discrete Simulink boundary for the actual Betaflight process.
    % Interpreted execution supports the bounded TCP transport and process.
    properties (Nontunable)
        Configuration = struct()
        Options = struct()
        SampleTime = 0.00025
    end
    properties (Access=private)
        Firmware = []
        Epoch = 0
        LastReceiverFrame = -1
    end
    methods (Access=protected)
        function setupImpl(obj,varargin)
            bf.validateOptions(obj.Options);
            if abs(obj.SampleTime-obj.Options.SampleTime)>1e-12
                error('bf:SampleTime','The block sample time and sensor interface sample time must agree.');
            end
        end
        function resetImpl(obj)
            if ~isempty(obj.Firmware), delete(obj.Firmware); end
            config=bf.calibratedConfig(obj.Configuration,obj.Options);
            obj.Firmware=bf.Client(config,obj.Options.Timeout,'java',obj.Options.TraceFile);
            try
                x=obj.Options.InitialState;
                % Stationary calibration before releasing the plant. Gravity
                % is rotated into FRD; the estimator receives no truth angle.
                a=obj.Options.Gravity*[sin(x(8));-sin(x(7))*cos(x(8));-cos(x(7))*cos(x(8))] ...
                    +obj.Options.CalibrationAccelBias;
                gyro=obj.Options.CalibrationGyro;
                flags=8+obj.Options.NavigationSensors;
                rc=bf.startupChannels(obj.Options,false);
                framePeriod=1/obj.Options.RcRateHz;
                count=ceil(obj.Options.WarmupSeconds/framePeriod);
                for tick=0:count
                    response=obj.Firmware.step(tick*framePeriod,gyro,a,rc,x,flags);
                end
                if response(31)~=0
                    error('bf:CalibrationArmed','The calibration receiver pulses activated ARM. Set the disarmed column on the Receiver channels page.');
                end
                rc=bf.startupChannels(obj.Options,true);
                armCount=ceil(obj.Options.ArmSettleSeconds/framePeriod);
                for tick=1:armCount
                    response=obj.Firmware.step((count+tick)*framePeriod,gyro,a,rc,x,flags);
                end
                if response(31)~=1
                    error('bf:NotArmed','Betaflight did not arm after calibration (disable mask %.0f). Firmware log: %s',response(32),obj.Firmware.Folder);
                end
                if strcmp(obj.Options.CommandMode,'angle') && ~bitand(uint32(response(33)),uint32(1))
                    error('bf:AngleNotActive','ANGLE mode did not activate. Check AUX ranges or supply matching pulses on the Receiver channels page.');
                end
                if strcmp(obj.Options.CommandMode,'rate') && bitand(uint32(response(33)),uint32(3))
                    error('bf:RateModeActive','ANGLE or HORIZON is active with a rate reference. Set matching AUX pulses on the Receiver channels page.');
                end
                if response(36)~=4, error('bf:MotorCount','The current plant requires a four-motor mixer.'); end
                if response(34)~=250 || abs(response(35)*1e-6-obj.Options.PidSampleTime)>1e-10
                    error('bf:LoopRate','Native gyro/PID periods disagree with the requested configuration (%.0f/%.0f us).',response(34),response(35));
                end
                % Establish the flight throttle before releasing the airborne
                % plant. Hold the initial attitude command during this phase
                % so the attitude loop is not integrating a release transient.
                rc=bf.receiverChannels(obj.Options);
                reference=zeros(12,1); reference(7:8)=x(7:8);
                if strcmp(obj.Options.CommandMode,'angle'), flags=flags+16; end
                if strcmp(obj.Options.CommandMode,'rate'), flags=flags+32; end
                spoolCount=ceil(obj.Options.SpoolupSeconds/framePeriod);
                for tick=1:spoolCount
                    response=obj.Firmware.step((count+armCount+tick)*framePeriod,gyro,a,rc,x,flags,reference);
                end
                if response(31)~=1, error('bf:SpoolupDisarmed','Firmware disarmed during throttle settling.'); end
                obj.Epoch=(count+armCount+spoolCount)*framePeriod+obj.SampleTime;
                obj.LastReceiverFrame=-1;
            catch exception
                delete(obj.Firmware); obj.Firmware=[]; rethrow(exception);
            end
        end
        function [delta,estimate,diagnostics]=stepImpl(obj,gyro,accel,rc,state,reference)
            time=getCurrentTime(obj);
            frame=floor((time+1e-10)*obj.Options.RcRateHz);
            flags=obj.Options.NavigationSensors;
            if frame~=obj.LastReceiverFrame
                flags=flags+8; obj.LastReceiverFrame=frame;
            end
            if strcmp(obj.Options.CommandMode,'angle'), flags=flags+16; end
            if strcmp(obj.Options.CommandMode,'rate'), flags=flags+32; end
            diagnostics=obj.Firmware.step(obj.Epoch+time,gyro,accel,rc,state,flags,reference);
            delta=diagnostics(5+obj.Options.MotorOrder)-obj.Options.TrimPot;
            delta=reshape(delta,4,1);
            estimate=[zeros(6,1);diagnostics(10:15)];
            % Log firmware time relative to the plant, while retaining all
            % native diagnostics. Warmup duration is in saved Options.
            diagnostics(5)=time;
        end
        function releaseImpl(obj)
            if ~isempty(obj.Firmware), delete(obj.Firmware); obj.Firmware=[]; end
        end
        function sampleTime=getSampleTimeImpl(obj)
            sampleTime=createSampleTime(obj,'Type','Discrete','SampleTime',obj.SampleTime);
        end
        function [a,b,c]=getOutputSizeImpl(~), a=[4 1]; b=[12 1]; c=[40 1]; end
        function [a,b,c]=getOutputDataTypeImpl(~), a='double'; b='double'; c='double'; end
        function [a,b,c]=isOutputComplexImpl(~), a=false; b=false; c=false; end
        function [a,b,c]=isOutputFixedSizeImpl(~), a=true; b=true; c=true; end
        function names=getIconImpl(~), names='Betaflight firmware'; end
        function [a,b,c,d,e]=getInputNamesImpl(~)
            a='gyro_rad_s'; b='specific_force_m_s2'; c='receiver_us'; d='true_state'; e='reference_SI';
        end
        function [a,b,c]=getOutputNamesImpl(~), a='delta_pot'; b='state_estimate'; c='firmware_diagnostics'; end
    end
end
