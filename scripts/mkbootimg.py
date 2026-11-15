#!/usr/bin/env python3
"""
Standalone Android boot.img v0 packager for Samsung Spreadtrum platforms.
Generates compliant boot images for Galaxy J3 (2016) SM-J320M.
"""

import argparse
import os
import struct
import hashlib

BOOT_MAGIC = b"ANDROID!"
BOOT_MAGIC_SIZE = 8
BOOT_NAME_SIZE = 16
BOOT_ARGS_SIZE = 512
BOOT_EXTRA_ARGS_SIZE = 1024

def pad_file(f, page_size):
    pad = (page_size - (f.tell() & (page_size - 1))) & (page_size - 1)
    f.write(b'\x00' * pad)

def write_padded(f_out, data, page_size):
    f_out.write(data)
    pad = (page_size - (len(data) & (page_size - 1))) & (page_size - 1)
    f_out.write(b'\x00' * pad)

def main():
    parser = argparse.ArgumentParser(description="Package Android boot.img v0")
    parser.add_argument("--kernel", required=True, help="path to kernel binary")
    parser.add_argument("--ramdisk", default=None, help="path to ramdisk binary")
    parser.add_argument("--second", default=None, help="path to second bootloader")
    parser.add_argument("--dt", default=None, help="path to device tree blob")
    parser.add_argument("--base", type=lambda x: int(x, 0), default=0x80000000)
    parser.add_argument("--kernel_offset", type=lambda x: int(x, 0), default=0x00008000)
    parser.add_argument("--ramdisk_offset", type=lambda x: int(x, 0), default=0x01000000)
    parser.add_argument("--second_offset", type=lambda x: int(x, 0), default=0x00f00000)
    parser.add_argument("--tags_offset", type=lambda x: int(x, 0), default=0x00000100)
    parser.add_argument("--pagesize", type=lambda x: int(x, 0), default=2048)
    parser.add_argument("--cmdline", default="")
    parser.add_argument("--board", default="")
    parser.add_argument("-o", "--output", required=True, help="output boot.img path")
    args = parser.parse_args()

    with open(args.kernel, "rb") as f:
        kernel_data = f.read()

    ramdisk_data = b""
    if args.ramdisk and os.path.exists(args.ramdisk):
        with open(args.ramdisk, "rb") as f:
            ramdisk_data = f.read()

    second_data = b""
    if args.second and os.path.exists(args.second):
        with open(args.second, "rb") as f:
            second_data = f.read()

    dt_data = b""
    if args.dt and os.path.exists(args.dt):
        with open(args.dt, "rb") as f:
            dt_data = f.read()

    kernel_addr = args.base + args.kernel_offset
    ramdisk_addr = args.base + args.ramdisk_offset
    second_addr = args.base + args.second_offset
    tags_addr = args.base + args.tags_offset

    # Compute SHA1 checksum
    sha = hashlib.sha1()
    sha.update(kernel_data)
    sha.update(struct.pack("<I", len(kernel_data)))
    sha.update(ramdisk_data)
    sha.update(struct.pack("<I", len(ramdisk_data)))
    sha.update(second_data)
    sha.update(struct.pack("<I", len(second_data)))
    if dt_data:
        sha.update(dt_data)
        sha.update(struct.pack("<I", len(dt_data)))
    digest = sha.digest()
    id_field = digest + b'\x00' * (32 - len(digest))

    name_field = args.board.encode("utf-8")[:BOOT_NAME_SIZE]
    name_field = name_field + b'\x00' * (BOOT_NAME_SIZE - len(name_field))

    cmdline = args.cmdline.encode("utf-8")
    cmdline_field = cmdline[:BOOT_ARGS_SIZE]
    cmdline_field = cmdline_field + b'\x00' * (BOOT_ARGS_SIZE - len(cmdline_field))

    extra_cmdline = cmdline[BOOT_ARGS_SIZE:BOOT_ARGS_SIZE + BOOT_EXTRA_ARGS_SIZE]
    extra_field = extra_cmdline + b'\x00' * (BOOT_EXTRA_ARGS_SIZE - len(extra_cmdline))

    # Format header v0:
    header = struct.pack(
        "<8s10I16s512s32s1024s",
        BOOT_MAGIC,
        len(kernel_data),
        kernel_addr,
        len(ramdisk_data),
        ramdisk_addr,
        len(second_data),
        second_addr,
        tags_addr,
        args.pagesize,
        len(dt_data), # header_version or dt_size in older formats
        0, # os_version
        name_field,
        cmdline_field,
        id_field,
        extra_field
    )

    with open(args.output, "wb") as f_out:
        write_padded(f_out, header, args.pagesize)
        write_padded(f_out, kernel_data, args.pagesize)
        if ramdisk_data:
            write_padded(f_out, ramdisk_data, args.pagesize)
        if second_data:
            write_padded(f_out, second_data, args.pagesize)
        if dt_data:
            write_padded(f_out, dt_data, args.pagesize)

    print(f"Packed {args.output} successfully:")
    print(f"  Kernel: {len(kernel_data)} bytes @ 0x{kernel_addr:08x}")
    print(f"  Ramdisk: {len(ramdisk_data)} bytes @ 0x{ramdisk_addr:08x}")
    print(f"  Base: 0x{args.base:08x}, Page size: {args.pagesize}")
    print(f"  Cmdline: {args.cmdline}")

if __name__ == "__main__":
    main()
