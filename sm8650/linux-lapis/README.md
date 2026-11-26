# linux-lapis

Arch package for the Lenovo Yoga Tab Plus kernel.

The source tree is [linux-lapis](https://github.com/Lenovo-Yoga-Tab-Plus/linux-lapis). This package does not vendor that tree. `makepkg` reads `KERNEL_SRC`, or `../../../linux-tb520fu` when that variable is unset.

The config is `arch/arm64/configs/lapis_defconfig`, with `LOCALVERSION` set to `-lapis`. The package installs the board DTB, the KMS DTB, and the simplefb DTB when the tree still builds them. The image boots `sm8650-lenovo-tb520fu.dtb`.

```bash
KERNEL_SRC=../../../linux-tb520fu makepkg -s
```
