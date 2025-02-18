// ---  NinjaNIRS 2022  ---
// Firmware for NN22_RPi_DetAdapter00_s02_R66R67 board
//
// Major update (2 wire read & resolution boost to 18 bits): 2024-04-14 
// Major update (status packet): 2023-03-30
// Initial version: 2022-12-13 (DetBoardTest00)
// Bernhard Zimmermann - bzim@bu.edu
// Boston University Neurophotonics Center
//

#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/unique_id.h"
#include "det_adapter_pins.h"
#include "hardware/adc.h"
#include "hardware/pio.h"
#include "hardware/pll.h"
#include "hardware/clocks.h"
#include "adcacq_main.pio.h"
#include "adcacq_miso_b.pio.h"

int init_all_adc();
int write_adc_reg(PIO pio, uint sm, uint offset, uint16_t cmd);

int main() {
	int ret = 0;
	uint ii;
	uint32_t adcbuf;
	int32_t adcres[8] = {0};

	bool end_cyc_last = 0;
	bool end_cyc_curr;
	bool first_sample = true;
	uint8_t cyc_cnt = 0;
	const uint8_t PKT_HEADER[] = {253, 252};
	const uint8_t STATUS_PKT_HEADER[] = {239, 238};
	const uint8_t FIRMWARE_VERSION[] = {0, 4};

	pico_unique_board_id_t board_id;
	uint16_t temp_dig;

	/* PLL settings calculator:
	$ python pll_divs.py 96
	Requested: 96.0 MHz
	Achieved: 96.0 MHz
	FBDIV: 128 (VCO = 1536 MHz)
	PD1: 4
	PD2: 4
	*/
	clock_stop(clk_peri);
	clock_configure(clk_sys,
					CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLK_REF,
					0,
					12 * MHZ,
					12 * MHZ);
	pll_deinit(pll_sys);
	pll_init(pll_sys, 1, 1536 * MHZ, 4, 4);
	clock_configure(clk_sys,
					CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLKSRC_CLK_SYS_AUX,
					CLOCKS_CLK_SYS_CTRL_AUXSRC_VALUE_CLKSRC_PLL_SYS,
					96 * MHZ,
					96 * MHZ);
	clock_configure(clk_peri,
					0,
					CLOCKS_CLK_PERI_CTRL_AUXSRC_VALUE_CLKSRC_PLL_SYS,
					96 * MHZ,
					96 * MHZ);

	// GPIO setup
	gpio_init(END_CYC_PIN); //input
	gpio_init(STATUS_SELECT_PIN); //input
	gpio_init(RESERVED_PIN);
	gpio_set_dir(RESERVED_PIN, GPIO_OUT);
	gpio_init(OPT_EN_VP_PIN);
	gpio_set_dir(OPT_EN_VP_PIN, GPIO_OUT);
	gpio_init(OPT_EN_VN_PIN);
	gpio_set_dir(OPT_EN_VN_PIN, GPIO_OUT);
	gpio_init(LED_PIN);
	gpio_set_dir(LED_PIN, GPIO_OUT);
	gpio_put(LED_PIN, 1);

	// UART setup
	uart_init(uart0, 6000000);
	uart_set_hw_flow(uart0, true, false); // enable CTS (tx flow control)
	gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
	gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
	gpio_set_function(BOARD_SELECT_PIN, GPIO_FUNC_UART);
	
	// PIO setup
	init_all_adc();

	// Internal ADC setup
	adc_init();
    adc_set_temp_sensor_enabled(true);
    adc_select_input(4); // select temperature sensor
	temp_dig = adc_read();

	// Unique board ID - read from flash
	pico_get_unique_board_id(&board_id);

	// sleep for a random (but constant for each board) time
	sleep_us(((uint64_t)board_id.id[6]<<5) + 512);

	// turn on power to detectors
	gpio_put(OPT_EN_VN_PIN, 1);
	gpio_put(OPT_EN_VP_PIN, 1);
	gpio_put(LED_PIN, 0);
	
	//uart_puts(uart0, "init\n");
	
	while (1) { // Main Loop
		end_cyc_curr = gpio_get(END_CYC_PIN);
		if (end_cyc_curr == 1 && end_cyc_last == 0) {
			if (gpio_get(STATUS_SELECT_PIN)) {
				// write status packet into uart fifo
				uart_write_blocking(uart0, STATUS_PKT_HEADER, 2);
				uart_putc_raw(uart0, (char)cyc_cnt);
				uart_write_blocking(uart0, board_id.id, 8);
				uart_write_blocking(uart0, FIRMWARE_VERSION, 2);
				uart_write_blocking(uart0, (uint8_t *) &temp_dig, 2);
				uart_putc_raw(uart0, 0); // future additional status info
				uart_putc_raw(uart0, 0); // e.g. adc overflow flags
				uart_putc_raw(uart0, 0); 
				uart_putc_raw(uart0, 0); 
				uart_putc_raw(uart0, 0); //possibly tx crc in future
				temp_dig = adc_read();
			} else {
				// write results packet into uart fifo
				uart_write_blocking(uart0, PKT_HEADER, 2);
				uart_putc_raw(uart0, (char)cyc_cnt);
				for (ii = 0; ii < 8; ii++){
					adcres[DET_ADC_MAP[ii]] = adcres[DET_ADC_MAP[ii]] >> 2; // for compatibility with prev versions
					uart_write_blocking(uart0, (uint8_t *) &adcres[DET_ADC_MAP[ii]], 3); // tx only 24 bit result
					adcres[DET_ADC_MAP[ii]] = 0;
				}
				uart_putc_raw(uart0, 0); //possibly tx crc in future

				// fifos should be empty here, but still check in case of abnormal startup or upset of single sm
				for (ii = 0; ii <= 3; ii++){
					if (!pio_sm_is_rx_fifo_empty(pio0, ii)) { // should always be false in steady state
						pio_sm_get(pio0, ii); // discard
					}
					if (!pio_sm_is_rx_fifo_empty(pio1, ii)) { // should always be false in steady state
						pio_sm_get(pio1, ii); // discard
					}
				}
			}

			cyc_cnt += 1;
			first_sample = true;
		}
		end_cyc_last = end_cyc_curr;

		if (!pio_sm_is_rx_fifo_empty(pio0, 0)) { // new sample available
			if (!first_sample) {
				for (ii = 0; ii <= 3; ii++){
					if (!pio_sm_is_rx_fifo_empty(pio0, ii)) { // should always be true in steady state
						adcbuf = pio_sm_get(pio0, ii);
						if (adcbuf & 1u<<17) { // sign extension if value is negative
							adcbuf = adcbuf | 0x3FFF<<18; 
						}
						adcres[ii] += (int32_t)adcbuf;
					}
					if (!pio_sm_is_rx_fifo_empty(pio1, ii)) { // should always be true in steady state
						adcbuf = pio_sm_get(pio1, ii);
						if (adcbuf & 1u<<17) { // sign extension if value is negative
							adcbuf = adcbuf | 0x3FFF<<18; 
						}
						adcres[ii+4] += (int32_t)adcbuf;
					}
				}
			} else { // discard first sample as it is from the previous LED state (ADC latency of 1)
				for (ii = 0; ii <= 3; ii++){
					if (!pio_sm_is_rx_fifo_empty(pio0, ii)) { // should always be true in steady state
						pio_sm_get(pio0, ii); // discard
					}
					if (!pio_sm_is_rx_fifo_empty(pio1, ii)) { // should always be true in steady state
						pio_sm_get(pio1, ii); // discard
					}
				}
				first_sample = false;
			}
		}

		gpio_put(RESERVED_PIN, 1); // for measuring loop execution duration
		asm volatile("nop"); //asm volatile("nop \n nop");
		gpio_put(RESERVED_PIN, 0);
	}
}


