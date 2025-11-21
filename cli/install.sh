#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_DIR="${PROJECT_ROOT}/core"
STAGE_DIR="${PROJECT_ROOT}/stages"
LOG_DIR="${PROJECT_ROOT}/logs"
HOOK_DIR="${PROJECT_ROOT}/hooks"
CONFIG_DIR="${PROJECT_ROOT}/config"

source "${CORE_DIR}/logging.sh"
source "${CORE_DIR}/errors.sh"
source "${CORE_DIR}/prompts.sh"
source "${CORE_DIR}/hw.sh"
source "${CORE_DIR}/config.sh"

INSTALL_DRY_RUN=0
INSTALL_LOG_LEVEL="INFO"
INSTALL_LOG_FILE=""
CUSTOM_STAGE=""
INSTALL_PROFILE=""

print_help() {
  cat <<USAGE
Arch installer orchestrator
Usage: $0 [options]

Options:
  -n, --dry-run           simulate steps without performing destructive actions
  -l, --log-level LEVEL   logging level (DEBUG, INFO, WARN, ERROR)
      --log-file PATH     custom log file path
  -s, --stage NAME        run only a specific stage (preflight|disk|system|apps|postinstall|aur)
  -p, --profile NAME      choose profile from config (default from YAML)
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
      -p|--profile)
        INSTALL_PROFILE="${2:-}"
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

stage_registry() {
  echo "preflight" "${STAGE_DIR}/preflight.sh"
  echo "disk" "${STAGE_DIR}/disk.sh"
  echo "system" "${STAGE_DIR}/system.sh"
  echo "apps" "${STAGE_DIR}/apps.sh"
  echo "postinstall" "${STAGE_DIR}/postinstall.sh"
  echo "aur" "${STAGE_DIR}/aur.sh"
}

run_hooks() {
  local stage="$1" phase="$2"
  local hook_path="${HOOK_DIR}/${stage}/${phase}.d"
  if [[ -d "${hook_path}" ]]; then
    while IFS= read -r hook; do
      if [[ -x "${hook}" ]]; then
        log_info "Running ${phase} hook ${hook}"
        "${hook}"
      fi
    done < <(find "${hook_path}" -maxdepth 1 -type f | sort)
  fi
}

run_stage() {
  local stage="$1" script="$2"
  if [[ ! -x "${script}" ]]; then
    log_error "Module not found or not executable: ${script}"
    exit 1
  fi
  log_section "Running stage: ${stage}"
  run_hooks "${stage}" before
  INSTALL_STAGE="${stage}" INSTALL_DRY_RUN="${INSTALL_DRY_RUN}" \
    INSTALL_PROFILE="${INSTALL_PROFILE:-${DEFAULT_PROFILE}}" bash "${script}"
  run_hooks "${stage}" after
}

main() {
  parse_args "$@"
  config_generate_if_needed
  config_load

  log_setup "${INSTALL_LOG_LEVEL}" "${LOG_DIR}"
  setup_error_trap

  log_info "Log file: ${INSTALL_LOG_FILE}"
  log_info "Dry run: ${INSTALL_DRY_RUN}"

  detect_cpu
  detect_gpu
  detect_virtualization
  export INSTALL_CPU INSTALL_GPU INSTALL_VIRT CONFIG_DIR PROJECT_ROOT

  local -a registry
  local -A stage_map
  while read -r name path; do
    registry+=("${name}")
    stage_map["${name}"]="${path}"
  done < <(stage_registry)

  if [[ -n "${CUSTOM_STAGE}" ]]; then
    if [[ -z "${stage_map[${CUSTOM_STAGE}]:-}" ]]; then
      log_error "Unknown stage ${CUSTOM_STAGE}"
      exit 1
    fi
    registry=("${CUSTOM_STAGE}")
  fi

  for stage in "${registry[@]}"; do
    run_stage "${stage}" "${stage_map[${stage}]}"
  done

  log_section "Installation flow completed"
}

main "$@"
