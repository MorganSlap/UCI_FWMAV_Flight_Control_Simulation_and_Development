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
        RunSettings
        RunVariables
        RunMetadata
        StopRequested = false
        DefaultAxes
        PlotCount = 0
        ParameterEditors
        UI = struct()
        FirmwareEditor = []
    end
    properties (Access = private)
        RunStarted
        Completing = false
    end
    methods
        function obj = HoverWorkbenchController(app)
            obj.App = app;
            obj.Settings = hover.hoverExample();
            obj.Schema = hover.settingsSchema();
            % The native firmware replaces these legacy controller settings.
            oldKeys={'mahoney.Kp','mahoney.Ki','roll_P','roll_I','roll_D', ...
                'pitch_P','pitch_I','pitch_D','yaw_P','yaw_I','yaw_D','strength','MMA','max_pot','fs'};
            if ~bf.flightInterfacesReady()
                % The prepared upgrade exposes these fixed sensor values.
                % Do not display ineffective editors before it is installed.
                oldKeys=[oldKeys,{'accel.sample_rate','accel.noise_density','accel.bias','accel.vibration', ...
                    'gyro.sample_rate','gyro.noise_density','gyro.bias','gyro.vibration'}];
            end
            obj.Schema=obj.Schema(~ismember({obj.Schema.Key},oldKeys));
            obj.DataRoot = fullfile(fileparts(mfilename('fullpath')), 'data');
            if ~isfolder(obj.DataRoot), mkdir(obj.DataRoot); end
            obj.ParameterEditors = containers.Map('KeyType','char','ValueType','any');
            obj.buildHeader();
            obj.buildSettings();
            obj.buildDefaultPlots();
            obj.buildExplorer();
            obj.refreshLibrary();
            obj.renderSettings();
            obj.PollTimer = timer('ExecutionMode','fixedSpacing','Period',0.3, ...
                'BusyMode','drop','Name','HoverWorkbenchProgress', ...
                'TimerFcn',@(~,~)obj.pollProgress());
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
            obj.UI.Groups = uilistbox(side,'Items',cellstr(["Firmware interface","Receiver channels",groups,"Derived values"]), ...
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
            obj.Settings.Betaflight=config;
            obj.renderSettings();
            obj.UI.PresetStatus.Text='Modified Betaflight configuration';
        end

        function syncFirmwareEditor(obj)
            if ~isempty(obj.FirmwareEditor) && isvalid(obj.FirmwareEditor)
                if isfield(obj.Settings,'Betaflight'), config=obj.Settings.Betaflight;
                else, config=bf.hoverConfig(obj.Settings.max_pot); end
                obj.FirmwareEditor.setConfiguration(config);
            end
        end

        function renderSettings(obj)
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
            n = numel(entries);
            heights = repmat({36},1,n+1); heights{end}='1x';
            for k=1:n
                if strcmp(entries(k).Kind,'matrix'), heights{k}=max(138,32+25*size(entries(k).Default,1)); end
            end
            g = uigridlayout(obj.UI.EditorPanel,[n+1 3]);
            g.RowHeight = heights; g.ColumnWidth = {240,'1x',115};
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
                'Re-trim after changing the plant or motor settings. Ideal bench calibration overrides CLI accelerometer offsets using the simulated bias; it is not an estimated in-flight correction.'], ...
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
            obj.Settings.FirmwareAdapter.(key)=value;
            obj.UI.PresetStatus.Text='Modified firmware interface';
        end

        function resetAdapter(obj)
            if obj.Busy, return; end
            obj.Settings.FirmwareAdapter=struct(); obj.renderSettings();
        end

        function editSetting(obj,key,value)
            if obj.Busy, return; end
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
            bar=uigridlayout(g,[1 3]); bar.ColumnWidth={110,'1x',140}; bar.Padding=[0 0 0 0];
            uilabel(bar,'Text','Displayed run','FontWeight','bold');
            obj.UI.DefaultRun=uidropdown(bar,'Items',{'No saved runs'}, ...
                'ValueChangedFcn',@(~,~)obj.chooseDefaultRun());
            uibutton(bar,'Text','Refresh plots','ButtonPushedFcn',@(~,~)obj.drawDefaults());
            obj.UI.DefaultPanel=uipanel(g,'BorderType','none');
            tiles=tiledlayout(obj.UI.DefaultPanel,2,2,'TileSpacing','compact','Padding','compact');
            obj.DefaultAxes=gobjects(1,4);
            names={'True states and rates','Absolute control commands','Estimated attitude and rates','Estimation error'};
            for k=1:4
                obj.DefaultAxes(k)=uiaxes(tiles); obj.DefaultAxes(k).Layout.Tile=k;
                title(obj.DefaultAxes(k),names{k}); xlabel(obj.DefaultAxes(k),'Time (s)'); grid(obj.DefaultAxes(k),'on');
            end
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
            right=uigridlayout(g,[4 1]); right.RowHeight={36,30,'1x',130}; right.Padding=[0 0 0 0];
            tools=uigridlayout(right,[1 5]); tools.ColumnWidth={'1x',100,100,95,110}; tools.Padding=[0 0 0 0];
            obj.UI.PlotMode=uidropdown(tools,'Items',{'Overlay on active plot','Replace active plot','Create a new plot'}, ...
                'Tooltip','Double-clicking a signal follows this plot mode');
            uibutton(tools,'Text','New plot','ButtonPushedFcn',@(~,~)obj.newPlot());
            uibutton(tools,'Text','Clear plot','ButtonPushedFcn',@(~,~)obj.clearPlot());
            uibutton(tools,'Text','Close plot','ButtonPushedFcn',@(~,~)obj.closePlot());
            uibutton(tools,'Text','Export plot...','ButtonPushedFcn',@(~,~)obj.exportPlot());
            obj.UI.PlotHint=uilabel(right,'Text','Select a run, then double-click a signal. Switch runs to compare on the same axes.','WordWrap','on');
            obj.UI.PlotTabs=uitabgroup(right); obj.newPlot();
            detailTabs=uitabgroup(right);
            details=uitab(detailTabs,'Title','Saved settings'); dg=uigridlayout(details,[1 1]); dg.Padding=[0 0 0 0];
            obj.UI.SavedSettings=uitable(dg,'Data',cell(0,2),'ColumnName',{'Setting','Saved value'}, ...
                'ColumnWidth',{220,'auto'},'RowName',{});
            metadataTab=uitab(detailTabs,'Title','Run details'); mg=uigridlayout(metadataTab,[1 1]); mg.Padding=[0 0 0 0];
            obj.UI.Metadata=uitextarea(mg,'Editable','off','Value',{'Select a saved run to inspect its configuration.'});
        end

        function startRun(obj)
            if obj.Busy, return; end
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
                obj.setStatus('Compiling and initializing the model...'); drawnow;
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
                obj.setStatus('Saving output and settings...'); drawnow;
                record=hover.saveRun(obj.RunMetadata.StorageRoot,obj.RunSettings, ...
                    obj.RunVariables,output,obj.RunMetadata);
                obj.cleanupSimulation(false); obj.Busy=false; obj.setBusy(false);
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
                    return
                end
                labels=arrayfun(@(r)sprintf('%s | %s', ...
                    strrep(char(extractBefore(string(r.Created),20)),'T',' '),char(r.Label)), ...
                    obj.Runs,'UniformOutput',false);
                folders=cellstr(string({obj.Runs.Folder}));
                obj.UI.RunList.Items=labels; obj.UI.RunList.ItemsData=folders;
                obj.UI.DefaultRun.Items=labels; obj.UI.DefaultRun.ItemsData=folders;
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
            try
                obj.setStatus('Loading saved run...'); drawnow;
                obj.activateRecord(hover.loadRun(folder));
                obj.setStatus(['Loaded: ' char(obj.ActiveRecord.Label)]);
            catch err, obj.showError(err.message); end
        end

        function activateRecord(obj,record)
            obj.ActiveRecord=record;
            folder=char(record.Folder);
            if ismember(folder,obj.UI.RunList.ItemsData), obj.UI.RunList.Value=folder; end
            if ismember(folder,obj.UI.DefaultRun.ItemsData), obj.UI.DefaultRun.Value=folder; end
            obj.UI.RunInfo.Text=sprintf('%s | %d signals\n%s',char(record.Created),numel(record.Signals),char(record.Label));
            obj.UI.SavedSettings.Data=obj.flatten(record.Settings,'');
            obj.UI.Metadata.Value=cellstr(splitlines(string(jsonencode(record.Metadata,'PrettyPrint',true))));
            obj.refreshSignals(); obj.drawDefaults();
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
            if ~isfield(info,'Node') || isempty(info.Node) || isempty(info.Node.NodeData), return; end
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
            if isempty(obj.ActiveRecord), return; end
            mode=obj.UI.PlotMode.Value;
            if strcmp(mode,'Create a new plot'), obj.newPlot(); end
            ax=obj.currentAxes();
            if strcmp(mode,'Replace active plot'), cla(ax); end
            hold(ax,'on');
            for idx=indices(:)'
                s=obj.ActiveRecord.Signals(idx);
                id=char(obj.ActiveRecord.ID);
                displayName=sprintf('%s | %s [%s] (%s)',obj.ActiveRecord.Label,s.Name,s.Unit,id(end-5:end));
                h=plot(ax,s.Time,s.Data,'LineWidth',1.3,'DisplayName',displayName);
                h.UserData=struct('RunID',obj.ActiveRecord.ID,'SignalKey',s.Key,'Unit',s.Unit);
            end
            hold(ax,'off'); grid(ax,'on'); xlabel(ax,'Time (s)');
            lines=findobj(ax,'Type','line'); units=strings(0,1);
            for k=1:numel(lines), units(end+1)=string(lines(k).UserData.Unit); end %#ok<AGROW>
            units=unique(units,'stable');
            ylabel(ax,char(strjoin(units,' / '))); title(ax,'Run comparison','Interpreter','none');
            legend(ax,'show','Interpreter','none','Location','best');
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
            ax=obj.currentAxes(); cla(ax); legend(ax,'off'); title(ax,'Double-click a signal to begin');
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
            try, hover.defaultPlots(obj.DefaultAxes,obj.ActiveRecord);
            catch err, obj.showError(err.message); end
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
            if isvalid(obj.App.UIFigure), obj.App.StatusLabel.Text=char(text); end
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
            obj.cleanupSimulation();
            if ~isempty(obj.FirmwareEditor) && isvalid(obj.FirmwareEditor), delete(obj.FirmwareEditor); end
            if ~isempty(obj.PollTimer) && isvalid(obj.PollTimer)
                stop(obj.PollTimer); delete(obj.PollTimer);
            end
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
