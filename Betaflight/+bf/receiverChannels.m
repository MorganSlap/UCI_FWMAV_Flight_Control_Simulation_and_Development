function rc = receiverChannels(options)
%RECEIVERCHANNELS Generate raw input using the configuration's map and modes.
% Set bfRc directly or connect your own 16-channel signal for receiver tests.
arguments
    options (1,1) struct
end
if isfield(options,'ReceiverPWM') && ~isempty(options.ReceiverPWM)
    rc=options.ReceiverPWM(:); return
end
rc=1000*ones(16,1);
layout=options.ReceiverLayout;
rc([layout.Roll layout.Pitch layout.Yaw])=layout.Ranges(1:3,1) ...
    +(layout.MidRc-1000)*diff(layout.Ranges(1:3,:),1,2)/1000;
rc(layout.Throttle)=options.ThrottlePWM;
rc(layout.Arm)=layout.ArmOn;
if ~isempty(layout.Angle)
    if strcmp(options.CommandMode,'angle'), rc(layout.Angle)=layout.AngleOn;
    else, rc(layout.Angle)=layout.AngleOff; end
elseif strcmp(options.CommandMode,'angle')
    error('bf:AngleMode','Angle reference requires an ANGLE auxiliary mode range in the firmware configuration.');
end
end
