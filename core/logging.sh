#!/usr/bin/env bash
# Centralized logging helpers
set -euo pipefail

: "${INSTALL_LOG_LEVEL:=INFO}"
: "${INSTALL_LOG_FILE:=}"

__log_levels=(DEBUG INFO WARN ERROR)

log__level_index() {
  local level="$1"
  local idx=0
  for entry in "${__log_levels[@]}"; do
    if [[ "${entry}" == "${level}" ]]; then
      echo "${idx}"
      return 0
    fi
    ((idx++))
  done
  echo 1
}

log_set_level() {
  local new_level="${1:-INFO}"
  case "${new_level}" in
    DEBUG|INFO|WARN|ERROR) INSTALL_LOG_LEVEL="${new_level}" ;;
    *)
      echo "Unknown log level: ${new_level}" >&2
      return 1
      ;;
  esac
}

log_setup() {
  local desired_level="${1:-${INSTALL_LOG_LEVEL}}"
  local log_dir="${2:-}"
  local timestamp
  timestamp="$(date +"%Y%m%d-%H%M%S")"

  log_set_level "${desired_level}"

  if [[ -z "${INSTALL_LOG_FILE}" ]]; then
    if [[ -n "${log_dir}" ]]; then
      mkdir -p "${log_dir}"
      INSTALL_LOG_FILE="${log_dir}/install-${timestamp}.log"
    else
      INSTALL_LOG_FILE="/tmp/arch-install-${timestamp}.log"
    fi
  else
    mkdir -p "$(dirname "${INSTALL_LOG_FILE}")"
  fi

  touch "${INSTALL_LOG_FILE}"
}

log__should_emit() {
  local level="$1"
  local level_idx current_idx
  level_idx="$(log__level_index "${level}")"
  current_idx="$(log__level_index "${INSTALL_LOG_LEVEL}")"
  [[ "${level_idx}" -ge "${current_idx}" ]]
}

log__output() {
  local level="$1"; shift
  local timestamp
  timestamp="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  local formatted="[${timestamp}] [${level}] $*"
  echo -e "${formatted}"
  if [[ -n "${INSTALL_LOG_FILE}" ]]; then
    echo -e "${formatted}" >> "${INSTALL_LOG_FILE}"
  fi
}

log_debug() { log__should_emit DEBUG && log__output DEBUG "$*"; }
log_info()  { log__should_emit INFO  && log__output INFO  "$*"; }
log_warn()  { log__should_emit WARN  && log__output WARN  "$*"; }
log_error() { log__output ERROR "$*" >&2; }

log_section() {
  local title="$1"
  log_info "==== ${title} ===="
}
