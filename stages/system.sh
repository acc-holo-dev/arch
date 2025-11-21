#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_DIR="${PROJECT_ROOT}/core"

source "${CORE_DIR}/logging.sh"
source "${CORE_DIR}/net.sh"
source "${CORE_DIR}/hw.sh"
source "${CORE_DIR}/config.sh"

run_stage() {
  config_load
  log_section "Base system installation"

  ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"

  BASE_PACKAGES=("${PACMAN_GROUP_BASE[@]}")
  gpu_extra=()
  hw_gpu_packages gpu_extra
  microcode_pkg="$(hw_microcode_package || true)"
  if [[ -n "${microcode_pkg}" ]]; then
    BASE_PACKAGES+=("${microcode_pkg}")
  fi
  BASE_PACKAGES+=("${gpu_extra[@]}")

  if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
    log_info "Bootstrapping packages: ${BASE_PACKAGES[*]}"
    pacstrap "${ROOT_MOUNT}" "${BASE_PACKAGES[@]}"
    log_info "Generating fstab"
    genfstab -U "${ROOT_MOUNT}" >> "${ROOT_MOUNT}/etc/fstab"

    log_info "Setting timezone and locales"
    arch-chroot "${ROOT_MOUNT}" ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    arch-chroot "${ROOT_MOUNT}" hwclock --systohc
    sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' "${ROOT_MOUNT}/etc/locale.gen"
    sed -i 's/^#ru_RU.UTF-8/ru_RU.UTF-8/' "${ROOT_MOUNT}/etc/locale.gen"
    arch-chroot "${ROOT_MOUNT}" locale-gen
    echo "LANG=en_US.UTF-8" > "${ROOT_MOUNT}/etc/locale.conf"
    echo "LC_TIME=ru_RU.UTF-8" >> "${ROOT_MOUNT}/etc/locale.conf"

    log_info "Setting hostname: ${HOSTNAME}"
    echo "${HOSTNAME}" > "${ROOT_MOUNT}/etc/hostname"

    log_info "Installing bootloader"
    arch-chroot "${ROOT_MOUNT}" bootctl install
  else
    log_info "Would pacstrap ${ROOT_MOUNT} ${BASE_PACKAGES[*]}"
    log_info "Would generate fstab and configure locales (en_US + ru_RU)"
    log_info "Would set hostname to ${HOSTNAME} and install bootloader"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
