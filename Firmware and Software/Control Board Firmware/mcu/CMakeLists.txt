# Generated Cmake Pico project file

set(PICO_BOARD_HEADER_DIRS ${CMAKE_SOURCE_DIR})
set(PICO_BOARD nn22board)

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Initialise pico_sdk from installed location
# (note this can come from environment, CMake cache etc)
set(PICO_SDK_PATH "/home/pi/pico/pico-sdk")

set(PICO_BOARD pico CACHE STRING "Board type")

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

if (PICO_SDK_VERSION_STRING VERSION_LESS "1.4.0")
  message(FATAL_ERROR "Raspberry Pi Pico SDK version 1.4.0 (or later) required. Your version is ${PICO_SDK_VERSION_STRING}")
endif()

project(CtrlBoardFirmware C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(CtrlBoardFirmware CtrlBoardFirmware.c )

pico_set_program_name(CtrlBoardFirmware "CtrlBoardFirmware")
pico_set_program_version(CtrlBoardFirmware "0.1")

pico_enable_stdio_uart(CtrlBoardFirmware 0)
pico_enable_stdio_usb(CtrlBoardFirmware 0)

# prevent slow execution on first cycle
pico_set_binary_type(CtrlBoardFirmware copy_to_ram)

# Add the standard library to the build
target_link_libraries(CtrlBoardFirmware
        pico_stdlib)

# Add the standard include files to the build
target_include_directories(CtrlBoardFirmware PRIVATE
  ${CMAKE_CURRENT_LIST_DIR}
  ${CMAKE_CURRENT_LIST_DIR}/.. # for our common lwipopts or any other standard includes, if required
)

# Add any user requested libraries
target_link_libraries(CtrlBoardFirmware
        pico_unique_id
        hardware_i2c
        hardware_pll
        hardware_pwm
        hardware_clocks
        hardware_watchdog
        hardware_adc
        )

pico_add_extra_outputs(CtrlBoardFirmware)

