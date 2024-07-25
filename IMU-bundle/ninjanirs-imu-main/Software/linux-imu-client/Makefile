
all: imu-client

clean:
	rm -f imu-client *.o *~ \#* *.lst

imu-client: imu-client.o sio_cmd.o
	$(CC) -o imu-client imu-client.o sio_cmd.o
