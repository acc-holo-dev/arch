#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
MODULE_DIR="${PROJECT_ROOT}/modules"
LOG_DIR="${PROJECT_ROOT}/logs"
APP_CONFIG="${PROJECT_ROOT}/config.sh"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/errors.sh"
source "${LIB_DIR}/prompts.sh"
source "${LIB_DIR}/net.sh"
source "${LIB_DIR}/hw.sh"

INSTALL_DRY_RUN=0
INSTALL_LOG_LEVEL="INFO"
INSTALL_LOG_FILE=""
CUSTOM_STAGE=""

print_help() {
  cat <<USAGE
Arch installer orchestrator
Usage: $0 [options]

Options:
  -n, --dry-run           simulate steps without performing destructive actions
  -l, --log-level LEVEL   logging level (DEBUG, INFO, WARN, ERROR)
      --log-file PATH     custom log file path
  -s, --stage NAME        run only a specific stage (preflight|disk|system|apps|postinstall|aur)
  -h, --help              show this help message
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        INSTALL_DRY_RUN=1
        shift
        ;;
      -l|--log-level)
        INSTALL_LOG_LEVEL="${2:-INFO}"
        shift 2
        ;;
      --log-file)
        INSTALL_LOG_FILE="${2:-}"
        shift 2
        ;;
      -s|--stage)
        CUSTOM_STAGE="${2:-}"
        shift 2
        ;;
      -h|--help)
        print_help
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        print_help
        exit 1
        ;;
    esac
  done
}

require_config() {
  if [[ ! -f "${APP_CONFIG}" ]]; then
    echo "Configuration file not found: ${APP_CONFIG}" >&2
    exit 1
  fi
}

run_stage() {
  local stage="$1"
  local script="${MODULE_DIR}/${stage}.sh"
  if [[ ! -x "${script}" ]]; then
    log_error "Module not found or not executable: ${script}"
    exit 1
  fi
  log_section "Running stage: ${stage}"
  INSTALL_STAGE="${stage}" INSTALL_DRY_RUN="${INSTALL_DRY_RUN}" bash "${script}"
}

main() {
  parse_args "$@"
  require_config
  log_setup "${INSTALL_LOG_LEVEL}" "${LOG_DIR}"
  setup_error_trap

  log_info "Log file: ${INSTALL_LOG_FILE}"
  log_info "Dry run: ${INSTALL_DRY_RUN}"

  detect_cpu
  detect_gpu
  detect_virtualization
  export INSTALL_CPU INSTALL_GPU INSTALL_VIRT APP_CONFIG PROJECT_ROOT

  local stages=(preflight disk system apps postinstall aur)

  if [[ -n "${CUSTOM_STAGE}" ]]; then
    if [[ ! " ${stages[*]} " =~ " ${CUSTOM_STAGE} " ]]; then
      log_error "Unknown stage ${CUSTOM_STAGE}"
      exit 1
    fi
    stages=("${CUSTOM_STAGE}")
  fi

  for stage in "${stages[@]}"; do
    run_stage "${stage}"
  done

  log_section "Installation flow completed"
}

main "$@"
