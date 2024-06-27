# ---  NinjaNIRS 2022  ---
# System class for NinjaNIRS 2022.
#
# Initial version: 2023-6-2
# Bernhard Zimmermann - bzim@bu.edu
# Boston University Neurophotonics Center
#

import time
import spidev
import configparser
import numpy as np
from math import ceil, floor

# system constants
N_DET_SLOTS = 24

def bitfield(num, nbits=8):
    return [num >> i & 1 for i in range(nbits)]

class NN22System:
    def __init__(self):
        configurations = configparser.ConfigParser()
        configurations.read('NN22config.cfg') # TODO: Use 'try' or 'with'?
        self.config = configurations['DEFAULT']

        # Initialize SPI bus
        self.spi = spidev.SpiDev()
        self.spi.open(self.config.getint('spi_bus'), self.config.getint('spi_dev')) #(bus, device)
        self.spi.max_speed_hz = self.config.getint('spi_max_speed_hz')
        self.spi.mode = self.config.getint('spi_mode')

        # Create default status register values
        self.vn22clk_en = False
        self.vn3p4_en = False
        self.vn22_en = False
        self.v9p0_en = False
        self.v5p1src_en = False
        self.v5p1rpi_off = False
        self.v5p1b23_en = False
        self.v5p1b01_en = False

        self.clk_div = self.config.getint('clk_div')

        self.aux_active = self.config.getboolean('aux_active')

        # Reset program counter A
        self.rst_pca = True
        # Reset all RP2040 microcontrollers
        self.rst_detb = True

        self.run = False
        self.powerOn()

        # TODO: Automatically determine which detector cards are plugged in and active
        # (translate Matlab)
        self.detb_active = [0] * N_DET_SLOTS
        self.detb_active[0] = 1
        self.n_detb_active = sum(self.detb_active)
        self.acc_active = False

        # create RAM A
        self.rama = np.zeros([1024, 32], dtype=int)
        self.n_states_a = 2
        # Example using only one wavelength and power setting of source 1
        # Used e.g. for filter wheel tests
        self.rama[0,0:3] = bitfield(1, 3) # select LED row
        self.rama[0,6] = 1 # select LED column
        self.rama[0,18:21] = bitfield(4, 3) # power level

        self.rama(self.n_states_a:, 26) = 1 # mark sequence end

        self.n_status_states = 0;

        # stat.rama(stat.nstates+1,22) = 1; %transmit status during this state
        # stat.rama((stat.nstates+1):end,27) = 1; % mark sequence end
 
        # create RAM B
        self.createRAMB()

        # Accelerometer / IMU constants
        # these are defined in the IMU MCU firmware
        # TODO: read this from the MCU directly (e.g. implement in status packet)
        if self.acc_active:
            self.accfs = 4 # +- 4g
            self.gyrofs = 250 # +- 250 degrees per second

        # upload to RAMs

    def uploadToRAM(self, ram_select, skipreadback=False):
        # Uploads selected ram variable to FPGA
        
        if ram_select == 'a':
            addr_offset = 16
            d = self.rama # create alias
        elif ram_select == 'b':
            addr_offset = 32
            d = self.ramb
        else:
            print("ram_select invalid")
            return
        
        # flush FSM in FPGA
        self.writeBytes([0]*8)

        buf = np.zeros(1024*(1+2+4), dtype=int)

        for irow in range(1024):
            offset = irow*(1+2+4)
            buf[offset] = 255 # command header
            buf[offset+1] = irow%256 # address low byte
            buf[offset+2] = 128 + addr_offset + irow>>8 # address high byte
            for ibyte in range(4): # value bytes
                # convert the 32 individual bits of each row to 4 bytes
                buf[offset+3+ibyte] = sum([d[irow, (ibyte*8 + ibit)]<<ibit for ibit in range(8)])

        self.writeBytes(buf)

        # TODO: implement read-back check


    def createRAMB(self):
        self.ramb = np.zeros([1024, 32], dtype=int)

        # number of used RAM B states
        self.n_states_b = self.config.getint('n_states_b')
        # duration of end cycle pulse period
        t_end_cyc = self.config.getfloat('t_end_cyc')
        # holdoff between different selected detector board uart transmissions
        t_bsel_holdoff = self.config.getfloat('t_bsel_holdoff')
        # minimum duration of each board select period
        # (32bytes*10bits/6000000baud = 53.4e-6 s)
        t_bsel_min = = self.config.getfloat('t_bsel_min')
        # time to hold off sampling after state switch to let analog signal settle
        # at 350 us the signal should be approx 101% of final value
        t_smp_holdoff_start = self.config.getfloat('t_smp_holdoff_start')
        # time to hold off sampling before state switch (at end of cycle)
        t_smp_holdoff_end = self.config.getfloat('t_smp_holdoff_end')
        # minimum period for each sample 
        # (depends on ADC, ADC internal oversampling, transfer to MCU, computation in MCU)
        t_smp_min = self.config.getfloat('t_smp_min')
        # target number of samples to be averaged for each A state
        # values >256 risk overflow of the result (ADC: 16bit, result: 24bit)
        n_smp_target = self.config.getint('n_smp_target')

        # duration of each RAM B state
        t_state_b = self.clk_div*8/96e6
        # duration of each RAM A state
        t_state_a = t_state_b * self.n_states_b
        # target ADC sampling perid
        t_smp_target = max((t_state_a -t_smp_holdoff_start - t_smp_holdoff_end)/n_smp_target, t_smp_min)
        # number of B states for each ADC sample
        ni_smp = max(ceil(t_smp_target/t_state_b), 2)
        # number of B states the trig signal is '1' for each ADC sample
        ni_smp_on = floor(ni_smp/2)

        # write end cycle bits
        self.ramb[1:(1+ceil(t_end_cyc/t_state_b)), 8] = 1;
    
        # write ADC sampling bits
        for ii in range(ni_smp_on):
            start_idx = round(t_smp_holdoff_start/t_state_b) + ii -1
            end_idx = self.n_state_b - round(t_smp_holdoff_end/t_state_b)  + ii
            # TODO: check that end_idx + ni_smp_off < n_state_b
            self.ramb[start_idx:ni_smp:end_idx, 10] = 1
        
        # number of samples collected during each A state
        # (first sample will be discarded by detector board)
        self.n_smp = sum(self.ramb[start_idx:ni_smp:end_idx, 10]) -1;
        if self.n_smp > 255 # 256*16bit number could overflow 24 bit result
            print("Warning: nsamples large, overflow possible.")

        # Data transmission management
        # number of B states allocated to each UART data source (det boards + IMU)
        ni_bsel = floor((self.n_state_b - round(t_end_cyc/t_state_b) - 2 - \
                (self.n_detb_active+1+1)*ceil(t_bsel_holdoff/t_state_b) ) \
                / (self.n_detb_active+1))
        if ni_bsel*t_state_b < t_bsel_min:
            print("Warning: t_bsel too short.")

        start_idx = round(t_end_cyc/t_state_b) + ceil(t_bsel_holdoff/t_state_b)
        self.ramb[start_idx-2, 8] = 1 # transmit program counter A
        if self.aux_active:
            self.ramb[start_idx-1, 7] = 1 # transmit aux data
        for (ii, x) in enumerate(self.detb_active):
            if x: # detector is active
                # set source selector bits (UART Rx Mux)
                for jj in range(ni_bsel):
                    self.ramb[start_idx+jj, 0:5] = bitfield(ii, 5)
                # set flow enable bit (DetB Rx En)
                for jj in range(ni_bsel-1):
                    self.ramb[start_idx+jj+1, 5] = 1
                start_idx += ni_bsel + ceil(t_bsel_holdoff/t_state_b)
        # mark sequence end
        self.ramb[(self.n_states_b-1):, 17] = 1

       
    def powerOn(self):
        # turn power on to subsystems sequentially
        # repeated update calls will create natural delay
        self.vn22clk_en = True
        self.v5p1rpi_off = False
        self.updateStatReg()
        self.v5p1b23_en = True
        self.updateStatReg()
        self.v5p1b01_en = True
        self.updateStatReg()
        self.vn3p4_en = True
        self.updateStatReg()
        self.v9p0_en = True
        self.updateStatReg()
        self.vn22_en = True
        self.updateStatReg()
        self.v5p1src_en = True
        self.updateStatReg()

        # this section does not need a delay
        self.rst_pca = False
        self.rst_detb = False
        self.run = False
        self.updateStatReg()
    
    def updateActiveDet(self):
        # This method will detect which detector adapter cards are plugged in 
        # and are active by sequentially trying to read from them.
        # It will also try to detect whether the IMU MCU is active.

        # TODO: translate funtion from MATLAB

        self.detb_active = [0] * 24
        self.detb_active[0] = True
        self.acc_active = False
    
    def updateStatReg(self):
        sreg = [0] * 32

        sreg[23] = self.vn22clk_en
        sreg[22] = self.vn3p4_en
        sreg[21] = self.vn22_en
        sreg[20] = self.v9p0_en
        sreg[19] = self.v5p1src_en
        sreg[18] = self.v5p1rpi_off
        sreg[17] = self.v5p1b23_en
        sreg[16] = self.v5p1b01_en
        sreg[8:15] = bitfield(self.clk_div-1) #[(self.clk_div-1) >> ii & 1 for ii in range(8)]
        sreg[4] = self.rst_pca
        sreg[1] = self.rst_detb
        sreg[0] = self.run

        addr_offset = 64

        valbytes = [0] * 4
        cmdbytes = [0] * 2

        for iv in range(4):
            valbytes[iv] = sum([sreg[ii+8*iv] << ii for ii in range(8)])

        cmdbytes[0] = 1
        cmdbytes[1] = 128 + addr_offset

        self.writeBytes([255] + cmdbytes + valbytes)

        # TODO : implement readback to verify register contents

    def writeBytes(self, vals):
        self.spi.writebytes2(vals)
        # TODO: - implement writing to PySerial
        # TODO: - implement writing to network socket
        # TODO: - use writebytes2 for SPI?





    














