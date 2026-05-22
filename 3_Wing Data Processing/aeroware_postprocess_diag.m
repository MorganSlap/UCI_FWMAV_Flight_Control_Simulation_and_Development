function aeroware_postprocess_diag
% AEROWARE_POSTPROCESS_DIAG
% AeroWare postprocessor with diagnostic logging, robust error handling,
% and NON-STANDARD mapping requested by user:
%   Lift   = PGB Axial
%   Thrust = PGB Normal
%
% Extras:
% - FFT plots show only the frequency range covering the FIRST 10 PEAKS.
% - Thrust vs Lift uses reduced marker size (75% smaller) and best linear fit
%   is drawn; slope & intercept shown in the plot title.
%
% Output summary CSV is saved to the SAME DIRECTORY as this script.

clc; clear; close all;
fprintf('\n=========================================\n');
fprintf('🌀  AeroWare Postprocessing Diagnostic Run\n');
fprintf('=========================================\n\n');

tStart = tic;
stage = "";

try
    %% === 1. File Selection ===
    stage = 'File Selection';
    logmsg(stage, 'Prompting user to select CSV file... (≈10 s)');
    [fname, fpath] = uigetfile({'*.csv','CSV Files (*.csv)'}, 'Select AeroWare CSV');
    if isequal(fname,0)
        logmsg(stage, 'User cancelled selection. Exiting.');The DelFly: Design, Aerodynamics, and Artificial Intelligence of a Flapping Wing Robot
        return;
    end
    fullfile_in = fullfile(fpath, fname);
    logmsg(stage, ['File selected: ', fullfile_in]);

    %% === 2. Read Headers ===
    stage = 'Header Parsing';
    logmsg(stage, 'Reading first two header rows to verify format... (≈1 s)');
    headers = readcell(fullfile_in, 'NumHeaderLines', 0);
    assert(size(headers,1) >= 2, 'File missing expected two header rows (names + units).');

    col_names = string(headers(1,:));      % Row 1: signal names
    col_units = string(headers(2,:));      % Row 2: units

    % Required fields
    req = ["Time","PGB Axial","PGB Normal"];
    for r = req
        assert(any(strcmpi(col_names,r)), ...
            sprintf('Missing required column "%s" in the header row.', r));
    end
    logmsg(stage, 'Header verification complete.');
    fprintf('⚙️  Mapping for this run:  Lift ← PGB Axial,  Thrust ← PGB Normal (non-standard)\n\n');

    %% === 3. Data Import ===
    stage = 'Data Import';
    logmsg(stage, 'Reading numeric data block... (≈3 s)');
    opts = detectImportOptions(fullfile_in);
    opts.DataLines = [3 Inf];                       % data starts after two header rows
    if any(strcmpi(opts.VariableNames,'Time'))
        opts = setvaropts(opts, 'Time', 'Type', 'char');
    end
    T = readtable(fullfile_in, opts);
    logmsg(stage, sprintf('Imported %d rows × %d columns.', height(T), width(T)));

    %% === 4. Parse & Clean Data ===
    stage = 'Data Parsing';
    logmsg(stage, 'Parsing timestamps and extracting channels... (≈2 s)');

    % Column indices in original header
    idxTime   = find(strcmpi(col_names,"Time"), 1);
    idxAxial  = find(strcmpi(col_names,"PGB Axial"), 1);
    idxNormal = find(strcmpi(col_names,"PGB Normal"), 1);

    % Units (lift uses axial units; thrust uses normal units)
    unitsLift   = safeUnit(col_units, idxAxial,  "Units");
    unitsThrust = safeUnit(col_units, idxNormal, "Units");

    % Pull raw columns by position
    timeStr = string(T{:, idxTime});

    % NON-STANDARD mapping:
    % Lift   ← PGB Axial
    % Thrust ← PGB Normal
    lift   = toNumeric(T{:, idxAxial});
    thrust = toNumeric(T{:, idxNormal});

    % Parse time — AeroWare styles
    dt = parseAerowareTime(timeStr);
    assert(~any(isnat(dt)), 'Unable to parse some time entries in Time column.');
    t = seconds(dt - dt(1));
    dt_s  = seconds(diff(dt));
    Fs = 1/median(dt_s(~isnan(dt_s) & isfinite(dt_s)));   % estimated sample rate
    dur_s = seconds(dt(end) - dt(1));

    logmsg(stage, sprintf('Parsed %.0f samples; estimated Fs=%.2f Hz; duration=%.3f s.', ...
        numel(t), Fs, dur_s));

    %% === 5. Compute Statistics ===
    stage = 'Statistics Computation';
    logmsg(stage, 'Calculating extrema and basic stats... (<1 s)');
    [minLift,   iMinLift]   = min(lift,   [], 'omitnan');
    [maxLift,   iMaxLift]   = max(lift,   [], 'omitnan');
    [minThrust, iMinThrust] = min(thrust, [], 'omitnan');
    [maxThrust, iMaxThrust] = max(thrust, [], 'omitnan');

    %% === 6. FFTs ===
    stage = 'FFT Computation';
    logmsg(stage, 'Performing FFT for Lift and Thrust... (≈2 s)');
    [freq, fftLift]   = simpleFFT(lift,   Fs);   % Lift spectrum (from Axial)
    [~,    fftThrust] = simpleFFT(thrust, Fs);   % Thrust spectrum (from Normal)

    %% === 7. Visualization ===
    stage = 'Visualization';
    logmsg(stage, 'Building diagnostic dashboard window... (≈2–3 s)');
    fig = uifigure('Name','AeroWare Diagnostic (Lift=Axial, Thrust=Normal)', ...
                   'Position',[80 80 1400 900]);
    gl = uigridlayout(fig,[3,3]);
    gl.RowHeight    = {160, '1x', '1x'};
    gl.ColumnWidth  = {'1x','1x','1x'};

    addSummaryPanel(gl, fname, Fs, dur_s, t, lift, thrust, ...
        maxLift, minLift, iMaxLift, iMinLift, ...
        maxThrust, minThrust, iMaxThrust, iMinThrust, ...
        unitsLift, unitsThrust);

    addPlots(gl, t, lift, thrust, freq, fftLift, fftThrust, unitsLift, unitsThrust);

    %% === 8. Save Results (to directory of this script) ===
    stage = 'Summary CSV Export';
    logmsg(stage, 'Writing summary CSV to script directory... (<1 s)');

    scriptDir = fileparts(mfilename('fullpath'));     % directory of this script
    [~,base,~] = fileparts(fname);
    outCSV = fullfile(scriptDir, base + "_postprocess_summary.csv");
    outfig = fullfile(scriptDir, base + "_postprocess_summary.fig");

    % writeSummary(outCSV, fname, Fs, dur_s, t, lift, thrust, ...
    %     maxLift, minLift, iMaxLift, iMinLift, ...
    %     maxThrust, minThrust, iMaxThrust, iMinThrust, ...
    %     freq, fftLift, fftThrust, unitsLift, unitsThrust);
    logmsg(stage, ['Summary saved to: ', outCSV]);
    saveas(fig,outfig) % save figure
    %% === Finished ===
    logmsg('Complete', sprintf('✅ Postprocessing complete in %.2f s total.', toc(tStart)));

