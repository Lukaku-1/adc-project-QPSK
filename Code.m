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
rxSignal = awgn(rxSignal,SNR,'measured');

%% 6. MATCHED FILTER
rxFiltered = upfirdn(rxSignal,rrc,1,1);

%% 7. TIMING RECOVERY
timing = comm.SymbolSynchronizer( ...
    'TimingErrorDetector','Gardner (non-data-aided)', ...
    'SamplesPerSymbol',SPS);

timingSignal = timing(rxFiltered);

%% 8. CARRIER RECOVERY
carrier = comm.CarrierSynchronizer( ...
    'Modulation','QPSK', ...
    'SamplesPerSymbol',1, ...
    'NormalizedLoopBandwidth', 0.05); % Increased from default 0.01

rxSymbols = carrier(timingSignal);

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
