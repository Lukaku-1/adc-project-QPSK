import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import upfirdn

# =============================================================================
# SHARED HELPER FUNCTION
# =============================================================================
def rcosdesign(beta, span, sps):
    """Root Raised Cosine filter generator"""
    num_taps = span * sps + 1
    t = np.arange(-num_taps // 2 + 1, num_taps // 2 + 1) / sps
    h = np.zeros_like(t, dtype=float)
    for i, ti in enumerate(t):
        if ti == 0:
            h[i] = 1.0 - beta + (4 * beta / np.pi)
        elif np.isclose(abs(ti), 1.0 / (4 * beta)):
            h[i] = (beta / np.sqrt(2)) * ((1 + 2/np.pi)*np.sin(np.pi / (4*beta)) + (1 - 2/np.pi)*np.cos(np.pi / (4*beta)))
        else:
            numerator = np.sin(np.pi * ti * (1 - beta)) + 4 * beta * ti * np.cos(np.pi * ti * (1 + beta))
            denominator = np.pi * ti * (1 - (4 * beta * ti)**2)
            h[i] = numerator / denominator
    h = h / np.sqrt(sps)
    return h


# =============================================================================
# 1. QPSK SIMULATION
# =============================================================================
def simulate_qpsk():
    N, SPS, SNR, rolloff = 2000, 8, 10, 0.4

    np.random.seed(42)
    txBits = np.random.randint(0, 2, N)
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

    rrc = rcosdesign(rolloff, 6, SPS)
    txSignal = upfirdn(rrc, txSymbols, up=SPS, down=1)

    n = np.arange(len(txSignal))
    freqError = 0.02
    phaseError = 20 * np.pi / 180
    rxSignal = txSignal * np.exp(1j * (2 * np.pi * freqError * n / SPS + phaseError))

    sigPower = np.mean(np.abs(rxSignal)**2)
    noisePower = sigPower / (10**(SNR / 10))
    noise = np.sqrt(noisePower / 2) * (np.random.randn(len(rxSignal)) + 1j * np.random.randn(len(rxSignal)))
    rxSignal = rxSignal + noise

    rxFiltered = upfirdn(rrc, rxSignal, up=1, down=1)
    filterDelay = 6 * SPS
    timingSignal = rxFiltered[filterDelay::SPS]

    rxSymbols_recovered = np.zeros(len(timingSignal), dtype=complex)
    phase_estimates = np.zeros(len(timingSignal))
    phase_est, freq_est = 0.0, 0.0
    alpha, beta_gain = 0.13, 0.005

    for k in range(len(timingSignal)):
        rxSymbols_recovered[k] = timingSignal[k] * np.exp(-1j * phase_est)
        I, Q = np.real(rxSymbols_recovered[k]), np.imag(rxSymbols_recovered[k])
        phase_error = (np.sign(I) * Q) - (np.sign(Q) * I)
        freq_est = freq_est + (beta_gain * phase_error)
        phase_est = phase_est + (alpha * phase_error) + freq_est
        phase_estimates[k] = phase_est

    # Create Carrier Only Signal (Stationary Blur) by applying phase tracker to max-ISI sampling
    badDelay = filterDelay - SPS // 2
    badTimingSignal = rxFiltered[badDelay::SPS][:len(timingSignal)]
    carrierOnlySignal = badTimingSignal * np.exp(-1j * phase_estimates)

    rxBits = np.zeros(2 * len(rxSymbols_recovered), dtype=int)
    for k in range(len(rxSymbols_recovered)):
        b1 = 0 if np.real(rxSymbols_recovered[k]) >= 0 else 1
        b2 = 0 if np.imag(rxSymbols_recovered[k]) >= 0 else 1
        if b1 == 0 and b2 == 0: rxBits[2*k:2*k+2] = [0, 0]
        elif b1 == 1 and b2 == 0: rxBits[2*k:2*k+2] = [0, 1]
        elif b1 == 1 and b2 == 1: rxBits[2*k:2*k+2] = [1, 1]
        else: rxBits[2*k:2*k+2] = [1, 0]

    L = min(len(txBits), len(rxBits))
    BER = np.sum(txBits[:L] != rxBits[:L]) / L

    plt.figure('QPSK System Simulation', figsize=(15, 10))
    plt.subplot(2, 3, 1)
    plt.plot(np.real(txSymbols), np.imag(txSymbols), '.')
    plt.grid(True); plt.axis('equal'); plt.title('1. Original (Transmitted QPSK)')

    plt.subplot(2, 3, 2)
    plt.plot(np.real(rxSignal), np.imag(rxSignal), '.')
    plt.grid(True); plt.title('2. Noise & Impairments (Received)')

    plt.subplot(2, 3, 3)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('3. Timing Recovery Only')

    plt.subplot(2, 3, 4)
    plt.plot(np.real(carrierOnlySignal), np.imag(carrierOnlySignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('4. Carrier Recovery Only (ISI)')

    plt.subplot(2, 3, 5)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.', alpha=0.3, label='Timing Only')
    plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), 'r.', label='Both Recovered')
    plt.grid(True); plt.axis('equal'); plt.title('5. Timing vs Both Recoveries'); plt.legend()

    plt.subplot(2, 3, 6); plt.axis('off')
    plt.text(0.1, 0.5, 'QPSK Simulation\nBER: {:.6f}'.format(BER), fontsize=12, fontweight='bold')
    plt.tight_layout()


# =============================================================================
# 2. 16-PSK SIMULATION
# =============================================================================
def simulate_16psk():
    N, SPS, SNR, rolloff, M = 2000, 8, 15, 0.4, 16
    N = (N // 4) * 4

    np.random.seed(42)
    txBits = np.random.randint(0, 2, N)
    bits = txBits.reshape(-1, 4)
    txSymbols = np.zeros(len(bits), dtype=complex)

    for k in range(len(bits)):
        b = bits[k]
        val = b[0]*8 + b[1]*4 + b[2]*2 + b[3]*1
        angle = val * (2 * np.pi / M)
        txSymbols[k] = np.exp(1j * angle)

    rrc = rcosdesign(rolloff, 6, SPS)
    txSignal = upfirdn(rrc, txSymbols, up=SPS, down=1)

    n = np.arange(len(txSignal))
    freqError, phaseError = 0.01, 15 * np.pi / 180
    rxSignal = txSignal * np.exp(1j * (2 * np.pi * freqError * n / SPS + phaseError))

    sigPower = np.mean(np.abs(rxSignal)**2)
    noisePower = sigPower / (10**(SNR / 10))
    noise = np.sqrt(noisePower / 2) * (np.random.randn(len(rxSignal)) + 1j * np.random.randn(len(rxSignal)))
    rxSignal = rxSignal + noise

    rxFiltered = upfirdn(rrc, rxSignal, up=1, down=1)
    filterDelay = 6 * SPS
    timingSignal = rxFiltered[filterDelay::SPS]

    rxSymbols_recovered = np.zeros(len(timingSignal), dtype=complex)
    phase_estimates = np.zeros(len(timingSignal))
    phase_est, freq_est = 0.0, 0.0
    alpha, beta_gain = 0.19, 0.009

    for k in range(len(timingSignal)):
        rxSymbols_recovered[k] = timingSignal[k] * np.exp(-1j * phase_est)
        theta_rx = np.angle(rxSymbols_recovered[k])
        sector = np.round(theta_rx / (2 * np.pi / M))
        ideal_theta = sector * (2 * np.pi / M)
        phase_error = np.angle(np.exp(1j * (theta_rx - ideal_theta)))
        freq_est = freq_est + (beta_gain * phase_error)
        phase_est = phase_est + (alpha * phase_error) + freq_est
        phase_estimates[k] = phase_est

    badDelay = filterDelay - SPS // 2
    badTimingSignal = rxFiltered[badDelay::SPS][:len(timingSignal)]
    carrierOnlySignal = badTimingSignal * np.exp(-1j * phase_estimates)

    rxBits = np.zeros(4 * len(rxSymbols_recovered), dtype=int)
    for k in range(len(rxSymbols_recovered)):
        theta = np.angle(rxSymbols_recovered[k])
        if theta < 0: theta += 2 * np.pi
        sector = int(np.round(theta / (2 * np.pi / M))) % M
        b_str = format(sector, '04b')
        rxBits[4*k : 4*k+4] = [int(bit) for bit in b_str]

    L = min(len(txBits), len(rxBits))
    BER = np.sum(txBits[:L] != rxBits[:L]) / L

    plt.figure('16-PSK System Simulation', figsize=(15, 10))
    plt.subplot(2, 3, 1)
    plt.plot(np.real(txSymbols), np.imag(txSymbols), '.')
    plt.grid(True); plt.axis('equal'); plt.title('1. Original (Transmitted 16-PSK)')

    plt.subplot(2, 3, 2)
    plt.plot(np.real(rxSignal), np.imag(rxSignal), '.')
    plt.grid(True); plt.title('2. Noise & Impairments (Received)')

    plt.subplot(2, 3, 3)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('3. Timing Recovery Only')

    plt.subplot(2, 3, 4)
    plt.plot(np.real(carrierOnlySignal), np.imag(carrierOnlySignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('4. Carrier Recovery Only (ISI)')

    plt.subplot(2, 3, 5)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.', alpha=0.3, label='Timing Only')
    plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), 'r.', label='Both Recovered')
    plt.grid(True); plt.axis('equal'); plt.title('5. Timing vs Both Recoveries'); plt.legend()

    plt.subplot(2, 3, 6); plt.axis('off')
    plt.text(0.1, 0.5, '16-PSK Simulation\nBER: {:.6f}'.format(BER), fontsize=12, fontweight='bold')
    plt.tight_layout()


# =============================================================================
# 3. 4-QAM SIMULATION
# =============================================================================
def simulate_4qam():
    N, SPS, SNR, rolloff = 2000, 8, 10, 0.4
    N = (N // 2) * 2

    np.random.seed(42)
    txBits = np.random.randint(0, 2, N)
    bits = txBits.reshape(-1, 2)
    txSymbols = np.zeros(len(bits), dtype=complex)

    for k in range(len(bits)):
        b1, b2 = bits[k, 0], bits[k, 1]
        i_level = 1 if b1 == 0 else -1
        q_level = 1 if b2 == 0 else -1
        txSymbols[k] = (i_level + 1j * q_level) / np.sqrt(2)

    rrc = rcosdesign(rolloff, 6, SPS)
    txSignal = upfirdn(rrc, txSymbols, up=SPS, down=1)

    n = np.arange(len(txSignal))
    freqError, phaseError = 0.02, 20 * np.pi / 180
    rxSignal = txSignal * np.exp(1j * (2 * np.pi * freqError * n / SPS + phaseError))

    sigPower = np.mean(np.abs(rxSignal)**2)
    noisePower = sigPower / (10**(SNR / 10))
    noise = np.sqrt(noisePower / 2) * (np.random.randn(len(rxSignal)) + 1j * np.random.randn(len(rxSignal)))
    rxSignal = rxSignal + noise

    rxFiltered = upfirdn(rrc, rxSignal, up=1, down=1)
    filterDelay = 6 * SPS
    timingSignal = rxFiltered[filterDelay::SPS]

    rxSymbols_recovered = np.zeros(len(timingSignal), dtype=complex)
    phase_estimates = np.zeros(len(timingSignal))
    phase_est, freq_est = 0.0, 0.0
    alpha, beta_gain = 0.15, 0.008

    for k in range(len(timingSignal)):
        rxSymbols_recovered[k] = timingSignal[k] * np.exp(-1j * phase_est)
        I, Q = np.real(rxSymbols_recovered[k]), np.imag(rxSymbols_recovered[k])
        phase_error = (np.sign(I) * Q) - (np.sign(Q) * I)
        freq_est = freq_est + (beta_gain * phase_error)
        phase_est = phase_est + (alpha * phase_error) + freq_est
        phase_estimates[k] = phase_est

    badDelay = filterDelay - SPS // 2
    badTimingSignal = rxFiltered[badDelay::SPS][:len(timingSignal)]
    carrierOnlySignal = badTimingSignal * np.exp(-1j * phase_estimates)

    rxBits = np.zeros(2 * len(rxSymbols_recovered), dtype=int)
    for k in range(len(rxSymbols_recovered)):
        b1 = 0 if np.real(rxSymbols_recovered[k]) >= 0 else 1
        b2 = 0 if np.imag(rxSymbols_recovered[k]) >= 0 else 1
        rxBits[2*k : 2*k+2] = [b1, b2]

    L = min(len(txBits), len(rxBits))
    BER = np.sum(txBits[:L] != rxBits[:L]) / L

    plt.figure('4-QAM System Simulation', figsize=(15, 10))
    plt.subplot(2, 3, 1)
    plt.plot(np.real(txSymbols), np.imag(txSymbols), '.')
    plt.grid(True); plt.axis('equal'); plt.title('1. Original (Transmitted 4-QAM)')

    plt.subplot(2, 3, 2)
    plt.plot(np.real(rxSignal), np.imag(rxSignal), '.')
    plt.grid(True); plt.title('2. Noise & Impairments (Received)')

    plt.subplot(2, 3, 3)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.')
    plt.grid(True); plt.axis('equal'); plt.title('3. Timing Recovery Only (Spinning)')

    plt.subplot(2, 3, 4)
    plt.plot(np.real(carrierOnlySignal), np.imag(carrierOnlySignal), 'r.')
    plt.grid(True); plt.axis('equal'); plt.title('4. Carrier Recovery Only (ISI)')

    plt.subplot(2, 3, 5)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.', alpha=0.3, label='Timing Only')
    plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), 'r.', label='Both Recovered')
    plt.grid(True); plt.axis('equal'); plt.title('5. Timing vs Both Recoveries'); plt.legend()

    plt.subplot(2, 3, 6); plt.axis('off')
    plt.text(0.1, 0.5, f'4-QAM Simulation\nBER: {BER:.6f}', fontsize=12, fontweight='bold')
    plt.tight_layout()


# =============================================================================
# 4. 16-QAM SIMULATION
# =============================================================================
def simulate_16qam():
    N, SPS, SNR, rolloff = 2000, 8, 18, 0.4
    N = (N // 4) * 4

    np.random.seed(42)
    txBits = np.random.randint(0, 2, N)
    bits = txBits.reshape(-1, 4)

    def bit2pam(b0, b1):
        val = (b0 << 1) | b1
        if val == 0: return -3
        elif val == 1: return -1
        elif val == 3: return 1
        else: return 3

    txSymbols = np.zeros(len(bits), dtype=complex)
    for k in range(len(bits)):
        i_level = bit2pam(bits[k, 0], bits[k, 1])
        q_level = bit2pam(bits[k, 2], bits[k, 3])
        txSymbols[k] = (i_level + 1j * q_level) / np.sqrt(10)

    rrc = rcosdesign(rolloff, 6, SPS)
    txSignal = upfirdn(rrc, txSymbols, up=SPS, down=1)

    n = np.arange(len(txSignal))
    freqError, phaseError = 0.01, 15 * np.pi / 180
    rxSignal = txSignal * np.exp(1j * (2 * np.pi * freqError * n / SPS + phaseError))

    sigPower = np.mean(np.abs(rxSignal)**2)
    noisePower = sigPower / (10**(SNR / 10))
    noise = np.sqrt(noisePower / 2) * (np.random.randn(len(rxSignal)) + 1j * np.random.randn(len(rxSignal)))
    rxSignal = rxSignal + noise

    rxFiltered = upfirdn(rrc, rxSignal, up=1, down=1)
    filterDelay = 6 * SPS
    timingSignal = rxFiltered[filterDelay::SPS]

    def qam16_slice(sym):
        scaled = sym * np.sqrt(10)
        i_val, q_val = np.real(scaled), np.imag(scaled)
        i_quant = 3 if i_val > 2 else (1 if i_val > 0 else (-1 if i_val > -2 else -3))
        q_quant = 3 if q_val > 2 else (1 if q_val > 0 else (-1 if q_val > -2 else -3))
        return (i_quant + 1j * q_quant) / np.sqrt(10)

    rxSymbols_recovered = np.zeros(len(timingSignal), dtype=complex)
    phase_estimates = np.zeros(len(timingSignal))
    phase_est, freq_est = 0.0, 0.0
    alpha, beta_gain = 0.19, 0.009

    for k in range(len(timingSignal)):
        rxSymbols_recovered[k] = timingSignal[k] * np.exp(-1j * phase_est)
        decision = qam16_slice(rxSymbols_recovered[k])
        phase_error = np.imag(rxSymbols_recovered[k] * np.conj(decision))
        freq_est = freq_est + (beta_gain * phase_error)
        phase_est = phase_est + (alpha * phase_error) + freq_est
        phase_estimates[k] = phase_est

    badDelay = filterDelay - SPS // 2
    badTimingSignal = rxFiltered[badDelay::SPS][:len(timingSignal)]
    carrierOnlySignal = badTimingSignal * np.exp(-1j * phase_estimates)

    def pam2bits(val):
        if val == -3: return [0, 0]
        elif val == -1: return [0, 1]
        elif val == 1: return [1, 1]
        else: return [1, 0]

    rxBits = np.zeros(4 * len(rxSymbols_recovered), dtype=int)
    for k in range(len(rxSymbols_recovered)):
        decision = qam16_slice(rxSymbols_recovered[k]) * np.sqrt(10)
        i_val = int(np.round(np.real(decision)))
        q_val = int(np.round(np.imag(decision)))
        rxBits[4*k : 4*k+4] = pam2bits(i_val) + pam2bits(q_val)

    L = min(len(txBits), len(rxBits))
    BER = np.sum(txBits[:L] != rxBits[:L]) / L

    plt.figure('16-QAM System Simulation', figsize=(15, 10))
    plt.subplot(2, 3, 1)
    plt.plot(np.real(txSymbols), np.imag(txSymbols), '.')
    plt.grid(True); plt.axis('equal'); plt.title('1. Original (Transmitted 16-QAM)')

    plt.subplot(2, 3, 2)
    plt.plot(np.real(rxSignal), np.imag(rxSignal), '.')
    plt.grid(True); plt.title('2. Noise & Impairments (Received)')

    plt.subplot(2, 3, 3)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('3. Timing Recovery Only')

    plt.subplot(2, 3, 4)
    plt.plot(np.real(carrierOnlySignal), np.imag(carrierOnlySignal), '.')
    plt.grid(True); plt.axis('equal'); plt.title('4. Carrier Recovery Only (ISI)')

    plt.subplot(2, 3, 5)
    plt.plot(np.real(timingSignal), np.imag(timingSignal), 'b.', alpha=0.3, label='Timing Only')
    plt.plot(np.real(rxSymbols_recovered), np.imag(rxSymbols_recovered), 'r.', label='Both Recovered')
    plt.grid(True); plt.axis('equal'); plt.title('5. Timing vs Both Recoveries'); plt.legend()

    plt.subplot(2, 3, 6); plt.axis('off')
    plt.text(0.1, 0.5, '16-QAM (High Power Loop)\nBER: {:.6f}'.format(BER), fontsize=12, fontweight='bold')
    plt.tight_layout()


# =============================================================================
# 5. COMPARATIVE BER vs SNR WATERFALL STUDY
# =============================================================================
def simulate_ber_waterfall(N_bits, snr_db_range):
    snr_linear = 10**(snr_db_range / 10.0)
    ber_qpsk = np.zeros(len(snr_db_range))
    ber_4qam = np.zeros(len(snr_db_range))
    ber_16psk = np.zeros(len(snr_db_range))
    ber_16qam = np.zeros(len(snr_db_range))

    for i, snr in enumerate(snr_db_range):
        # QPSK / 4-QAM
        tx_bits_2 = np.random.randint(0, 2, N_bits)
        sym_i = np.where(tx_bits_2[0::2] == 0, 1, -1)
        sym_q = np.where(tx_bits_2[1::2] == 0, 1, -1)
        tx_qpsk = (sym_i + 1j * sym_q) / np.sqrt(2)

        noisePower_qpsk = 1.0 / snr
        noise = np.sqrt(noisePower_qpsk / 2) * (np.random.randn(len(tx_qpsk)) + 1j * np.random.randn(len(tx_qpsk)))
        rx_qpsk = tx_qpsk + noise

        rx_bits_2 = np.zeros(N_bits, dtype=int)
        rx_bits_2[0::2] = np.where(np.real(rx_qpsk) >= 0, 0, 1)
        rx_bits_2[1::2] = np.where(np.imag(rx_qpsk) >= 0, 0, 1)

        ber_qpsk[i] = np.sum(tx_bits_2 != rx_bits_2) / N_bits
        ber_4qam[i] = ber_qpsk[i]

        # 16-PSK
        tx_bits_4 = np.random.randint(0, 2, N_bits)
        bits_16psk = tx_bits_4.reshape(-1, 4)
        vals_16psk = bits_16psk[:,0]*8 + bits_16psk[:,1]*4 + bits_16psk[:,2]*2 + bits_16psk[:,3]*1
        tx_16psk = np.exp(1j * vals_16psk * (2 * np.pi / 16))

        noisePower_16 = 1.0 / (snr * 2)
        noise = np.sqrt(noisePower_16 / 2) * (np.random.randn(len(tx_16psk)) + 1j * np.random.randn(len(tx_16psk)))
        rx_16psk = tx_16psk + noise

        angles = np.angle(rx_16psk)
        angles[angles < 0] += 2 * np.pi
        rx_vals_16psk = np.round(angles / (2 * np.pi / 16)) % 16
        rx_bits_16psk = np.array([list(format(int(v), '04b')) for v in rx_vals_16psk], dtype=int).flatten()
        ber_16psk[i] = np.sum(tx_bits_4 != rx_bits_16psk) / N_bits

        # 16-QAM
        def pam_mod(b0, b1):
            val = (b0 * 2) + b1
            return {0: -3, 1: -1, 3: 1, 2: 3}[val]

        tx_16qam = np.zeros(len(bits_16psk), dtype=complex)
        for k in range(len(bits_16psk)):
            tx_16qam[k] = (pam_mod(bits_16psk[k,0], bits_16psk[k,1]) + 1j * pam_mod(bits_16psk[k,2], bits_16psk[k,3])) / np.sqrt(10)

        noise = np.sqrt(noisePower_16 / 2) * (np.random.randn(len(tx_16qam)) + 1j * np.random.randn(len(tx_16qam)))
        rx_16qam = tx_16qam + noise

        rx_bits_16qam = np.zeros(N_bits, dtype=int)
        for k in range(len(rx_16qam)):
            scaled = rx_16qam[k] * np.sqrt(10)
            i_val, q_val = np.real(scaled), np.imag(scaled)
            rx_bits_16qam[4*k]   = 1 if i_val > 0 else 0
            rx_bits_16qam[4*k+1] = 1 if abs(i_val) < 2 else 0
            rx_bits_16qam[4*k+2] = 1 if q_val > 0 else 0
            rx_bits_16qam[4*k+3] = 1 if abs(q_val) < 2 else 0

        ber_16qam[i] = np.sum(tx_bits_4 != rx_bits_16qam) / N_bits

    # Plot the Waterfall Curves
    plt.figure('BER vs SNR Comparison', figsize=(10, 7))
    plt.semilogy(snr_db_range, ber_qpsk, 'bo-', linewidth=2, label='QPSK / 4-QAM (2 bits/symbol)')
    plt.semilogy(snr_db_range, ber_16qam, 'rs-', linewidth=2, label='16-QAM (4 bits/symbol)')
    plt.semilogy(snr_db_range, ber_16psk, 'k^-', linewidth=2, label='16-PSK (4 bits/symbol)')
    plt.grid(True, which="both", ls="--")
    plt.axis([0, 15, 1e-5, 1])
    plt.xlabel('Eb/N0 (SNR per bit) [dB]', fontsize=12)
    plt.ylabel('Bit Error Rate (BER)', fontsize=12)
    plt.title('Comparative BER vs SNR Waterfall Plot', fontsize=14)
    plt.legend(fontsize=12)


# =============================================================================
# EXECUTE ALL SIMULATIONS
# =============================================================================
if __name__ == '__main__':
    # 1. Run the system processing chains (Constellations & Tracking)
    simulate_qpsk()
    simulate_16psk()
    simulate_4qam()
    simulate_16qam()

    # 2. Run the comparative theoretical BER curves
    simulate_ber_waterfall(N_bits=200000, snr_db_range=np.arange(0, 16, 1))

    # 3. Render all 5 generated plot windows simultaneously
    plt.show()
