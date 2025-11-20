#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${MODULE_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/prompts.sh"
source "${LIB_DIR}/hw.sh"

CONFIG_FILE="${APP_CONFIG:-${PROJECT_ROOT}/config.sh}"
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}" || {
  log_error "Configuration file not found: ${CONFIG_FILE}"
  exit 1
}

ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"
DEFAULT_USER="${DEFAULT_USER:-archuser}"
AUR_PLANNED=()

if [[ -n "${AUR_PLAN:-}" ]]; then
  # shellcheck disable=SC2206
  AUR_PLANNED=(${AUR_PLAN})
else
  plan_aur_packages() {
    local -n _aur=$1
    _aur=("${AUR_PACKAGES[@]}")
    local gpu_aur=()
    hw_aur_gpu_packages gpu_aur
    _aur+=("${gpu_aur[@]}")
  }
  plan_aur_packages AUR_PLANNED
fi

log_section "AUR provisioning"

install_yay() {
  arch-chroot "${ROOT_MOUNT}" sudo -u "${DEFAULT_USER}" bash -c '
    set -euo pipefail
    if ! command -v yay >/dev/null 2>&1; then
      tmpdir=$(mktemp -d)
      cd "$tmpdir"
      git clone https://aur.archlinux.org/yay-bin.git
      cd yay-bin
      makepkg --noconfirm -si
      rm -rf "$tmpdir"
    fi
  '
}

install_packages() {
  local packages=("${AUR_PLANNED[@]}")
  arch-chroot "${ROOT_MOUNT}" sudo -u "${DEFAULT_USER}" yay --noconfirm -S "${packages[@]}"
}

if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
  if [[ ${#AUR_PLANNED[@]} -eq 0 ]]; then
    log_info "No AUR packages requested; skipping yay bootstrap"
  else
    install_yay
    install_packages
  fi
else
  log_info "Would install yay and AUR packages: ${AUR_PLANNED[*]:-<none>}"
fi
