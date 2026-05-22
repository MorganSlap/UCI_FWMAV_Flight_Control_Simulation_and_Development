function aeroware_postprocess
% AEROWARE_POSTPROCESS
% 1) Prompt for AeroWare CSV
% 2) Verify required columns (Time, PGB Axial, PGB Normal)
% 3) Parse units, compute duration & stats
% 4) Show single UI with all required plots/info
% 5) Save a single CSV with summary + FFT data

try
    % ---- 1) FILE PICKER ----
    [fname, fpath] = uigetfile({'*.csv','CSV Files (*.csv)'}, 'Select AeroWare CSV');
    if isequal(fname,0)
        return; % user cancelled
    end
    fullfile_in = fullfile(fpath, fname);

    % ---- 2) READ HEADERS (NAMES + UNITS) ----
    headers = readcell(fullfile_in, 'NumHeaderLines', 0);
    if size(headers,1) < 2
        error('Expected two header rows: names (row 1) and units (row 2).');
    end
    col_names = headers(1,:);  % first row: names
    col_units = headers(2,:);  % second row: units

    % make sure they are strings
    col_names = string(col_names);
    col_units = string(col_units);

    % Required signals
    req = ["Time","PGB Axial","PGB Normal"];
    for r = req
        if ~any(strcmpi(col_names, r))
            error('Missing required column "%s" in the header row.', r);
        end
    end

    % Column indices
    idxTime   = find(strcmpi(col_names,"Time"), 1);
    idxAxial  = find(strcmpi(col_names,"PGB Axial"), 1);
    idxNormal = find(strcmpi(col_names,"PGB Normal"), 1);

    % Units for display
    unitsAxial  = safeUnit(col_units, idxAxial, "Units");
    unitsNormal = safeUnit(col_units, idxNormal, "Units");

    % ---- 3) READ DATA LINES ----
    opts = detectImportOptions(fullfile_in);
    % Data start after 2 header rows
    opts.DataLines = [3 Inf];
    % Avoid overly clever type guessing for mixed columns
    opts = setvaropts(opts, 'Time', 'Type', 'char');
    T = readtable(fullfile_in, opts);

    % Coerce numeric columns if they came in as text with leading spaces
    T.(T.Properties.VariableNames{idxAxial - 0}) = toNumeric(T{:, idxAxial - (0)}); %#ok<NASGU>
    T.(T.Properties.VariableNames{idxNormal - 0}) = toNumeric(T{:, idxNormal - (0)}); %#ok<NASGU>

    % Re-fetch by names in case detectImportOptions renamed columns
    timeColName   = T.Properties.VariableNames{matchName(T.Properties.VariableNames, col_names(idxTime))};
    axialColName  = T.Properties.VariableNames{matchName(T.Properties.VariableNames, col_names(idxAxial))};
    normalColName = T.Properties.VariableNames{matchName(T.Properties.VariableNames, col_names(idxNormal))};

    % Extract raw vectors
    timeStr = string(T.(timeColName));
    thrust  = toNumeric(T.(axialColName));   % PGB Axial
    lift    = toNumeric(T.(normalColName));  % PGB Normal

    % Parse time
    % Format expected: 'ddMMyy HH:mm:ss.SSSSSS' (e.g., 041125 15:31:10.517959)
    dt = parseAerowareTime(timeStr);
    if any(isnat(dt))
        error('Failed to parse some Time entries. Check the Time column format.');
    end
    t = seconds(dt - dt(1));    % time in seconds, starting at 0

    % Determine sampling frequency (robust to small jitter)
    dt_s  = seconds(diff(dt));
    Fs    = 1/median(dt_s(~isnan(dt_s) & isfinite(dt_s)));  % Hz
    dur_s = seconds(dt(end) - dt(1));

    % ---- Compute stats ----
    [minThrust, minThrustIdx] = min(thrust, [], 'omitnan');
    [maxThrust, maxThrustIdx] = max(thrust, [], 'omitnan');
    [minLift,   minLiftIdx]   = min(lift,   [], 'omitnan');
    [maxLift,   maxLiftIdx]   = max(lift,   [], 'omitnan');

    % ---- FFTs (single-sided amplitude spectra) ----
    [freq, fftLift]   = simpleFFT(lift, Fs);
    [~,    fftThrust] = simpleFFT(thrust, Fs);

    % ---- 4) UI DIALOG WITH EVERYTHING ----
    fig = uifigure('Name','AeroWare Postprocessor','Position',[80 80 1400 900]);
    gl  = uigridlayout(fig,[3,3]); gl.RowHeight = {160,'1x','1x'}; gl.ColumnWidth = {'1x','1x','1x'};

    % Summary panel (top row spanning all columns)
    pSummary = uipanel(gl, 'Title','Summary'); pSummary.Layout.Row = 1; pSummary.Layout.Column = [1 3];
    g2 = uigridlayout(pSummary,[1,4]); g2.ColumnWidth = {'1x','1x','1x','1x'};

    % Summary text blocks
    lbl1 = uitextarea(g2,'Editable','off');
    lbl2 = uitextarea(g2,'Editable','off');
    lbl3 = uitextarea(g2,'Editable','off');
    lbl4 = uitextarea(g2,'Editable','off');

    lbl1.Value = { ...
        sprintf('File: %s', fname), ...
        sprintf('Duration: %.3f s', dur_s), ...
        sprintf('Samples: %d', numel(t)), ...
        sprintf('Fs (est.): %.2f Hz', Fs)};

    lbl2.Value = { ...
        sprintf('THRUST (PGB Axial) [%s]', unitsAxial), ...
        sprintf('Max: %.6g @ t=%.3fs', maxThrust, t(maxThrustIdx)), ...
        sprintf('Min: %.6g @ t=%.3fs', minThrust, t(minThrustIdx)), ...
        sprintf('Mean: %.6g | Std: %.6g', mean(thrust,'omitnan'), std(thrust,'omitnan'))};

    lbl3.Value = { ...
        sprintf('LIFT (PGB Normal) [%s]', unitsNormal), ...
        sprintf('Max: %.6g @ t=%.3fs', maxLift, t(maxLiftIdx)), ...
        sprintf('Min: %.6g @ t=%.3fs', minLift, t(minLiftIdx)), ...
        sprintf('Mean: %.6g | Std: %.6g', mean(lift,'omitnan'), std(lift,'omitnan'))};

    lbl4.Value = { ...
        'Notes:', ...
        '- Time parsed from AeroWare ''Time'' column', ...
        '- Lift = PGB Normal; Thrust = PGB Axial', ...
        '- FFTs use single-sided amplitude spectra'};

    % Time series: Lift, Thrust
    ax1 = uiaxes(gl); ax1.Layout.Row = 2; ax1.Layout.Column = [1 2];
    plot(ax1, t, lift, 'DisplayName', sprintf('Lift (PGB Normal) [%s]', unitsNormal)); hold(ax1,'on');
    plot(ax1, t, thrust, 'DisplayName', sprintf('Thrust (PGB Axial) [%s]', unitsAxial));
    grid(ax1,'on'); legend(ax1,'Location','best');
    xlabel(ax1,'Time [s]');
    ylabel(ax1,'Force / Moment Units');
    title(ax1,'Time Series: Lift & Thrust');

    % Scatter: Thrust vs Lift
    ax2 = uiaxes(gl); ax2.Layout.Row = 2; ax2.Layout.Column = 3;
    plot(ax2, lift, thrust, '.', 'DisplayName','Thrust vs Lift');
    grid(ax2,'on'); xlabel(ax2, sprintf('Lift (PGB Normal) [%s]', unitsNormal));
    ylabel(ax2, sprintf('Thrust (PGB Axial) [%s]', unitsAxial));
    title(ax2,'Thrust vs. Lift'); legend(ax2,'Location','best');

    % FFT: Lift
    ax3 = uiaxes(gl); ax3.Layout.Row = 3; ax3.Layout.Column = 1;
    plot(ax3, freq, fftLift, 'DisplayName','FFT(Lift)');
    grid(ax3,'on'); xlabel(ax3,'Frequency [Hz]'); ylabel(ax3,'Amplitude');
    title(ax3,'FFT of Lift (PGB Normal)'); legend(ax3,'Location','northeast');

    % FFT: Thrust
    ax4 = uiaxes(gl); ax4.Layout.Row = 3; ax4.Layout.Column = 2;
    plot(ax4, freq, fftThrust, 'DisplayName','FFT(Thrust)');
    grid(ax4,'on'); xlabel(ax4,'Frequency [Hz]'); ylabel(ax4,'Amplitude');
    title(ax4,'FFT of Thrust (PGB Axial)'); legend(ax4,'Location','northeast');

    % Empty spacer or could add controls
    dummy = uipanel(gl,'Title',''); dummy.Layout.Row = 3; dummy.Layout.Column = 3;

    % ---- 5) SAVE SUMMARY CSV (one file) ----
    % We will create a single CSV with:
    % - Key/Value metadata rows
    % - Blank row separator
    % - FFT block: freq_hz, fft_lift, fft_thrust
    [~,base,~] = fileparts(fname);
    outCSV = fullfile(fpath, base + "_postprocess_summary.csv");
    writelines("AeroWare Postprocess Summary", outCSV);
    appendKV(outCSV, "Input File", fname);
    appendKV(outCSV, "Duration_s", sprintf("%.6f", dur_s));
    appendKV(outCSV, "Samples", sprintf("%d", numel(t)));
    appendKV(outCSV, "Fs_Hz_est", sprintf("%.6f", Fs));
    appendKV(outCSV, "Thrust_Units", unitsAxial);
    appendKV(outCSV, "Lift_Units", unitsNormal);
    appendKV(outCSV, "Thrust_Max", sprintf("%.9g", maxThrust));
    appendKV(outCSV, "Thrust_Max_t_s", sprintf("%.6f", t(maxThrustIdx)));
    appendKV(outCSV, "Thrust_Min", sprintf("%.9g", minThrust));
    appendKV(outCSV, "Thrust_Min_t_s", sprintf("%.6f", t(minThrustIdx)));
    appendKV(outCSV, "Thrust_Mean", sprintf("%.9g", mean(thrust,'omitnan')));
    appendKV(outCSV, "Thrust_Std", sprintf("%.9g", std(thrust,'omitnan')));
    appendKV(outCSV, "Lift_Max", sprintf("%.9g", maxLift));
    appendKV(outCSV, "Lift_Max_t_s", sprintf("%.6f", t(maxLiftIdx)));
    appendKV(outCSV, "Lift_Min", sprintf("%.9g", minLift));
    appendKV(outCSV, "Lift_Min_t_s", sprintf("%.6f", t(minLiftIdx)));
    appendKV(outCSV, "Lift_Mean", sprintf("%.9g", mean(lift,'omitnan')));
    appendKV(outCSV, "Lift_Std", sprintf("%.9g", std(lift,'omitnan')));

    % Blank separator row
    writelines("", outCSV, WriteMode="append");
    writelines("freq_hz,fft_lift,fft_thrust", outCSV, WriteMode="append");

    % Combine FFT columns
    M = [freq(:), fftLift(:), fftThrust(:)];
    writematrix(M, outCSV, WriteMode="append");

    uialert(fig, sprintf("Saved summary CSV:\n%s", outCSV), 'Saved', 'Icon','success');

