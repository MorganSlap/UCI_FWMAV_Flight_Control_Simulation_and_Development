classdef Client < handle
    %CLIENT One independent, bounded lockstep connection to actual firmware.
    properties (SetAccess=private)
        Process = []
        Socket = []
        Folder = ''
        Sequence = 0
        LastTime = -inf
        LastResponse = zeros(40,1)
        EffectiveConfiguration = ''
        Transport = 'java'
        InputChannel = []
        OutputStream = []
        ResponseBuffer = []
    end
    properties (Access=private)
        TraceFID = -1
    end
    methods
        function obj=Client(config,timeout,transport,traceFile)
            if nargin<2, timeout=5; end
            if nargin>=3, obj.Transport=char(transport); end
            assert(ismember(obj.Transport,{'java','matlab'}),'bf:Transport','Unknown transport.');
            p=bf.paths();
            if ~isfolder(p.Runtime), mkdir(p.Runtime); end
            obj.Folder=tempname(p.Runtime); mkdir(obj.Folder);
            obj.EffectiveConfiguration=bf.provision(config,obj.Folder);
            % Ask the OS for a free ephemeral port, then immediately launch.
            reservation=java.net.ServerSocket(0);
            port=reservation.getLocalPort(); reservation.close();
            obj.Process=bf.startProcess({'--host-port',sprintf('%d',port)}, ...
                obj.Folder,fullfile(obj.Folder,'firmware.log'));
            started=tic;
            try
                while isempty(obj.Socket)
                    if ~obj.Process.isAlive()
                        error('bf:FirmwareExited','Firmware exited during startup. See %s',obj.Folder);
                    end
                    try
                        if strcmp(obj.Transport,'java')
                            connection=java.net.Socket();
                            try
                                connection.connect(java.net.InetSocketAddress('127.0.0.1',port),1000);
                                connection.setTcpNoDelay(true);
                                connection.setSoTimeout(ceil(1000*timeout));
                                obj.InputChannel=java.nio.channels.Channels.newChannel(connection.getInputStream());
                                obj.OutputStream=connection.getOutputStream();
                                obj.ResponseBuffer=java.nio.ByteBuffer.allocate(320);
                                obj.Socket=connection;
                            catch exception
                                connection.close(); rethrow(exception);
                            end
                        else
                            obj.Socket=tcpclient('127.0.0.1',port,'ConnectTimeout',1, ...
                                'Timeout',timeout,'EnableTransferDelay',false);
                        end
                    catch errorInfo
                        if toc(started)>15, rethrow(errorInfo); end
                        pause(0.05);
                    end
                end
                if strcmp(obj.Transport,'matlab'), obj.Socket.ByteOrder='little-endian'; end
                if nargin>=4 && strlength(string(traceFile))>0
                    obj.beginTrace(char(traceFile),config);
                end
            catch errorInfo
                delete(obj); rethrow(errorInfo);
            end
        end

        function response=step(obj,time,gyro,accel,rc,state,nav,reference)
            if nargin<7, nav=0; end
            if nargin<8, reference=zeros(12,1); end
            validateattributes(time,{'double'},{'scalar','real','finite','nonnegative'});
            if time==obj.LastTime, response=obj.LastResponse; return; end
            if time<obj.LastTime, error('bf:TimeReversal','Firmware time cannot run backwards. Start a new run.'); end
            request=zeros(52,1);
            request(1:5)=[20261011;1;1;obj.Sequence+1;time];
            request(6:8)=gyro(:); request(9:11)=accel(:);
            request(12:27)=rc(:); request(28:39)=state(:); request(40)=nav;
            request(41:52)=reference(:);
            if any(~isfinite(request)), error('bf:NonfiniteInput','Firmware inputs must be finite.'); end
            if strcmp(obj.Transport,'java')
                bytes=typecast(request,'int8');
                obj.OutputStream.write(bytes,0,numel(bytes));
                obj.ResponseBuffer.clear();
                while obj.ResponseBuffer.hasRemaining()
                    count=obj.InputChannel.read(obj.ResponseBuffer);
                    if count<0, error('bf:ConnectionClosed','Firmware closed the connection. See %s',obj.Folder); end
                end
                response=typecast(int8(obj.ResponseBuffer.array()),'double');
            else
                write(obj.Socket,request,'double');
                response=read(obj.Socket,40,'double');
            end
            response=response(:);
            if numel(response)~=40
                error('bf:Protocol','Incomplete firmware reply (%d of 40 values). See %s',numel(response),obj.Folder);
            end
            if response(1)~=20261011 || response(2)~=1 || ...
                    response(3)~=0 || response(4)~=request(4) || abs(response(5)-time)>1e-9
                error('bf:Protocol','Invalid firmware reply (status %g, time %.9g, requested %.9g). See %s',response(3),response(5),time,obj.Folder);
            end
            obj.Sequence=request(4); obj.LastTime=time; obj.LastResponse=response;
            if obj.TraceFID>=0
                count=fwrite(obj.TraceFID,[request;response],'double');
                if count~=92, error('bf:TraceWrite','Could not write the complete firmware exchange.'); end
            end
        end

        function delete(obj)
            if obj.TraceFID>=0, fclose(obj.TraceFID); obj.TraceFID=-1; end
            % The client owns exactly this process; never kill by image name.
            if strcmp(obj.Transport,'java') && ~isempty(obj.Socket), obj.Socket.close(); end
            obj.Socket=[];
            if ~isempty(obj.Process) && obj.Process.isAlive()
                obj.Process.destroy();
                if obj.Process.isAlive(), obj.Process.destroyForcibly(); end
            end
        end
    end
    methods (Access=private)
        function beginTrace(obj,path,configuration)
            % Opt-in numeric input/output capture, including calibration.
            % Refuse replacement so a later run cannot erase previous evidence.
            if isfile(path) || isfile([path '.mat'])
                error('bf:TraceExists','Trace already exists: %s. Choose a new filename.',path);
            end
            [folder,~,~]=fileparts(path);
            if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
            [obj.TraceFID,message]=fopen(path,'w','ieee-le');
            if obj.TraceFID<0, error('bf:TraceOpen','%s',message); end
            metadata=struct('Version',1,'RequestWords',52,'ResponseWords',40, ...
                'BinarySHA256',bf.binaryHash(),'Transport',obj.Transport);
            save([path '.mat'],'configuration','metadata');
        end
    end
end
