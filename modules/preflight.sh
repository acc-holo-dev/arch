#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${MODULE_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/net.sh"
source "${LIB_DIR}/prompts.sh"

CONFIG_FILE="${APP_CONFIG:-${PROJECT_ROOT}/config.sh}"
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}" || {
  log_error "Configuration file not found: ${CONFIG_FILE}"
  exit 1
}

log_section "Preflight checks"

if [[ $(id -u) -ne 0 ]]; then
  log_error "Preflight requires root privileges."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  log_warn "This installer is optimized for x86_64 but detected $(uname -m)."
fi

if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]] && [[ ! -d /sys/firmware/efi ]]; then
  log_error "UEFI environment not detected. bootctl requires UEFI firmware."
  exit 1
fi

require_command lsblk
require_command timedatectl || true
require_command pacstrap || true
require_command systemd-detect-virt || true
require_command git || true
require_command parted || true

sync_time
if [[ ${INSTALL_DRY_RUN:-0} -eq 1 ]]; then
  log_info "Dry run: skipping network wait"
else
  net_wait_for_link 20
fi

if [[ ${INSTALL_DRY_RUN:-0} -eq 1 ]]; then
  log_info "Dry run: skipping hardware stress tests"
else
  log_info "Running smartctl quick check (if available)"
  if command -v smartctl >/dev/null 2>&1; then
    smartctl -H "${TARGET_DISK}" || log_warn "SMART check returned non-zero"
  else
    log_warn "smartctl not installed"
  fi
fi

lsblk -f
log_info "Preflight complete"
