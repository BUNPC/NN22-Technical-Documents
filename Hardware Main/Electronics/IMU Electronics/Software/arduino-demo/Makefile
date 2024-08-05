#
# Makefile for UART example
#
# NOTE: edit F_OSC and DUDPORT to support either directly programming
# the hardware using a programming cable, or Arduino bootloader.
#

MCU = atmega328

# 8 MHz for on-board oscillator
# F_OSC = 8000000

# 16 MHz for Arduino
F_OSC = 16000000

EXTRAOPT = -Wno-discarded-qualifiers -DDEBUG

CFLAGS = -g -Os -mmcu=$(MCU) $(EXTRAOPT) -DF_CPU=$(F_OSC) -Wl,-u,vfprintf -lprintf_min -lm
# no-optimization settings for interrupt code
CFLAGS_NOOPT = -g -O0 -mmcu=$(MCU) $(EXTRAOPT) -DF_CPU=$(F_OSC) -I../util -Wl,-u,vfprintf -lprintf_min

LDFLAGS = -Wl,-Map=$(<:.o=.map),--cref -mmcu=$(MCU)

FUSEOPT = -U hfuse:w:0xd9:m

# programmer configuration for avrdude programming utility

# for AVRISP programmer on USB
DUDEPORT  = -c avrispv2 -P usb

# for Arduino bootloader
# DUDEPORT  = -c arduino -P /dev/ttyACM0

# set to correct device type; usually an Arduino Uno is 328p
DUDEMCU = m328p

AVRDUDE  = avrdude $(DUDEPORT) -p $(DUDEMCU) -y -u 

objects = main.o uart.o i2c.o imu.o

headers = uart.h


all: $(objects)  main.hex list

clean:
	rm -f *.o *~ *.hex *.elf *.map *.lst

flash: main.hex
	$(AVRDUDE) -U flash:w:$^:i

list:
	avr-objdump -h -S main.elf > main.lst
	avr-size --common -x main.elf

$(objects): %.o: %.c $(headers)
	avr-gcc -c $(CFLAGS) $< -o $@

main.elf: $(objects)
	avr-gcc $(LDFLAGS) $(objects) -o $@

main.hex: main.elf
	avr-objcopy -j .text -j .data -O ihex $< $@

fuse:
	$(AVRDUDE) $(FUSEOPT)
