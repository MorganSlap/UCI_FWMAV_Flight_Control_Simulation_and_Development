%% estimate_quadflapper_ssest.m
% Estimate a 6-state attitude/rate state-space model for the Quadflapper
% from Betaflight Blackbox Excel data, then insert the result into an
% editable 12-state model structure.
%
% Requires: System Identification Toolbox
%
% Measured/output states used for identification:
%   x6 = [roll; pitch; yaw; p; q; r]
%
% Default actuator inputs:
%   u4 = [motor0; motor1; motor2; motor3] + 1000
% because this Blackbox file stores motor channels roughly as 0--1000 style
% values, while the existing Quadflapper model expects throttle/pot values
% in the 1000--2000 range.
%
% The script estimates deviations about hover, so the identified model is:
%   dx6_dev/dt = A6c*x6_dev + B6c*u4_dev       continuous-time version
% or
%   x6_dev[k+1] = A6d*x6_dev[k] + B6d*u4_dev[k] discrete-time version
%
% Edit the USER SETTINGS section to change the hover time window, input
% source, decimation, or the 6-state-to-12-state mapping.

clear; clc; close all;

%% USER SETTINGS
xlsxFile = "flight 4-10-26 Blackbox Data.xlsx";
sheetName = "Data Collected";

% Choose input source:
%   "motorPlus1000" : u = motor[0:3] + 1000. Best if identifying actuator-to-attitude plant.
%   "motorRaw"      : u = motor[0:3]. Same data, without adding 1000 offset.
%   "rcCommand"     : u = rcCommand[0:3]. These are pilot roll/pitch/yaw/throttle commands, not four actuators.
inputMode = "motorPlus1000";

% Hover/data window in seconds after log start.
% Leave as NaN for automatic selection.
% For best results, manually set these after looking at the diagnostic plots.
tStart = NaN;
tEnd   = NaN;

% Decimation. Blackbox data here is probably very high rate.
% Identification is usually better-conditioned at 50--250 Hz for attitude dynamics.
decimFactor = 10;

% Use filtered or unfiltered gyro measurements for p,q,r.
gyroSource = "gyroADC";     % "gyroADC" or "gyroUnfilt"

% 12-state mapping. Change this to match your original model's state order.
% Common aerospace convention assumed here:
% x12 = [x;y;z; u;v;w; roll;pitch;yaw; p;q;r]
idx6_in_12 = [7 8 9 10 11 12];

% Existing 12-state model.
% Replace these with your current A/B matrices, or load them before running.
A12_base = zeros(12,12);
B12_base = zeros(12,4);

% Identification order. You requested 6 states:
% [roll pitch yaw p q r]
nx = 6;

%% LOAD BLACKBOX DATA
opts = detectImportOptions(xlsxFile, ...
    "Sheet", sheetName, ...
    "VariableNamingRule", "preserve");

T = readtable(xlsxFile, opts);

% Time appears to be in microseconds in this Blackbox export.
tRaw = T.("time");
t = (tRaw - tRaw(1))*1e-6;
Ts = median(diff(t), "omitnan");

fprintf("Loaded %d samples.\n", height(T));
fprintf("Median raw sample time: %.6f s, %.1f Hz\n", Ts, 1/Ts);

%% BUILD MEASURED STATE MATRIX y = [roll pitch yaw p q r]
roll  = T.("heading[0]");
pitch = T.("heading[1]");
yaw   = unwrap(T.("heading[2]"));

switch gyroSource
    case "gyroADC"
        p = T.("gyroADC[0]");
        q = T.("gyroADC[1]");
        r = T.("gyroADC[2]");

    case "gyroUnfilt"
        p = T.("gyroUnfilt[0]");
        q = T.("gyroUnfilt[1]");
        r = T.("gyroUnfilt[2]");

    otherwise
        error("Unsupported gyroSource: %s", gyroSource);
end

% Betaflight gyro columns are normally deg/s in Blackbox exports.
% Convert to rad/s.
p = deg2rad(p);
q = deg2rad(q);
r = deg2rad(r);

Y = [roll pitch yaw p q r];

stateNames = ["roll_rad", ...
              "pitch_rad", ...
              "yaw_rad", ...
              "p_radps", ...
              "q_radps", ...
              "r_radps"];

