function layout=receiverLayout(config)
%RECEIVERLAYOUT Resolve native channel mapping and ARM/ANGLE mode ranges.
% AETR is the physical input order only for the default preset; CLI `map`
% changes are honored, including remapped first four auxiliary channels.
lines=splitlines(string(config.CLI)); map='AETR1234'; modes=zeros(20,4);
ranges=repmat([1000 2000],4,1);
for k=1:numel(lines)
    line=strtrim(char(lines(k)));
    if ~isempty(regexp(line,'^defaults(?:\s|$)','once'))
        map='AETR1234'; modes=zeros(20,4); ranges=repmat([1000 2000],4,1);
    end
    token=regexp(line,'^map\s+([AERT1234]{8})$','tokens','once');
    if ~isempty(token), map=token{1}; end
    if strcmpi(line,'rxrange reset'), ranges=repmat([1000 2000],4,1); end
    token=regexp(line,'^rxrange\s+([0-3])\s+(\d+)\s+(\d+)','tokens','once');
    if ~isempty(token), row=str2double(token); ranges(row(1)+1,:)=row(2:3); end
    token=regexp(line,'^aux\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)','tokens','once');
    if ~isempty(token)
        row=str2double(token);
        modes(row(1)+1,:)=row(2:5);
    end
end
modes=modes(modes(:,4)>modes(:,3),:);
schema=bf.parseCliSettings(config.SchemaText); item=schema(strcmp({schema.Name},'mid_rc'));
midrc=1500;
if ~isempty(item), midrc=str2double(bf.settingValue(config.CLI,item(1),0)); end
layout=struct('Roll',find(map=='A'),'Pitch',find(map=='E'), ...
    'Throttle',find(map=='T'),'Yaw',find(map=='R'),'Arm',[], ...
    'ArmOn',2000,'ArmOff',1000,'Angle',[],'AngleOn',2000,'AngleOff',1000, ...
    'Ranges',ranges,'MidRc',midrc);
for pair={'Arm','Angle'}
    name=pair{1}; id=double(strcmp(name,'Angle'));
    row=find(modes(:,1)==id,1,'first');
    if isempty(row), continue; end
    aux=modes(row,2);
    if aux<4, channel=find(map==char('1'+aux)); else, channel=5+aux; end
    layout.(name)=channel;
    layout.([name 'On'])=mean(modes(row,3:4));
    if modes(row,3)<=1000 && modes(row,4)>1000, layout.([name 'Off'])=2000; end
end
if isempty(layout.Arm)
    error('bf:ArmMode','Automatic startup requires an ARM auxiliary mode range in the firmware configuration.');
end
end
