#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDL_DIR="${ROOT_DIR}/sdl/.sdl3"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: bootstrap-macos.sh only supports macOS" >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required; install it before bootstrapping SDL" >&2
    exit 1
fi

resolve_library() {
    local formula="$1"
    local library="$2"
    local prefix

    if ! prefix="$(brew --prefix "${formula}" 2>/dev/null)"; then
        echo "error: Homebrew formula '${formula}' is not installed" >&2
        echo "run: brew install sdl3 sdl3_ttf" >&2
        exit 1
    fi

    local source_path="${prefix}/lib/${library}"
    if [[ ! -f "${source_path}" ]]; then
        echo "error: expected library not found: ${source_path}" >&2
        exit 1
    fi

    printf '%s\n' "${source_path}"
}

install_library() {
    local source_path="$1"
    local destination_path="$2"

    if [[ -e "${destination_path}" ]]; then
        chmod u+w "${destination_path}"
    fi
    /bin/cp -fL "${source_path}" "${destination_path}"
    chmod 0644 "${destination_path}"
}

mkdir -p "${SDL_DIR}"

SDL3_SOURCE="$(resolve_library sdl3 libSDL3.dylib)"
SDL3_TTF_SOURCE="$(resolve_library sdl3_ttf libSDL3_ttf.dylib)"

install_library "${SDL3_SOURCE}" "${SDL_DIR}/libSDL3.dylib"
install_library "${SDL3_TTF_SOURCE}" "${SDL_DIR}/libSDL3_ttf.dylib"

echo "macOS SDL libraries are ready in ${SDL_DIR}"
