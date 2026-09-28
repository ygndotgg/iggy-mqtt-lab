#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGGY_REPO_DIR="${IGGY_REPO_DIR:-$(cd "$LAB_DIR/.." && pwd)}"
IGGY_CLI="${IGGY_CLI:-$IGGY_REPO_DIR/target/release/iggy}"

create_stream() {
  "$IGGY_CLI" --username iggy --password iggy stream create "$1" || true
}

create_topic() {
  "$IGGY_CLI" --username iggy --password iggy \
    topic create "$1" "$2" 2 none --durability persisted || true
}

create_stream vehicle-telemetry
create_stream vehicle-location
create_stream vehicle-diagnostics

create_topic vehicle-telemetry engine-battery
create_topic vehicle-telemetry tire-fuel
create_topic vehicle-location gps-location
create_topic vehicle-location speed-heading
create_topic vehicle-diagnostics diagnostics-faults
create_topic vehicle-diagnostics alerts-events

for destination in \
  "vehicle-telemetry engine-battery" \
  "vehicle-telemetry tire-fuel" \
  "vehicle-location gps-location" \
  "vehicle-location speed-heading" \
  "vehicle-diagnostics diagnostics-faults" \
  "vehicle-diagnostics alerts-events"
do
  read -r stream topic <<< "$destination"
  "$IGGY_CLI" --username iggy --password iggy topic get "$stream" "$topic"
done
