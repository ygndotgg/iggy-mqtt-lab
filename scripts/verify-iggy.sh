#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGGY_REPO_DIR="${IGGY_REPO_DIR:-$(cd "$LAB_DIR/.." && pwd)}"
IGGY_CLI="${IGGY_CLI:-$IGGY_REPO_DIR/target/release/iggy}"
CONSUMER_SUFFIX="$(date +%s)"

curl -s http://127.0.0.1:8081/stats \
  | jq '.connectors[] | select(.key | startswith("mqtt_vehicle_")) | {key, status, messages_produced, messages_sent, errors}'

for destination in \
  "vehicle-telemetry engine-battery" \
  "vehicle-telemetry tire-fuel" \
  "vehicle-location gps-location" \
  "vehicle-location speed-heading" \
  "vehicle-diagnostics diagnostics-faults" \
  "vehicle-diagnostics alerts-events"
do
  read -r stream topic <<< "$destination"
  for partition in 0 1
  do
    "$IGGY_CLI" --username iggy --password iggy message poll \
      "$stream" "$topic" "$partition" \
      --first --message-count 20 \
      --consumer "vehicle-check-${stream}-${topic}-${partition}-${CONSUMER_SUFFIX}" \
      --show-headers
  done
done
