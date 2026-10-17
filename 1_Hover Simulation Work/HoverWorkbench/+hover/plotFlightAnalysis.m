function summary=plotFlightAnalysis(record,axisIndex,axesHandles)
%PLOTFLIGHTANALYSIS Tracking, estimator, PIDF, motors and raw gyro error.
% Uses saved settings and signals, never the current editor configuration.
arguments
    record (1,1) struct
    axisIndex (1,1) double {mustBeMember(axisIndex,1:3)}
    axesHandles (1,6)
end
signals=record.Signals;
variables=struct();
if isfield(record,'Variables'), variables=record.Variables; end
names={'Roll','Pitch','Yaw'}; angleKeys={'phi','theta','psi'}; rateKeys={'p','q','r'};
axisName=names{axisIndex}; angleKey=angleKeys{axisIndex}; rateKey=rateKeys{axisIndex};
mode='receiver';
if isfield(variables,'bfSim') && isfield(variables.bfSim,'CommandMode'), mode=variables.bfSim.CommandMode; end
angleTracking=strcmp(mode,'angle') && axisIndex<3;
if angleTracking, trackKey=angleKey; unit='deg'; quantity='angle';
else, trackKey=rateKey; unit='deg/s'; quantity='rate'; end
valid=find(arrayfun(@(s)~isempty(s.Time),signals));
timeLimits=[0 1];
if ~isempty(valid)
    timeLimits=[min(arrayfun(@(s)s.Time(1),signals(valid))) max(arrayfun(@(s)s.Time(end),signals(valid)))];
end
truthColor=[0 0.447 0.741]; estimateColor=[0.85 0.325 0.098]; commandColor=[0.15 0.15 0.15];
for k=1:6
    cla(axesHandles(k)); hold(axesHandles(k),'on'); grid(axesHandles(k),'on');
    xlabel(axesHandles(k),'Time (s)'); legend(axesHandles(k),'off');
end
truth=get(['display.state.' trackKey]); estimate=get(['display.estimate.' trackKey]);
command=get(['command.' trackKey]);
% Old archives predate normalized commands; reconstruct only from saved inputs.
if isempty(command) && ~strcmp(mode,'receiver') && isfield(variables,'Xref') && ~isempty(truth)
    [values,keys]=bf.commandSeries(truth.Time,variables.Xref,variables.bfSim);
    index=find(strcmp(keys,trackKey),1);
    if ~isempty(index), command=truth; command.Data=values(:,index); end
end
commandLabel='Requested command'; commandNote='Requested before receiver shaping; response from plant and firmware';
if isempty(command) && ~angleTracking
    command=get(['betaflight.receiver_rate.' lower(axisName)]);
    if ~isempty(command)
        command.Data=command.Data*180/pi;
        commandLabel='Native receiver rate'; commandNote='Native receiver rate after input processing; plant and gyro response';
    end
end
if isempty(command), commandNote='Command not logged; showing available response signals'; end
estimateLabel='Betaflight attitude';
if ~angleTracking, estimateLabel='Filtered gyro'; end
draw(1,command,commandLabel,'--',commandColor);
draw(1,truth,'True plant','-',truthColor); draw(1,estimate,estimateLabel,':',estimateColor);
describe(1,[axisName ' ' quantity ': command and response'],commandNote,unit);
if angleTracking
    draw(2,get(['display.state.' rateKey]),'True body rate','-',truthColor);
    draw(2,get(['display.estimate.' rateKey]),'Filtered gyro','--',estimateColor);
    describe(2,[axisName ' angular rate feedback'],'True body rate versus the gyro signal used by the rate controller','deg/s');
else
    draw(2,get(['display.state.' angleKey]),'True plant','-',truthColor);
    draw(2,get(['display.estimate.' angleKey]),'Betaflight attitude','--',estimateColor);
    describe(2,[axisName ' attitude estimate'],'Orientation resulting from the rate response; true versus estimated','deg');
end
errorSignal=get(['display.error.' angleKey]);
if ~isempty(errorSignal)
    errorSignal.Data=atan2(sin(errorSignal.Data*pi/180),cos(errorSignal.Data*pi/180))*180/pi;
end
draw(3,errorSignal,'True - estimated','-',estimateColor);
describe(3,[axisName ' attitude estimation error'],'True angle minus estimated angle; zero means an accurate estimate','deg');
pidColors=lines(5); termIndex=0;
for term={'P','I','D','F','Sum'}
    termIndex=termIndex+1;
    draw(4,get(['betaflight.pid.' lower(axisName) '.' term{1}]),term{1},'-',pidColors(termIndex,:));
