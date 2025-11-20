#!/usr/bin/env bash
# Prompt helpers

set -euo pipefail

prompt_confirm() {
  local message="${1:-Proceed?}"
  local default_answer="${2:-y}"
  local prompt="[y/N]"
  [[ "${default_answer}" =~ ^[Yy]$ ]] && prompt="[Y/n]"

  while true; do
    read -r -p "${message} ${prompt} " reply
    reply=${reply:-${default_answer}}
    case "${reply}" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

prompt_input() {
  local message="$1"
  local default_value="${2:-}"
  read -r -p "${message} ${default_value:+[${default_value}]} " reply
  echo "${reply:-${default_value}}"
}