catch ME
    fprintf(2,'\n❌ ERROR in stage: [%s]\n   → %s\n\n', stage, ME.message);
    if ~isempty(ME.stack)
        stk = ME.stack(1);
        fprintf(2,'   (File: %s, Line: %d)\n', stk.file, stk.line);
    end
end
end

%% ---------- Helper Utilities ----------

function logmsg(stage,msg)
fprintf('🔹 [%s] %s\n', stage, msg);
end

function u = safeUnit(row, idx, fallback)
if idx<=numel(row) && strlength(row(idx))>0
    u = strtrim(row(idx));
else
    u = fallback;
end
end

function x = toNumeric(x)
% Convert text/strings/cells to double robustly
if istable(x), x = table2array(x); end
if iscell(x),  x = string(x); end
if isstring(x)
    x = double(str2double(strtrim(x)));
elseif ischar(x)
    x = double(str2double(strtrim(string(x))));
else
    x = double(x);
end
end

function dt = parseAerowareTime(ts)
% Parse common AeroWare formats like 'ddMMyy HH:mm:ss.SSSSSS'
fmtList = ["ddMMyy HH:mm:ss.SSSSSS", ...
           "ddMMyy HH:mm:ss.SSSS", ...
           "ddMMyy HH:mm:ss.SSS", ...
           "MM/dd/yy HH:mm:ss.SSSSSS", ...
           "MM/dd/uuuu HH:mm:ss.SSSSSS"];
for k = 1:numel(fmtList)
    try
        dt = datetime(ts, 'InputFormat', fmtList(k), 'TimeZone', 'local');
        if ~any(isnat(dt))
            return;
        end
    catch
        % try next
    end
end
% final fallback
try
    dt = datetime(ts, 'TimeZone','local');
