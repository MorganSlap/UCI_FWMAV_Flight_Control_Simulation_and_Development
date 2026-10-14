classdef PlantCheck < handle
    %PLANTCHECK Nonblocking plant verification with results saved on completion.
    % check=bf.PlantCheck('high',10); inspect check.Status and check.Report.
    properties (SetAccess=private)
        Status = 'starting'
        Simulation
        Settings
        Variables
        Report = struct()
        Error = ''
    end
    properties (Access=private)
        Listener
        Started
        Finishing = false
    end
    methods
        function obj=PlantCheck(fidelity,duration)
            if nargin<1, fidelity='high'; end
            if nargin<2, duration=10; end
            p=bf.paths(); folder=fullfile(fileparts(p.Root),'1_Hover Simulation Work');
            addpath(fullfile(folder,'HoverWorkbench'));
            obj.Settings=hover.defaultSettings();
            obj.Settings.sim_fidelity=fidelity; obj.Settings.t_sim=duration;
            [input,obj.Variables]=hover.makeSimulationInput(obj.Settings,fullfile(folder,'lin_hover_sim.slx'));
            obj.Simulation=simulation(input);
            obj.Listener=addlistener(obj.Simulation,'SimulationStatusChanged',@(~,event)obj.changed(event));
            obj.Started=tic;
            start(obj.Simulation);
        end
        function delete(obj)
            if ~isempty(obj.Listener), delete(obj.Listener); end
        end
    end
    methods (Access=private)
        function changed(obj,event)
            obj.Status=char(string(event.NewStatus));
            if ~strcmpi(obj.Status,'inactive') || obj.Finishing, return; end
            obj.Finishing=true;
            try
                output=obj.Simulation.SimulationOutput;
                assert(isempty(output.ErrorMessage),'bf:SimulationFailed','%s',output.ErrorMessage);
                state=squeeze(output.state_output.signals.values);
                diagnostic=squeeze(output.betaflight_diagnostics.signals.values)';
                assert(size(state,2)==12 && size(diagnostic,2)==40,'Output shape mismatch.');
                assert(all(isfinite(state),'all') && all(isfinite(diagnostic),'all'),'Nonfinite output.');
                assert(all(diagnostic(:,31)==1),'Firmware unexpectedly disarmed.');
                assert(all(diagnostic(:,34)==250) && all(diagnostic(:,35)==1e6*obj.Variables.bfSim.PidSampleTime),'Firmware loop period mismatch.');
                assert(all(diagnostic(:,36)==4),'Motor count mismatch.');
                assert(all(diagnostic(:,6:9)>=1000 & diagnostic(:,6:9)<=1950,'all'),'Motor bounds failed.');
                assert(abs(output.tout(end)-obj.Settings.t_sim)<1e-9,'Run ended early.');
                peak=max(abs(state(:,7:9)),[],1)*180/pi;
                obj.Report=struct('Fidelity',obj.Settings.sim_fidelity,'SimulatedSeconds',output.tout(end), ...
                    'WallSeconds',toc(obj.Started),'Samples',size(diagnostic,1),'InterfacePassed',true, ...
                    'HoverStable',all(peak(1:2)<30),'PeakEulerDegrees',peak, ...
                    'FinalEulerDegrees',state(end,7:9)*180/pi);
                folder=fullfile(bf.paths().Root,'test-output');
                record=hover.saveRun(fullfile(folder,'runs'),obj.Settings,obj.Variables,output, ...
                    struct('Label',['Betaflight validation - ' obj.Settings.sim_fidelity],'Verification',obj.Report));
                loaded=hover.loadRun(record.Folder);
                assert(isequal(loaded.Settings.Betaflight,obj.Settings.Betaflight),'Saved firmware settings differ.');
                obj.Report.RunFolder=record.Folder;
                obj.Report.SignalCount=numel(loaded.Signals);
                writelines(jsonencode(obj.Report,PrettyPrint=true),fullfile(folder,['plant-' obj.Settings.sim_fidelity '.json']));
                assert(obj.Report.HoverStable,'bf:UnstablePreset','Hover preset exceeded 30 degrees roll/pitch.');
                obj.Status='passed';
            catch exception
                obj.Status='failed'; obj.Error=getReport(exception,'extended','hyperlinks','off');
                folder=fullfile(bf.paths().Root,'test-output');
                if ~isfolder(folder), mkdir(folder); end
                writelines(obj.Error,fullfile(folder,['plant-' obj.Settings.sim_fidelity '-error.txt']));
            end
        end
    end
end
