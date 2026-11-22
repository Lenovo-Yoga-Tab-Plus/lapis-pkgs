# lapis-pkgs

Package repository for the Lenovo Yoga Tab Plus (TB520FU, codename lapis, SM8650P).
The EndeavourOS image builder lives in the sibling `endeavouros-lapis` tree and installs `lapis-metapkg` from this repo.

## Layout

- `common/`: the three userspace tools this port actually built: `qbootctl` for the A/B slot, `qrtr` for the sensor name service, and `hexagonrpc` (commit `40e50412812a`) for the ADSP sensor file server
- `sm8650/`: the kernel package, firmware helper, ALSA UCM, WirePlumber and topology, network and session config, slot and charge tools, hotspot, ADB gadget, and `lapis-metapkg`
- `config/packages.local.txt`: package directories `scripts/build-local-packages.sh` builds
- `config/packages.upstream.txt`: empty. This port does not mirror another tablet repo
- `config/repo.env`: repo name, architecture, and kernel version
- `scripts/`: build the pacman repo, compose the database, and stage a Pages site
- `.github/workflows/publish.yml`: builds the pacman repo on an ARM runner

The kernel source is [linux-lapis](https://github.com/Lenovo-Yoga-Tab-Plus/linux-lapis). The local checkout stays at `linux-tb520fu`. Firmware blobs, `sn.img`, keys, partition backups, and packed boot images stay out of this tree.

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

`linux-tb520fu` is not installed into the builder image. The builder also does not install `linux-firmware-qcom`; the image build does. Set `LAPIS_FIRMWARE_ROOT` to a firmware directory when building `lenovo-lapis-firmware` if the package should contain the device blobs. Without that directory the package still builds and ships only the staging scripts.

To build one package on the host:

```bash
cd sm8650/alsa-ucm-conf-sm8650
makepkg -s
```
