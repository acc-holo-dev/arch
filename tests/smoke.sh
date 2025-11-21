#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${PROJECT_ROOT}/config/generate.sh" >/dev/null
"${PROJECT_ROOT}/cli/install.sh" --dry-run --stage preflight --profile desktop >/tmp/arch-installer-smoke.log 2>&1 || {
  echo "Preflight dry-run failed"
  exit 1
}

if ! grep -q "Preflight complete" /tmp/arch-installer-smoke.log; then
  echo "Missing completion marker in log"
  exit 1
fi

echo "Smoke test passed"
