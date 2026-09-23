# Carrier and Timing Recovery for QPSK Communication

## Description

PCECT502 Analog and Digital Communication course project for B.tech Electronics and Communication Engineering @ College of Engineering Trivandrum (CET)
Done by Team 12 (Akul S Mohan, Samil R, Sandeep Santhosh K)

## About
A software-based QPSK communication receiver with carrier and timing synchronization. Random binary data will be QPSK modulated, pulse-shaped, and transmitted through a simulated channel containing noise, carrier frequency/phase offset, and timing error. At the receiver, matched filtering, timing recovery, and carrier recovery will synchronize the signal before QPSK demodulation. Constellation diagrams and BER measurements will be used for evaluation. 

## System Flow
```mermaid
block-beta
columns 5
A["Random Bits"] B["QPSK Mod"] C["RRC Pulse"] D["Channel"] E["Sync Error"]
K["BER Analysis"] J["Demod"] I["Carrier"] H["Timing"] F["Matched Filter"]

A --> B
B --> C
C --> D
D --> E

%% Force the arrow out the East side of E and into the East side of F
E:e --> F:e

%% Reverse the arrows on the bottom row to point left
F <-- H
H <-- I
I <-- J
J <-- K
```

## Authors

Akul S Mohan 
Samil R
Sandeep Santhosh K


## License

MIT License

## Acknowledgments

Thank you
