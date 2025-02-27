import struct

# Define the pattern
pattern = [
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
]

# Open a binary file for writing
with open("pattern.bin", "wb") as f:
    for i in range(4096):
        # Write the pattern to the file
        f.write(struct.pack("B", pattern[i % len(pattern)]))
