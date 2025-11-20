#!/usr/bin/env bash
# Network utilities

set -euo pipefail

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log_error "Missing command: ${cmd}"
    return 1
  fi
}

net_wait_for_link() {
  local timeout="${1:-30}"
  local elapsed=0
  while ! ping -c1 archlinux.org >/dev/null 2>&1; do
    if (( elapsed >= timeout )); then
      log_error "Network check failed after ${timeout}s"
      return 1
    fi
    sleep 2
    ((elapsed+=2))
    log_warn "Waiting for network... (${elapsed}s)"
  done
  log_info "Network is reachable."
}

sync_time() {
  if command -v timedatectl >/dev/null 2>&1; then
    log_info "Synchronizing system clock via timedatectl."
    if ! timedatectl set-ntp true; then
      log_warn "timedatectl failed; continuing without NTP"
    fi
  else
    log_warn "timedatectl not available; skipping time sync."
  fi
}
