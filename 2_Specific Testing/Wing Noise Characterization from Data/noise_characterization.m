close all
clc

data = readtable('imu_log_35hz.csv');
time = (data.timestamp - data.timestamp(1))/1000;

plot(time,data.gyroscopeX)

meanX = mean(data.gyroscopeX)
stdX = std(data.gyroscopeX)

meanY = mean(data.gyroscopeY)
stdY = std(data.gyroscopeY)

meanZ = mean(data.gyroscopeZ)
stdZ = std(data.gyroscopeZ)

%% Amplitude Specturm Analysis----------------------------------------------

% x-data
x = data.gyroscopeX;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz
x = x - mean(x);

N = length(x);
Y = fft(x);

P2 = abs(Y)/N;                  % two-sided amplitude spectrum
P1 = P2(1:floor(N/2)+1);        % single-sided
P1(2:end-1) = 2*P1(2:end-1);    % preserve total amplitude

f = Fs*(0:floor(N/2))/N;

% find peaks in PSD
[pks,locs] = findpeaks(P1, f, ...
    'MinPeakProminence', max(P1)*0.05, ...
    'SortStr', 'descend');

% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)


figure(1);
subplot(3,1,1)
plot(f,P1,'LineWidth',1.5);hold on;
plot(locs(1:numPeaks),pks(1:numPeaks),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('Amplitude [deg/s]');
title('Single-Sided Amplitude Spectrum (GyroX)');
grid on; hold off

% y-data------------------------------------------------------------
y = data.gyroscopeY;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz
x = x - mean(x);

N = length(y);
Y = fft(y);

P2 = abs(Y)/N;                  % two-sided amplitude spectrum
P1 = P2(1:floor(N/2)+1);        % single-sided
P1(2:end-1) = 2*P1(2:end-1);    % preserve total amplitude

f = Fs*(0:floor(N/2))/N;

% find peaks in PSD
[pks,locs] = findpeaks(P1, f, ...
    'MinPeakProminence', max(P1)*0.05, ...
    'SortStr', 'descend');


% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)


figure(1);
subplot(3,1,2)
plot(f,P1,'LineWidth',1.5);hold on;
plot(locs(1:numPeaks),pks(1:numPeaks),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('Amplitude [deg/s]');
title('Single-Sided Amplitude Spectrum (GyroY)');
grid on; hold off;
% z-data------------------------------------------------------------
z = data.gyroscopeZ;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz
x = x - mean(x);

N = length(z);
Y = fft(z);

P2 = abs(Y)/N;                  % two-sided amplitude spectrum
P1 = P2(1:floor(N/2)+1);        % single-sided
P1(2:end-1) = 2*P1(2:end-1);    % preserve total amplitude

f = Fs*(0:floor(N/2))/N;

% find peaks in PSD
[pks,locs] = findpeaks(P1, f, ...
    'MinPeakProminence', max(P1)*0.05, ...
    'SortStr', 'descend');

% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)


figure(1);
subplot(3,1,3)
plot(f,P1,'LineWidth',1.5); hold on;
plot(locs(1:numPeaks),pks(1:numPeaks),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('Amplitude [deg/s]');
title('Single-Sided Amplitude Spectrum (GyroZ)');
grid on; hold off;

%% PSD Analysis-----------------------------------------------------------

% x data------------------------------------------------------------------
x = data.gyroscopeX;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz

x = x - mean(x);

window   = hamming(256);
noverlap = 128;
nfft     = 1024;

[pxx,f] = pwelch(x, window, noverlap, nfft, Fs);

% find peaks in PSD
[pks,locs] = findpeaks(pxx, f, ...
    'MinPeakProminence', max(pxx)*0.05, ...
    'SortStr', 'descend');

% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)

figure(2);
subplot(3,1,1)
plot(f,10*log10(pxx),'LineWidth',1.5); hold on;
plot(locs(1:numPeaks),10*log10(pks(1:numPeaks)),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('PSD [dB (deg/s)^2/Hz]');
title('Dominant Frequencies from PSD (GyroX)');
grid on; hold on

% y data ----------------------------------------------------------------
x = data.gyroscopeY;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz

x = x - mean(x);

window   = hamming(256);
noverlap = 128;
nfft     = 1024;

[pxx,f] = pwelch(x, window, noverlap, nfft, Fs);

% find peaks in PSD
[pks,locs] = findpeaks(pxx, f, ...
    'MinPeakProminence', max(pxx)*0.05, ...
    'SortStr', 'descend');

% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)

