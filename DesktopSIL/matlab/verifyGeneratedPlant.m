function result=verifyGeneratedPlant()
%VERIFYGENERATEDPLANT Compare native executable output against Simulink.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=fullfile(root,'DesktopSIL','verification');
load_system(fullfile(root,'DesktopSIL','model','hover_plant_sil.slx'));
result=struct('NoiseEnabled',{},'MaximumAbsoluteError',{},'PerSignalError',{},'Samples',{},'Passed',{});
for noisy=0:1
    native=readmatrix(fullfile(folder,sprintf('plant_%d.csv',noisy)));
    input=Simulink.SimulationInput('hover_plant_sil');
    input=input.setVariable('noise_true',double(noisy),'Workspace','hover_plant_sil');
    x=zeros(12,1); x(7:8)=[0.03;-0.02];
    input=input.setVariable('X0',x,'Workspace','hover_plant_sil');
    data=[0 3 -2 3 -2;1 3 -2 3 -2];
    input=input.setExternalInput(data);
    input=input.setModelParameter('StopTime','1');
    output=sim(input);
    actual=[];
    for k=1:4
        ts=output.yout.get(k).Values;
        values=ts.Data;
        if ~ts.IsTimeFirst, values=permute(values,[ndims(values) 1:ndims(values)-1]); end
        % Compare integer base ticks, avoiding rounding at sample boundaries.
        actual=[actual interp1(round(ts.Time*16000),reshape(values,numel(ts.Time),[]),round(native(:,1)*16000),'previous')]; %#ok<AGROW>
    end
    differences=max(abs(actual-native(:,2:end)),[],1);
    assert(all(differences<1e-9),'Native and Simulink plant outputs disagree. Max error %g',max(differences));
    result(noisy+1)=struct('NoiseEnabled',logical(noisy),'MaximumAbsoluteError',max(differences), ...
        'PerSignalError',differences,'Samples',height(native),'Passed',true); %#ok<AGROW>
    fprintf('Noise %d: %d samples, maximum error %.3g\n',noisy,height(native),max(differences));
end
f=fopen(fullfile(folder,'plant_equivalence.json'),'w'); cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s\n',jsonencode(result,PrettyPrint=true));
end
