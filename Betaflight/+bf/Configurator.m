classdef Configurator < handle
    %CONFIGURATOR Native editor for the compiled Betaflight CLI catalog.
    % Public getConfiguration/setConfiguration support script integration
    % and UI tests without executing firmware or changing the plant model.
    properties (SetAccess=private)
        Figure
        Config
        Schema
        UI = struct()
        LastError = ''
    end
    properties
        AppliedFcn = []
    end
    properties (Access=private)
        Rows = []
        SelectedItem = []
        Updating = false
    end

    methods
        function obj=Configurator(config)
            if nargin<1, config=bf.hoverConfig(); end
            bf.validateConfig(config);
            obj.Config=config;
            obj.Schema=bf.parseCliSettings(config.SchemaText);
            obj.build();
            obj.refreshAll();
        end

        function config=getConfiguration(obj)
            config=obj.Config;
        end

        function setConfiguration(obj,config)
            bf.validateConfig(config);
            obj.Config=config;
            obj.Schema=bf.parseCliSettings(config.SchemaText);
            obj.SelectedItem=[];
            obj.refreshAll();
        end

        function setSchemaText(obj,text)
            obj.Config.SchemaText=char(join(string(text),newline));
            obj.Schema=bf.parseCliSettings(obj.Config.SchemaText);
            obj.SelectedItem=[];
            obj.refreshAll();
        end

        function setValue(obj,name,value,scope,index)
            if nargin<4, scope='master'; end
            if nargin<5, index=0; end
            found=find(strcmp({obj.Schema.Name},name)&strcmp({obj.Schema.Scope},scope),1);
            if isempty(found)
                error('bf:UnknownSetting','%s is absent from the loaded firmware catalog.',name);
            end
            obj.Config=bf.setSetting(obj.Config,obj.Schema(found),value,index);
            obj.refreshAll();
            obj.status(sprintf('Updated %s. Apply to bfConfig before running.',name));
        end

        function apply(obj)
            bf.validateConfig(obj.Config);
            assignin('base','bfConfig',obj.Config);
            if ~isempty(obj.AppliedFcn), obj.AppliedFcn(obj.Config); end
            obj.status('Applied. The next simulation uses this firmware configuration.');
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn=[];
                delete(obj.Figure);
            end
        end
    end

    methods (Access=private)
        function build(obj)
            tokens=bf.theme();
            obj.Figure=uifigure('Name','Betaflight | Simulation Configurator','Theme','dark', ...
                'CloseRequestFcn',@(~,~)delete(obj));
            obj.Figure.WindowState='maximized';
            obj.Figure.UserData=obj;
            root=uigridlayout(obj.Figure,[4 1]);
            root.RowHeight={70,40,'1x',32}; root.Padding=[18 12 18 14]; root.RowSpacing=10;
            header=uigridlayout(root,[2 2]); header.RowHeight={32,22};
            header.ColumnWidth={'1x',280}; header.Padding=[0 0 0 0];
            title=uilabel(header,'Text','BETAFLIGHT  /  SIMULATION','FontSize',24,'FontWeight','bold', ...
                'FontColor',tokens.primary); title.Layout.Row=1; title.Layout.Column=1;
            obj.UI.Identity=uilabel(header,'Text','Compiled firmware settings','FontSize',12);
            obj.UI.Identity.Layout.Row=2; obj.UI.Identity.Layout.Column=1;
            obj.UI.Count=uilabel(header,'HorizontalAlignment','right','FontWeight','bold');
            obj.UI.Count.Layout.Row=[1 2]; obj.UI.Count.Layout.Column=2;

            toolbar=uigridlayout(root,[1 6]); toolbar.Padding=[0 0 0 0];
            toolbar.ColumnWidth={118,118,118,158,'1x',190};
            uibutton(toolbar,'Text','Load config...','ButtonPushedFcn',@(~,~)obj.loadDialog());
            uibutton(toolbar,'Text','Save JSON...','ButtonPushedFcn',@(~,~)obj.saveDialog('.json'));
            uibutton(toolbar,'Text','Export CLI...','ButtonPushedFcn',@(~,~)obj.saveDialog('.cli'));
            uibutton(toolbar,'Text','Import firmware catalog...','ButtonPushedFcn',@(~,~)obj.importCatalog());
            obj.UI.File=uilabel(toolbar,'Text','Unsaved configuration');
            obj.UI.Apply=uibutton(toolbar,'Text','Apply to bfConfig','FontWeight','bold', ...
                'BackgroundColor',tokens.primary,'FontColor',tokens.onPrimary, ...
                'ButtonPushedFcn',@(~,~)obj.safe(@()obj.apply()));

            obj.UI.Tabs=uitabgroup(root);
            tuningTab=uitab(obj.UI.Tabs,'Title','PID tuning');
            obj.buildTuning(tuningTab);
            settingsTab=uitab(obj.UI.Tabs,'Title','All firmware settings');
            obj.buildSettings(settingsTab);
            receiverTab=uitab(obj.UI.Tabs,'Title','Receiver');
            obj.buildCommands(receiverTab,'Receiver',{'map','rxrange','rxfail'}, ...
                'Channel mapping, receiver ranges and channel failsafe commands. Values come from the complete CLI document.', ...
                'Receiver and failsafe');
            modesTab=uitab(obj.UI.Tabs,'Title','Modes');
            obj.buildCommands(modesTab,'Modes',{'aux','adjrange'}, ...
                'Firmware mode and adjustment commands. AUX channel indexes and mode IDs use the captured firmware CLI conventions.', '');
            mixerTab=uitab(obj.UI.Tabs,'Title','Mixer');
            obj.buildCommands(mixerTab,'Mixer',{'mixer','mmix','smix','servo'}, ...
                'Firmware motor/servo mixer commands. The simulation adapter separately maps motor output to the plant actuator order and pot units.', ...
                'Motors and mixer');
            cliTab=uitab(obj.UI.Tabs,'Title','Complete CLI');
            g=uigridlayout(cliTab,[3 1]); g.RowHeight={50,'1x',34};
            uilabel(g,'Text',['Complete replay document, including all profiles, receiver configuration, modes, features and mixer commands. ' ...
                'Edits are stored as text and interpreted by the actual firmware when the simulation starts.'], ...
                'WordWrap','on');
            obj.UI.CLI=uitextarea(g,'FontName','Consolas','ValueChangedFcn',@(~,~)obj.cliEdited());
            obj.UI.CLICommit=uibutton(g,'Text','Use this CLI document', ...
                'ButtonPushedFcn',@(~,~)obj.cliEdited());
            obj.UI.Status=uilabel(root,'Text','Ready','WordWrap','on');
        end

        function buildTuning(obj,tab)
            g=uigridlayout(tab,[5 1]);
            g.RowHeight={40,145,50,180,40}; g.Padding=[22 18 22 18]; g.RowSpacing=12; g.Scrollable='on';
            bar=uigridlayout(g,[1 3]); bar.ColumnWidth={'1x',110,130}; bar.Padding=[0 0 0 0];
            uilabel(bar,'Text','RATE CONTROLLER','FontSize',20,'FontWeight','bold');
            uilabel(bar,'Text','PID profile');
            obj.UI.TuningProfile=uidropdown(bar,'Items',{'0'}, ...
                'ValueChangedFcn',@(src,~)obj.profileChanged('profile',src.Value));
            obj.UI.PID=uitable(g,'Data',zeros(3,4), ...
                'ColumnName',{'Proportional / P','Integral / I','Derivative / D','Feedforward / F'}, ...
                'RowName',{'ROLL','PITCH','YAW'},'ColumnWidth',{'auto','auto','auto','auto'}, ...
                'ColumnEditable',true(1,4),'FontSize',17, ...
                'CellEditCallback',@(~,evt)obj.pidEdited(evt));
            uilabel(g,'Text',['Native Betaflight values. The hover preset uses a custom four-flapper mixer. ' ...
                'Simplified tuning can overwrite manual gains; its mode is shown below. ' ...
                'Changes apply to the next run after you press Apply.'],'WordWrap','on');
            cards=uigridlayout(g,[1 3]); cards.ColumnWidth={'1x','1x','1x'}; cards.Padding=[0 0 0 0];
            titles={'ANGLE MODE','FILTERS','FEEDFORWARD & I-TERM'};
            fields={{'angle_p_gain','angle_limit','simplified_pids_mode'}, ...
                {'gyro_lpf1_static_hz','dterm_lpf1_static_hz','dterm_lpf2_static_hz'}, ...
                {'feedforward_smooth_factor','anti_gravity_gain','iterm_relax'}};
            obj.UI.Quick=struct();
            for k=1:3
                panel=uipanel(cards,'Title',titles{k},'FontWeight','bold');
                grid=uigridlayout(panel,[4 2]); grid.RowHeight={42,42,42,'1x'}; grid.ColumnWidth={'1x',100};
                for j=1:numel(fields{k})
                    name=fields{k}{j}; item=obj.Schema(strcmp({obj.Schema.Name},name));
                    if isempty(item), continue; end
                    item=item(1);
                    uilabel(grid,'Text',strrep(name,'_',' '),'WordWrap','on','Tooltip',name);
                    if strcmp(item.Type,'choice')
                        control=uidropdown(grid,'Items',item.Choices, ...
                            'ValueChangedFcn',@(src,~)obj.quickEdited(name,src.Value));
                    else
                        control=uieditfield(grid,'numeric', ...
                            'ValueChangedFcn',@(src,~)obj.quickEdited(name,src.Value));
                    end
                    control.Tooltip=item.Constraint;
                    obj.UI.Quick.(name)=control;
                end
            end
            actions=uigridlayout(g,[1 4]); actions.RowHeight={40}; actions.Padding=[0 0 0 0];
            uibutton(actions,'Text','All PID settings','ButtonPushedFcn',@(~,~)obj.showGroup('PID and feedforward'));
            uibutton(actions,'Text','Filters','ButtonPushedFcn',@(~,~)obj.showGroup('Filters'));
            uibutton(actions,'Text','Rates & RC smoothing','ButtonPushedFcn',@(~,~)obj.showGroup('Rates and smoothing'));
            uibutton(actions,'Text','Sensors & attitude','ButtonPushedFcn',@(~,~)obj.showGroup('Sensors and attitude'));
        end

        function pidEdited(obj,event)
            if obj.Updating || isempty(event.Indices), return; end
            axes={'roll','pitch','yaw'}; terms={'p','i','d','f'};
            name=[terms{event.Indices(2)} '_' axes{event.Indices(1)}];
            obj.safe(@()obj.setValue(name,event.NewData,'profile',obj.indexFor('profile')));
            obj.refreshAll();
        end

        function quickEdited(obj,name,value)
            if obj.Updating, return; end
            item=obj.Schema(strcmp({obj.Schema.Name},name)); item=item(1);
            obj.safe(@()obj.setValue(name,value,item.Scope,obj.indexFor(item.Scope)));
            obj.refreshAll();
        end

        function buildSettings(obj,tab)
            g=uigridlayout(tab,[3 1]); g.RowHeight={42,40,'1x'};
            filters=uigridlayout(g,[1 3]); filters.ColumnWidth={'1x',225,180}; filters.Padding=[0 0 0 0];
            obj.UI.Search=uieditfield(filters,'text','Placeholder','Search parameter, value, or constraint...', ...
                'ValueChangedFcn',@(~,~)obj.refreshTable());
            obj.UI.Group=uidropdown(filters,'Items',{'All groups'},'ValueChangedFcn',@(~,~)obj.refreshTable());
            obj.UI.Scope=uidropdown(filters,'Items',{'All scopes','master','profile','rateprofile','battery_profile'}, ...
                'ValueChangedFcn',@(~,~)obj.refreshTable());
            profiles=uigridlayout(g,[1 6]); profiles.ColumnWidth={110,'1x',110,'1x',110,'1x'}; profiles.Padding=[0 0 0 0];
            uilabel(profiles,'Text','PID profile');
            obj.UI.Profile=uidropdown(profiles,'Items',{'0'},'ValueChangedFcn',@(src,~)obj.profileChanged('profile',src.Value));
            uilabel(profiles,'Text','Rate profile');
            obj.UI.Rateprofile=uidropdown(profiles,'Items',{'0'},'ValueChangedFcn',@(src,~)obj.profileChanged('rateprofile',src.Value));
            uilabel(profiles,'Text','Battery profile');
            obj.UI.Batteryprofile=uidropdown(profiles,'Items',{'0'},'ValueChangedFcn',@(src,~)obj.profileChanged('battery_profile',src.Value));
            main=uigridlayout(g,[1 2]); main.ColumnWidth={'1x',310}; main.Padding=[0 0 0 0];
            obj.UI.Settings=uitable(main,'Data',cell(0,5),'ColumnName',{'Parameter','Value','Scope','Group','Allowed values'}, ...
                'ColumnEditable',[false true false false false],'ColumnWidth',{260,180,95,150,'auto'}, ...
                'RowName',{},'CellEditCallback',@(~,evt)obj.tableEdited(evt), ...
                'CellSelectionCallback',@(~,evt)obj.tableSelected(evt));
            panel=uipanel(main,'Title','Selected parameter');
            detail=uigridlayout(panel,[7 1]); detail.RowHeight={55,25,115,36,36,36,'1x'};
            obj.UI.SelectedName=uilabel(detail,'Text','Choose a parameter','WordWrap','on','FontWeight','bold','FontSize',15);
            obj.UI.SelectedScope=uilabel(detail,'Text','');
            obj.UI.Constraint=uitextarea(detail,'Editable','off','Value',{'Limits come directly from the compiled firmware.'});
            obj.UI.Value=uieditfield(detail,'text','Enable','off');
            obj.UI.Choice=uidropdown(detail,'Items',{'No selection'},'Enable','off', ...
                'ValueChangedFcn',@(src,~)set(obj.UI.Value,'Value',src.Value));
            obj.UI.SetValue=uibutton(detail,'Text','Update value','Enable','off', ...
                'ButtonPushedFcn',@(~,~)obj.detailEdited());
            uilabel(detail,'Text',['The table also supports direct value editing. Global values apply to every profile. ' ...
                'Profile selectors are zero-based, as in the firmware CLI.'], 'WordWrap','on','VerticalAlignment','top');
        end

        function buildCommands(obj,tab,key,prefixes,description,group)
            g=uigridlayout(tab,[4 1]); g.RowHeight={58,34,'1x',34};
            uilabel(g,'Text',description,'WordWrap','on');
            tools=uigridlayout(g,[1 2]); tools.ColumnWidth={230,'1x'}; tools.Padding=[0 0 0 0];
            button=uibutton(tools,'Text','Show related firmware settings', ...
                'ButtonPushedFcn',@(~,~)obj.showGroup(group));
            if isempty(group), button.Enable='off'; end
            uilabel(tools,'Text',['Commands: ' strjoin(prefixes,', ')],'WordWrap','on');
            obj.UI.([key 'Commands'])=uitextarea(g,'FontName','Consolas', ...
                'ValueChangedFcn',@(~,~)obj.commandsEdited(key));
            obj.UI.([key 'Prefixes'])=prefixes;
            uibutton(g,'Text',['Update ' lower(key) ' commands'], ...
                'ButtonPushedFcn',@(~,~)obj.commandsEdited(key));
        end

        function refreshAll(obj)
            obj.Updating=true;
            cleanup=onCleanup(@()obj.finishedUpdating());
            profiles=bf.cliProfiles(obj.Config.CLI,obj.Schema);
            obj.updateProfileDrop(obj.UI.Profile,profiles.profile,profiles.SelectedProfile);
            obj.updateProfileDrop(obj.UI.TuningProfile,profiles.profile,profiles.SelectedProfile);
            obj.updateProfileDrop(obj.UI.Rateprofile,profiles.rateprofile,profiles.SelectedRateprofile);
            obj.updateProfileDrop(obj.UI.Batteryprofile,profiles.battery_profile,profiles.SelectedBatteryprofile);
            values=bf.readCliValues(obj.Config.CLI,obj.Schema);
            axes={'roll','pitch','yaw'}; terms={'p','i','d','f'};
            pid=zeros(3,4);
            for axis=1:3
                for term=1:4
                    item=obj.Schema(strcmp({obj.Schema.Name},[terms{term} '_' axes{axis}]));
                    if ~isempty(item), pid(axis,term)=str2double(bf.settingValue(obj.Config.CLI,item(1),profiles.SelectedProfile,values)); end
                end
            end
            obj.UI.PID.Data=pid;
            names=fieldnames(obj.UI.Quick);
            for k=1:numel(names)
                name=names{k}; item=obj.Schema(strcmp({obj.Schema.Name},name)); item=item(1);
                value=bf.settingValue(obj.Config.CLI,item,obj.indexFor(item.Scope),values);
                if strcmp(item.Type,'choice'), obj.UI.Quick.(name).Value=value;
                else, obj.UI.Quick.(name).Value=str2double(value); end
            end
            selected=obj.UI.Group.Value;
            groups=[{'All groups'} unique({obj.Schema.Group},'stable')];
            obj.UI.Group.Items=groups;
            if ismember(selected,groups), obj.UI.Group.Value=selected; end
            obj.UI.CLI.Value=cellstr(splitlines(string(obj.Config.CLI)));
            keys={'Receiver','Modes','Mixer'};
            for k=1:numel(keys)
                key=keys{k};
                section=bf.commandSection(obj.Config,obj.UI.([key 'Prefixes']));
                obj.UI.([key 'Commands']).Value=cellstr(splitlines(string(section)));
            end
            obj.UI.Count.Text=sprintf('%d captured firmware settings',numel(obj.Schema));
            fields=fieldnames(obj.Config.Firmware); identity=strings(0,1);
            for k=1:numel(fields)
                item=obj.Config.Firmware.(fields{k});
                if (ischar(item)||isstring(item)) && isscalar(string(item))
                    identity(end+1)=string(fields{k})+": "+string(item); %#ok<AGROW>
                end
            end
            if isempty(identity), identity="Firmware identity follows the loaded capture"; end
            obj.UI.Identity.Text=char(join(identity,' | '));
            obj.UI.Identity.Tooltip=obj.UI.Identity.Text;
            if all(isfield(obj.Config.Firmware,{'Version','Commit'}))
                obj.UI.Identity.Text=sprintf('%s  |  SITL flight stack  |  commit %.12s', ...
                    obj.Config.Firmware.Version,obj.Config.Firmware.Commit);
            end
            obj.refreshTable();
            if isempty(obj.Schema)
                obj.status('No compiled firmware catalog loaded. Import its get output, or reopen after the build captures it. Complete CLI editing is available.');
            end
        end

        function finishedUpdating(obj)
            obj.Updating=false;
        end

        function updateProfileDrop(~,drop,indexes,selected)
            if isempty(indexes)
                drop.Items={'Not captured'}; drop.Value='Not captured'; drop.Enable='off';
            else
                drop.Items=cellstr(string(sort(indexes)));
                if ismember(selected,indexes), drop.Value=char(string(selected));
                else, drop.Value=drop.Items{1}; end
                drop.Enable='on';
            end
        end

        function refreshTable(obj)
            data=cell(0,5); rows=[];
            query=lower(string(obj.UI.Search.Value)); group=obj.UI.Group.Value; scope=obj.UI.Scope.Value;
            seen=strings(0,1);
            values=bf.readCliValues(obj.Config.CLI,obj.Schema);
            for k=1:numel(obj.Schema)
                item=obj.Schema(k); key=string(item.Name)+"|"+string(item.Scope);
                if any(seen==key), continue; end
                seen(end+1)=key; %#ok<AGROW>
                if ~strcmp(group,'All groups') && ~strcmp(group,item.Group), continue; end
                if ~strcmp(scope,'All scopes') && ~strcmp(scope,item.Scope), continue; end
                value=bf.settingValue(obj.Config.CLI,item,obj.indexFor(item.Scope),values);
                if strlength(query)>0 && ~contains(lower(string(strjoin({item.Name,value,item.Constraint,item.Group},' '))),query)
                    continue;
                end
                data(end+1,:)={item.Name,value,item.Scope,item.Group,item.Constraint}; %#ok<AGROW>
                rows(end+1)=k; %#ok<AGROW>
            end
            obj.Rows=rows; obj.UI.Settings.Data=data;
            if ~isempty(obj.SelectedItem) && obj.SelectedItem<=numel(obj.Schema)
                obj.showSelected(obj.SelectedItem);
            else
                obj.UI.Value.Enable='off'; obj.UI.Choice.Enable='off'; obj.UI.SetValue.Enable='off';
            end
        end

        function index=indexFor(obj,scope)
            switch scope
                case 'profile', value=obj.UI.Profile.Value;
                case 'rateprofile', value=obj.UI.Rateprofile.Value;
                case 'battery_profile', value=obj.UI.Batteryprofile.Value;
                otherwise, value='0';
            end
            index=str2double(value);
            if ~isfinite(index), index=0; end
        end

        function tableSelected(obj,event)
            if isempty(event.Indices), return; end
            row=event.Indices(1,1);
            if row<=numel(obj.Rows), obj.showSelected(obj.Rows(row)); end
        end

        function showSelected(obj,index)
            obj.SelectedItem=index; item=obj.Schema(index);
            value=bf.settingValue(obj.Config.CLI,item,obj.indexFor(item.Scope));
            obj.UI.SelectedName.Text=item.Name;
            obj.UI.SelectedScope.Text=sprintf('%s  |  index %d',item.Scope,obj.indexFor(item.Scope));
            obj.UI.Constraint.Value={item.Constraint;['Firmware default: ' item.Default]};
            obj.UI.Value.Value=value; obj.UI.Value.Enable='on'; obj.UI.SetValue.Enable='on';
            if strcmp(item.Type,'choice') && ~isempty(item.Choices)
                obj.UI.Choice.Items=item.Choices;
                if ismember(value,item.Choices), obj.UI.Choice.Value=value; end
                obj.UI.Choice.Enable='on';
            else
                obj.UI.Choice.Items={'Enter value above'}; obj.UI.Choice.Enable='off';
            end
        end

        function tableEdited(obj,event)
            if obj.Updating || isempty(event.Indices), return; end
            row=event.Indices(1); item=obj.Schema(obj.Rows(row));
            obj.safe(@()obj.setValue(item.Name,event.NewData,item.Scope,obj.indexFor(item.Scope)));
            obj.refreshTable();
        end

        function detailEdited(obj)
            if isempty(obj.SelectedItem), return; end
            item=obj.Schema(obj.SelectedItem);
            obj.safe(@()obj.setValue(item.Name,obj.UI.Value.Value,item.Scope,obj.indexFor(item.Scope)));
        end

        function profileChanged(obj,scope,value)
            if obj.Updating, return; end
            obj.Config=bf.selectProfile(obj.Config,scope,str2double(value));
            obj.refreshAll();
            obj.status(sprintf('Selected %s %s; edits now apply to this profile.',scope,value));
        end

        function commandsEdited(obj,key)
            if obj.Updating, return; end
            obj.safe(@()obj.commitCommands(key));
        end

        function commitCommands(obj,key)
            value=join(string(obj.UI.([key 'Commands']).Value),newline);
            [~,obj.Config]=bf.commandSection(obj.Config,obj.UI.([key 'Prefixes']),value);
            obj.refreshAll();
            obj.status([key ' commands updated. Firmware validates their syntax when the simulation starts.']);
        end

        function cliEdited(obj)
            if obj.Updating, return; end
            obj.Config.CLI=char(join(string(obj.UI.CLI.Value),newline));
            obj.refreshAll();
            obj.status('Complete CLI document updated. Apply to bfConfig before running.');
        end

        function showGroup(obj,group)
            obj.UI.Search.Value=''; obj.UI.Scope.Value='All scopes';
            if ismember(group,obj.UI.Group.Items), obj.UI.Group.Value=group; end
            obj.UI.Tabs.SelectedTab=ancestor(obj.UI.Settings,'uitab');
            obj.refreshTable();
        end

        function loadDialog(obj)
            [name,path]=uigetfile({'*.json;*.cli;*.txt','Betaflight configuration'},'Load configuration');
            if isequal(name,0), return; end
            obj.safe(@()obj.loadFile(fullfile(path,name)));
        end

        function loadFile(obj,filename)
            config=bf.loadConfig(filename,obj.Config.SchemaText,obj.Config.Firmware);
            if isempty(config.SchemaText), config.SchemaText=obj.Config.SchemaText; end
            obj.setConfiguration(config); obj.UI.File.Text=filename;
            obj.status('Loaded configuration. Apply to bfConfig to use it for a simulation.');
        end

        function saveDialog(obj,extension)
            [name,path]=uiputfile(['*' extension],'Save configuration',['betaflight-config' extension]);
            if isequal(name,0), return; end
            filename=fullfile(path,name);
            obj.safe(@()bf.saveConfig(filename,obj.Config));
            if isempty(obj.LastError), obj.UI.File.Text=filename; obj.status(['Saved ' filename]); end
        end

        function importCatalog(obj)
            [name,path]=uigetfile({'*.txt;*.cli','Captured firmware get output'},'Import firmware setting catalog');
            if isequal(name,0), return; end
            obj.safe(@()obj.setSchemaText(fileread(fullfile(path,name))));
        end

        function safe(obj,action)
            obj.LastError='';
            try
                action();
            catch exception
                obj.LastError=exception.message;
                obj.status(exception.message);
                uialert(obj.Figure,exception.message,'Configuration could not be updated');
            end
        end

        function status(obj,text)
            obj.UI.Status.Text=char(text);
        end
    end
end