int init_all_adc(){
	int ret = 0;
	uint main_offset_pio0 = pio_add_program(pio0, &adcacq_main_program);
	uint miso_b_offset_pio0 = pio_add_program(pio0, &adcacq_miso_b_program);
	uint main_offset_pio1 = pio_add_program(pio1, &adcacq_main_program);
	uint miso_b_offset_pio1 = pio_add_program(pio1, &adcacq_miso_b_program);

	adcacq_main_program_init(pio0, 0, main_offset_pio0, CSN_A1_PIN, SCLK_A1_PIN, MISO_A1_PIN, MOSI_A1_PIN);
	adcacq_miso_b_program_init(pio0, 1, miso_b_offset_pio0, MISOB_A1_PIN);
	adcacq_main_program_init(pio0, 2, main_offset_pio0, CSN_A2_PIN, SCLK_A2_PIN, MISO_A2_PIN, MOSI_A2_PIN);
	adcacq_miso_b_program_init(pio0, 3, miso_b_offset_pio0, MISOB_A2_PIN);

	adcacq_main_program_init(pio1, 0, main_offset_pio1, CSN_A3_PIN, SCLK_A3_PIN, MISO_A3_PIN, MOSI_A3_PIN);
	adcacq_miso_b_program_init(pio1, 1, miso_b_offset_pio1, MISOB_A3_PIN);
	adcacq_main_program_init(pio1, 2, main_offset_pio1, CSN_A4_PIN, SCLK_A4_PIN, MISO_A4_PIN, MOSI_A4_PIN);
	adcacq_miso_b_program_init(pio1, 3, miso_b_offset_pio1, MISOB_A4_PIN);

	pio_enable_sm_mask_in_sync(pio0, 0xf);
	pio_enable_sm_mask_in_sync(pio1, 0xf);

	// init ADC + set config registers
	write_adc_reg(pio0, 0, main_offset_pio0, 0x20FF); //hard reset
	ret += write_adc_reg(pio0, 0, main_offset_pio0, 0x1084); // 4x oversampling + resolution boost
	write_adc_reg(pio0, 2, main_offset_pio0, 0x20FF); //hard reset
	ret += write_adc_reg(pio0, 2, main_offset_pio0, 0x1084); // 4x oversampling + resolution boost
	write_adc_reg(pio1, 0, main_offset_pio1, 0x20FF); //hard reset
	ret += write_adc_reg(pio1, 0, main_offset_pio1, 0x1084); // 4x oversampling + resolution boost
	write_adc_reg(pio1, 2, main_offset_pio1, 0x20FF); //hard reset
	ret += write_adc_reg(pio1, 2, main_offset_pio1, 0x1084); // 4x oversampling + resolution boost

	pio_clkdiv_restart_sm_mask(pio0, 0xf);
	pio_clkdiv_restart_sm_mask(pio1, 0xf);
}

