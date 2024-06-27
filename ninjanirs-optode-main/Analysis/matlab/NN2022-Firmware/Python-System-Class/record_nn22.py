# NinjaNIRS 2022 - Raspberry Pi Zero SPI byte stream recorder
#
# This program continously polls the SPI interface on the NN22 FPGA
# and stores any received data in a binary file.
# Effectively this is a copy of the data sent over UART to NinjaGUI.
#
# Tested on Raspberry Pi Zero 2 W.
#
# bzim@bu.edu
# Initial version 2023-3-29
#

import spidev
import time

print("\n-----  NinjaNIRS 2022 byte stream recorder  -----\n")
print("Press Ctrl-C to exit.\n")

spi = spidev.SpiDev()
spi.open(0, 0) #(bus, device)
spi.max_speed_hz = 12_000_000
spi.mode = 0b00

fname = "./meas/{}_NN22.bin".format(time.strftime("%Y%m%d-%H%M%S"))
print("Opening {}\n".format(fname))
f = open(fname, "wb")

# flush buffer in FPGA
bytes_available = spi.readbytes(1)[0]
while bytes_available>0:
    buf = spi.readbytes(bytes_available+1)
    bytes_available = buf[0] - bytes_available

n_bytes_rxd = 0
n_bytes_rxd_total = 0
n_cyc = 0
n_cyc_zero_b = 0
n_cyc_max_b = 0

last_report_time = time.perf_counter()

try:
    while True:
        buf = spi.readbytes(bytes_available+1)
        bytes_available = buf[0] - bytes_available
        
        n_cyc += 1
        if buf[0] == 0: # no new data was available
            n_cyc_zero_b += 1
        if buf[0] == 255: # max read length in this cycle
            n_cyc_max_b += 1

        if len(buf)>1: # received data
            n_bytes_rxd += len(buf)-1
            f.write(bytearray(buf[1:]))

        if time.perf_counter() - last_report_time > 2:
            n_bytes_rxd_total += n_bytes_rxd
            print("Bytes rcvd tot: {:11,d}  Last: {:8,d} | Cycs (0/max/tot): {:7,d} /{:7,d} /{:7,d}".format(n_bytes_rxd_total, n_bytes_rxd, n_cyc_zero_b, n_cyc_max_b, n_cyc))
            last_report_time = time.perf_counter()
            n_cyc_zero_b = 0;
            n_bytes_rxd = 0;
            n_cyc_max_b = 0
            n_cyc = 0

except KeyboardInterrupt: # Close the program by pressing Ctrl-C
    f.close()
    spi.close()
    print("\n{:,d} bytes received total.".format(n_bytes_rxd_total))
    print("Closing {}".format(fname))
    print("Exiting.\n")
    

