import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import upfirdn

# PARAMETERS
N = 2000               # Number of bits
SPS = 8                # Samples per symbol
SNR = 10               # Noise level in dB
rolloff = 0.4          # RRC roll-off

# 1. GENERATE RANDOM BITS
np.random.seed(42)     # Set seed for reproducibility
txBits = np.random.randint(0, 2, N)

# 2. QPSK MODULATION
bits = txBits.reshape(-1, 2)
txSymbols = np.zeros(len(bits), dtype=complex)

for k in range(len(bits)):
    b = bits[k]
    if np.array_equal(b, [0, 0]):
        txSymbols[k] = 1 + 1j
    elif np.array_equal(b, [0, 1]):
        txSymbols[k] = -1 + 1j
    elif np.array_equal(b, [1, 1]):
        txSymbols[k] = -1 - 1j
    else:
        txSymbols[k] = 1 - 1j

txSymbols = txSymbols / np.sqrt(2)

# Helper function to generate Root Raised Cosine filter
def rcosdesign(beta, span, sps):
    num_taps = span * sps + 1
    t = np.arange(-num_taps // 2 + 1, num_taps // 2 + 1) / sps
    h = np.zeros_like(t, dtype=float)
    for i, ti in enumerate(t):
        if ti == 0:
            h[i] = 1.0 - beta + (4 * beta / np.pi)
        elif np.isclose(abs(ti), 1.0 / (4 * beta)):
            h[i] = (beta / np.sqrt(2)) * ((1 + 2/np.pi) * np.sin(np.pi / (4 * beta)) + (1 - 2/np.pi) * np.cos(np.pi / (4 * beta)))
        else:
            numerator = np.sin(np.pi * ti * (1 - beta)) + 4 * beta * ti * np.cos(np.pi * ti * (1 + beta))
            denominator = np.pi * ti * (1 - (4 * beta * ti)**2)
            h[i] = numerator / denominator
    h = h / np.sqrt(sps)
    return h

rrc = rcosdesign(rolloff, 6, SPS)

# 3. RRC PULSE SHAPING
txSignal = upfirdn(rrc, txSymbols, up=SPS, down=1)

# 4. ADD FREQUENCY AND PHASE ERROR
n = np.arange(len(txSignal))
freqError = 0.02
phaseError = 20 * np.pi / 180

rxSignal = txSignal * np.exp(1j * (2 * np.pi * freqError * n / SPS + phaseError))

# 5. ADD NOISE
sigPower = np.mean(np.abs(rxSignal)**2)
noisePower = sigPower / (10**(SNR / 10))
noise = np.sqrt(noisePower / 2) * (np.random.randn(len(rxSignal)) + 1j * np.random.randn(len(rxSignal)))
rxSignal = rxSignal + noise

# 6. MATCHED FILTER
rxFiltered = upfirdn(rrc, rxSignal, up=1, down=1)

# 7. TIMING RECOVERY (Manual Downsampling)
filterDelay = 6 * SPS
timingSignal = rxFiltered[filterDelay::SPS]

# 8. CARRIER RECOVERY (Custom QPSK Costas Loop)
rxSymbols_recovered = np.zeros(len(timingSignal), dtype=complex)
phase_est = 0.0
freq_est = 0.0

alpha = 0.13      # Proportional gain
beta_gain = 0.005 # Integral (frequency) gain

for k in range(len(timingSignal)):
    # 1. Apply current phase correction
    rxSymbols_recovered[k] = timingSignal[k] * np.exp(-1j * phase_est)

    # 2. Phase Error Detector for QPSK
    I = np.real(rxSymbols_recovered[k])
    Q = np.imag(rxSymbols_recovered[k])
    phase_error = (np.sign(I) * Q) - (np.sign(Q) * I)

    # 3. Update Loop Filter
    freq_est = freq_est + (beta_gain * phase_error)
    phase_est = phase_est + (alpha * phase_error) + freq_est

# 9. QPSK DEMODULATION
rxBits = np.zeros(2 * len(rxSymbols_recovered), dtype=int)

for k in range(len(rxSymbols_recovered)):
    b1 = 0 if np.real(rxSymbols_recovered[k]) >= 0 else 1
    b2 = 0 if np.imag(rxSymbols_recovered[k]) >= 0 else 1

    if b1 == 0 and b2 == 0:
        rxBits[2*k:2*k+2] = [0, 0]
    elif b1 == 1 and b2 == 0:
        rxBits[2*k:2*k+2] = [0, 1]
    elif b1 == 1 and b2 == 1:
        rxBits[2*k:2*k+2] = [1, 1]
    else:
        rxBits[2*k:2*k+2] = [1, 0]

# 10. BER
L = min(len(txBits), len(rxBits))
errors = np.sum(txBits[:L] != rxBits[:L])
BER = errors / L

print(f"Number of errors = {errors}")
print(f"BER = {BER:.6f}")

# 11. PLOTS (5 Subplots in a 2x3 Grid)
plt.figure(figsize=(15, 10))

# 1. Original Plot
plt.subplot(2, 3, 1)
plt.plot(np.real(txSymbols), np.imag(txSymbols), '.')
plt.grid(True)
plt.axis('equal')
plt.title('1. Original (Transmitted QPSK)')
plt.xlabel('I')
plt.ylabel('Q')

# 2. Noise Plot (Received Signal with impairments & noise)
plt.subplot(2, 3, 2)
plt.plot(np.real(rxSignal), np.imag(rxSignal), '.')
plt.grid(True)
plt.title('2. Noise & Impairments (Received)')
plt.xlabel('I')
plt.ylabel('Q')

# 3. Timing Recovery Plot
plt.subplot(2, 3, 3)
plt.plot(np.real(timingSignal), np.imag(timingSignal), '.')
plt.grid(True)
plt.axis('equal')
plt.title('3. Timing Recovery')
plt.xlabel('I')
plt.ylabel('Q')

# 4. Carrier Recovery Plot (Phase/Freq correction view)
plt.subplot(2, 3, 4)
plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), '.')
plt.grid(True)
plt.axis('equal')
plt.title('4. Carrier Recovery')
plt.xlabel('I')
plt.ylabel('Q')

# 5. Comparison: Timing Recovery ONLY (spinning) vs Both Recoveries (locked)
plt.subplot(2, 3, 5)
plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.', alpha=0.3, label='Timing Only')
plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), 'r.', label='Both Recovered')
plt.grid(True)
plt.axis('equal')
plt.title('5. Timing vs Both Recoveries')
plt.xlabel('I')
plt.ylabel('Q')
plt.legend()

# Hide the 6th empty subplot slot if desired, or leave clean
plt.subplot(2, 3, 6)
plt.axis('off')
plt.text(0.1, 0.5, 'Simulation Completed\nBER: {:.6f}'.format(BER), fontsize=12, fontweight='bold')

plt.tight_layout()
plt.show()
