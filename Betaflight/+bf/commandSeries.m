function [values,keys,units]=commandSeries(time,reference,options)
%COMMANDSERIES Requested physical commands before receiver quantization/filtering.
% For the workbench's constant Xref source plus optional held sequence. Raw
% receiver mode has no physical-reference signal and returns empty outputs.
values=[]; keys={}; units={};
if strcmp(options.CommandMode,'receiver'), return; end
if strcmp(options.CommandMode,'angle')
    indices=[7 8 12]; keys={'phi','theta','r'}; units={'deg','deg','deg/s'};
else
    indices=10:12; keys={'p','q','r'}; units={'deg/s','deg/s','deg/s'};
end
values=repmat(reshape(reference(indices),1,3),numel(time),1);
if isfield(options,'ReferenceSchedule')
    schedule=options.ReferenceSchedule;
    for k=1:size(schedule,1)
        selected=time(:)+1e-10>=schedule(k,1);
        values(selected,:)=repmat(schedule(k,2:4),nnz(selected),1);
    end
end
values=values*180/pi;
end
