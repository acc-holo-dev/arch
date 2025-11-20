#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${MODULE_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/hw.sh"

CONFIG_FILE="${APP_CONFIG:-${PROJECT_ROOT}/config.sh}"
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}" || {
  log_error "Configuration file not found: ${CONFIG_FILE}"
  exit 1
}

ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"

build_package_plan() {
  local -n _pacman=$1
  _pacman=()
  _pacman+=("${PACMAN_UTILS[@]}")
  if [[ ${ENABLE_DESKTOP:-1} -eq 1 ]]; then
    _pacman+=("${PACMAN_DESKTOP[@]}")
  fi
  if [[ ${ENABLE_HYPRLAND:-1} -eq 1 ]]; then
    _pacman+=("${PACMAN_HYPRLAND[@]}")
  fi
  if [[ ${ENABLE_DEVTOOLS:-1} -eq 1 ]]; then
    _pacman+=("${PACMAN_DEVTOOLS[@]}")
  fi
  if [[ ${ENABLE_FONTS:-1} -eq 1 ]]; then
    _pacman+=("${PACMAN_FONTS[@]}")
  fi
  if [[ ${ENABLE_GAMING:-0} -eq 1 ]]; then
    _pacman+=("${PACMAN_GAMING[@]}")
  fi
  local gpu_pkgs=()
  hw_gpu_packages gpu_pkgs
  _pacman+=("${gpu_pkgs[@]}")
}

log_section "Userland package install (pacman)"

declare -a pacman_plan
build_package_plan pacman_plan

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
