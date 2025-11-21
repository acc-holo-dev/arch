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
  log_section "Userland package install (pacman)"

  ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"

  declare -a pacman_plan
  pacman_plan=("${PACMAN_SELECTED[@]}")

  local gpu_pkgs=()
  hw_gpu_packages gpu_pkgs
  pacman_plan+=("${gpu_pkgs[@]}")

  if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
    if [[ ${#pacman_plan[@]} -gt 0 ]]; then
      log_info "Installing packages: ${pacman_plan[*]}"
      arch-chroot "${ROOT_MOUNT}" pacman --noconfirm -S "${pacman_plan[@]}"
    else
      log_info "No pacman packages scheduled"
    fi
  else
    log_info "Would install packages: ${pacman_plan[*]:-<none>}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