figure(2);
subplot(3,1,2)
plot(f,10*log10(pxx),'LineWidth',1.5); hold on;
plot(locs(1:numPeaks),10*log10(pks(1:numPeaks)),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('PSD [dB (deg/s)^2/Hz]');
title('Dominant Frequencies from PSD (GyroY)');
grid on;

% z data ----------------------------------------------------------------
x = data.gyroscopeZ;
Fs = 1/(mean(diff(data.timestamp))/1000); % hz

x = x - mean(x);

window   = hamming(256);
noverlap = 128;
nfft     = 1024;

[pxx,f] = pwelch(x, window, noverlap, nfft, Fs);

% find peaks in PSD
[pks,locs] = findpeaks(pxx, f, ...
    'MinPeakProminence', max(pxx)*0.05, ...
    'SortStr', 'descend');

% show top 5 dominant frequencies
numPeaks = min(5,length(locs));
dominantFreqs = locs(1:numPeaks)
dominantPSD   = pks(1:numPeaks)

figure(2);
subplot(3,1,3)
plot(f,10*log10(pxx),'LineWidth',1.5); hold on;
plot(locs(1:numPeaks),10*log10(pks(1:numPeaks)),'ro','MarkerSize',8,'LineWidth',1.5);
xlabel('Frequency [Hz]');
ylabel('PSD [dB (deg/s)^2/Hz]');
title('Dominant Frequencies from PSD (GyroZ)');
grid on;

%% test lpf filter
x_filt = zeros(length(data.gyroscopeX),1);
fc = 15; % hz
Fs = 1/(mean(diff(data.timestamp))/1000); % sampling frequency [hz]
Ts = 1/Fs;                                % Sampling period [s]
alpha = 2*pi*fc*Ts/(1+2*pi*fc*Ts);
notch_bw = 2;

for i = 1:length(data.gyroscopeX)

    x = data.gyroscopeX(i);

    x_filt(i) = lpf(x,alpha);
    %x_filt(i) = notchFilterSample(x, fc, Fs, notch_bw);

end
clear notchFilterSample

plot(time,data.gyroscopeX,'DisplayName','Raw'); hold on
plot(time,x_filt, 'DisplayName', 'Filtered data'); hold off;
grid on
legend()

%% helper function

%===================== LPF Function ===========================
function xlpf = lpf(x,alpha)

persistent prevx firstrun

if isempty(firstrun)
    prevx = x;
    firstrun = 1;
end

xlpf = (1-alpha)*prevx + alpha*x;

prevx = xlpf;

end


%===================== Notch Filter Function ===========================


function y = notchFilterSample(x, f0, fs, bw)
%NOTCHFILTERSAMPLE Single-sample 2nd-order discrete notch filter
%
%   y = notchFilterSample(x, f0, fs, bw)
%
% Inputs:
%   x   - current input sample
%   f0  - notch center frequency [Hz]
%   fs  - sampling frequency [Hz]
%   bw  - approximate notch bandwidth [Hz]
%
% Output:
%   y   - current filtered output sample
%
% Difference equation:
%   y[k] = 2*r*cos(w0)*y[k-1] - r^2*y[k-2] ...
%          + x[k] - 2*cos(w0)*x[k-1] + x[k-2]
%
% Filter transfer function:
%   H(z) = (1 - 2*cos(w0) z^-1 + z^-2) /
%          (1 - 2*r*cos(w0) z^-1 + r^2 z^-2)
%
% Parameter relations:
%   w0 = 2*pi*f0/fs
%   r  ~= 1 - pi*bw/fs
%
% Notes:
%   - All frequency inputs are in Hz
%   - Larger bw => wider notch
%   - Smaller bw => narrower notch
%   - States are stored persistently between calls
%
% To reset the filter, clear the function:
%   clear notchFilterSample

    persistent x1 x2 y1 y2

    % Initialize persistent states
    if isempty(x1)
        x1 = 0;
        x2 = 0;
        y1 = 0;
        y2 = 0;
    end

    % Basic checks
    if fs <= 0
        error('fs must be positive.');
    end
    if f0 <= 0 || f0 >= fs/2
        error('f0 must satisfy 0 < f0 < fs/2.');
    end
    if bw <= 0
        error('bw must be positive.');
    end

    % Convert center frequency from Hz to rad/sample
    w0 = 2*pi*f0/fs;

    % Approximate pole radius from bandwidth
    r = 1 - pi*bw/fs;

    if r <= 0 || r >= 1
        error('Chosen bandwidth gives invalid pole radius. Reduce bw.');
    end

    % Coefficients
    c = cos(w0);

    b0 = 1;
    b1 = -2*c;
    b2 = 1;

    a1 = -2*r*c;
    a2 = r^2;

    % Direct-form difference equation
    % y[k] = -a1*y[k-1] - a2*y[k-2] + b0*x[k] + b1*x[k-1] + b2*x[k-2]
    y = -a1*y1 - a2*y2 + b0*x + b1*x1 + b2*x2;

    % Update states
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
end