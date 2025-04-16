
# NEORV32 Core with Extended User Flash as Instruction Memory running Zephyr

This project implements a NEORV32 powered by [Gowin's GW1NR-9](https://www.gowinsemi.com/en/product/detail/49/) FPGA chip core with extended user flash memory (78kb) used as instruction memory for your program. The user flash space can be directly programmed using either the `uart_upload.py` script or the `openFPGALoader` tool.

It can be tested on the [Tang Nano 9k FPGA development board](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html).

## Features

- NEORV32 core implementation
- Extended user flash memory used as instruction memory without first copy to ram, this gives you 38 * 2048 bytes for your program.
- Direct programming of user flash space from the bootloader over uart.
- Flash pages can also be erased from the application, and be written on the go.
- Default configuration have enabled JTAG, GPIO and UART.
- No propriary Gowin IP is used in this repo, you own all the sources.
- Runs Zephyr!!
- Modified bootloader that supports flashing user space part directly from uart.

## Programming the User Flash

### Using `uart_upload.py`

The `uart_upload.py` script allows you to upload and execute an application image via the serial port (UART) to the NEORV32 bootloader. Make sure to reset the processor before starting the upload.

#### Usage

```sh
python uart_upload.py <serial port> <NEORV32 executable>
```

#### Example

```sh
python uart_upload.py /dev/ttyS6 hello_world/neorv32_exe.bin
```

### Using `openFPGALoader`

You can also use the `openFPGALoader` tool to program the user flash space directly.

#### Command

```sh
openFPGALoader -f impl/pnr/tang_nano_9k.fs --user-flash hello_world/neorv32_raw_exe.bin
```

Note, when flashing directly, you need the raw binary!

## Directory Structure

- hello_world: Contains example NEORV32 executable binaries.
- bootloader: Contains a modified bootloader that can erase and upload new programs
- src: Contains the source code for the NEORV32 core, a bespoke user flash driver

## Getting Started

1. Clone the repository.
2. Update the pinout to where you have your uart and JTAG debugger connected on.
3. Build the NEORV32 core and generate the bitstream using GOWIN FPGA Designer.
4. Program the FPGA with the generated bitstream.
5. Use either `uart_upload.py` or `openFPGALoader` to program the user flash space with your NEORV32 executable.

## Requirements

- Python 3.x
- `pyserial` library (for `uart_upload.py`)
- `openFPGALoader` tool


### `openFPGALoader`

Install the `openFPGALoader` tool by following the instructions on the [openFPGALoader GitHub page](https://github.com/trabucayre/openFPGALoader).

### Zephyr app

One of the coolest feature with this soft core, is that you have a zephyr compatible enviroment at your hands. A simple blinky togheter with a uart shell can be found under app.

Build these as a normal zephyr app, and use `openFPGALoader` or `uart_upload.py` tool to upload it, the samy way as the hello_world example

## License

This project is licensed under License SPDX BSD-2-Clause.

## Acknowledgments

- [neorv32](https://github.com/stnolting/neorv32) - The NEORV32 RISC-V Processor
- [picorv32_tang_nano_unified](https://github.com/grughuhler/picorv32_tang_nano_unified) - Original author of flash driver written in verilog for picorv32

