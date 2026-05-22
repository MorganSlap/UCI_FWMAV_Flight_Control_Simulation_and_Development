function plot_multi_axis_pid_ff()
% plot_multi_axis_pid_ff
%
% Create a conceptual diagram of the cascaded angle + rate PID + feedforward
% structure for all three axes (roll, pitch, yaw) using digraph/plot.
% The figure has three subplots:
%   1) Roll axis: Angle loop + Rate PID + FF
%   2) Pitch axis: Angle loop + Rate PID + FF
%   3) Yaw axis: Rate PID + FF (no outer angle loop in Angle mode)

    figure('Name','Multi-Axis Angle + Rate PID + Feedforward','NumberTitle','off');
    
    %----------------------------------------------------------------------
    % 1) Roll Axis
    %----------------------------------------------------------------------
    subplot(3,1,1);
    G_roll = build_axis_graph('Roll', 'Roll Stick (ch\_roll)', true);  % hasOuterAngleLoop
    plot_axis_graph(G_roll, 'Roll Axis: Angle Loop + Rate PID + Feedforward');
    
    %----------------------------------------------------------------------
    % 2) Pitch Axis
    %----------------------------------------------------------------------
    subplot(3,1,2);
    G_pitch = build_axis_graph('Pitch', 'Pitch Stick (ch\_pitch)', true); % hasOuterAngleLoop
    plot_axis_graph(G_pitch, 'Pitch Axis: Angle Loop + Rate PID + Feedforward');
    
    %----------------------------------------------------------------------
    % 3) Yaw Axis
    %----------------------------------------------------------------------
    subplot(3,1,3);
    G_yaw = build_axis_graph('Yaw', 'Yaw Stick (ch\_yaw)', false);       % rate-only
    plot_axis_graph(G_yaw, 'Yaw Axis: Rate PID + Feedforward (No Outer Angle Loop)');
end


%======================================================================
% Helper: build digraph for a single axis (Roll/Pitch/Yaw)
%======================================================================
function G = build_axis_graph(axisName, stickLabel, hasOuterAngleLoop)
    % axisName: 'Roll' | 'Pitch' | 'Yaw'
    % stickLabel: text for stick input node
    % hasOuterAngleLoop: true for roll/pitch, false for yaw
    
    % Use cell arrays for edges (from,to) to avoid dimension issues.
    edges = {};   % each row: {fromNodeName, toNodeName}
    nodes = {};   % each row: {NodeName, Label}
    
    % Canonical node names (string names used in edges)
    Stick      = [axisName 'Stick'];
    RCScale    = [axisName 'RCScale'];
    AngleCmd   = [axisName 'AngleCmd'];
    EstAngle   = [axisName 'EstAngle'];
    AngleErr   = [axisName 'AngleErr'];
    AngleP     = [axisName 'AngleP'];
    RateSp     = [axisName 'RateSp'];
    GyroRate   = [axisName 'GyroRate'];
    RateErr    = [axisName 'RateErr'];
    Pgain      = [axisName 'Pgain'];
    Igain      = [axisName 'Igain'];
    Integrator = [axisName 'Integrator'];
    Dfilter    = [axisName 'Dfilter'];
    Delay      = [axisName 'Delay'];
    DeltaSp    = [axisName 'DeltaSp'];
    InvTs      = [axisName 'InvTs'];
    FFGain     = [axisName 'FFGain'];
    SumAll     = [axisName 'SumAll'];
    Output     = [axisName 'Output'];
    
    %------------------------------------------------------------------
    % Node labels
    %------------------------------------------------------------------
    % Stick input
    nodes(end+1,:) = {Stick, stickLabel};
    
    % RC scale
    if hasOuterAngleLoop
        rcScaleLabel = sprintf('%s RC Scaling\\n%s_angle_cmd = max_angle * stick', ...
                               axisName, lower(axisName));
    else
        rcScaleLabel = sprintf('%s RC Scaling\\n%s_rate_sp = max_rate * stick', ...
                               axisName, lower(axisName));
    end
    nodes(end+1,:) = {RCScale, rcScaleLabel};
    
    % Outer loop nodes (roll/pitch)
    if hasOuterAngleLoop
        nodes(end+1,:) = {AngleCmd,  sprintf('%s_angle_cmd (deg)', lower(axisName))};
        nodes(end+1,:) = {EstAngle,  sprintf('%s_est (deg)', lower(axisName))};
        nodes(end+1,:) = {AngleErr,  'e_angle = cmd - est'};
        nodes(end+1,:) = {AngleP,    sprintf('Angle P-gain\\n%s_rate_sp = Kp_angle * e_angle', ...
                                             lower(axisName))};
        nodes(end+1,:) = {RateSp,    sprintf('%s_rate_sp (deg/s)', lower(axisName))};
    else
        % Yaw: directly rate setpoint from RC
        nodes(end+1,:) = {RateSp,    sprintf('%s_rate_sp (deg/s)', lower(axisName))};
    end
    
    % Gyro rate
    nodes(end+1,:) = {GyroRate, sprintf('gyro %s rate (deg/s)', lower(axisName))};
    
    % Rate loop & PID
    nodes(end+1,:) = {RateErr,    'e_rate = rate_sp - gyro'};
    nodes(end+1,:) = {Pgain,      'P: Kp'};
    nodes(end+1,:) = {Igain,      'I: Ki'};
    nodes(end+1,:) = {Integrator, 'Integrator\\nI_out = ∫ Ki * e_rate dt'};
    nodes(end+1,:) = {Dfilter,    'D path\\nDerivative + LPF'};
    
    % FF path
    nodes(end+1,:) = {Delay,   'Unit Delay z^{-1}\\nrate_sp_prev'};
    nodes(end+1,:) = {DeltaSp, 'Δrate_sp = rate_sp - rate_sp_prev'};
    nodes(end+1,:) = {InvTs,   'Gain 1/Ts\\n d_rate_sp = Δrate_sp/Ts'};
    nodes(end+1,:) = {FFGain,  'FF Gain K_ff\\nFF_term = K_ff * d_rate_sp'};
    
    % Sum + output
    nodes(end+1,:) = {SumAll,  sprintf('u_%s = P + I + D + FF', lower(axisName))};
    nodes(end+1,:) = {Output,  sprintf('u_%s (to Mixer)', lower(axisName))};
    
    %------------------------------------------------------------------
    % Edges (cell array of {from, to})
    %------------------------------------------------------------------
    % Stick -> RC
    edges(end+1,:) = {Stick, RCScale};
    
    if hasOuterAngleLoop
        % RCScale -> AngleCmd -> AngleErr, plus EstAngle
        edges(end+1,:) = {RCScale, AngleCmd};
        edges(end+1,:) = {AngleCmd, AngleErr};
        edges(end+1,:) = {EstAngle, AngleErr};
        
        % AngleErr -> AngleP -> RateSp
        edges(end+1,:) = {AngleErr, AngleP};
        edges(end+1,:) = {AngleP,   RateSp};
    else
        % Yaw: RCScale directly produces RateSp
        edges(end+1,:) = {RCScale, RateSp};
    end
    
    % RateSp and GyroRate -> RateErr
    edges(end+1,:) = {RateSp,   RateErr};
    edges(end+1,:) = {GyroRate, RateErr};
    
    % PID
    edges(end+1,:) = {RateErr, Pgain};
    edges(end+1,:) = {RateErr, Igain};
    edges(end+1,:) = {RateErr, Dfilter};
    edges(end+1,:) = {Igain,   Integrator};
    
    % FF path
    edges(end+1,:) = {RateSp, Delay};
    edges(end+1,:) = {RateSp, DeltaSp};
    edges(end+1,:) = {Delay,  DeltaSp};
    edges(end+1,:) = {DeltaSp, InvTs};
    edges(end+1,:) = {InvTs,  FFGain};
    
    % Sum + output
    edges(end+1,:) = {Pgain,      SumAll};
    edges(end+1,:) = {Integrator, SumAll};
    edges(end+1,:) = {Dfilter,    SumAll};
    edges(end+1,:) = {FFGain,     SumAll};
    edges(end+1,:) = {SumAll,     Output};
    
    % Build digraph from cell arrays
    G = digraph(edges(:,1), edges(:,2));
    
    % Attach labels
    G.Nodes.NodeLabel = nodes(:,2);
