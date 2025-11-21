#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_YAML="${SCRIPT_DIR}/config.yaml"
OUTPUT_FILE="${SCRIPT_DIR}/generated.sh"

if [[ ! -f "${CONFIG_YAML}" ]]; then
  echo "Config file missing: ${CONFIG_YAML}" >&2
  exit 1
fi

tmpfile="$(mktemp)"
python - "$CONFIG_YAML" "$tmpfile" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
raw = config_path.read_text()

try:
    import yaml  # type: ignore
except Exception:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pyyaml"])
    import yaml  # type: ignore

data = yaml.safe_load(raw)

install = data.get("install", {})
pacman_groups = data.get("packages", {}).get("pacman", {})
aur_groups = data.get("packages", {}).get("aur", {})
services = data.get("services", [])
profiles = data.get("profiles", {})

lines = []

lines.append(f'INSTALL_ROOT="{install.get("root", "/mnt")}"')
lines.append(f'TARGET_DISK="{install.get("target_disk", "/dev/sda")}"')
lines.append(f'DEFAULT_USER="{install.get("user", "archuser")}"')
lines.append(f'HOSTNAME="{install.get("hostname", "arch-host")}"')
lines.append(f'DEFAULT_PROFILE="{install.get("default_profile", "desktop")}"')

for group, items in pacman_groups.items():
    arr = ' '.join(items)
    lines.append(f'PACMAN_GROUP_{group.upper()}=({arr})')

for group, items in aur_groups.items():
    arr = ' '.join(items)
    lines.append(f'AUR_GROUP_{group.upper()}=({arr})')

svc_arr = ' '.join(services)
lines.append(f'SYSTEM_SERVICES=({svc_arr})')

for name, profile in profiles.items():
    pgroups = ' '.join(profile.get('pacman_groups', []))
    agroups = ' '.join(profile.get('aur_groups', []))
    flag_parts = []
    for key, val in profile.get('flags', {}).items():
        flag_parts.append(f'{key}={val}')
    flag_joined = ' '.join(flag_parts)
    lines.append(f'PROFILE_{name.upper()}_PACMAN_GROUPS=({pgroups})')
    lines.append(f'PROFILE_{name.upper()}_AUR_GROUPS=({agroups})')
    lines.append(f'PROFILE_{name.upper()}_FLAGS=({flag_joined})')

output_path.write_text('\n'.join(lines) + '\n')
PY

mv "${tmpfile}" "${OUTPUT_FILE}"
echo "Generated ${OUTPUT_FILE}"
