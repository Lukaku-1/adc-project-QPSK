clc;
clear;
close all;

%% PARAMETERS
N = 2000;
SNR = 10;

%% 1. RANDOM BITS
txBits = randi([0 1], N, 1);

%% 2. QPSK MODULATION
b1 = txBits(1:2:end);
b2 = txBits(2:2:end);

% QPSK mapping
I = 1 - 2*b1;
Q = 1 - 2*b2;

txSymbols = (I + 1j*Q)/sqrt(2);

%% 3. ADD NOISE AND PHASE ERROR
phaseError = 20*pi/180;

rxSignal = txSymbols .* exp(1j*phaseError);

rxSignal = awgn(rxSignal, SNR, 'measured');

%% 4. PLOT

figure;

subplot(1,2,1);
plot(real(txSymbols), imag(txSymbols), 'o');
grid on;
axis equal;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
xlabel('In-Phase');
ylabel('Quadrature');
title('Transmitted QPSK');

subplot(1,2,2);
plot(real(rxSignal), imag(rxSignal), '.');
grid on;
axis equal;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
xlabel('In-Phase');
ylabel('Quadrature');
title('Received QPSK');

sgtitle('QPSK Transmission and Reception');