int write_adc_reg(PIO pio, uint sm, uint offset, uint16_t cmd){
	//cmd should be in "read" format, meaning the MSB should be 0

	uint32_t readback = 0;

	// reset SM	
	pio_sm_restart(pio, sm);
	pio_sm_clear_fifos(pio, sm);

	// jump to reg_rw sub-program
	pio_sm_exec(pio, sm , pio_encode_jmp(offset + adcacq_main_offset_reg_rw) | pio_encode_sideset(1, 1));

	// send write cmd
	pio_sm_put_blocking(pio, sm, (uint32_t)(cmd | 1u<<15) <<16);
	pio_sm_get_blocking(pio, sm); //discard
	// send read command
	pio_sm_put_blocking(pio, sm, (uint32_t)cmd <<16);
	pio_sm_get_blocking(pio, sm); //discard
	// send nop
	pio_sm_put_blocking(pio, sm, 0);
	readback = pio_sm_get_blocking(pio, sm);

	// reset SM	
	pio_sm_restart(pio, sm);
	pio_sm_clear_fifos(pio, sm);

	// jump to main program
	pio_sm_exec(pio, sm , pio_encode_jmp(offset) | pio_encode_sideset(1, 1));

	if ((cmd & 0x0fff) == ((uint16_t *) &readback)[0]) {
		return 0;
	} else {
		return 1;
	}
}
