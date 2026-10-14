function channels=startupChannels(options,armed)
%STARTUPCHANNELS Receiver pulses during stationary calibration and arming.
% Custom vectors allow the firmware's own AND/OR and linked mode logic to run.
arguments
    options (1,1) struct
    armed (1,1) logical = false
end
channels=bf.receiverChannels(options);
layout=options.ReceiverLayout;
channels(layout.Throttle)=options.MinThrottlePWM;
if ~armed
    if ~isempty(options.StartupReceiverPWM)
        channels=options.StartupReceiverPWM(:);
    else
        channels(layout.Arm)=layout.ArmOff;
    end
end
end
