function report=replayTrace(path,transport)
%REPLAYTRACE Repeat captured sensor/receiver inputs in a fresh native process.
% Every response word must equal the original exactly, including PID terms,
% motors, estimator, status and scheduler ticks. No plant or model is needed.
% Capture by setting bfSim.TraceFile to a new .bin path before simulation.
arguments
    path {mustBeTextScalar}
    transport {mustBeMember(transport,{'java','matlab'})} = 'java'
end
path=char(path);
saved=load([path '.mat'],'configuration','metadata');
assert(saved.metadata.Version==1,'bf:TraceVersion','Unsupported trace format.');
assert(strcmp(saved.metadata.BinarySHA256,bf.binaryHash()), ...
    'bf:TraceBinary','The trace was recorded with a different firmware binary.');
info=dir(path);
assert(~isempty(info) && info.bytes>0 && mod(info.bytes,92*8)==0, ...
    'bf:TraceSize','The firmware trace is empty or incomplete.');
fid=fopen(path,'r','ieee-le');
if fid<0, error('bf:TraceOpen','Cannot open trace: %s',path); end
fileCleanup=onCleanup(@()fclose(fid));
client=bf.Client(saved.configuration,5,transport);
clientCleanup=onCleanup(@()delete(client));
count=info.bytes/(92*8); started=tic;
for k=1:count
    packet=fread(fid,92,'double');
    request=packet(1:52); expected=packet(53:92);
    actual=client.step(request(5),request(6:8),request(9:11), ...
        request(12:27),request(28:39),request(40),request(41:52));
    mismatch=find(actual~=expected,1);
    if ~isempty(mismatch)
        error('bf:ReplayMismatch','Exchange %d at %.9g s, response word %d: expected %.17g, got %.17g.', ...
            k,request(5),mismatch,expected(mismatch),actual(mismatch));
    end
end
report=struct('Passed',true,'ExactlyEqual',true,'Exchanges',count, ...
    'LastFirmwareTime',request(5),'ReplayWallSeconds',toc(started), ...
    'Transport',char(transport),'BinarySHA256',saved.metadata.BinarySHA256,'TraceFile',path);
end
