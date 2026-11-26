#!/bin/sh
# Build the initramfs that mounts root=LABEL=eos-lapis.
# Usage: build-initramfs.sh <static-aarch64-busybox> <output.img>
set -eu
BUSYBOX=${1:?static aarch64 busybox}
OUT=${2:?output image}
INIT=$(dirname "$0")/init
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/bin" "$STAGE/sbin" "$STAGE/proc" "$STAGE/sys" "$STAGE/dev" "$STAGE/newroot"
cp "$BUSYBOX" "$STAGE/bin/busybox"
chmod 755 "$STAGE/bin/busybox"
for app in sh ash mount umount findfs switch_root mkdir sleep cat ln ls head ip; do
    ln -s busybox "$STAGE/bin/$app"
done
ln -s ../bin/busybox "$STAGE/sbin/findfs"
ln -s ../bin/busybox "$STAGE/sbin/switch_root"
install -m755 "$INIT" "$STAGE/init"
mkdir -p "$(dirname "$OUT")"
(cd "$STAGE" && find . -print0 | sort -z | cpio --null -o -H newc) | gzip -9 > "$OUT"
