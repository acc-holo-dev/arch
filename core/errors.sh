#!/usr/bin/env bash
# Error handling helpers
set -euo pipefail

setup_error_trap() {
  trap 'catch_error $?' ERR
}

catch_error() {
  local status=$1
  if declare -f log_error >/dev/null 2>&1; then
    log_error "Installer aborted with status ${status}"
  else
    echo "Installer aborted with status ${status}" >&2
  fi
  exit "${status}"
}