catch
    dt = NaT(size(ts));
end
end

function [f, A] = simpleFFT(sig, Fs)
% Single-sided amplitude spectrum
sig = sig(:);
sig = sig - mean(sig,'omitnan');
sig(~isfinite(sig)) = 0;

N = numel(sig);
Nfft = 2^nextpow2(N);
Y = fft(sig, Nfft);
P2 = abs(Y/N);
P1 = P2(1:Nfft/2+1);
if numel(P1) > 2
    P1(2:end-1) = 2*P1(2:end-1);
end
f = Fs*(0:(Nfft/2))/Nfft;
A = P1;
end

function fmax = firstNPeaksLimit(freq, amp, N)
% Find x-limit so the FIRST N peaks are visible; pad by 10%.
% Independent of Signal Processing Toolbox (manual local-max detection).
freq = freq(:); amp = amp(:);
if numel(freq) ~= numel(amp), error('firstNPeaksLimit: size mismatch'); end

% Ignore DC (index 1); search interior points
if numel(amp) < 5
    fmax = max(freq); return
end
ii = 2:(numel(amp)-1);
isPeak = (amp(ii) > amp(ii-1)) & (amp(ii) >= amp(ii+1));

% Drop tiny peaks (2% of max) to avoid noise
promThresh = 0.02 * max(amp);
cand = ii(isPeak & amp(ii) >= promThresh);

if isempty(cand)
    fmax = min(max(freq), max(freq)/5 * 1.1);
    return
end

cand = cand(1:min(N, numel(cand)));          % first N peaks in frequency order
fmax = 1.10 * max(freq(cand));               % 10% headroom
fmax = min(fmax, max(freq));                 % never exceed Nyquist
if fmax <= 0, fmax = max(freq)/10; end
end

function addSummaryPanel(gl, fname, Fs, dur, t, lift, thrust, ...
    maxLift, minLift, iMaxLift, iMinLift, maxThrust, minThrust, iMaxThrust, iMinThrust, ...
    unitsLift, unitsThrust)

p = uipanel(gl,'Title','Summary'); p.Layout.Row = 1; p.Layout.Column = [1 3];
g = uigridlayout(p,[1,4]); g.ColumnWidth = {'1x','1x','1x','1x'};
txt = @(s) uitextarea(g,'Value',s,'Editable','off');

txt({sprintf('File: %s',fname), ...
     sprintf('Duration: %.3f s',dur), ...
     sprintf('Fs (est.): %.2f Hz',Fs), ...
     sprintf('Samples: %d',numel(t))});

txt({sprintf('LIFT   (PGB Axial)   [%s]', unitsLift), ...
     sprintf('Max: %.6g @ t=%.3fs', maxLift,   t(iMaxLift)), ...
     sprintf('Min: %.6g @ t=%.3fs', minLift,   t(iMinLift)), ...
     sprintf('Mean: %.6g | Std: %.6g', mean(lift,'omitnan'), std(lift,'omitnan'))});

txt({sprintf('THRUST (PGB Normal) [%s]', unitsThrust), ...
     sprintf('Max: %.6g @ t=%.3fs', maxThrust, t(iMaxThrust)), ...
     sprintf('Min: %.6g @ t=%.3fs', minThrust, t(iMinThrust)), ...
     sprintf('Mean: %.6g | Std: %.6g', mean(thrust,'omitnan'), std(thrust,'omitnan'))});

txt({'Notes:', ...
     '- Time parsed from AeroWare ''Time'' column', ...
     '- Lift = PGB Axial; Thrust = PGB Normal (non-standard mapping)', ...
     '- FFTs show first 10 peaks (auto-limited x-range); single-sided spectra'});
end

function addPlots(gl, t, lift, thrust, freq, fftLift, fftThrust, unitsLift, unitsThrust)
% Time series
ax1 = uiaxes(gl); ax1.Layout.Row = 2; ax1.Layout.Column = [1 2];
plot(ax1, t, lift,   'DisplayName', sprintf('Lift (PGB Axial) [%s]', unitsLift)); hold(ax1,'on');
plot(ax1, t, thrust, 'DisplayName', sprintf('Thrust (PGB Normal) [%s]', unitsThrust));
grid(ax1,'on'); legend(ax1,'Location','best');
xlabel(ax1,'Time [s]'); ylabel(ax1,'Force'); title(ax1,'Time Series: Lift & Thrust');

