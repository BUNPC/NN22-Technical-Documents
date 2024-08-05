//
// wrappers to provide the i2c_write_blocking() and i2c_read_blocking() functions
//

#include <stdbool.h>
#include <stdint.h>

int i2c_write_blocking( int dev, uint8_t i2c_addr, 
			uint8_t* reg_addr, int count, bool flag);

int i2c_read_blocking( int dev, uint8_t i2c_addr,
		       uint8_t* dbuf, int count, bool flag);

