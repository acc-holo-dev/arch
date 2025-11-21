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
  log_section "Disk preparation"

  ROOT_MOUNT="${INSTALL_ROOT:-/mnt}"
  TARGET_DISK="${TARGET_DISK:-/dev/sda}"

  if [[ ${INSTALL_DRY_RUN:-0} -eq 1 ]]; then
    log_info "Dry run enabled; printing intended disk operations only."
  fi

  log_info "Target disk: ${TARGET_DISK}"

  if [[ ${INSTALL_DRY_RUN:-0} -eq 0 ]]; then
    prompt_double_confirm "This will wipe ${TARGET_DISK}. Continue?" || exit 1
    log_info "Creating GPT on ${TARGET_DISK}"
    parted --script "${TARGET_DISK}" \
      mklabel gpt \
      mkpart primary fat32 1MiB 513MiB \
      set 1 esp on \
      mkpart primary linux-swap 513MiB 4.5GiB \
      mkpart primary ext4 4.5GiB 100%

    log_info "Formatting partitions"
    mkfs.fat -F32 "${TARGET_DISK}1"
    mkswap "${TARGET_DISK}2"
    mkfs.ext4 -F "${TARGET_DISK}3"

    log_info "Mounting partitions"
    mount "${TARGET_DISK}3" "${ROOT_MOUNT}"
    mkdir -p "${ROOT_MOUNT}/boot"
    mount "${TARGET_DISK}1" "${ROOT_MOUNT}/boot"
    swapon "${TARGET_DISK}2"
  else
    log_info "Would run partitioning and formatting commands on ${TARGET_DISK}."
  fi

  lsblk -f
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_stage "$@"
fi
