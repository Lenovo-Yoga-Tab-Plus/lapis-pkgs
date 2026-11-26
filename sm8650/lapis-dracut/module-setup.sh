#!/usr/bin/bash

install_optional_dirs() {
    local dir

    for dir in "$@"; do
        [[ -d "$dir" ]] || continue
        inst_dir "$dir"
    done
}

install_optional_firmware() {
    local firmware

    for firmware in "$@"; do
        [[ -e "$firmware" ]] || continue
        inst "$firmware"
    done
}

# called by dracut
install() {
    install_optional_dirs \
        "/usr/lib/firmware" \
        "/usr/lib/firmware/ath12k" \
        "/usr/lib/firmware/qca" \
        "/usr/lib/firmware/awinic" \
        "/usr/lib/firmware/novatek" \
        "/usr/lib/firmware/qcom/sm8650/lenovo/tb520fu"

    install_optional_firmware \
        "/usr/lib/firmware/qcom/gen70900_sqe.fw" \
        "/usr/lib/firmware/qcom/gmu_gen70900.bin" \
        "/usr/lib/firmware/qcom/sm8650/lenovo/tb520fu/gen70900_zap.mbn" \
        "/usr/lib/firmware/awinic/tb520fu-aw882xx-acf.bin"
}
