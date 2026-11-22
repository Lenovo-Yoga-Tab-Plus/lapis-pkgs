#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""
Squash Qualcomm split PIL firmware (.mdt + .b00..bNN) into a single ELF (.mbn),
matching upstream linux-msm/pil-squasher semantics.
"""

import pathlib
import struct
import sys

QCOM_MDT_TYPE_MASK = 7 << 24
QCOM_MDT_TYPE_HASH = 2 << 24
PT_LOAD = 1


def squash_mdt(mdt_path: pathlib.Path, out_path: pathlib.Path) -> None:
    mdt = mdt_path.read_bytes()
    if mdt[:4] != b"\x7fELF":
        raise ValueError(f"{mdt_path} is not an ELF file")

    ei_class = mdt[4]
    if ei_class == 1:  # ELF32
        e_phoff, _, _, _, e_phentsize, e_phnum = struct.unpack_from("<IIIHHH", mdt, 28)
        ph_fmt = "<IIIIIIII"  # p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align
    elif ei_class == 2:  # ELF64
        e_phoff, _, _, _, e_phentsize, e_phnum = struct.unpack_from("<QQQIHH", mdt, 32)
        ph_fmt = "<IIQQQQQQ"  # p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align
    else:
        raise ValueError(f"Unsupported ELF class {ei_class}")

    stem = mdt_path.with_suffix("")
    b00_path = pathlib.Path(f"{stem}.b00")
    out_buf = bytearray(b00_path.read_bytes() if b00_path.exists() else mdt[: e_phoff + e_phentsize * e_phnum])

    for idx in range(e_phnum):
        off = e_phoff + idx * e_phentsize
        fields = struct.unpack_from(ph_fmt, mdt, off)
        if ei_class == 1:
            p_type, p_offset, _, _, p_filesz, _, p_flags, _ = fields
        else:
            p_type, p_flags, p_offset, _, _, p_filesz, _, _ = fields

        if p_filesz == 0:
            continue

        is_hash = (p_flags & QCOM_MDT_TYPE_MASK) == QCOM_MDT_TYPE_HASH
        if idx == 0:
            continue
        if not is_hash and p_type != PT_LOAD:
            continue

        seg_path = pathlib.Path(f"{stem}.b{idx:02d}")
        if not seg_path.exists():
            raise FileNotFoundError(f"Missing segment {seg_path} for phdr {idx} (filesz={p_filesz})")

        seg_data = seg_path.read_bytes()
        if len(seg_data) != p_filesz:
            raise ValueError(f"{seg_path}: size {len(seg_data)} != p_filesz {p_filesz}")

        end = p_offset + p_filesz
        if len(out_buf) < end:
            out_buf.extend(b"\x00" * (end - len(out_buf)))
        out_buf[p_offset:end] = seg_data

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(out_buf)
    print(f"[OK] Squashed {mdt_path.name} ({e_phnum} phdrs) -> {out_path} ({len(out_buf)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.mdt> <output.mbn>", file=sys.stderr)
        sys.exit(1)
    squash_mdt(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
