#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_DIR="${PROJECT_ROOT}/core"

source "${CORE_DIR}/logging.sh"
source "${CORE_DIR}/net.sh"
source "${CORE_DIR}/prompts.sh"
source "${CORE_DIR}/config.sh"

run_stage() {
  config_load
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
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