end


%======================================================================
% Helper: plot a single axis digraph with coloring
%======================================================================
function plot_axis_graph(G, plotTitle)
    nodeLabels = G.Nodes.NodeLabel;
    nodeNames  = G.Nodes.Name;
    
    h = plot(G, ...
        'Layout',      'layered', ...
        'Direction',   'right', ...
        'NodeLabel',   nodeLabels, ...
        'Interpreter', 'tex', ...   % allow \n and subscripts
        'ArrowSize',   9, ...
        'LineWidth',   1.2);
    
    title(plotTitle, 'Interpreter','none');
    
    % Heuristic grouping by name patterns
    isStick      = contains(nodeNames, 'Stick');
    isRC         = contains(nodeNames, 'RCScale') | contains(nodeNames, 'AngleCmd');
    isAngleLoop  = contains(nodeNames, 'AngleErr') | contains(nodeNames, 'AngleP') | contains(nodeNames, 'EstAngle');
    isRateLoop   = contains(nodeNames, 'RateErr') | contains(nodeNames, 'Pgain') | ...
                   contains(nodeNames, 'Igain')  | contains(nodeNames, 'Integrator') | ...
                   contains(nodeNames, 'Dfilter') | contains(nodeNames, 'GyroRate');
    isFF         = contains(nodeNames, 'Delay') | contains(nodeNames, 'DeltaSp') | ...
                   contains(nodeNames, 'InvTs') | contains(nodeNames, 'FFGain');
    isSumOut     = contains(nodeNames, 'SumAll') | contains(nodeNames, 'Output');
    
    stickColor   = [0.85 0.92 1.00];   % light blue
    rcColor      = [0.90 0.95 1.00];   % slightly different blue
    angleColor   = [0.95 0.95 1.00];   % very light blue/gray
    rateColor    = [0.95 0.95 0.95];   % light gray
    ffColor      = [1.00 0.95 0.85];   % light orange
    sumOutColor  = [0.90 1.00 0.90];   % light green
    
    highlight(h, find(isStick),    'NodeColor', stickColor);
    highlight(h, find(isRC),       'NodeColor', rcColor);
    highlight(h, find(isAngleLoop),'NodeColor', angleColor);
    highlight(h, find(isRateLoop), 'NodeColor', rateColor);
    highlight(h, find(isFF),       'NodeColor', ffColor);
    highlight(h, find(isSumOut),   'NodeColor', sumOutColor);
end