classdef HoverWorkbenchController < handle
    %HOVERWORKBENCHCONTROLLER UI behavior for the App Designer workbench.
    % Settings, storage, and signal transforms live in the +hover package.
    properties
        App
        Settings
        Schema
        DataRoot
        ActiveRecord = []
        Runs = []
        Busy = false
        Simulation = []
        SimulationListener = []
        PollTimer = []
        LastError = ''
        LastAnalysisError = ''
        RunSettings
        RunVariables
        RunMetadata
        StopRequested = false
        DefaultAxes
        PlotCount = 0
        ParameterEditors
        UI = struct()
        FirmwareEditor = []
        FlightExampleKind = 'hover'
    end
    properties (Access = private)
        RunStarted
        Completing = false
        FigureListener = []
        Disposing = false
        Loading = false
        Plotting = false
        FirmwareSchema
    end
    methods
        function obj = HoverWorkbenchController(app)
            obj.App = app;
            % AppBase.delete deletes the figure without CloseRequestFcn.
            % Release timers, saved arrays and native processes on either path.
            obj.FigureListener=addlistener(app.UIFigure,'ObjectBeingDestroyed',@(~,~)delete(obj));
            obj.Settings = hover.hoverExample();
            obj.FirmwareSchema=bf.parseCliSettings(obj.Settings.Betaflight.SchemaText);
            obj.Schema = hover.settingsSchema();
            % The native firmware replaces these legacy controller settings.
            oldKeys={'mahoney.Kp','mahoney.Ki','accel.LPF_set','gyro.LPF_set','roll_P','roll_I','roll_D', ...
                'pitch_P','pitch_I','pitch_D','yaw_P','yaw_I','yaw_D','strength','MMA','max_pot','fs', ...
                'use_time_constant_damping','tau_p','tau_q','tau_r'};
            if ~bf.flightInterfacesReady()
                % The prepared upgrade exposes these fixed sensor values.
                % Do not display ineffective editors before it is installed.
                oldKeys=[oldKeys,{'accel.sample_rate','accel.noise_density','accel.bias','accel.vibration', ...
                    'gyro.sample_rate','gyro.noise_density','gyro.bias','gyro.vibration'}];
            end
            obj.Schema=obj.Schema(~ismember({obj.Schema.Key},oldKeys));
            obj.Schema=[hover.nativeAttitudeSchema(),hover.nativeGyroSchema(obj.Settings.Betaflight),obj.Schema];
            obj.DataRoot = fullfile(fileparts(mfilename('fullpath')), 'data');
            if ~isfolder(obj.DataRoot), mkdir(obj.DataRoot); end
            obj.ParameterEditors = containers.Map('KeyType','char','ValueType','any');
            obj.buildHeader();
            obj.buildSettings();
            obj.buildDefaultPlots();
            obj.buildExplorer();
            obj.buildFlightAnalysis();
            obj.refreshLibrary();
            obj.renderSettings();
            obj.PollTimer = timer('ExecutionMode','fixedSpacing','Period',0.3, ...
                'BusyMode','drop','Name','HoverWorkbenchProgress', ...
                'TimerFcn',@(~,~)obj.pollProgress());
            controls=findall(app.UIFigure,'-property','Interruptible');
            set(controls,'Interruptible','off','BusyAction','cancel');
        end

        function buildHeader(obj)
            g = uigridlayout(obj.App.HeaderPanel,[3 6]);
            g.ColumnWidth = {'1x',220,170,165,120,80};
            g.RowHeight={12,36,12}; g.RowSpacing=0; g.Padding = [0 0 0 0];
            titleGrid = uigridlayout(g,[2 1]);
            titleGrid.Layout.Row=[1 3]; titleGrid.Layout.Column=1;
            titleGrid.RowHeight = {32,22}; titleGrid.Padding = [0 0 0 0];
            uilabel(titleGrid,'Text','HOVER WORKBENCH','FontSize',24,'FontWeight','bold');
            uilabel(titleGrid,'Text','Configure flight. Capture results. Compare runs.','FontSize',12);
            obj.UI.RunLabel = uieditfield(g,'text','Value','IMU-only trimmed hover', ...
                'Placeholder','Name this run','Tooltip','A descriptive label for the saved run');
            obj.UI.RunLabel.Layout.Row=2; obj.UI.RunLabel.Layout.Column=2;
            obj.UI.Noise=uicheckbox(g,'Text','Simulated noise: ON', ...
                'Value',logical(obj.Settings.noise_true),'FontWeight','bold', ...
                'Tooltip','Enable the existing sensor noise, bias, vibration and actuator-noise model. Saved with every preset and run.', ...
                'ValueChangedFcn',@(src,~)obj.editSetting('noise_true',logical(src.Value)));
            obj.UI.Noise.Layout.Row=2; obj.UI.Noise.Layout.Column=3;
            obj.UI.DefaultPlots = uicheckbox(g,'Text','Show default plots','Value',true, ...
                'ValueChangedFcn',@(~,~)obj.toggleDefaults());
            obj.UI.DefaultPlots.Layout.Row=2; obj.UI.DefaultPlots.Layout.Column=4;
            obj.UI.Run = uibutton(g,'Text','Run simulation','FontWeight','bold', ...
                'ButtonPushedFcn',@(~,~)obj.startRun());
            obj.UI.Run.Layout.Row=2; obj.UI.Run.Layout.Column=5;
            obj.UI.Stop = uibutton(g,'Text','Stop','Enable','off', ...
                'ButtonPushedFcn',@(~,~)obj.stopRun());
            obj.UI.Stop.Layout.Row=2; obj.UI.Stop.Layout.Column=6;
        end

        function buildSettings(obj)
            g = uigridlayout(obj.App.SettingsTab,[1 2]);
            g.ColumnWidth = {235,'1x'}; g.Padding = [16 16 16 16]; g.ColumnSpacing = 20;
            side = uigridlayout(g,[10 1]);
            side.RowHeight = {28,38,32,'1x',32,32,32,32,42,80}; side.Padding = [0 0 0 0];
            uilabel(side,'Text','SIMULATION SETTINGS','FontWeight','bold');
            obj.UI.Firmware=uibutton(side,'Text','BETAFLIGHT CONFIGURATOR', ...
                'BackgroundColor',[1 0.72 0.12],'FontColor',[0.08 0.09 0.11], ...
                'FontWeight','bold','ButtonPushedFcn',@(~,~)obj.openFirmware());
            obj.UI.SearchSettings = uieditfield(side,'text','Placeholder','Find a parameter...', ...
                'ValueChangedFcn',@(~,~)obj.renderSettings());
            groups = unique(string({obj.Schema.Group}),'stable');
            groups(groups=="Simulation")=[];
            obj.UI.Groups = uilistbox(side,'Items',cellstr(["Run setup","Firmware interface","Receiver channels",groups,"Derived values"]), ...
                'ValueChangedFcn',@(~,~)obj.renderSettings());
            uibutton(side,'Text','Save preset...','ButtonPushedFcn',@(~,~)obj.savePreset());
            uibutton(side,'Text','Load preset...','ButtonPushedFcn',@(~,~)obj.loadPreset());
            uibutton(side,'Text','Load hover example','ButtonPushedFcn',@(~,~)obj.loadHoverExample());
            uibutton(side,'Text','Reset to script defaults','ButtonPushedFcn',@(~,~)obj.resetSettings());
            obj.UI.PresetStatus = uilabel(side,'Text','Level hover: IMU only, fixed throttle, noise ON','WordWrap','on');
            uilabel(side,'Text',sprintf(['Inputs are saved with every run.\n' ...
                'Open Betaflight Configurator for PID, filters, rates, modes and mixer settings.']), ...
                'WordWrap','on','FontSize',11);
            main = uigridlayout(g,[4 1]);
            main.RowHeight = {32,42,'1x',66}; main.Padding = [0 0 0 0];
            obj.UI.GroupTitle = uilabel(main,'Text','Settings','FontSize',21,'FontWeight','bold');
            obj.UI.GroupHelp = uilabel(main,'Text','Edit values below. Hover over any field for details.', ...
                'WordWrap','on');
            obj.UI.EditorPanel = uipanel(main,'BorderType','none','Scrollable','on');
            obj.UI.Notes = uitextarea(main,'Placeholder','Run notes (saved with the results)');
        end

        function loadHoverExample(obj)
            if obj.Busy, return; end
            obj.Settings=hover.hoverExample();
            obj.UI.RunLabel.Value='IMU-only trimmed hover';
            obj.syncFirmwareEditor(); obj.renderSettings();
            obj.UI.PresetStatus.Text='Level hover: IMU only, fixed throttle, noise ON';
        end

        function openFirmware(obj)
            if obj.Busy, return; end
            if ~isfield(obj.Settings,'Betaflight'), obj.Settings.Betaflight=bf.hoverConfig(obj.Settings.max_pot); end
            if ~isempty(obj.FirmwareEditor) && isvalid(obj.FirmwareEditor)
                delete(obj.FirmwareEditor);
            end
            obj.FirmwareEditor=bf.Configurator(obj.Settings.Betaflight);
            obj.FirmwareEditor.AppliedFcn=@(config)obj.applyFirmware(config);
        end

        function applyFirmware(obj,config)
            obj.FirmwareSchema=bf.parseCliSettings(config.SchemaText);
            obj.Settings.Betaflight=config;
            obj.renderSettings();
            obj.UI.PresetStatus.Text='Modified Betaflight configuration';
        end

        function syncFirmwareEditor(obj)
            obj.FirmwareSchema=bf.parseCliSettings(obj.Settings.Betaflight.SchemaText);
            if ~isempty(obj.FirmwareEditor) && isvalid(obj.FirmwareEditor)
                if isfield(obj.Settings,'Betaflight'), config=obj.Settings.Betaflight;
                else, config=bf.hoverConfig(obj.Settings.max_pot); end
                obj.FirmwareEditor.setConfiguration(config);
            end
        end

        function renderSettings(obj)
            % The workbench now exposes reference-speed drag only. Retain the
            % legacy fields in the file format for old script consumers.
            obj.Settings.use_time_constant_damping=false;
            obj.syncNoiseControl();
            delete(obj.UI.EditorPanel.Children);
            obj.ParameterEditors = containers.Map('KeyType','char','ValueType','any');
            group = string(obj.UI.Groups.Value);
            query = lower(string(obj.UI.SearchSettings.Value));
            obj.UI.GroupTitle.Text = char(group);
            if group == "Firmware interface" && strlength(query)==0
                obj.renderFirmwareInterface(); return
            end
            if group == "Receiver channels" && strlength(query)==0
                obj.renderReceiverChannels(); return
            end
            if group == "Run setup" && strlength(query)==0
                obj.renderFlightTest(); return
            end
            if group == "Derived values" && strlength(query)==0
                obj.renderDerived(); return
            end
            sel = string({obj.Schema.Group})==group;
            if strlength(query)>0
                sel = contains(lower(string({obj.Schema.Label})),query) | ...
                    contains(lower(string({obj.Schema.Key})),query);
                obj.UI.GroupTitle.Text = 'Search results';
            end
            entries = obj.Schema(sel);
            obj.UI.GroupHelp.Text = 'Edit values below. Hover over a field for its variable name and explanation.';
            if group=="Attitude estimator" && strlength(query)==0
                obj.UI.GroupHelp.Text=['These controls edit the actual Betaflight configuration. ' ...
                    'Kp/Ki are shown as physical gains; the native CLI stores gain times 10000.'];
            elseif group=="Sensors and estimator" && strlength(query)==0
                obj.renderSensors(); return
            end
            obj.renderFields(obj.UI.EditorPanel,entries);
        end

        function renderFields(obj,parent,entries)
            n = numel(entries);
            heights = repmat({36},1,n+1); heights{end}='1x';
            for k=1:n
                if strcmp(entries(k).Kind,'matrix'), heights{k}=max(138,32+25*size(entries(k).Default,1)); end
            end
            g = uigridlayout(parent,[n+1 3]);
            g.RowHeight = heights; g.ColumnWidth = {'1.5x','1x',85};
            g.Padding = [0 6 14 6]; g.RowSpacing = 12; g.Scrollable = 'on';
            for k=1:n
                e = entries(k); key = char(e.Key); value = obj.getSetting(key);
                label = uilabel(g,'Text',char(e.Label),'WordWrap','on');
                label.Layout.Row=k; label.Layout.Column=1;
                tip = sprintf('%s\n%s',key,char(e.Help)); label.Tooltip=tip;
                switch char(e.Kind)
                    case 'logical'
                        control = uicheckbox(g,'Text','Enabled','Value',logical(value), ...
                            'ValueChangedFcn',@(src,~)obj.editSetting(key,src.Value));
                    case 'choice'
                        control = uidropdown(g,'Items',cellstr(string(e.Choices)), ...
                            'Value',char(string(value)), ...
                            'ValueChangedFcn',@(src,~)obj.editSetting(key,src.Value));
                        if strcmp(key,'sim_fidelity')
                            control.ItemsData={'high','low'};
                            control.Items={'Nonlinear dynamics','Linearized hover'};
                            control.Value=char(string(value));
                        end
                    case 'matrix'
                        control = uitable(g,'Data',value,'ColumnEditable',true(1,size(value,2)), ...
                            'CellEditCallback',@(src,ev)obj.editMatrix(key,src,ev));
                        if any(strcmp(key,{'X0','Xref'}))
                            control.RowName={'x [m]','y [m]','z down [m]','u [m/s]','v [m/s]', ...
                                'w [m/s]','roll [rad]','pitch [rad]','yaw [rad]', ...
                                'p [rad/s]','q [rad/s]','r [rad/s]'};
                            control.ColumnName={'Value'};
                        elseif strcmp(key,'I')
                            control.RowName={'x','y','z'}; control.ColumnName={'x','y','z'};
                        end
                    otherwise
                        control = uieditfield(g,'numeric','Value',double(value), ...
                            'ValueDisplayFormat','%.9g', ...
                            'ValueChangedFcn',@(src,~)obj.editSetting(key,src.Value));
                end
                control.Layout.Row=k; control.Layout.Column=2; control.Tooltip=tip;
                if obj.Busy, control.Enable='off'; end
                unit = uilabel(g,'Text',char(e.Unit),'WordWrap','on');
                unit.Layout.Row=k; unit.Layout.Column=3;
                obj.ParameterEditors(key)=control;
            end
            if n==0, uilabel(g,'Text','No matching parameters.'); end
        end

        function renderSensors(obj)
            obj.UI.GroupHelp.Text=['Sensor models and the actual firmware filters. Raw IMU channels in Explore are measured before firmware filters. ' ...
                'Static gyro cutoff applies when dynamic filtering is disabled (minimum = 0).'];
            g=uigridlayout(obj.UI.EditorPanel,[1 2]); g.ColumnWidth={'1x','1x'};
            g.RowHeight={920}; g.Scrollable='on'; g.Padding=[0 8 14 8];
            gyroPanel=uipanel(g,'Title','GYROSCOPE  |  angular velocity','FontWeight','bold');
            accelPanel=uipanel(g,'Title','ACCELEROMETER  |  specific force','FontWeight','bold');
            keys=string({obj.Schema.Key});
            obj.renderFields(gyroPanel,obj.Schema(startsWith(keys,'gyro.') | startsWith(keys,'firmware.')));
            obj.renderFields(accelPanel,obj.Schema(startsWith(keys,'accel.') | keys=="native.acc_lpf_hz"));
        end

        function renderDerived(obj)
            obj.UI.GroupHelp.Text = ['Read-only values computed from your inputs. ' ...
                'The initialization script formulas are preserved.'];
            g=uigridlayout(obj.UI.EditorPanel,[1 1]); g.Padding=[0 0 0 0];
            try
                v=hover.buildVariables(obj.Settings);
                rows=obj.flatten(v,'');
                uitable(g,'Data',rows,'ColumnName',{'Variable','Computed value'}, ...
                    'ColumnWidth',{220,'auto'},'RowName',{});
            catch err
                uilabel(g,'Text',err.message,'WordWrap','on');
            end
        end

        function renderFirmwareInterface(obj)
            obj.UI.GroupHelp.Text=['Configure the simulated receiver and startup. ' ...
                'Use Betaflight Configurator for the flight software itself.'];
            v=hover.buildVariables(obj.Settings);
            g=uigridlayout(obj.UI.EditorPanel,[11 3]); g.ColumnWidth={240,'1x',150};
            g.RowHeight={40,40,40,40,40,40,50,40,40,90,40}; g.Padding=[8 8 16 8];
            labels={'Command source','Receiver update rate','Calibration warmup','Arming settle time','Throttle settling before release','Throttle receiver pulse','Ideal bench accel calibration'};
            keys={'CommandMode','RcRateHz','WarmupSeconds','ArmSettleSeconds','SpoolupSeconds','ThrottlePWM','UseKnownAccelCalibration'};
            units={'','Hz','s','s','s','microseconds','Known simulated bias'};
            for k=1:7
                key=keys{k}; uilabel(g,'Text',labels{k},'WordWrap','on');
                if k==1
                    control=uidropdown(g,'Items',{'Angle reference','Rate reference','Raw receiver'}, ...
                        'ItemsData',{'angle','rate','receiver'},'Value',v.bfSim.CommandMode, ...
                        'ValueChangedFcn',@(src,~)obj.editAdapter(key,src.Value));
                elseif strcmp(key,'UseKnownAccelCalibration')
                    control=uicheckbox(g,'Text','Use simulated sensor bias','Value',logical(v.bfSim.(key)), ...
                        'Tooltip','Sets native acc_calibration from the configured simulated bias (zero when noise is off). Disable to use the Configurator CLI offsets. Effective offsets are saved in Variables.bfConfig.', ...
                        'ValueChangedFcn',@(src,~)obj.editAdapter(key,logical(src.Value)));
                else
                    value=v.bfSim.(key);
                    if strcmp(key,'ThrottlePWM') && ~isempty(v.bfSim.ReceiverPWM)
                        value=v.bfSim.ReceiverPWM(v.bfSim.ReceiverLayout.Throttle);
                    end
                    control=uieditfield(g,'numeric','Value',value, ...
                        'ValueChangedFcn',@(src,~)obj.editAdapter(key,src.Value));
                    if strcmp(key,'ThrottlePWM') && ~isempty(v.bfSim.ReceiverPWM)
                        control.Enable='off'; control.Tooltip='Custom value from the Receiver channels page. Edit it there, or restore automatic channel values.';
                    end
                end
                if obj.Busy, control.Enable='off'; end
                uilabel(g,'Text',units{k});
            end
            uilabel(g,'Text','Gyro / sensor sampling');
            uilabel(g,'Text','4000 Hz','FontWeight','bold');
            uilabel(g,'Text','Fixed by SITL build');
            uilabel(g,'Text','PID and mixer frequency');
            divider=round(4000*v.bfSim.PidSampleTime);
            obj.UI.PidDivider=uidropdown(g,'Items',cellstr(compose('%.4g Hz (divide by %d)',4000./(1:16)',(1:16)')), ...
                'ItemsData',1:16,'Value',divider, ...
                'ValueChangedFcn',@(src,~)obj.editPidDivider(src.Value));
            if obj.Busy, obj.UI.PidDivider.Enable='off'; end
            uilabel(g,'Text','Native firmware rate');
            note=uilabel(g,'Text',['Angle mode uses Xref roll/pitch angles and yaw rate. Rate mode uses Xref body rates. ' ...
                'Raw receiver uses the Receiver channels page and configured channel map. Throttle is fixed: no altitude feedback. ' ...
                'Re-trim after changing the plant or motor settings. Native gyro calibration uses sensor-rate white noise and the configured noise seed; its duration is gyro_calib_duration in the Configurator. ' ...
                'Ideal bench calibration overrides CLI accelerometer offsets using the simulated bias; it is not an estimated in-flight correction.'], ...
                'WordWrap','on'); note.Layout.Row=10; note.Layout.Column=[1 3];
            reset=uibutton(g,'Text','Restore automatic receiver / startup defaults', ...
                'ButtonPushedFcn',@(~,~)obj.resetAdapter()); reset.Layout.Row=11; reset.Layout.Column=[1 3];
        end

        function editPidDivider(obj,divider)
            if obj.Busy, return; end
            config=obj.Settings.Betaflight;
            schema=bf.parseCliSettings(config.SchemaText);
            item=schema(strcmp({schema.Name},'pid_process_denom'));
            obj.Settings.Betaflight=bf.setSetting(config,item(1),sprintf('%d',divider));
            obj.syncFirmwareEditor(); obj.renderSettings();
            obj.UI.PresetStatus.Text='Modified native PID/mixer frequency';
        end

        function renderReceiverChannels(obj)
            obj.UI.GroupHelp.Text=['Set physical receiver pulses in microseconds. Custom AUX pulses support native AND/OR and linked modes. ' ...
                'Keep ARM off during calibration. Stick pulses are used in Raw receiver mode; AUX and throttle apply in every mode.'];
            v=hover.buildVariables(obj.Settings); layout=v.bfSim.ReceiverLayout;
            labels=compose("CH %d",1:16);
            labels(layout.Roll)="Roll"; labels(layout.Pitch)="Pitch";
            labels(layout.Throttle)="Throttle"; labels(layout.Yaw)="Yaw";
            labels(layout.Arm)=labels(layout.Arm)+" / ARM";
            if ~isempty(layout.Angle), labels(layout.Angle)=labels(layout.Angle)+" / ANGLE"; end
            g=uigridlayout(obj.UI.EditorPanel,[3 1]); g.RowHeight={42,'1x',40}; g.Padding=[8 8 16 8];
            if isempty(v.bfSim.ReceiverPWM) && isempty(v.bfSim.StartupReceiverPWM)
                state='Automatic values from channel map, endpoints and mode ranges. Edit a cell to customize.';
            else
                state='Custom channel values. These pulses are saved with the preset and each run.';
            end
            obj.UI.ReceiverStatus=uilabel(g,'Text',state,'WordWrap','on');
            obj.UI.ReceiverPulses=uitable(g,'Data',[bf.startupChannels(v.bfSim,false),bf.receiverChannels(v.bfSim)], ...
                'RowName',cellstr(labels),'ColumnName',{'Calibration / disarmed','Armed / simulation'}, ...
                'ColumnEditable',repmat(~obj.Busy,1,2),'ColumnFormat',{'bank','bank'}, ...
                'CellEditCallback',@(src,event)obj.editReceiverPulses(src,event));
            obj.UI.ReceiverPulses.Tooltip='Arming settle uses the simulation column with throttle held at its calibrated minimum.';
            reset=uibutton(g,'Text','Restore automatic channel values', ...
                'ButtonPushedFcn',@(~,~)obj.resetReceiverPulses());
            if obj.Busy, reset.Enable='off'; end
        end

        function editReceiverPulses(obj,source,event)
            if obj.Busy, return; end
            try
                candidate=obj.Settings;
                candidate.FirmwareAdapter.StartupReceiverPWM=source.Data(:,1);
                candidate.FirmwareAdapter.ReceiverPWM=source.Data(:,2);
                hover.buildVariables(candidate);
                obj.Settings=candidate;
                obj.UI.ReceiverStatus.Text='Custom channel values. These pulses are saved with the preset and each run.';
                obj.UI.PresetStatus.Text='Modified receiver channels';
            catch err
                source.Data(event.Indices(1),event.Indices(2))=event.PreviousData;
                uialert(obj.App.UIFigure,err.message,'Invalid receiver pulse');
            end
        end

        function resetReceiverPulses(obj)
            if obj.Busy, return; end
            fields=intersect(fieldnames(obj.Settings.FirmwareAdapter),{'ReceiverPWM','StartupReceiverPWM'});
            obj.Settings.FirmwareAdapter=rmfield(obj.Settings.FirmwareAdapter,fields);
            obj.renderSettings(); obj.UI.PresetStatus.Text='Automatic receiver channels';
        end

        function editAdapter(obj,key,value)
            if obj.Busy, return; end
            candidate=obj.Settings; candidate.FirmwareAdapter.(key)=value;
            try
                hover.buildVariables(candidate);
                obj.Settings=candidate;
                obj.UI.PresetStatus.Text='Modified firmware interface';
            catch err
                obj.renderSettings(); obj.showError(err.message);
            end
        end

        function renderFlightTest(obj)
            obj.UI.GroupHelp.Text=['Choose a complete case, then adjust duration, fidelity, noise, drag, flight mode and throttle here. ' ...
                'Initial conditions and constant references have their own pages.'];
            v=hover.buildVariables(obj.Settings); mode=v.bfSim.CommandMode;
            g=uigridlayout(obj.UI.EditorPanel,[8 1]);
            g.RowHeight={42,170,44,48,30,180,36,72}; g.Padding=[8 8 16 8]; g.Scrollable='on';
            bar=uigridlayout(g,[1 2]); bar.ColumnWidth={'1x',200}; bar.Padding=[0 0 0 0];
            obj.UI.Example=uidropdown(bar,'Items',{'Noisy level hover','Noisy attitude recovery', ...
                'Angle pulses: roll then pitch','Rate doublets: roll then pitch'}, ...
                'ItemsData',{'hover','recovery','angle','rate'},'Value',obj.FlightExampleKind, ...
                'ValueChangedFcn',@(src,~)obj.selectFlightExample(src.Value));
            loadButton=uibutton(bar,'Text','Load complete example', ...
                'Tooltip','Replaces plant, firmware, startup and command settings with the selected 10-second example.', ...
                'ButtonPushedFcn',@(~,~)obj.loadFlightExample(obj.UI.Example.Value));
            cards=uigridlayout(g,[1 2]); cards.Padding=[0 0 0 0];
            timing=uipanel(cards,'Title','SIMULATION','FontWeight','bold');
            inputs=uipanel(cards,'Title','NOISE & AERODYNAMICS','FontWeight','bold');
            keys=string({obj.Schema.Key});
            obj.renderFields(timing,obj.Schema(ismember(keys,["t_sim","sim_fidelity"])));
            obj.renderFields(inputs,obj.Schema(ismember(keys,["noise_true","seed","drag_enabled"])));
            flight=uigridlayout(g,[1 4]); flight.ColumnWidth={100,'1x',100,'1x'}; flight.Padding=[0 0 0 0];
            uilabel(flight,'Text','Flight mode');
            modeControl=uidropdown(flight,'Items',{'angle','rate','receiver'},'Value',mode, ...
                'ValueChangedFcn',@(src,~)obj.editRunAdapter('CommandMode',src.Value));
            uilabel(flight,'Text','Throttle [us]');
            throttle=uieditfield(flight,'numeric','Value',v.bfSim.ThrottlePWM,'Limits',[1000 2000], ...
                'ValueChangedFcn',@(src,~)obj.editRunAdapter('ThrottlePWM',src.Value));
            uilabel(g,'Text',sprintf('Current source: %s | Run length: %.4g s | Fixed throttle: %.4g us', ...
                upper(mode),obj.Settings.t_sim,v.bfSim.ThrottlePWM),'WordWrap','on','FontWeight','bold');
            uilabel(g,'Text','COMMAND SEQUENCE  /  each row holds until the next time','FontWeight','bold');
            data=v.bfSim.ReferenceSchedule;
            if isempty(data), data=zeros(0,4); end
            data(:,2:4)=data(:,2:4)*180/pi;
            if strcmp(mode,'angle'), columns={'Time [s]','Roll [deg]','Pitch [deg]','Yaw rate [deg/s]'};
            else, columns={'Time [s]','Roll rate [deg/s]','Pitch rate [deg/s]','Yaw rate [deg/s]'}; end
            obj.UI.Sequence=uitable(g,'Data',data,'ColumnName',columns,'RowName',{}, ...
                'ColumnEditable',true(1,4),'ColumnFormat',{'numeric','numeric','numeric','numeric'}, ...
                'CellEditCallback',@(src,~)obj.editSequence(src.Data));
            buttons=uigridlayout(g,[1 3]); buttons.Padding=[0 0 0 0];
            add=uibutton(buttons,'Text','Add command','ButtonPushedFcn',@(~,~)obj.appendCommand());
            remove=uibutton(buttons,'Text','Remove last','ButtonPushedFcn',@(~,~)obj.removeCommand());
            clearButton=uibutton(buttons,'Text','Use constant Xref','ButtonPushedFcn',@(~,~)obj.editSequence(zeros(0,4)));
            uilabel(g,'Text',['Times start at plant release, after calibration and arming. Before the first row, Xref applies. ' ...
                'Commands are held, not interpolated, and accepted on receiver frames. Empty table uses Xref throughout. ' ...
                'Change source on Firmware interface. No altitude feedback; the default plant has no yaw control authority.'], ...
                'WordWrap','on');
            controls={obj.UI.Example,loadButton,obj.UI.Sequence,add,remove,clearButton,modeControl,throttle};
            for k=1:numel(controls)
                obj.ParameterEditors(sprintf('flightTest%d',k))=controls{k};
                if obj.Busy, controls{k}.Enable='off'; end
            end
        end

        function editRunAdapter(obj,key,value)
            obj.editAdapter(key,value); obj.renderSettings();
        end

        function loadFlightExample(obj,kind)
            if obj.Busy, return; end
            obj.FlightExampleKind=kind;
            obj.Settings=hover.flightExample(kind);
            labels=struct('hover','IMU-only trimmed hover','recovery','Noisy attitude recovery', ...
                'angle','Angle pulses','rate','Rate doublets');
            obj.UI.RunLabel.Value=labels.(kind);
            obj.syncFirmwareEditor(); obj.renderSettings();
            obj.UI.PresetStatus.Text=['Loaded complete example: ' labels.(kind)];
        end

        function selectFlightExample(obj,kind)
            obj.FlightExampleKind=kind;
        end

        function editSequence(obj,data)
            if obj.Busy, return; end
            candidate=obj.Settings;
            data(:,2:4)=data(:,2:4)*pi/180;
            candidate.FirmwareAdapter.ReferenceSchedule=data;
            try
                hover.buildVariables(candidate);
                obj.Settings=candidate; obj.renderSettings();
                obj.UI.PresetStatus.Text='Modified flight command sequence';
            catch err
                obj.renderSettings(); obj.showError(err.message);
            end
        end

        function appendCommand(obj)
            if obj.Busy, return; end
            data=obj.UI.Sequence.Data;
            if isempty(data), data=[0 0 0 0];
            else, data(end+1,:)=[data(end,1)+1 data(end,2:4)]; end
            obj.editSequence(data);
        end

        function removeCommand(obj)
            if obj.Busy, return; end
            data=obj.UI.Sequence.Data;
            if ~isempty(data), data(end,:)=[]; end
            obj.editSequence(data);
        end

        function resetAdapter(obj)
            if obj.Busy, return; end
            obj.Settings.FirmwareAdapter=struct(); obj.renderSettings();
        end

        function editSetting(obj,key,value)
            if obj.Busy, return; end
            if startsWith(key,'firmware.')
                try
                    schema=obj.FirmwareSchema;
                    item=schema(strcmp({schema.Name},extractAfter(key,'firmware.')));
                    obj.Settings.Betaflight=bf.setSetting(obj.Settings.Betaflight,item(1),value,0);
                    obj.syncFirmwareEditor(); obj.renderSettings();
                    obj.UI.PresetStatus.Text='Modified native gyro filter';
                catch err
                    obj.renderSettings(); obj.showError(err.message);
                end
                return
            end
            if startsWith(key,'native.')
                try
                    [~,config]=hover.nativeAttitudeValue(obj.Settings.Betaflight,extractAfter(key,'native.'),value);
                    obj.Settings.Betaflight=config;
                    obj.syncFirmwareEditor(); obj.renderSettings();
                    obj.UI.PresetStatus.Text='Modified native attitude-estimator settings';
                    obj.setStatus('Native firmware configuration updated. Run to capture a new result.');
                catch err
                    obj.renderSettings(); obj.showError(err.message);
                end
                return
            end
            parts=strsplit(key,'.');
            if numel(parts)==1
                obj.Settings.(parts{1})=value;
            else
                obj.Settings.(parts{1}).(parts{2})=value;
            end
            if strcmp(key,'noise_true')
                obj.syncNoiseControl();
                if obj.ParameterEditors.isKey(key)
                    control=obj.ParameterEditors(key);
                    control.Value=logical(value);
                end
            end
            obj.UI.PresetStatus.Text='Modified settings';
            obj.setStatus('Settings updated. Run to capture a new result.');
        end

        function syncNoiseControl(obj)
            enabled=logical(obj.Settings.noise_true);
            obj.UI.Noise.Value=enabled;
            if enabled
                obj.UI.Noise.Text='Simulated noise: ON';
                obj.UI.Noise.FontColor=[0.52 0.32 0.02];
            else
                obj.UI.Noise.Text='Simulated noise: OFF';
                obj.UI.Noise.FontColor=[0.35 0.35 0.35];
            end
            obj.UI.Noise.Enable=obj.onOff(~obj.Busy);
        end

        function editMatrix(obj,key,control,event)
            if ~isempty(event.Error) || ~isnumeric(control.Data) || any(~isfinite(control.Data(:)))
                control.Data=obj.getSetting(key);
                obj.showError('Enter finite numeric values in the table.'); return
            end
            obj.editSetting(key,control.Data);
        end

        function v=getSetting(obj,key)
            if startsWith(key,'firmware.')
                schema=obj.FirmwareSchema;
                item=schema(strcmp({schema.Name},extractAfter(key,'firmware.')));
                v=bf.settingValue(obj.Settings.Betaflight.CLI,item(1),0);
                if ~strcmp(item(1).Type,'choice'), v=str2double(v); end
                return
            end
            if startsWith(key,'native.')
                v=hover.nativeAttitudeValue(obj.Settings.Betaflight,extractAfter(key,'native.'));
                return
            end
            parts=strsplit(key,'.'); v=obj.Settings.(parts{1});
            if numel(parts)>1, v=v.(parts{2}); end
        end

        function savePreset(obj)
            try
                hover.validateSettings(obj.Settings);
                folder=fullfile(obj.DataRoot,'presets'); if ~isfolder(folder), mkdir(folder); end
                [name,path]=uiputfile('*.json','Save settings preset',fullfile(folder,'hover-preset.json'));
                if isequal(name,0), return; end
                options=struct('DefaultPlots',obj.UI.DefaultPlots.Value, ...
                    'RunLabel',obj.UI.RunLabel.Value,'Notes',{obj.UI.Notes.Value});
                hover.savePreset(fullfile(path,name),obj.Settings,options);
                obj.UI.PresetStatus.Text=['Saved: ' name];
            catch err, obj.showError(err.message); end
        end

        function loadPreset(obj)
            if obj.Busy, return; end
            [name,path]=uigetfile('*.json','Load settings preset',obj.DataRoot);
            if isequal(name,0), return; end
            try
                [settings,options]=hover.loadPreset(fullfile(path,name));
                hover.validateSettings(settings); obj.Settings=settings;
                if isfield(options,'DefaultPlots'), obj.UI.DefaultPlots.Value=options.DefaultPlots; end
                if isfield(options,'RunLabel'), obj.UI.RunLabel.Value=char(options.RunLabel); end
                if isfield(options,'Notes'), obj.UI.Notes.Value=cellstr(string(options.Notes)); end
                obj.syncFirmwareEditor(); obj.renderSettings(); obj.toggleDefaults(); obj.UI.PresetStatus.Text=['Loaded: ' name];
            catch err, obj.showError(err.message); end
        end

        function resetSettings(obj)
            if obj.Busy, return; end
            answer=uiconfirm(obj.App.UIFigure,'Replace the current inputs with the script defaults?', ...
                'Reset settings','Options',{'Reset','Cancel'},'DefaultOption',2,'CancelOption',2);
            if ~strcmp(answer,'Reset'), return; end
            obj.Settings=hover.defaultSettings(); obj.syncFirmwareEditor(); obj.renderSettings();
            obj.UI.PresetStatus.Text='Script defaults';
        end

        function buildDefaultPlots(obj)
            g=uigridlayout(obj.App.DefaultPlotsTab,[2 1]); g.RowHeight={38,'1x'};
            bar=uigridlayout(g,[1 5]); bar.ColumnWidth={75,'1x',110,110,130}; bar.Padding=[0 0 0 0];
            uilabel(bar,'Text','Run (UTC)','FontWeight','bold');
            obj.UI.DefaultRun=uidropdown(bar,'Items',{'No saved runs'}, ...
                'ValueChangedFcn',@(~,~)obj.chooseDefaultRun());
            uibutton(bar,'Text','Refresh plots','ButtonPushedFcn',@(~,~)obj.drawDefaults());
            uibutton(bar,'Text','Full duration','ButtonPushedFcn',@(~,~)obj.fitDefaults());
            uibutton(bar,'Text','Undock this view','ButtonPushedFcn',@(~,~)obj.undockDefaults());
            obj.UI.DefaultPanel=uipanel(g,'BorderType','none');
            plotGrid=uigridlayout(obj.UI.DefaultPanel,[1 1]); plotGrid.Padding=[0 0 0 0];
            obj.UI.DefaultPlotTabs=uitabgroup(plotGrid);
            specs=hover.defaultPlotSpec();
            groups=unique({specs.Tab},'stable');
            obj.DefaultAxes=gobjects(1,numel(specs));
            for group=1:numel(groups)
                tab=uitab(obj.UI.DefaultPlotTabs,'Title',groups{group});
                axesGrid=uigridlayout(tab,[2 2]);
                axesGrid.RowHeight={'1x','1x'}; axesGrid.ColumnWidth={'1x','1x'};
                axesGrid.Padding=[10 10 10 10]; axesGrid.RowSpacing=12; axesGrid.ColumnSpacing=18;
                indices=find(strcmp({specs.Tab},groups{group}));
                for tile=1:numel(indices)
                    k=indices(tile);
                    obj.DefaultAxes(k)=uiaxes(axesGrid,'FontUnits','points','FontSize',10);
                    obj.DefaultAxes(k).Layout.Row=ceil(tile/2);
                    obj.DefaultAxes(k).Layout.Column=mod(tile-1,2)+1;
                    title(obj.DefaultAxes(k),specs(k).Title);
                    xlabel(obj.DefaultAxes(k),'Time [s]'); ylabel(obj.DefaultAxes(k),specs(k).YLabel);
                    grid(obj.DefaultAxes(k),'on');
                end
                if numel(indices)==3
                    obj.DefaultAxes(indices(3)).Layout.Column=[1 2];
                end
            end
            obj.UI.DefaultPlotTabs.SelectionChangedFcn=@(~,~)obj.drawDefaults();
        end

        function buildExplorer(obj)
            g=uigridlayout(obj.App.ExploreTab,[1 2]); g.ColumnWidth={335,'1x'}; g.ColumnSpacing=16;
            left=uigridlayout(g,[10 1]); left.Padding=[0 0 0 0];
            left.RowHeight={28,130,32,32,48,30,32,'1x',32,32};
            uilabel(left,'Text','RUN LIBRARY  (UTC)','FontWeight','bold','FontSize',16);
            obj.UI.RunList=uilistbox(left,'Items',{},'ValueChangedFcn',@(~,~)obj.selectRun());
            buttons=uigridlayout(left,[1 2]); buttons.Padding=[0 0 0 0];
            uibutton(buttons,'Text','Refresh','ButtonPushedFcn',@(~,~)obj.refreshLibrary());
            uibutton(buttons,'Text','Storage folder...','ButtonPushedFcn',@(~,~)obj.chooseDataRoot());
            uibutton(left,'Text','Use this run''s settings','ButtonPushedFcn',@(~,~)obj.useRunSettings());
            obj.UI.RunInfo=uilabel(left,'Text','Run a simulation to populate the library.','WordWrap','on','FontSize',11);
            uilabel(left,'Text','SIGNALS  /  double-click to plot','FontWeight','bold');
            obj.UI.SearchSignals=uieditfield(left,'text','Placeholder','Search signals or units...', ...
                'ValueChangedFcn',@(~,~)obj.refreshSignals());
            obj.UI.Signals=uitree(left,'Multiselect','on', ...
                'DoubleClickedFcn',@(~,event)obj.signalDoubleClick(event));
            uibutton(left,'Text','Plot selected signals','ButtonPushedFcn',@(~,~)obj.plotSelected());
            exports=uigridlayout(left,[1 2]); exports.Padding=[0 0 0 0];
            uibutton(exports,'Text','To workspace','ButtonPushedFcn',@(~,~)obj.exportWorkspace());
            uibutton(exports,'Text','Export signal CSV','ButtonPushedFcn',@(~,~)obj.exportCSV());
            right=uigridlayout(g,[5 1]); right.RowHeight={36,32,30,'1x',130}; right.Padding=[0 0 0 0];
            tools=uigridlayout(right,[1 5]); tools.ColumnWidth={'1x',100,100,95,110}; tools.Padding=[0 0 0 0];
            obj.UI.PlotMode=uidropdown(tools,'Items',{'Overlay on active plot','Replace active plot','Create a new plot'}, ...
                'Tooltip','Double-clicking a signal follows this plot mode');
            uibutton(tools,'Text','New plot','ButtonPushedFcn',@(~,~)obj.newPlot());
            uibutton(tools,'Text','Clear plot','ButtonPushedFcn',@(~,~)obj.clearPlot());
            uibutton(tools,'Text','Close plot','ButtonPushedFcn',@(~,~)obj.closePlot());
            uibutton(tools,'Text','Export plot...','ButtonPushedFcn',@(~,~)obj.exportPlot());
