#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_DIR="${PROJECT_ROOT}/core"

source "${CORE_DIR}/logging.sh"
source "${CORE_DIR}/prompts.sh"
source "${CORE_DIR}/config.sh"

run_stage() {
  config_load
  log_section "Post-install configuration"

  ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"
  DEFAULT_SHELL="${DEFAULT_SHELL:-/bin/bash}"

  create_user() {
    if arch-chroot "${ROOT_MOUNT}" id "${DEFAULT_USER}" >/dev/null 2>&1; then
      log_info "User ${DEFAULT_USER} already exists"
      return
    fi
    log_info "Creating user ${DEFAULT_USER}"
    arch-chroot "${ROOT_MOUNT}" useradd -m -G wheel,video,audio -s "${DEFAULT_SHELL}" "${DEFAULT_USER}"
    echo "${DEFAULT_USER}:changeme" | arch-chroot "${ROOT_MOUNT}" chpasswd
    log_info "Enabling sudo for wheel group"
    sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' "${ROOT_MOUNT}/etc/sudoers"
  }

  enable_services() {
    local services=("${SYSTEM_SERVICES[@]}")
    for svc in "${services[@]}"; do
      log_info "Enabling service ${svc}"
      arch-chroot "${ROOT_MOUNT}" systemctl enable "${svc}" || log_warn "Unable to enable ${svc}"
    done
  }

  if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
    create_user
    enable_services
  else
    log_info "Would create user ${DEFAULT_USER} with shell ${DEFAULT_SHELL}"
    log_info "Would enable services: ${SYSTEM_SERVICES[*]:-<none>}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