catch ME
    errordlg(ME.message, 'AeroWare Postprocess Error');
end
end

% ---------- Helpers ----------

function idx = matchName(varnames, rawName)
% Try to match a raw header name to table var names (MATLAB may mangle names)
rawName = string(rawName);
varnames = string(varnames);
% direct match first
idx = find(strcmp(varnames, rawName), 1);
if ~isempty(idx); return; end
% case-insensitive
idx = find(strcmpi(varnames, rawName), 1);
if ~isempty(idx); return; end
% fallback: remove non-word characters and compare
r1 = regexprep(rawName, '\W', '');
cand = regexprep(varnames, '\W', '');
idx = find(strcmpi(cand, r1), 1);
if isempty(idx)
    error('Could not match column "%s" in the imported table.', rawName);
end
end

function u = safeUnit(unitsRow, idx, fallback)
if idx > 0 && idx <= numel(unitsRow) && strlength(unitsRow(idx))>0
    u = strtrim(unitsRow(idx));
else
    u = fallback;
end
end

function x = toNumeric(x)
% Convert to double if strings/char with leading spaces etc.
if istable(x); x = table2array(x); end
if iscell(x);  x = string(x); end
if isstring(x)
    x = double(str2double(strtrim(x)));
elseif ischar(x)
    x = double(str2double(strtrim(string(x))));
else
    x = double(x);
end
end

function dt = parseAerowareTime(ts)
% Parse 'ddMMyy HH:mm:ss.SSSSSS'
% If parsing fails, attempt a couple of alternates.
fmtList = ["ddMMyy HH:mm:ss.SSSSSS", ...
           "ddMMyy HH:mm:ss.SSSSS", ...
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
        % keep trying
    end
end
% final attempt with automatic detection
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
P2 = abs(Y/N);                 % two-sided amplitude
P1 = P2(1:Nfft/2+1);           % single-sided
P1(2:end-1) = 2*P1(2:end-1);   % scale except DC and Nyquist
f = Fs*(0:(Nfft/2))/Nfft;
A = P1;
end

function appendKV(csvpath, key, val)
% Append 'key,value' line to CSV
writelines(sprintf('%s,%s', key, val), csvpath, WriteMode="append");
end