actions=uigridlayout(right,[1 4]); actions.Padding=[0 0 0 0];
            actions.ColumnWidth={130,130,150,'1x'};
            uibutton(actions,'Text','Full duration','ButtonPushedFcn',@(~,~)hover.fitPlot(obj.currentAxes()));
            uibutton(actions,'Text','Undock plot','ButtonPushedFcn',@(~,~)obj.undockExplorer());
            uibutton(actions,'Text','Remove signals...', ...
                'Tooltip','Choose traces to remove from this plot, including overlays from other runs', ...
                'ButtonPushedFcn',@(~,~)obj.removePlotSignals());
            uilabel(actions,'Text','Overview preserves peaks; zoom in for full detail.','FontSize',10);
            obj.UI.PlotHint=uilabel(right,'Text','Select a run, then double-click a signal. Switch runs to compare on the same axes.','WordWrap','on');
            obj.UI.PlotTabs=uitabgroup(right); obj.newPlot();
            detailTabs=uitabgroup(right);
            details=uitab(detailTabs,'Title','Saved settings'); dg=uigridlayout(details,[1 1]); dg.Padding=[0 0 0 0];
            obj.UI.SavedSettings=uitable(dg,'Data',cell(0,2),'ColumnName',{'Setting','Saved value'}, ...
                'ColumnWidth',{220,'auto'},'RowName',{});
            metadataTab=uitab(detailTabs,'Title','Run details'); mg=uigridlayout(metadataTab,[1 1]); mg.Padding=[0 0 0 0];
            obj.UI.Metadata=uitextarea(mg,'Editable','off','Value',{'Select a saved run to inspect its configuration.'});
        end

        function buildFlightAnalysis(obj)
            obj.UI.FlightTab=uitab(obj.App.Pages,'Title','Flight analysis');
            g=uigridlayout(obj.UI.FlightTab,[4 1]); g.RowHeight={38,54,'1x',44};
            bar=uigridlayout(g,[1 5]); bar.ColumnWidth={110,'1x',110,130,130}; bar.Padding=[0 0 0 0];
            uilabel(bar,'Text','Run (UTC)','FontWeight','bold');
            obj.UI.FlightRun=uidropdown(bar,'Items',{'No saved runs'}, ...
                'ValueChangedFcn',@(~,~)obj.loadFolder(obj.UI.FlightRun.Value));
            obj.UI.FlightAxis=uidropdown(bar,'Items',{'Roll','Pitch','Yaw'},'ItemsData',1:3, ...
                'Tooltip','Select the axis for tracking, estimator, PID and gyro-error plots. Motor outputs always show all four actuators.', ...
                'ValueChangedFcn',@(~,~)obj.drawFlightAnalysis());
            uibutton(bar,'Text','Export plots...', ...
                'ButtonPushedFcn',@(~,~)obj.exportFlightAnalysis());
            uibutton(bar,'Text','Undock plots','ButtonPushedFcn', ...
                @(~,~)hover.undockPlots(obj.UI.FlightAxes,'Hover Workbench - Flight analysis'));
            obj.UI.FlightSummary=uilabel(g,'Text','Run a simulation or select saved data.','WordWrap','on');
            obj.UI.FlightPanel=uipanel(g,'BorderType','none');
            tiles=tiledlayout(obj.UI.FlightPanel,3,2,'TileSpacing','compact','Padding','compact');
            obj.UI.FlightAxes=gobjects(1,6);
            for k=1:6
                obj.UI.FlightAxes(k)=uiaxes(tiles); obj.UI.FlightAxes(k).Layout.Tile=k;
            end
            uilabel(g,'Text',['Tracking RMS = true response minus the plotted command. Estimator RMS = true angle minus estimated angle. ' ...
                'Raw gyro error includes bias, white noise, vibration and sensor sampling. All plots use this run''s saved data; motors show all four outputs.'], ...
                'WordWrap','on');
        end

        function drawFlightAnalysis(obj)
            if isempty(obj.ActiveRecord), return; end
            obj.LastAnalysisError='';
            try
                metrics=hover.plotFlightAnalysis(obj.ActiveRecord,obj.UI.FlightAxis.Value,obj.UI.FlightAxes);
                obj.UI.FlightSummary.Text=sprintf(['%s | %s mode | %s %s tracking RMS %.3g %s\n' ...
                    'Attitude estimation RMS error %.3g deg | Motor outputs %.1f to %.1f us / pot'], ...
                    char(obj.ActiveRecord.Label),upper(metrics.CommandMode),metrics.Axis, ...
                    metrics.TrackingQuantity,metrics.TrackingRms,metrics.TrackingUnit,metrics.EstimatorRmsDegrees, ...
                    metrics.MotorRangeMicroseconds);
            catch err
                obj.LastAnalysisError=getReport(err,'extended','hyperlinks','off');
                obj.UI.FlightSummary.Text=['Analysis unavailable: ' err.message];
            end
        end

        function exportFlightAnalysis(obj)
            if isempty(obj.ActiveRecord), return; end
            [name,folder]=uiputfile({'*.png','PNG image';'*.pdf','PDF document'},'Export flight analysis');
            if isequal(name,0), return; end
            try
                exportgraphics(obj.UI.FlightPanel,fullfile(folder,name),'Resolution',150);
                obj.setStatus(['Exported ' name]);
            catch err
                obj.showError(err.message);
            end
        end

        function startRun(obj)
            if obj.Busy || obj.Loading || obj.Plotting || obj.Completing, return; end
            obj.Busy=true;
            obj.cleanupSimulation();
            obj.LastError=''; obj.StopRequested=false; obj.Completing=false;
            try
                obj.RunSettings=obj.Settings;
                modelPath=fullfile(fileparts(fileparts(mfilename('fullpath'))),'lin_hover_sim.slx');
                scriptPath=fullfile(fileparts(modelPath),'lin_hover.m');
                [simInput,obj.RunVariables]=hover.makeSimulationInput(obj.RunSettings,modelPath);
                if strcmp(get_param('lin_hover_sim','Dirty'),'on')
                    error('HoverWorkbench:UnsavedModel', ...
                        'The open model has unsaved edits. Save those edits before running so the archived model matches the simulation.');
                end
                obj.RunMetadata=struct('Label',obj.UI.RunLabel.Value, ...
                    'Notes',strjoin(string(obj.UI.Notes.Value),newline),'Status','completed', ...
                    'DefaultPlots',obj.UI.DefaultPlots.Value,'ModelPath',modelPath,'ScriptPath',scriptPath, ...
                    'MATLABRelease',version('-release'));
                obj.RunMetadata.ModelSHA256=hover.fileHash(modelPath);
                obj.RunMetadata.ScriptSHA256=hover.fileHash(scriptPath);
                obj.RunMetadata.GitBranch=hover.gitInfo(fileparts(modelPath),'branch');
                obj.RunMetadata.GitCommit=hover.gitInfo(fileparts(modelPath),'commit');
                obj.RunMetadata.ValidationNotes=hover.validateSettings(obj.RunSettings);
                obj.RunMetadata.StorageRoot=obj.DataRoot;
                obj.Busy=true; obj.setBusy(true); obj.RunStarted=tic;
                obj.setStatus('Compiling and initializing the model...'); drawnow limitrate nocallbacks;
                obj.Simulation=simulation(simInput);
                obj.SimulationListener=addlistener(obj.Simulation,'SimulationStatusChanged', ...
                    @(~,event)obj.simulationStatusChanged(event));
                start(obj.PollTimer);
                start(obj.Simulation);
                obj.simulationStatusChanged();
            catch err
                obj.LastError=err.message; obj.Busy=false; obj.setBusy(false); obj.cleanupSimulation();
                obj.showError(err.message);
            end
        end

        function pollProgress(obj)
            if ~obj.Busy || isempty(obj.Simulation) || obj.Completing, return; end
            try
                obj.setStatus(sprintf('%s | %.3f / %.3f s simulated | %.1f s elapsed', ...
                    char(obj.Simulation.Status),obj.Simulation.Time,obj.RunSettings.t_sim,toc(obj.RunStarted)));
            catch
                % Simulation may be terminating while the progress tick fires.
            end
        end

        function simulationStatusChanged(obj,event)
            if ~obj.Busy || obj.Completing || isempty(obj.Simulation), return; end
            if nargin>1
                status=string(event.NewStatus);
            else
                status=string(obj.Simulation.Status);
            end
            if strcmpi(status,"inactive")
                obj.finishRun();
            end
        end

        function finishRun(obj)
            if obj.Completing, return; end
            obj.Completing=true;
            stop(obj.PollTimer);
            try
                output=obj.Simulation.SimulationOutput;
                obj.RunMetadata.ElapsedSeconds=toc(obj.RunStarted);
                if obj.StopRequested, obj.RunMetadata.Status='stopped'; end
                if ~isempty(output.ErrorMessage)
                    obj.RunMetadata.Status='failed'; obj.RunMetadata.Error=output.ErrorMessage;
                end
                obj.setStatus('Saving output and settings...'); drawnow limitrate nocallbacks;
                record=hover.saveRun(obj.RunMetadata.StorageRoot,obj.RunSettings, ...
                    obj.RunVariables,output,obj.RunMetadata);
                obj.cleanupSimulation(false);
                obj.refreshLibrary(); obj.activateRecord(record);
                obj.setStatus(sprintf('Saved %s | %d signals | %s',record.Label,numel(record.Signals),record.Folder));
                if strcmp(obj.RunMetadata.Status,'failed')
                    obj.showError(['Partial results saved. ' char(output.ErrorMessage)]);
                elseif obj.UI.DefaultPlots.Value
                    obj.App.Pages.SelectedTab=obj.App.DefaultPlotsTab;
                else
                    obj.App.Pages.SelectedTab=obj.App.ExploreTab;
                end
            catch err
                obj.LastError=err.message;
                % Keep raw results accessible even if storage fails.
                try
                    recovery=struct('Settings',obj.RunSettings,'Variables',obj.RunVariables, ...
                        'Output',obj.Simulation.SimulationOutput,'Metadata',obj.RunMetadata);
                    assignin('base','hoverRecovery',recovery);
                catch
                end
                obj.Busy=false; obj.setBusy(false); obj.cleanupSimulation(false);
                obj.showError(sprintf('Could not archive the run: %s\nAny available result is in workspace variable hoverRecovery.',err.message));
            end
            obj.Completing=false;
            obj.Busy=false; obj.setBusy(false);
        end

        function stopRun(obj)
            if ~obj.Busy || isempty(obj.Simulation), return; end
            obj.StopRequested=true; obj.setStatus('Stopping; partial results will be saved...');
            stop(obj.Simulation);
        end

        function setBusy(obj,value)
            obj.UI.Run.Enable=obj.onOff(~value); obj.UI.Stop.Enable=obj.onOff(value);
            obj.UI.Noise.Enable=obj.onOff(~value);
            obj.UI.RunLabel.Enable=obj.onOff(~value); obj.UI.Notes.Enable=obj.onOff(~value);
            obj.UI.RunList.Enable=obj.onOff(~value);
            obj.UI.DefaultRun.Enable=obj.onOff(~value); obj.UI.FlightRun.Enable=obj.onOff(~value);
            obj.UI.Signals.Enable=obj.onOff(~value);
            keys=obj.ParameterEditors.keys;
            for k=1:numel(keys)
                c=obj.ParameterEditors(keys{k}); if isvalid(c), c.Enable=obj.onOff(~value); end
            end
        end

        function cleanupSimulation(obj,destroy)
            if nargin<2, destroy=true; end
            if ~isempty(obj.PollTimer) && isvalid(obj.PollTimer), stop(obj.PollTimer); end
            if ~isempty(obj.SimulationListener), delete(obj.SimulationListener); obj.SimulationListener=[]; end
            % A completion listener runs inside Simulink's lifecycle. Keep the
            % Simulation alive until that call stack unwinds (next run/close).
            if destroy && ~isempty(obj.Simulation)
                try
                    if string(obj.Simulation.Status)~="inactive", terminate(obj.Simulation); end
                    delete(obj.Simulation);
                catch
                end
                obj.Simulation=[];
            end
        end

        function refreshLibrary(obj)
            try
                obj.Runs=hover.listRuns(obj.DataRoot);
                if isempty(obj.Runs)
                    obj.UI.RunList.Items={}; obj.UI.RunList.ItemsData={};
                    obj.UI.DefaultRun.Items={'No saved runs'}; obj.UI.DefaultRun.ItemsData={''};
                    obj.UI.FlightRun.Items={'No saved runs'}; obj.UI.FlightRun.ItemsData={''};
                    return
                end
                labels=arrayfun(@(r)sprintf('%s | %s', ...
                    strrep(char(extractBefore(string(r.Created),20)),'T',' '),char(r.Label)), ...
                    obj.Runs,'UniformOutput',false);
                folders=cellstr(string({obj.Runs.Folder}));
                obj.UI.RunList.Items=labels; obj.UI.RunList.ItemsData=folders;
                obj.UI.DefaultRun.Items=labels; obj.UI.DefaultRun.ItemsData=folders;
                obj.UI.FlightRun.Items=labels; obj.UI.FlightRun.ItemsData=folders;
            catch err, obj.showError(err.message); end
        end

        function selectRun(obj)
            if isempty(obj.UI.RunList.Value), return; end
            obj.loadFolder(obj.UI.RunList.Value);
        end

        function chooseDefaultRun(obj)
            if isempty(obj.UI.DefaultRun.Value), return; end
            obj.loadFolder(obj.UI.DefaultRun.Value);
        end

        function loadFolder(obj,folder)
            if obj.Busy || obj.Loading || obj.Plotting, return; end
            if ~isempty(obj.ActiveRecord) && strcmp(char(folder),obj.ActiveRecord.Folder), return; end
            obj.Loading=true; cleanup=onCleanup(@()obj.endLoading());
            try
                obj.setStatus('Loading saved run...'); drawnow limitrate nocallbacks;
                obj.activateRecord(hover.loadRun(folder));
                obj.setStatus(['Loaded: ' char(obj.ActiveRecord.Label)]);
            catch err, obj.showError(err.message); end
        end

        function activateRecord(obj,record)
            obj.ActiveRecord=record;
            folder=char(record.Folder);
            if ismember(folder,obj.UI.RunList.ItemsData), obj.UI.RunList.Value=folder; end
            if ismember(folder,obj.UI.DefaultRun.ItemsData), obj.UI.DefaultRun.Value=folder; end
            if ismember(folder,obj.UI.FlightRun.ItemsData), obj.UI.FlightRun.Value=folder; end
            obj.UI.RunInfo.Text=sprintf('%s | %d signals\n%s',char(record.Created),numel(record.Signals),char(record.Label));
            obj.UI.SavedSettings.Data=obj.flatten(record.Settings,'');
            obj.UI.Metadata.Value=cellstr(splitlines(string(jsonencode(record.Metadata,'PrettyPrint',true))));
            for k=1:numel(obj.DefaultAxes), cla(obj.DefaultAxes(k)); end
            obj.refreshSignals(); obj.drawDefaults(); obj.drawFlightAnalysis();
        end

        function refreshSignals(obj)
            delete(obj.UI.Signals.Children);
            if isempty(obj.ActiveRecord), return; end
            signals=obj.ActiveRecord.Signals;
            query=lower(string(obj.UI.SearchSignals.Value));
            groups=unique(string({signals.Group}),'stable');
            for k=1:numel(groups)
                indices=find(string({signals.Group})==groups(k));
                indices=indices(contains(lower(string({signals(indices).Name})),query) | ...
                    contains(lower(string({signals(indices).Unit})),query));
                if isempty(indices), continue; end
                node=uitreenode(obj.UI.Signals,'Text',char(groups(k)),'NodeData',[]);
                for j=indices
                    uitreenode(node,'Text',sprintf('%s [%s]',signals(j).Name,signals(j).Unit),'NodeData',j);
                end
                expand(node);
            end
        end

        function signalDoubleClick(obj,event)
            info=event.InteractionInformation;
            if ~isfield(info,'Node') || isempty(info.Node) || ~isvalid(info.Node) || isempty(info.Node.NodeData), return; end
            obj.plotSignals(info.Node.NodeData);
        end

        function plotSelected(obj)
            nodes=obj.UI.Signals.SelectedNodes;
            indices=[];
            for k=1:numel(nodes)
                if ~isempty(nodes(k).NodeData), indices(end+1)=nodes(k).NodeData; end %#ok<AGROW>
            end
            if isempty(indices), obj.setStatus('Select one or more signal names in the tree.'); return; end
            obj.plotSignals(indices);
        end

        function plotSignals(obj,indices)
            if isempty(obj.ActiveRecord) || obj.Busy || obj.Loading || obj.Plotting, return; end
            indices=unique(indices(:)','stable');
            if any(indices<1 | indices>numel(obj.ActiveRecord.Signals) | fix(indices)~=indices), return; end
            obj.Plotting=true; cleanup=onCleanup(@()obj.endPlotting());
            try
            mode=obj.UI.PlotMode.Value;
            if strcmp(mode,'Create a new plot'), obj.newPlot(); end
            ax=obj.currentAxes();
            if strcmp(mode,'Replace active plot'), cla(ax); end
            hold(ax,'on');
            for idx=indices(:)'
                s=obj.ActiveRecord.Signals(idx);
                existing=findobj(ax,'Type','line');
                duplicate=false;
                for k=1:numel(existing)
                    identity=existing(k).UserData;
                    if isstruct(identity) && all(isfield(identity,{'RunID','SignalKey'})) && ...
                            strcmp(identity.RunID,obj.ActiveRecord.ID) && strcmp(identity.SignalKey,s.Key)
                        duplicate=true; break;
                    end
                end
                if duplicate, continue; end
                id=char(obj.ActiveRecord.ID);
                displayName=sprintf('%s | %s [%s] (%s)',obj.ActiveRecord.Label,s.Name,s.Unit,id(end-5:end));
                h=hover.plotSignal(ax,s.Time,s.Data,'LineWidth',1.3,'DisplayName',displayName);
                h.UserData=struct('RunID',obj.ActiveRecord.ID,'SignalKey',s.Key,'Unit',s.Unit);
            end
            hold(ax,'off'); grid(ax,'on'); xlabel(ax,'Time (s)');
            obj.finishExplorerPlot(ax);
            catch err
                obj.showError(['Could not plot the selected signals: ' err.message]);
            end
        end

        function finishExplorerPlot(obj,ax)
            lines=findobj(ax,'Type','line');
            if isempty(lines)
                legend(ax,'off'); title(ax,'Double-click a signal to begin'); ylabel(ax,'');
                hover.fitPlot(ax); return;
            end
            units=strings(0,1);
            for k=1:numel(lines), units(end+1)=string(lines(k).UserData.Unit); end %#ok<AGROW>
            units=unique(units,'stable');
            ylabel(ax,char(strjoin(units,' / '))); title(ax,'Run comparison','Interpreter','none');
            legend(ax,'show','Interpreter','none','Location','northeast');
            hover.fitPlot(ax);
            if numel(units)>1
                obj.UI.PlotHint.Text='Mixed units share this axis. Create separate plot tabs when scales differ.';
            else
                obj.UI.PlotHint.Text='Overlay keeps existing traces. Switch runs and double-click to compare.';
            end
        end

        function ax=newPlot(obj)
            obj.PlotCount=obj.PlotCount+1;
            tab=uitab(obj.UI.PlotTabs,'Title',sprintf('Plot %d',obj.PlotCount));
            g=uigridlayout(tab,[1 1]); g.Padding=[8 8 8 8];
            ax=uiaxes(g); tab.UserData=ax;
            title(ax,'Double-click a signal to begin'); xlabel(ax,'Time (s)'); grid(ax,'on');
            obj.UI.PlotTabs.SelectedTab=tab;
        end

        function ax=currentAxes(obj)
            if isempty(obj.UI.PlotTabs.Children), obj.newPlot(); end
            ax=obj.UI.PlotTabs.SelectedTab.UserData;
        end

        function clearPlot(obj)
            ax=obj.currentAxes(); cla(ax); obj.finishExplorerPlot(ax);
        end

        function closePlot(obj)
            delete(obj.UI.PlotTabs.SelectedTab);
            if isempty(obj.UI.PlotTabs.Children), obj.newPlot(); end
        end

        function toggleDefaults(obj)
            obj.UI.DefaultPanel.Visible=obj.onOff(obj.UI.DefaultPlots.Value);
            obj.drawDefaults();
        end

        function drawDefaults(obj)
            if isempty(obj.ActiveRecord) || ~obj.UI.DefaultPlots.Value, return; end
            try, hover.defaultPlots(obj.DefaultAxes,obj.ActiveRecord,obj.defaultPlotIndices());
            catch err, obj.showError(err.message); end
        end

        function indices=defaultPlotIndices(obj)
            specs=hover.defaultPlotSpec();
            indices=find(strcmp({specs.Tab},obj.UI.DefaultPlotTabs.SelectedTab.Title));
        end

        function fitDefaults(obj)
            if isempty(obj.ActiveRecord), return; end
            signals=obj.ActiveRecord.Signals;
            starts=arrayfun(@(s)min(s.Time),signals,'UniformOutput',false);
            stops=arrayfun(@(s)max(s.Time),signals,'UniformOutput',false);
            limits=[min([starts{:}]) max([stops{:}])];
            for k=obj.defaultPlotIndices(), hover.fitPlot(obj.DefaultAxes(k),limits); end
        end

        function fig=undockDefaults(obj)
            fig=hover.undockPlots(obj.DefaultAxes(obj.defaultPlotIndices()), ...
                ['Hover Workbench - ' obj.UI.DefaultPlotTabs.SelectedTab.Title]);
        end

        function fig=undockExplorer(obj)
            fig=hover.undockPlots(obj.currentAxes(),['Hover Workbench - ' obj.UI.PlotTabs.SelectedTab.Title]);
        end

        function removePlotSignals(obj,indices)
            ax=obj.currentAxes(); traces=flipud(findobj(ax,'Type','line'));
            if isempty(traces), obj.setStatus('This plot has no signals to remove.'); return; end
            if nargin<2
                [indices,accepted]=listdlg('PromptString','Remove traces from the active plot:', ...
                    'ListString',{traces.DisplayName},'SelectionMode','multiple', ...
                    'ListSize',[650 260],'Name','Remove plotted signals');
                if ~accepted, return; end
            end
            delete(traces(indices)); obj.finishExplorerPlot(ax);
        end

        function useRunSettings(obj)
            if obj.Busy || isempty(obj.ActiveRecord), return; end
            obj.Settings=hover.upgradeSettings(obj.ActiveRecord.Settings); obj.syncFirmwareEditor(); obj.renderSettings();
            obj.UI.PresetStatus.Text=['From run: ' char(obj.ActiveRecord.Label)];
            obj.App.Pages.SelectedTab=obj.App.SettingsTab;
        end

        function chooseDataRoot(obj)
            if obj.Busy, return; end
            folder=uigetdir(obj.DataRoot,'Select the folder containing runs and presets');
            if isequal(folder,0), return; end
            obj.DataRoot=folder; obj.refreshLibrary();
            obj.setStatus(['Storage folder: ' folder]);
        end

        function exportWorkspace(obj)
            if isempty(obj.ActiveRecord), return; end
            assignin('base','hoverRun',obj.ActiveRecord);
            nodes=obj.UI.Signals.SelectedNodes; selected=struct();
            for k=1:numel(nodes)
                if isempty(nodes(k).NodeData), continue; end
                s=obj.ActiveRecord.Signals(nodes(k).NodeData);
                name=matlab.lang.makeValidName(s.Key);
                name=matlab.lang.makeUniqueStrings(name,fieldnames(selected));
                ts=timeseries(s.Data,s.Time,'Name',s.Name); ts.DataInfo.Units=s.Unit;
                selected.(name)=ts;
            end
            assignin('base','hoverSignals',selected);
            obj.setStatus('Exported hoverRun (full record) and hoverSignals (selected timeseries) to the MATLAB workspace.');
        end

        function exportCSV(obj)
            if isempty(obj.ActiveRecord), return; end
            nodes=obj.UI.Signals.SelectedNodes;
            indices=[];
            for k=1:numel(nodes)
                if ~isempty(nodes(k).NodeData), indices(end+1)=nodes(k).NodeData; end %#ok<AGROW>
            end
            if isempty(indices), obj.setStatus('Select signals to export first.'); return; end
            folder=uigetdir(obj.DataRoot,'Choose a folder for the selected signal CSV files');
            if isequal(folder,0), return; end
            try
                for idx=indices
                    s=obj.ActiveRecord.Signals(idx);
                    name=sprintf('%s_%s.csv',obj.ActiveRecord.ID,matlab.lang.makeValidName(s.Key));
                    path=fullfile(folder,name);
                    if isfile(path)
                        path=fullfile(folder,[char(java.util.UUID.randomUUID()) '_' name]);
                    end
                    valueName=matlab.lang.makeValidName([s.Name '_' s.Unit]);
                    data=table(s.Time,s.Data,'VariableNames',{'Time_s',valueName});
                    writetable(data,path);
                end
                obj.setStatus(sprintf('Exported %d signals to %s',numel(indices),folder));
            catch err, obj.showError(err.message); end
        end

        function exportPlot(obj)
            [name,path]=uiputfile({'*.png';'*.pdf'},'Export current plot','hover-comparison.png');
            if isequal(name,0), return; end
            try, exportgraphics(obj.currentAxes(),fullfile(path,name),'Resolution',200);
            catch err, obj.showError(err.message); end
        end

        function setStatus(obj,text)
            if isvalid(obj.App) && isgraphics(obj.App.UIFigure), obj.App.StatusLabel.Text=char(text); end
        end

        function showError(obj,message)
            obj.LastError=char(message); obj.setStatus(message);
            if isvalid(obj.App.UIFigure), uialert(obj.App.UIFigure,char(message),'Hover Workbench'); end
        end

        function allowed=requestClose(obj)
            allowed=~obj.Busy;
            if obj.Busy
                obj.setStatus('Stop the current simulation and let its results save before closing.');
            end
        end

        function delete(obj)
            if obj.Disposing, return; end
            obj.Disposing=true;
            if ~isempty(obj.FigureListener), delete(obj.FigureListener); obj.FigureListener=[]; end
            obj.cleanupSimulation();
            if ~isempty(obj.FirmwareEditor) && isvalid(obj.FirmwareEditor), delete(obj.FirmwareEditor); end
            if ~isempty(obj.PollTimer) && isvalid(obj.PollTimer)
                stop(obj.PollTimer); delete(obj.PollTimer);
            end
            obj.ActiveRecord=[]; obj.RunVariables=[]; obj.RunSettings=[];
            obj.App=[];
        end
    end
    methods (Access=private)
        function endLoading(obj)
            if isvalid(obj), obj.Loading=false; end
        end
        function endPlotting(obj)
            if isvalid(obj), obj.Plotting=false; end
        end
    end
    methods (Static)
        function value=onOff(flag)
            if flag, value='on'; else, value='off'; end
        end

        function rows=flatten(value,prefix)
            rows=cell(0,2); names=fieldnames(value);
            for k=1:numel(names)
                name=names{k}; key=[prefix name]; item=value.(name);
                if isstruct(item) && isscalar(item)
                    rows=[rows; HoverWorkbenchController.flatten(item,[key '.'])]; %#ok<AGROW>
                else
                    if isnumeric(item) || islogical(item)
                        text=mat2str(item,9);
                    else
                        text=char(string(item));
                    end
                    rows(end+1,:)={key,text}; %#ok<AGROW>
                end
            end
        end
    end
end
