#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Stage Lenovo-signed firmware blobs for Lenovo Yoga Tab Plus (TB520FU / lapis)
# into an Arch Linux ARM rootfs / initramfs firmware tree.
#
# Usage:
#   ./scripts/stage-lapis-firmware.sh <vendor_dir> <firmware_mnt_image_dir> <target_rootfs_dir> [bluetooth_image_dir] [dsp_lib_dir]

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <vendor_dir> <firmware_mnt_image_dir> <target_rootfs_dir> [bluetooth_image_dir] [dsp_lib_dir]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$1"
FWMNT_DIR="$2"
ROOTFS_DIR="$3"
BT_DIR="${4:-}"
DSP_DIR="${5:-}"

QCOM_FW_DST="${ROOTFS_DIR}/usr/lib/firmware/qcom/sm8650/lenovo/tb520fu"
ATH12K_DST="${ROOTFS_DIR}/usr/lib/firmware/ath12k/WCN7850/hw2.0"
QCA_DST="${ROOTFS_DIR}/usr/lib/firmware/qca"
AWINIC_DST="${ROOTFS_DIR}/usr/lib/firmware/awinic"
NOVATEK_DST="${ROOTFS_DIR}/usr/lib/firmware/novatek"
DSP_SHARE="${ROOTFS_DIR}/usr/share/qcom/sm8650/Lenovo/tb520fu/dsp"

mkdir -p "${QCOM_FW_DST}" "${ATH12K_DST}" "${QCA_DST}" "${AWINIC_DST}" "${NOVATEK_DST}"

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -f "${src}" ]]; then
    install -Dm644 "${src}" "${dst}"
    echo "[OK] Staged $(basename "${dst}")"
  else
    echo "[WARN] Missing optional/pending blob: ${src}"
  fi
}

echo "=== 1. GPU (Adreno 750), Iris VPU & Camera ICP ==="
copy_if_exists "${VENDOR_DIR}/firmware/gen70900_zap.mbn" "${QCOM_FW_DST}/gen70900_zap.mbn"
copy_if_exists "${VENDOR_DIR}/firmware/gen70900_sqe.fw"  "${ROOTFS_DIR}/usr/lib/firmware/qcom/gen70900_sqe.fw"
copy_if_exists "${VENDOR_DIR}/firmware/gmu_gen70900.bin" "${ROOTFS_DIR}/usr/lib/firmware/qcom/gmu_gen70900.bin"
copy_if_exists "${VENDOR_DIR}/firmware/vpu33_4v.mbn"     "${QCOM_FW_DST}/vpu33_4v.mbn"
copy_if_exists "${VENDOR_DIR}/firmware/CAMERA_ICP.mbn"   "${QCOM_FW_DST}/camera_icp.mbn"

echo "=== 2. Touch (Novatek NT36532) & Audio (6x Awinic AW882xx) ==="
copy_if_exists "${VENDOR_DIR}/firmware/novatek_ts_tianma_fw.bin" "${NOVATEK_DST}/novatek_ts_tianma_fw.bin"
copy_if_exists "${VENDOR_DIR}/firmware/novatek_ts_boe_fw.bin"    "${NOVATEK_DST}/novatek_ts_boe_fw.bin"
copy_if_exists "${VENDOR_DIR}/firmware/aw882xx_acf.bin"          "${AWINIC_DST}/tb520fu-aw882xx-acf.bin"

echo "=== 3. ADSP & CDSP (.mbn or PIL squash from .mdt+.bXX) ==="
for stem in adsp adsp_dtb cdsp cdsp_dtb; do
  if [[ -f "${FWMNT_DIR}/${stem}.mbn" ]]; then
    copy_if_exists "${FWMNT_DIR}/${stem}.mbn" "${QCOM_FW_DST}/${stem}.mbn"
  elif [[ -f "${FWMNT_DIR}/${stem}.mdt" ]]; then
    python3 "${SCRIPT_DIR}/pil_squash.py" "${FWMNT_DIR}/${stem}.mdt" "${QCOM_FW_DST}/${stem}.mbn"
  else
    echo "[WARN] Missing ${stem}.mbn / ${stem}.mdt in ${FWMNT_DIR}"
  fi
done

for f in battmgr.jsn adspr.jsn adspua.jsn adsps.jsn cdspr.jsn; do
  copy_if_exists "${FWMNT_DIR}/${f}" "${QCOM_FW_DST}/${f}"
done

echo "=== 4. WCN7850 (kiwi_v2) Wi-Fi 7 & Bluetooth ==="
for bdf in "${FWMNT_DIR}"/kiwi/bdwlan* "${FWMNT_DIR}"/bdwlan*; do
  [[ -f "${bdf}" ]] && install -Dm644 "${bdf}" "${ATH12K_DST}/$(basename "${bdf}")"
done
echo "[OK] Staged WCN7850 board calibration files into ${ATH12K_DST}"

if [[ -n "${BT_DIR}" && -d "${BT_DIR}" ]]; then
  cp -a "${BT_DIR}/"* "${QCA_DST}/"
  echo "[OK] Staged WCN7850 Bluetooth firmware into ${QCA_DST}"
fi

if [[ -n "${DSP_DIR}" && -d "${DSP_DIR}" ]]; then
  mkdir -p "${DSP_SHARE}"
  cp -a "${DSP_DIR}/adsp" "${DSP_DIR}/cdsp" "${DSP_SHARE}/" 2>/dev/null || true
  echo "[OK] Staged FastRPC ADSP/CDSP user libraries into ${DSP_SHARE}"
fi

echo "Done staging TB520FU firmware into ${ROOTFS_DIR}/usr/lib/firmware/"
