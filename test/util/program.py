import sys
import struct


def generate_hex_program(src: str, dst: str) -> None:
    with open(src, "rb") as f:
        data = f.read()

    # Pad to multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    with open(dst, "w") as f_out:
        # Process 4 bytes at a time
        for i in range(0, len(data), 4):
            chunk = data[i:i+4]
            # Unpack as little-endian 32-bit unsigned integer
            val = struct.unpack("<I", chunk)[0]
            # Print as 8-digit hex
            f_out.write(f"{val:08x}\n")
