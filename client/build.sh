#!/usr/bin/env bash
# Build Godot web export locally.
# Usage: ./build.sh [godot-binary]
# Example: ./build.sh godot4

set -euo pipefail

GODOT=${1:-godot}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Exporting Godot project (Web) ..."
mkdir -p "${SCRIPT_DIR}/build/web"
"${GODOT}" --headless --path "${SCRIPT_DIR}" --export-release "Web" build/web/index.html

echo "==> Verifying output ..."
test -f "${SCRIPT_DIR}/build/web/index.wasm" || { echo "ERROR: index.wasm not found"; exit 1; }
echo "==> Build complete: $(du -sh "${SCRIPT_DIR}/build/web/")"

echo ""
echo "To deploy:"
echo "  cd ${SCRIPT_DIR} && vercel deploy --prod"
