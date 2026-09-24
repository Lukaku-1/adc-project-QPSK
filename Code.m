clc;
clear;
close all;

%% PARAMETERS
N = 2000;              % Number of bits
SPS = 8;               % Samples per symbol
rolloff = 0.4;         % RRC roll-off

%% 1. GENERATE RANDOM BITS
txBits = randi([0 1], N, 1);

%% 2. QPSK MODULATION
% Group bits into pairs
bits = reshape(txBits, 2, []).';

% QPSK mapping
% 00 ->  1+j
% 01 -> -1+j
% 11 -> -1-j
% 10 ->  1-j
txSymbols = zeros(size(bits, 1), 1);
for k = 1:size(bits, 1)
    if isequal(bits(k,:), [0 0])
        txSymbols(k) = 1 + 1j;
    elseif isequal(bits(k,:), [0 1])
        txSymbols(k) = -1 + 1j;
    elseif isequal(bits(k,:), [1 1])
        txSymbols(k) = -1 - 1j;
    else
        txSymbols(k) = 1 - 1j;
    end
end
txSymbols = txSymbols / sqrt(2);

%% 3. RRC PULSE SHAPING
% Create the pulse shaping filter and upsample/filter the symbols
rrc = rcosdesign(rolloff, 6, SPS, 'sqrt');
txSignal = upfirdn(txSymbols, rrc, SPS, 1);

%% 4. PLOTS
figure;

% Plot 1: The ideal QPSK constellation
subplot(2,1,1);
plot(real(txSymbols), imag(txSymbols), '.');
grid on;
axis equal;
axis([-1.5 1.5 -1.5 1.5]);
title('Transmitted QPSK Constellation');
xlabel('I');
ylabel('Q');

% Plot 2: The shaped baseband signal in the time domain
subplot(2,1,2);
plot(real(txSignal));
hold on;
plot(imag(txSignal));
grid on;
title('Shaped Baseband Transmit Signal');
xlabel('Samples');
ylabel('Amplitude');
legend('In-phase (I)', 'Quadrature (Q)');