% Thrust vs Lift (reduced marker size, linear fit)
ax2 = uiaxes(gl); ax2.Layout.Row = 2; ax2.Layout.Column = 3;
hold(ax2,'on');
% 75% smaller than typical -> use small size (default ~36 for scatter), set to 9
scatter(ax2, lift, thrust, 9, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName','Data');
% Best linear fit: thrust ≈ m*lift + b
valid = isfinite(lift) & isfinite(thrust);
if any(valid)
    p = polyfit(lift(valid), thrust(valid), 1);
    m = p(1); b = p(2);
    xfit = linspace(min(lift(valid)), max(lift(valid)), 200);
    yfit = polyval(p, xfit);
    plot(ax2, xfit, yfit, 'LineWidth', 1.5, 'DisplayName','Linear fit');
    title(ax2, sprintf('Thrust vs Lift  (fit: y = %.3g x + %.3g)', m, b));
else
    title(ax2, 'Thrust vs Lift (insufficient valid data for fit)');
end
grid(ax2,'on');
xlabel(ax2, sprintf('Lift (PGB Axial) [%s]', unitsLift));
ylabel(ax2, sprintf('Thrust (PGB Normal) [%s]', unitsThrust));
legend(ax2,'Location','best');

% FFT: Lift (limit to first 10 peaks)
ax3 = uiaxes(gl); ax3.Layout.Row = 3; ax3.Layout.Column = 1;
plot(ax3, freq, fftLift, 'DisplayName','FFT(Lift)');
grid(ax3,'on'); xlabel(ax3,'Frequency [Hz]'); ylabel(ax3,'Amplitude');
title(ax3,'FFT of Lift (PGB Axial)'); legend(ax3,'Location','northeast');
try
    fmaxL = firstNPeaksLimit(freq, fftLift, 10);
    xlim(ax3, [0, fmaxL]);
catch
    % fallback: leave default
end

% FFT: Thrust (limit to first 10 peaks)
ax4 = uiaxes(gl); ax4.Layout.Row = 3; ax4.Layout.Column = 2;
plot(ax4, freq, fftThrust, 'DisplayName','FFT(Thrust)');
grid(ax4,'on'); xlabel(ax4,'Frequency [Hz]'); ylabel(ax4,'Amplitude');
title(ax4,'FFT of Thrust (PGB Normal)'); legend(ax4,'Location','northeast');
try
    fmaxT = firstNPeaksLimit(freq, fftThrust, 10);
    xlim(ax4, [0, fmaxT]);
catch
    % fallback: leave default
end

% Spacer panel
sp = uipanel(gl,'Title',''); 
sp.Layout.Row = 3; 
sp.Layout.Column = 3;
end

function writeSummary(outCSV, fname, Fs, dur, t, lift, thrust, ...
    maxLift, minLift, iMaxLift, iMinLift, ...
    maxThrust, minThrust, iMaxThrust, iMinThrust, ...
    freq, fftLift, fftThrust, unitsLift, unitsThrust)

fid = fopen(outCSV,'w');
assert(fid>0, 'Could not open output CSV for writing: %s', outCSV);

fprintf(fid,'AeroWare Diagnostic Summary (Lift=Axial, Thrust=Normal)\n');
fprintf(fid,'File,%s\n', fname);
fprintf(fid,'Duration_s,%.6f\nFs_Hz,%.3f\n', dur, Fs);
fprintf(fid,'Lift_Units,%s\nThrust_Units,%s\n', unitsLift, unitsThrust);

fprintf(fid,'Lift_Max,%.9g\nLift_Max_t_s,%.6f\n', maxLift,   t(iMaxLift));
fprintf(fid,'Lift_Min,%.9g\nLift_Min_t_s,%.6f\n', minLift,   t(iMinLift));
fprintf(fid,'Lift_Mean,%.9g\nLift_Std,%.9g\n',   mean(lift,'omitnan'),   std(lift,'omitnan'));

fprintf(fid,'Thrust_Max,%.9g\nThrust_Max_t_s,%.6f\n', maxThrust, t(iMaxThrust));
fprintf(fid,'Thrust_Min,%.9g\nThrust_Min_t_s,%.6f\n', minThrust, t(iMinThrust));
fprintf(fid,'Thrust_Mean,%.9g\nThrust_Std,%.9g\n',   mean(thrust,'omitnan'), std(thrust,'omitnan'));

fprintf(fid,'\nFrequency_Hz,FFT_Lift,FFT_Thrust\n');
fclose(fid);

% Append FFT block
writematrix([freq(:), fftLift(:), fftThrust(:)], outCSV, 'WriteMode','append');
end
