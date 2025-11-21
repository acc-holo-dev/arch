#!/usr/bin/env bash
# User prompts
set -euo pipefail

prompt_confirm() {
  local message="$1"
  read -r -p "${message} [y/N]: " response
  [[ "${response}" =~ ^[Yy]$ ]]
}

prompt_double_confirm() {
  local message="$1"
  prompt_confirm "${message}" && prompt_confirm "${message} (second confirmation)"
}