%% BUILD INPUT MATRIX u = 4 channels
switch inputMode
    case "motorPlus1000"
        U = [T.("motor[0]") ...
             T.("motor[1]") ...
             T.("motor[2]") ...
             T.("motor[3]")] + 1000;

        inputNames = ["motor0_pot", ...
                      "motor1_pot", ...
                      "motor2_pot", ...
                      "motor3_pot"];

    case "motorRaw"
        U = [T.("motor[0]") ...
             T.("motor[1]") ...
             T.("motor[2]") ...
             T.("motor[3]")];

        inputNames = ["motor0_raw", ...
                      "motor1_raw", ...
                      "motor2_raw", ...
                      "motor3_raw"];

    case "rcCommand"
        U = [T.("rcCommand[0]") ...
             T.("rcCommand[1]") ...
             T.("rcCommand[2]") ...
             T.("rcCommand[3]")];

        inputNames = ["roll_cmd", ...
                      "pitch_cmd", ...
                      "yaw_cmd", ...
                      "throttle_cmd"];

    otherwise
        error("Unsupported inputMode: %s", inputMode);
end

%% PICK HOVER WINDOW
valid = all(isfinite(Y),2) & all(isfinite(U),2) & isfinite(t);

if isnan(tStart) || isnan(tEnd)

    % Automatic hover-ish selection.
    % This is only a starting point. You should manually override tStart/tEnd
    % after inspecting the plot.
    angleGate = abs(roll) < deg2rad(12) & abs(pitch) < deg2rad(15);

    rateGate = abs(p) < deg2rad(120) & ...
               abs(q) < deg2rad(120) & ...
               abs(r) < deg2rad(150);

    inputGate = mean(U,2) > prctile(mean(U,2), 25);

    hoverMask = valid & angleGate & rateGate & inputGate;

    % Use longest contiguous valid segment.
    [i1, i2] = longestTrueRun(hoverMask);

    if isempty(i1)
        warning("Automatic hover selection failed. Using all valid samples.");
        hoverMask = valid;
        [i1, i2] = longestTrueRun(hoverMask);
    end

else
    hoverMask = valid & t >= tStart & t <= tEnd;
    idx = find(hoverMask);

    if isempty(idx)
        error("No samples found between tStart and tEnd.");
    end

    i1 = idx(1);
    i2 = idx(end);
end

fprintf("Selected identification window: %.3f s to %.3f s.\n", t(i1), t(i2));
fprintf("Samples before decimation: %d\n", sum(hoverMask));

%% DIAGNOSTIC PLOTS FOR WINDOW SELECTION
figure("Name", "Quadflapper Blackbox Data - Window Selection");
tiledlayout(3,1);

nexttile;
plot(t, rad2deg([roll pitch]));
grid on;
hold on;
xline(t(i1));
xline(t(i2));
ylabel("roll/pitch [deg]");
legend("roll", "pitch", "start", "end");

nexttile;
plot(t, rad2deg([p q r]));
grid on;
hold on;
xline(t(i1));
xline(t(i2));
ylabel("rates [deg/s]");
legend("p", "q", "r", "start", "end");

nexttile;
plot(t, U);
grid on;
hold on;
xline(t(i1));
xline(t(i2));
ylabel("inputs");
xlabel("time [s]");
legend(inputNames, "Location", "best");

%% EXTRACT, DECIMATE, AND REMOVE HOVER OPERATING POINT
Yw = Y(hoverMask,:);
Uw = U(hoverMask,:);
tw = t(hoverMask);

% Simple decimation.
Yw = Yw(1:decimFactor:end,:);
Uw = Uw(1:decimFactor:end,:);
tw = tw(1:decimFactor:end);

TsId = median(diff(tw), "omitnan");

x_hover = mean(Yw, 1, "omitnan");
u_hover = mean(Uw, 1, "omitnan");

Ydev = Yw - x_hover;
Udev = Uw - u_hover;

fprintf("Identification sample time after decimation: %.6f s, %.1f Hz\n", TsId, 1/TsId);
fprintf("Hover state x_hover = [roll pitch yaw p q r]:\n");
disp(x_hover);
fprintf("Hover input u_hover:\n");
disp(u_hover);

%% CREATE IDDATA OBJECT
z = iddata(Ydev, Udev, TsId, ...
    "OutputName", cellstr(stateNames), ...
    "InputName",  cellstr(inputNames), ...
    "TimeUnit", "seconds");