end
describe(4,[axisName ' rate-controller contributions'],'P, I, D, feedforward (F) and sum, before motor mixing','Native PID units');
motorRange=[Inf -Inf]; motorColors=lines(4);
for motor=1:4
    signal=get(sprintf('betaflight.motor%d',motor));
    draw(5,signal,sprintf('Motor %d',motor),'-',motorColors(motor,:));
    if ~isempty(signal), motorRange=[min(motorRange(1),min(signal.Data)) max(motorRange(2),max(signal.Data))]; end
end
if ~isfinite(motorRange(1)), motorRange=[NaN NaN];
elseif isfield(variables,'u0')
    trim=struct('Time',timeLimits(:),'Data',repmat(variables.u0,2,1));
    draw(5,trim,'Plant hover trim','--',commandColor);
end
describe(5,'Actuator outputs after mixing','All four firmware motor commands; same numeric values as plant pot inputs','Output (us / pot)');
ideal=getLogged('imu_gyro_ideal',axisIndex); measured=getLogged('imu_gyro_measured',axisIndex);
if ~isempty(ideal) && ~isempty(measured)
    noise=measured;
    noise.Data=(measured.Data-align(ideal,measured.Time,'previous'))*180/pi;
    draw(6,noise,'Raw measured - ideal','-',truthColor);
end
describe(6,[axisName ' raw gyro measurement error'],'Measured minus ideal, before firmware filtering and bias calibration','deg/s');
trackingRms=NaN;
if ~isempty(command) && ~isempty(truth)
    difference=truth.Data-align(command,truth.Time,'previous');
    if angleTracking, difference=atan2(sin(difference*pi/180),cos(difference*pi/180))*180/pi; end
    trackingRms=weightedRms(truth.Time,difference);
end
estimatorRms=NaN;
if ~isempty(errorSignal), estimatorRms=weightedRms(errorSignal.Time,errorSignal.Data); end
summary=struct('Axis',axisName,'CommandMode',mode,'TrackingRms',trackingRms, ...
    'TrackingUnit',unit,'TrackingQuantity',quantity,'CommandSource',commandLabel, ...
    'EstimatorRmsDegrees',estimatorRms,'MotorRangeMicroseconds',motorRange);
missing={'No command/response signals in this run','No state/gyro feedback in this run', ...
    'No attitude error signals in this run','Native PID terms were not logged', ...
    'Firmware motor outputs were not logged','Raw IMU signals were not logged'};
for k=1:6
    hold(axesHandles(k),'off');
    if ~isempty(findobj(axesHandles(k),'Type','line'))
        legend(axesHandles(k),'show','Location','northeast','Interpreter','none','FontSize',9);
    else
        text(axesHandles(k),0.5,0.5,missing{k},'Units','normalized','HorizontalAlignment','center');
    end
    hover.fitPlot(axesHandles(k),timeLimits);
end

    function signal=get(key)
        index=find(strcmp({signals.Key},key),1); signal=[];
        if ~isempty(index) && ~isempty(signals(index).Time) && ~isempty(signals(index).Data), signal=signals(index); end
    end
    function signal=getLogged(name,component)
        index=find(contains({signals.Key},name) & endsWith({signals.Key},sprintf('.%d',component)),1);
        signal=[]; if ~isempty(index), signal=signals(index); end
    end
    function draw(tile,signal,label,style,color)
        if isempty(signal), return; end
        hover.plotSignal(axesHandles(tile),signal.Time,signal.Data,'LineStyle',style, ...
            'Color',color,'DisplayName',label,'LineWidth',1);
    end
    function describe(tile,heading,explanation,units)
        title(axesHandles(tile),heading,'Interpreter','none','FontSize',11);
        subtitle(axesHandles(tile),explanation,'Interpreter','none','FontSize',9);
        ylabel(axesHandles(tile),units,'Interpreter','none');
    end
end

function values=align(signal,time,method)
[t,idx]=unique(signal.Time,'last');
if isscalar(t), values=repmat(signal.Data(idx),size(time));
else, values=interp1(t,signal.Data(idx),time,method,'extrap'); end
end

function result=weightedRms(time,values)
if numel(time)<2 || time(end)==time(1), result=sqrt(mean(values.^2));
else, result=sqrt(trapz(time,values.^2)/(time(end)-time(1))); end
end
