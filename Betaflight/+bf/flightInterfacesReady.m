function ready=flightInterfacesReady()
%FLIGHTINTERFACESREADY Inspect whether the prepared sensor upgrade is installed.
% Read only: neither the model nor its parameters are saved or changed.
p=bf.paths(); model='lin_hover_sim';
load_system(fullfile(fileparts(p.Root),'1_Hover Simulation Work',[model '.slx']));
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',[model '/MATLAB Function']);
ready=isscalar(chart) && contains(chart.Script,'bf.idealImu') ...
    && strcmp(get_param([model '/Lin vs NonLin Dynamics/Non Linear Simulation/Constant3'],'Value'),'S') ...
    && strcmp(get_param([model '/Gyro Model/Gyro Sample Rate'],'SampleTime'),'1/gyro.sample_rate');
end
