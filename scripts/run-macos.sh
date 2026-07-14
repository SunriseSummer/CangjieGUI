#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_NAME="${1:-notepad}"
EXAMPLE_DIR="${ROOT_DIR}/examples/${EXAMPLE_NAME}"

if [[ ! -f "${EXAMPLE_DIR}/cjpm.toml" ]]; then
    echo "error: unknown example '${EXAMPLE_NAME}'" >&2
    echo "choose a directory under ${ROOT_DIR}/examples" >&2
    exit 1
fi

"${ROOT_DIR}/scripts/bootstrap-macos.sh"
(cd "${EXAMPLE_DIR}" && cjpm run)
