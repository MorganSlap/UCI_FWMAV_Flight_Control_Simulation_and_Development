function value=angularInputValue(key,value,direction)
%ANGULARINPUTVALUE Convert UI degrees to/from the existing SI settings format.
% Gyro sensor settings already use degree units and pass through unchanged.
arguments
    key (1,1) string
    value
    direction (1,1) string {mustBeMember(direction,["display","simulation"])}
end
if direction=="display", factor=180/pi; else, factor=pi/180; end
if any(key==["X0","Xref"])
    value(7:12,:)=value(7:12,:)*factor;
elseif any(key==["p_ref","q_ref","r_ref"])
    value=value*factor;
elseif key=="FirmwareAdapter.ReferenceSchedule"
    value(:,2:4)=value(:,2:4)*factor;
end
end
