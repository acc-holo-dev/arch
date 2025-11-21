#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_DIR="${PROJECT_ROOT}/core"

source "${CORE_DIR}/logging.sh"
source "${CORE_DIR}/hw.sh"
source "${CORE_DIR}/config.sh"

run_stage() {
  config_load
  config_select_profile "${INSTALL_PROFILE:-${DEFAULT_PROFILE}}"
  log_section "AUR packages"

  ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"
  declare -a aur_plan
  aur_plan=("${AUR_SELECTED[@]}")

  local gpu_aur=()
  hw_aur_gpu_packages gpu_aur
  aur_plan+=("${gpu_aur[@]}")

  if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
    if [[ ${#aur_plan[@]} -eq 0 ]]; then
      log_info "No AUR packages scheduled"
      return
    fi
    if ! arch-chroot "${ROOT_MOUNT}" command -v yay >/dev/null 2>&1; then
      log_info "Installing yay helper"
      arch-chroot "${ROOT_MOUNT}" bash -c "cd /tmp && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm"
    fi
    log_info "Installing AUR packages: ${aur_plan[*]}"
    arch-chroot "${ROOT_MOUNT}" sudo -u "${DEFAULT_USER}" yay --noconfirm -S "${aur_plan[@]}"
  else
    log_info "Would install AUR packages: ${aur_plan[*]:-<none>}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
