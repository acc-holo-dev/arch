#!/usr/bin/env bash
# Error handling helpers

set -euo pipefail

: "${INSTALL_DEBUG:=0}"

error_trap() {
  local exit_code=$?
  local line_no=$1
  log_error "Installation failed at line ${line_no} with exit code ${exit_code}."
  log_error "See log file: ${INSTALL_LOG_FILE}"
  exit "${exit_code}"
}

setup_error_trap() {
  set -E
  trap 'error_trap $LINENO' ERR
}
