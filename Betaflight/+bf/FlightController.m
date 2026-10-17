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
                obj.Epoch=bf.startup(obj.Firmware,obj.Options);
                obj.LastReceiverFrame=-1;
            catch exception
                delete(obj.Firmware); obj.Firmware=[]; rethrow(exception);
            end
        end
        function [delta,estimate,diagnostics]=stepImpl(obj,gyro,accel,rc,state,reference)
            time=getCurrentTime(obj);
            reference=bf.commandReference(reference,time,obj.Options);
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
