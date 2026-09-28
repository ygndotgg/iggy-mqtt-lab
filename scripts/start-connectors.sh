#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGGY_REPO_DIR="${IGGY_REPO_DIR:-$(cd "$LAB_DIR/.." && pwd)}"
IGGY_CONNECTORS="${IGGY_CONNECTORS:-$IGGY_REPO_DIR/target/release/iggy-connectors}"

cd "$IGGY_REPO_DIR"
IGGY_CONNECTORS_CONFIG_PATH="$LAB_DIR/config/connectors" \
  "$IGGY_CONNECTORS"
