# avr-imu-readout

Readout the IMU in response to a serial command byte.
There are two compile-time options:

1.  Any byte recieved sends the return message
2.  'A' sends IMU data, 'T' sends 1111, 2222, 3333 etc test data

Normal data.  All 16-bit values sent LSB first.

| Offset | Value    | Size    | Notes                         |
|--------|----------|---------|-------------------------------|
| 0      | echo     | 8 bits  | received byte                 |
| 1      | count    | 8 bits  | = 14                          |
| 2, 3   | temp     | 16 bits | raw temperature               |
| 4, 5   | gyro_x   | 16 bits | raw gyro reading              |
| 6, 7   | gyro_y   | 16 bits |                               |
| 8, 9   | gyro_z   | 16 bits |                               |
| 10, 11 | accel_x  | 16 bits |                               |
| 12, 13 | accel_y  | 16 bits |                               |
| 14, 15 | accel_z  | 16 bits |                               |
| 16     | checksum | 8 bits  | unsigned sum of offsets 1..15 |

Error response (may not be a complete list):

| Offset | Value    | Size   | Notes         |                                                       |
|--------|----------|--------|---------------|-------------------------------------------------------|
| 0      | echo     | 8 bits | received byte |                                                       |
| 1      | count    | 8 bits | = 1           |                                                       |
| 2      | error    | 8 bits |               |                                                       |
|        |          |        | 0x20          | NAK received after sending device address for writing |
|        |          |        | 0x30          | NAK received after sending data                       |
|        |          |        | 0x38          | Arbitration lost with address or data                 |
|        |          |        | 0x48          | NAK received after sending device address for reading |
|        |          |        | 0xff          | unexpected data from IMU                              |
| 3      | checksum | 8 bits |               | unsigned sum of offsets 1, 2                          |

