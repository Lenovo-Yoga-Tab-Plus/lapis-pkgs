# lapis-pkgs

Pacman repository for the Lenovo Yoga Tab Plus (TB520FU, codename lapis, SM8650P). The EndeavourOS image builder is the sibling `endeavouros-lapis` tree. It installs `lapis-metapkg` from this repo.

## Layout

`common/` has the two userspace tools this port built. `qrtr` is the sensor name service, and `hexagonrpc` (commit `40e50412812a`) is the ADSP sensor file server.

`qbootctl` is not packaged and must not be installed. `qbootctl -s` moves the active flag without the partition type GUIDs, and this tablet's bootloader then refuses every boot and stays in fastboot. `lapis-slot` in `lapis-utils` reads the slot state and marks the booted slot successful. Slots are switched from fastboot with `fastboot set_active`.

`sm8650/` has the kernel package, the firmware helper, ALSA UCM, WirePlumber, the topology, network and session config, the slot and charge tools, the hotspot, the ADB gadget, and `lapis-metapkg`.

`config/packages.local.txt` is the package list `scripts/build-local-packages.sh` builds. `config/packages.upstream.txt` is empty. This port does not mirror another tablet repo. `config/repo.env` holds the repo name, the architecture, and the kernel version.

`scripts/` builds the pacman repo, writes the database, and stages a Pages site. `.github/workflows/publish.yml` runs that build on an ARM runner.

The kernel source is [linux-lapis](https://github.com/Lenovo-Yoga-Tab-Plus/linux-lapis). The local checkout stays at `linux-tb520fu`. `sn.img`, keys, partition backups, and packed boot images stay out of this tree. The Lenovo device firmware is in `sm8650/lenovo-lapis-firmware/firmware`.

## Local build

On an aarch64 host, from this directory:

```bash
docker build -t lapis-pkgs-builder .
mkdir -p repo

docker run --rm \
  -e LOCAL_BUILDER_ROOT=/work \
  -e KERNEL_SRC=/kernel \
  -v "$PWD/repo:/repo" \
  -v "$PWD/config:/config" \
  -v "$PWD/common:/work/common" \
  -v "$PWD/sm8650:/work/sm8650" \
  -v "$PWD/../linux-tb520fu:/kernel" \
  lapis-pkgs-builder /usr/local/bin/build-local-packages.sh

docker run --rm -v "$PWD:/work" -w /work lapis-pkgs-builder scripts/compose-repo.sh
scripts/stage-pages.sh
```

`linux-tb520fu` is not copied into the builder image. The builder also does not install `linux-firmware-qcom`. The image build does. `lenovo-lapis-firmware` packs the device blobs from `firmware/` next to its PKGBUILD. It leaves out the generic Bluetooth, SQE, and GMU files that `linux-firmware-atheros` and `linux-firmware-qcom` already install. Set `LAPIS_FIRMWARE_ROOT` to use a different tree.

One package on the host:

```bash
cd sm8650/alsa-ucm-conf-sm8650
makepkg -s
```
