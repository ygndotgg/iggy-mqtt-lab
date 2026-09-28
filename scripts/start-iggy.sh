#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGGY_REPO_DIR="${IGGY_REPO_DIR:-$(cd "$LAB_DIR/.." && pwd)}"
IGGY_SERVER="${IGGY_SERVER:-$IGGY_REPO_DIR/target/release/iggy-server}"

mkdir -p "$LAB_DIR/data/iggy"
cd "$IGGY_REPO_DIR"

IGGY_PATH="$LAB_DIR/data/iggy" \
IGGY_HTTP_ENABLED=true \
IGGY_HTTP_ADDRESS=127.0.0.1:3000 \
IGGY_ROOT_USERNAME=iggy \
IGGY_ROOT_PASSWORD=iggy \
"$IGGY_SERVER" --with-default-root-credentials
