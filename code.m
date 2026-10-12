clc;
clear;
close all;

%% PARAMETERS
N = 2000;              % Number of bits
SPS = 8;               % Samples per symbol
SNR = 10;              % Noise level
rolloff = 0.4;         % RRC roll-off

%% 1. GENERATE RANDOM BITS
txBits = randi([0 1],N,1);

%% 2. QPSK MODULATION
% Group bits into pairs
bits = reshape(txBits,2,[]).';

% QPSK mapping
% 00 ->  1+j
% 01 -> -1+j
% 11 -> -1-j
% 10 ->  1-j

txSymbols = zeros(size(bits,1),1);

for k = 1:size(bits,1)

    if isequal(bits(k,:),[0 0])
        txSymbols(k) = 1 + 1j;

    elseif isequal(bits(k,:),[0 1])
        txSymbols(k) = -1 + 1j;

    elseif isequal(bits(k,:),[1 1])
        txSymbols(k) = -1 - 1j;

    else
        txSymbols(k) = 1 - 1j;
    end

end

txSymbols = txSymbols/sqrt(2);

%% 3. RRC PULSE SHAPING
rrc = rcosdesign(rolloff,6,SPS,'sqrt');

txSignal = upfirdn(txSymbols,rrc,SPS,1);

%% 4. ADD FREQUENCY AND PHASE ERROR
n = (0:length(txSignal)-1).';

freqError = 0.02;
phaseError = 20*pi/180;

rxSignal = txSignal .* ...
    exp(1j*(2*pi*freqError*n/SPS + phaseError));

%% 5. ADD NOISE
% Calculate measured signal power
sigPower = mean(abs(rxSignal).^2); 

% Calculate required noise power based on SNR (in dB)
noisePower = sigPower / (10^(SNR/10)); 

% Generate complex Gaussian noise
noise = sqrt(noisePower/2) * (randn(size(rxSignal)) + 1j * randn(size(rxSignal)));

% Add noise to the received signal
rxSignal = rxSignal + noise;

%% 6. MATCHED FILTER
rxFiltered = upfirdn(rxSignal,rrc,1,1);

%% 7. TIMING RECOVERY (Manual Downsampling)

filterDelay = 6 * SPS;
timingSignal = rxFiltered(filterDelay + 1 : SPS : end);

%% 8. CARRIER RECOVERY (Custom QPSK Costas Loop)
rxSymbols = zeros(length(timingSignal), 1);
phase_est = 0;
freq_est = 0;

% Loop filter parameters (similar to LoopBandwidth = 0.05)
alpha = 0.13;    % Proportional gain
beta  = 0.005;   % Integral (frequency) gain

for k = 1:length(timingSignal)
    % 1. Apply the current phase correction
    rxSymbols(k) = timingSignal(k) * exp(-1j * phase_est);

    % 2. Phase Error Detector for QPSK
    I = real(rxSymbols(k));
    Q = imag(rxSymbols(k));
    % The error metric pulls the symbol towards the nearest diagonal (QPSK constellation)
    phase_error = (sign(I) * Q) - (sign(Q) * I); 

    % 3. Update the Loop Filter
    freq_est = freq_est + (beta * phase_error);
    phase_est = phase_est + (alpha * phase_error) + freq_est;
end
%% 9. QPSK DEMODULATION
rxBits = zeros(2*length(rxSymbols),1);

for k = 1:length(rxSymbols)

    if real(rxSymbols(k)) >= 0
        b1 = 0;
    else
        b1 = 1;
    end

    if imag(rxSymbols(k)) >= 0
        b2 = 0;
    else
        b2 = 1;
    end

    % Mapping correction
    if b1==0 && b2==0
        rxBits(2*k-1:2*k) = [0;0];

    elseif b1==1 && b2==0
        rxBits(2*k-1:2*k) = [0;1];

    elseif b1==1 && b2==1
        rxBits(2*k-1:2*k) = [1;1];

    else
        rxBits(2*k-1:2*k) = [1;0];
    end

end

%% 10. BER
L = min(length(txBits),length(rxBits));

errors = sum(txBits(1:L) ~= rxBits(1:L));

BER = errors/L;

fprintf('Number of errors = %d\n',errors);
fprintf('BER = %f\n',BER);

%% 11. PLOTS

figure;

subplot(2,2,1);
plot(real(txSymbols),imag(txSymbols),'.');
grid on;
axis equal;
title('Transmitted QPSK');
xlabel('I');
ylabel('Q');

subplot(2,2,2);
plot(real(rxSignal),imag(rxSignal),'.');
grid on;
title('Received Signal');
xlabel('I');
ylabel('Q');

subplot(2,2,3);
plot(real(timingSignal),imag(timingSignal),'.');
grid on;
axis equal;
title('After Timing Recovery');
xlabel('I');
ylabel('Q');

subplot(2,2,4);
plot(real(rxSymbols),imag(rxSymbols),'.');
grid on;
axis equal;
title('After Carrier Recovery');
xlabel('I');
ylabel('Q');
