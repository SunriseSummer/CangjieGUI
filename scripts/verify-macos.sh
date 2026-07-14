#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/scripts/bootstrap-macos.sh"

echo "==> building CUI"
(cd "${ROOT_DIR}" && cjpm build)

echo "==> building SDL"
(cd "${ROOT_DIR}/sdl" && cjpm build)

echo "==> linking Notepad example"
(cd "${ROOT_DIR}/examples/notepad" && cjpm build)

if [[ "${CANGHUI_RUN_TESTS:-0}" == "1" ]]; then
    echo "==> testing CUI"
    (cd "${ROOT_DIR}" && cjpm test)

    echo "==> testing SDL"
    (cd "${ROOT_DIR}/sdl" && cjpm test)
fi

echo "macOS build verification passed"
