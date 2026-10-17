function reference=commandReference(reference,time,options)
%COMMANDREFERENCE Apply a held angle/rate command sequence in SI units.
% Rows are [simulation seconds, roll, pitch, yaw rate]. Roll/pitch are radians
% in ANGLE mode and rad/s in RATE mode. Empty sequences preserve the model
% reference input. The sequence is sampled by the native receiver frame path;
% it does not bypass native rate conversion, smoothing, limits or PID control.
if ~isfield(options,'ReferenceSchedule') || isempty(options.ReferenceSchedule)
    return
end
row=find(options.ReferenceSchedule(:,1)<=time+1e-10,1,'last');
if isempty(row), return; end
values=options.ReferenceSchedule(row,2:4)';
if strcmp(options.CommandMode,'angle')
    reference([7 8 12])=values;
elseif strcmp(options.CommandMode,'rate')
    reference(10:12)=values;
end
end