% Remove remaining constant offsets.
z = detrend(z, 0);

%% ESTIMATE 6-STATE MODEL USING SSEST
% Plain ssest(z,6) gives an arbitrary internal state basis.
% To make the state approximately equal to:
%   [roll pitch yaw p q r]
% initialize an idss model with fixed C = I and D = 0.
%
% Then A and B are directly usable as an attitude/rate state model.

A0 = eye(nx);
A0(1,4) = TsId;
A0(2,5) = TsId;
A0(3,6) = TsId;

B0 = zeros(nx,4);

C0 = eye(nx);
D0 = zeros(nx,4);

% K is the innovation/noise model.
K0 = zeros(nx,nx);

x0 = zeros(nx,1);

initSys = idss(A0, B0, C0, D0, K0, x0, TsId);

% Keep C and D fixed so measured outputs are the states.
initSys.Structure.C.Free = false(size(C0));
initSys.Structure.D.Free = false(size(D0));

% Estimate A, B, and K.
initSys.Structure.A.Free = true(size(A0));
initSys.Structure.B.Free = true(size(B0));
initSys.Structure.K.Free = true(size(K0));

opt = ssestOptions;
opt.Display = "on";
opt.Focus = "simulation";
opt.EnforceStability = true;
opt.SearchOptions.MaxIterations = 100;

sys6d = ssest(z, initSys, opt);
sys6d.Name = "Quadflapper hover attitude/rate model - discrete";

A6d = sys6d.A;
B6d = sys6d.B;
C6d = sys6d.C;
D6d = sys6d.D;

% Convert to continuous-time equivalent using ZOH.
sys6c = d2c(sys6d, "zoh");
sys6c.Name = "Quadflapper hover attitude/rate model - continuous";

A6c = sys6c.A;
B6c = sys6c.B;
C6c = sys6c.C;
D6c = sys6c.D;

fprintf("\nEstimated discrete-time A6d:\n");
disp(A6d);

fprintf("\nEstimated discrete-time B6d:\n");
disp(B6d);

fprintf("\nEstimated continuous-time A6c:\n");
disp(A6c);

fprintf("\nEstimated continuous-time B6c:\n");
disp(B6c);

%% VALIDATE / COMPARE
figure("Name", "Quadflapper ssest Validation");
compare(z, sys6d);
grid on;

figure("Name", "Quadflapper ssest Residuals");
resid(z, sys6d);

%% INSERT 6-STATE MODEL INTO EDITABLE 12-STATE MODEL
% Use continuous-time A/B for the original 12-state ODE-style model.
A12_est = A12_base;
B12_est = B12_base;

A12_est(idx6_in_12, idx6_in_12) = A6c;
B12_est(idx6_in_12, :) = B6c;

% Also provide a discrete-time 12-state version.
A12d_est = eye(12);
B12d_est = zeros(12,4);

A12d_est(idx6_in_12, idx6_in_12) = A6d;
B12d_est(idx6_in_12, :) = B6d;

%% SAVE RESULTS
resultsFile = "quadflapper_ssest_hover_model.mat";

save(resultsFile, ...
    "sys6d", "sys6c", ...
    "A6d", "B6d", "C6d", "D6d", ...
    "A6c", "B6c", "C6c", "D6c", ...
    "A12_est", "B12_est", ...
    "A12d_est", "B12d_est", ...
    "x_hover", "u_hover", ...
    "idx6_in_12", ...
    "inputMode", "gyroSource", "TsId", ...
    "stateNames", "inputNames");

fprintf("\nSaved identification results to %s\n", resultsFile);
fprintf("Use A12_est/B12_est as the continuous-time editable 12x12 and 12x4 matrices.\n");
fprintf("Use A12d_est/B12d_est as the discrete-time editable 12x12 and 12x4 matrices.\n");

%% LOCAL FUNCTION
function [i1, i2] = longestTrueRun(mask)
    mask = mask(:);
    d = diff([false; mask; false]);

    starts = find(d == 1);
    stops  = find(d == -1) - 1;

    if isempty(starts)
        i1 = [];
        i2 = [];
        return;
    end

    [~, k] = max(stops - starts + 1);

    i1 = starts(k);
    i2 = stops(k);
end