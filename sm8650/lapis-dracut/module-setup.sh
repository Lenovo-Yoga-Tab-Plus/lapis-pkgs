#!/usr/bin/bash

install_optional_firmware() {
    local firmware

    for firmware in "$@"; do
        [[ -e "$firmware" ]] || continue
        inst "$firmware"
    done
}

# called by dracut
install() {
    # The panel driver is built in and asks for these files before the root
    # filesystem is mounted. Everything else waits until the real root.
    install_optional_firmware \
        "/usr/lib/firmware/qcom/gen70900_sqe.fw" \
        "/usr/lib/firmware/qcom/gmu_gen70900.bin" \
        "/usr/lib/firmware/qcom/sm8650/lenovo/tb520fu/gen70900_zap.mbn"
}
