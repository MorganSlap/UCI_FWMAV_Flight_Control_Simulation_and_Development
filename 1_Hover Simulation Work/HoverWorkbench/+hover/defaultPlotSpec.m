function specs = defaultPlotSpec()
%DEFAULTPLOTSPEC Separate state quantities with one physical unit per axes.
template = struct('Tab','','Title','','Keys',{{}},'Labels',{{}}, ...
    'Factors',[],'YLabel','','UnavailableForNative',false);
specs = repmat(template,1,11);
quantities = {'attitude','angular rates','position','body velocity'};
keys = {{'phi','theta','psi'},{'p','q','r'},{'x','y','z'},{'u','v','w'}};
labels = {{'Roll','Pitch','Yaw'},{'Roll rate p','Pitch rate q','Yaw rate r'}, ...
    {'x (north)','y (east)','Altitude (-z)'},{'u (forward)','v (right)','w (down)'}};
factors = {repmat(180/pi,1,3),repmat(180/pi,1,3),[1 1 -1],[1 1 1]};
units = {'Angle [deg]','Angular rate [deg/s]','Position [m]','Body velocity [m/s]'};
prefixes = {'state','estimate'};
tabs = {'True state','Estimated state'};
titles = {'True','Estimated'};
for group = 1:2
    for quantity = 1:4
        index = 4*(group-1)+quantity;
        specs(index).Tab = tabs{group};
        specs(index).Title = [titles{group} ' ' quantities{quantity}];
        specs(index).Keys = strcat(prefixes{group},'.',keys{quantity});
        specs(index).Labels = labels{quantity};
        specs(index).Factors = factors{quantity};
        specs(index).YLabel = units{quantity};
        specs(index).UnavailableForNative = group==2 && quantity>=3;
    end
end
specs(11) = struct('Tab','Errors and controls','Title','Absolute control inputs', ...
    'Keys',{{'control.pot1','control.pot2','control.pot3','control.pot4'}}, ...
    'Labels',{{'Control 1 (pot1)','Control 2 (pot2)','Control 3 (pot3)','Control 4 (pot4)'}}, ...
    'Factors',ones(1,4),'YLabel','Pot value','UnavailableForNative',false);
for quantity = 1:2
    index = 8+quantity;
    specs(index).Tab = 'Errors and controls';
    specs(index).Title = ['True - estimated ' quantities{quantity}];
    specs(index).Keys = strcat('error.',keys{quantity});
    specs(index).Labels = labels{quantity};
    specs(index).Factors = factors{quantity};
    specs(index).YLabel = ['Error: ' units{quantity}];
end
end
