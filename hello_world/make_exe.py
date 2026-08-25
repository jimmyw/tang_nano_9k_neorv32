"""Wrap a raw NEORV32 binary in the legacy executable header.

The bootloader in this repository accepts the classic NEORV32 executable
format:

    [signature 0x4788CAFE : 4B][size : 4B][checksum : 4B][data ...]

Recent upstream NEORV32 releases changed the header emitted by `make exe`,
so an image built against a current neorv32 checkout is rejected by this
bootloader with ERR_EXE. Build the raw image instead and repackage it:

    make bin
    python make_exe.py neorv32_raw_exe.bin neorv32_exe.bin
"""

import struct
import sys

EXE_SIGNATURE = 0x4788CAFE


def make_exe(raw_bin_path, output_path):
    with open(raw_bin_path, 'rb') as f:
        data = f.read()

    # Pad to a 32-bit word boundary
    while len(data) % 4 != 0:
        data += b'\x00'

    size = len(data)

    # Two's complement of the 32-bit word sum, as checked by the bootloader
    checksum = 0
    for i in range(0, size, 4):
        word = struct.unpack_from('<I', data, i)[0]
        checksum = (checksum + word) & 0xFFFFFFFF
    checksum = ((~checksum) + 1) & 0xFFFFFFFF

    with open(output_path, 'wb') as f:
        f.write(struct.pack('<I', EXE_SIGNATURE))
        f.write(struct.pack('<I', size))
        f.write(struct.pack('<I', checksum))
        f.write(data)

    print(f"Wrote {output_path}")
    print(f"  Size:     {size} bytes")
    print(f"  Checksum: 0x{checksum:08X}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python make_exe.py <neorv32_raw_exe.bin> <neorv32_exe.bin>")
        sys.exit(1)
    make_exe(sys.argv[1], sys.argv[2])
