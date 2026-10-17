function [timeView,dataView] = displaySamples(time,data,limits,maxPoints)
%DISPLAYSAMPLES Peak-preserving overview; exact samples at close zoom.
arguments
    time (:,1) double
    data (:,1) double
    limits (1,2) double
    maxPoints (1,1) double = 4000
end
if isempty(time), timeView=time; dataView=data; return; end
first=max(1,lowerBound(time,limits(1))-1);
last=min(numel(time),lowerBound(time,limits(2)));
indices=(first:last)';
if numel(indices)>maxPoints
    width=ceil(numel(indices)/floor((maxPoints-5)/3));
    count=floor(numel(indices)/width);
    blocks=reshape(data(indices(1:count*width)),width,count);
    [~,lo]=min(blocks,[],1,'omitnan');
    [~,hi]=max(blocks,[],1,'omitnan');
    [hasGap,gap]=max(isnan(blocks),[],1);
    offsets=(0:count-1)*width;
    chosen=[1,numel(indices),offsets+lo,offsets+hi,offsets(hasGap)+gap(hasGap)];
    tail=data(indices(count*width+1:end));
    if ~isempty(tail)
        [~,lo]=min(tail,[],'omitnan'); [~,hi]=max(tail,[],'omitnan');
        chosen=[chosen,count*width+[lo hi],count*width+find(isnan(tail),1)];
    end
    indices=indices(unique(chosen));
end
timeView=time(indices); dataView=data(indices);
end

function index=lowerBound(values,target)
left=1; right=numel(values)+1;
while left<right
    middle=floor((left+right)/2);
    if values(middle)<target, left=middle+1; else, right=middle; end
end
index=left;
end
