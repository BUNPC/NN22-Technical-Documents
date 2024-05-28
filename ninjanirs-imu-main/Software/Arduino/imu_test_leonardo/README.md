# imu_test_leonardo.ino

This is an arduino sketch to test readout of the NN IMU at 250k baud.
I will run on an Arduino Pro Micro with an ATMega32U4 processor.
Known to work with Arduino IDE 2.3.2.

Two serial ports are implemented:

* *Serial* is the USB interface to the computer
* *Serial1* is the Tx/Rx port on pins 0, 1

The code just prints a prompt ">" and waits for the user to either
just hit Enter or type a numeric byte to send.  Then it receives
the message from the IMU and prints the raw data, both as a byte
stream and as 16-bit IMU values.  For example, with the IMU more or
less right-side up to +Z is about 1G (8500 or so).
Note the checksum calculated and received are both displayed
and should match!

    >
    Send: 85
    Count: IMU data:
    942 171 -273 22 257 -114 8413 
    Sum rx calc: 249 249
    raw dump:
    17
    0: 85
    1: 14
    2: -82
    3: 3
    4: -85
    5: 0
    6: -17
    7: -2
    8: 22
    9: 0
    10: 1
    11: 1
    12: -114
    13: -1
    14: -35
    15: 32
    16: -7
    >
