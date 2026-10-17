function settings=flightExample(kind)
%FLIGHTEXAMPLE Complete noisy tuning cases with held commands after release.
arguments
    kind (1,1) string {mustBeMember(kind,["hover","recovery","angle","rate"])} = "hover"
end
if kind=="recovery", settings=hover.hoverExample('recovery'); return; end
settings=hover.hoverExample();
switch kind
    case "angle"
        settings.FirmwareAdapter.CommandMode='angle';
        % Roll pulse, then pitch pulse; angles in degrees in this example.
        schedule=[0 0 0 0; 2 3 0 0; 4 0 0 0; 6 0 -3 0; 8 0 0 0];
    case "rate"
        settings.FirmwareAdapter.CommandMode='rate';
        % Matched positive/negative rate requests; no yaw plant authority.
        schedule=[0 0 0 0; 2 15 0 0; 3 -15 0 0; 4 0 0 0; ...
            6 0 15 0; 7 0 -15 0; 8 0 0 0];
    otherwise
        return
end
schedule(:,2:4)=schedule(:,2:4)*pi/180;
settings.FirmwareAdapter.ReferenceSchedule=schedule;
end
