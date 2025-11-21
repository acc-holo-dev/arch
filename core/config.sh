#!/usr/bin/env bash
# Configuration loader (YAML -> bash)
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config}"
CONFIG_CACHE="${CONFIG_DIR}/generated.sh"
CONFIG_YAML="${CONFIG_DIR}/config.yaml"

config_generate_if_needed() {
  if [[ ! -f "${CONFIG_CACHE}" || "${CONFIG_CACHE}" -ot "${CONFIG_YAML}" ]]; then
    "${CONFIG_DIR}/generate.sh"
  fi
}

config_load() {
  config_generate_if_needed
  # shellcheck source=/dev/null
  source "${CONFIG_CACHE}"
}

config_select_profile() {
  local profile_name="${1:-${DEFAULT_PROFILE}}"
  local upper="${profile_name^^}"
  local pacman_groups_var="PROFILE_${upper}_PACMAN_GROUPS[@]"
  local aur_groups_var="PROFILE_${upper}_AUR_GROUPS[@]"
  local flags_var="PROFILE_${upper}_FLAGS[@]"

  if ! declare -p "PROFILE_${upper}_PACMAN_GROUPS" >/dev/null 2>&1; then
    log_error "Unknown profile: ${profile_name}"
    exit 1
  fi

  PACMAN_SELECTED=()
  AUR_SELECTED=()

  for group in "${!pacman_groups_var}"; do
    local array_var="PACMAN_GROUP_${group^^}[@]"
    if declare -p "PACMAN_GROUP_${group^^}" >/dev/null 2>&1; then
      PACMAN_SELECTED+=("${!array_var}")
    else
      log_warn "Profile ${profile_name} references missing pacman group ${group}"
    fi
  done

  for group in "${!aur_groups_var}"; do
    local array_var="AUR_GROUP_${group^^}[@]"
    if declare -p "AUR_GROUP_${group^^}" >/dev/null 2>&1; then
      AUR_SELECTED+=("${!array_var}")
    else
      log_warn "Profile ${profile_name} references missing AUR group ${group}"
    fi
  done

  for flag in "${!flags_var}"; do
    local key="${flag%%=*}"
    local value="${flag#*=}"
    export "${key}"="${value}"
  done

  export INSTALL_PROFILE="${profile_name}"
  export PACMAN_SELECTED AUR_SELECTED
}
