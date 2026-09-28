#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGGY_REPO_DIR="${IGGY_REPO_DIR:-$(cd "$LAB_DIR/.." && pwd)}"
BENCH="${BENCH:-$IGGY_REPO_DIR/_build/emqtt_bench/rel/emqtt_bench/bin/emqtt_bench}"
MESSAGE_LIMIT="${MESSAGE_LIMIT:-10000}"
INTERVAL_MS="${INTERVAL_MS:-30}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$LAB_DIR/templates}"
LOG_DIR="${LOG_DIR:-$LAB_DIR/logs}"

mkdir -p "$LOG_DIR"

publish() {
  local route="$1"
  local template="$2"
  local log_name="$3"

  "$BENCH" pub \
    -h 127.0.0.1 -p 1883 -V 5 -q 1 \
    -u mqtt-test -P mqtt-password -c 1 \
    -I "$INTERVAL_MS" -L "$MESSAGE_LIMIT" \
    -t "vehicle/vehicle-001/$route" \
    -m "template://$TEMPLATE_DIR/$template" \
    -C false -x 3600 \
    > "$LOG_DIR/$log_name.log" 2>&1 &
}

publish engine engine.json.tpl vehicle-c1-engine
publish battery battery.json.tpl vehicle-c1-battery
publish tire tire.json.tpl vehicle-c2-tire
publish fuel fuel.json.tpl vehicle-c2-fuel
publish gps gps.json.tpl vehicle-c3-gps
publish location location.json.tpl vehicle-c3-location
publish speed speed.json.tpl vehicle-c4-speed
publish heading heading.json.tpl vehicle-c4-heading
publish diagnostics diagnostics.json.tpl vehicle-c5-diagnostics
publish faults faults.json.tpl vehicle-c5-faults
publish alerts alerts.json.tpl vehicle-c6-alerts
publish events events.json.tpl vehicle-c6-events

echo "Started 12 publishers with limit=$MESSAGE_LIMIT interval=${INTERVAL_MS}ms"
echo "Publisher logs: $LOG_DIR"
