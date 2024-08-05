# ninjanirs-imu

IMU and multiplexer designs for ninjaNIRS

## IMU Board

Board designed in early 2024 along with various adapters and a splitter.
The IMU board has an ATMeg168 so plenty of resources.

### UART connector pinout

    1 - VCC (5V or 3.3V)
	2 - TxD (output from MCU)
	3 - RxD (input to MCU)
	4 - GND
	
### RJ Adapter board pinout

    GND     1
	RxD        2
	TxD     3
	VCC        4
