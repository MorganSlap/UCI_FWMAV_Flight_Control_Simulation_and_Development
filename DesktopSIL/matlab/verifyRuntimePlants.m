function report=verifyRuntimePlants()
%VERIFYRUNTIMEPLANTS Verify both generated plants and tunable runtime adapters.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'Betaflight'),fullfile(root,'1_Hover Simulation Work','HoverWorkbench'));
folder=fullfile(root,'DesktopSIL','verification');
cases=jsondecode(fileread(fullfile(folder,'adapter_cases.json')));
report=struct('Case',{},'MaximumAbsoluteError',{},'Samples',{},'Passed',{});
for index=1:numel(cases)
    c=cases(index).case; s=hover.hoverExample();
    s.sim_fidelity=c.fidelity; s.noise_true=c.noise; s.drag_enabled=c.drag; s.seed=c.seed;
    s.X0=c.initial(:); s.X0(7:12)=s.X0(7:12)*pi/180;
    p=c.plant;
    fields={'m','g','S','rho','C11','C21','tau_wing','wing_type','AxFactor','AyFactor','AzFactor','AomegaFactor','CDx','CDy','CDz','CDw','v_ref','w_ref','k_tau'};
    for k=1:numel(fields), s.(fields{k})=p.(fields{k}); end
    s.I=p.tensor; s.p_ref=p.p_ref*pi/180; s.q_ref=p.q_ref*pi/180; s.r_ref=p.r_ref*pi/180;
    for name={'gyro','accel'}
        key=name{1}; sensor=c.(key);
        s.(key).sample_rate=sensor.sample_rate; s.(key).noise_density=sensor.density;
        s.(key).BW=sensor.bandwidth; s.(key).bias=sensor.bias(:); s.(key).vibration=sensor.vibration;
    end
    v=hover.buildVariables(s);
    model='hover_plant_sil'; if strcmp(c.fidelity,'low'), model='hover_linear_sil'; end
    load_system(fullfile(root,'DesktopSIL','model',[model '.slx']));
    input=Simulink.SimulationInput(model);
    names=fieldnames(v);
    for k=1:numel(names), input=input.setVariable(names{k},v.(names{k}),'Workspace',model); end
    input=input.setVariable('sil_gyro_noise_power',ones(3,1)*(v.gyro.noise_density*pi/180)^2*v.gyro.BW,'Workspace',model);
    input=input.setVariable('sil_accel_noise_power',ones(3,1)*(v.accel.noise_density*v.g)^2*v.accel.BW,'Workspace',model);
    input=input.setExternalInput([0 3 -2 1 4;1 3 -2 1 4]);
    input=input.setModelParameter('StopTime','1');
    if strcmp(cases(index).tag,'high_flexible_rates'), input=input.setModelParameter('FixedStep',num2str(1/48000,17)); end
    simulation=sim(input); native=readmatrix(cases(index).output); values=[];
    for k=1:6
        ts=simulation.yout.get(k).Values; data=ts.Data;
        if ~ts.IsTimeFirst, data=permute(data,[ndims(data) 1:ndims(data)-1]); end
        values=[values interp1(round(ts.Time*1e12),reshape(data,numel(ts.Time),[]),round(native(:,1)*1e12),'previous')]; %#ok<AGROW>
    end
    error=max(abs(values-native(:,2:end)),[],'all');
    assert(error<1e-8,'Runtime plant %s differs from Simulink by %.12g',cases(index).tag,error);
    report(end+1)=struct('Case',cases(index).tag,'MaximumAbsoluteError',error,'Samples',height(native),'Passed',true); %#ok<AGROW>
    fprintf('%s: %d samples, maximum absolute error %.4g\n',cases(index).tag,height(native),error);
end
f=fopen(fullfile(folder,'runtime_plant_equivalence.json'),'w'); cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s\n',jsonencode(report,PrettyPrint=true));
end
