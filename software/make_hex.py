import sys
import struct

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 make_hex.py <binary_file>")
        sys.exit(1)

    with open(sys.argv[1], "rb") as f:
        data = f.read()

    # Pad to multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    # Process 4 bytes at a time
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        # Unpack as little-endian 32-bit unsigned integer
        val = struct.unpack("<I", chunk)[0]
        # Print as 8-digit hex
        print(f"{val:08x}")

if __name__ == "__main__":
    main()
