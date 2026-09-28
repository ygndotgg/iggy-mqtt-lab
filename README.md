# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# MQTT Example Using Iggy

This is a source-only lab for testing the MQTT source connector with a vehicle
telemetry workload.

~~~text
emqtt-bench -> EMQX -> six MQTT source connectors -> Iggy
~~~

The lab creates three Iggy streams, six Iggy topics, and two persisted
partitions per topic. Each connector subscribes to two MQTT filters and writes
to one Iggy destination topic.

This repository intentionally focuses on the source path. Sink connectors are
not included yet.

## What you will learn

- How MQTT authentication works with EMQX.
- How six source instances consume different MQTT routes.
- How MQTT routes map to Iggy streams and topics.
- How Iggy persists messages across multiple partitions.
- How MQTT metadata appears in Iggy headers.
- How QoS 1 acknowledgements relate to source persistence.
- How to compare publisher counts with connector and Iggy results.

## Requirements

- Apache Iggy repository checked out beside this directory
- Rust toolchain used by Iggy
- Docker and Docker Compose
- `jq` and `curl`
- `emqtt-bench`

The default benchmark location is:

~~~text
<iggy-repository>/_build/emqtt_bench/rel/emqtt_bench/bin/emqtt_bench
~~~

If it is installed elsewhere, set `BENCH` when publishing.

By default, scripts expect this directory to be inside the Iggy repository.
Set `IGGY_REPO_DIR` if the Iggy checkout is elsewhere.

## Architecture

~~~text
                    ┌─────────────────┐
                    │   emqtt-bench   │
                    └────────┬────────┘
                             │ MQTT 5 / QoS 1
                    ┌────────▼────────┐
                    │      EMQX       │
                    └────────┬────────┘
                             │ six MQTT source instances
              ┌──────────────▼──────────────┐
              │       iggy-connectors       │
              └──────────────┬──────────────┘
                             │
       ┌─────────────────────▼─────────────────────┐
       │                 Iggy server                │
       │  3 streams → 6 topics → 2 partitions each │
       └───────────────────────────────────────────┘
~~~

## Start the lab

~~~bash
./scripts/start-emqx.sh
~~~

Open `http://127.0.0.1:18083` and create this EMQX user:

~~~text
Username: mqtt-test
Password: mqtt-password
~~~

Build Iggy from the Iggy repository root:

~~~bash
cargo build --release --bin iggy-server --bin iggy-connectors --bin iggy
cargo build --release -p iggy_connector_mqtt_source
~~~

Start each long-running process in a separate terminal:

~~~bash
./scripts/start-iggy.sh
./scripts/create-destinations.sh
./scripts/start-connectors.sh
~~~

The Iggy server must be running before `create-destinations.sh`. The streams
and topics must exist before the MQTT source connectors start.

Publish and verify the workload:

~~~bash
./scripts/publish-vehicle-data.sh
./scripts/verify-iggy.sh
~~~

## Service endpoints

| Service | Address |
| --- | --- |
| EMQX MQTT | `mqtt://127.0.0.1:1883` |
| EMQX dashboard | <http://127.0.0.1:18083> |
| Iggy HTTP API | <http://127.0.0.1:3000> |
| Connector API | <http://127.0.0.1:8081> |

## Verify the result

Check connector counters:

~~~bash
curl -s http://127.0.0.1:8081/stats | jq \
  '.connectors[] | select(.key | startswith("mqtt_vehicle_")) | {
    key, status, messages_produced, messages_sent, errors
  }'
~~~

For every destination, `verify-iggy.sh` polls both partitions and prints
headers. Confirm that:

- Each connector is running.
- `messages_produced` and `messages_sent` increase.
- Each route appears only in its mapped Iggy topic.
- `mqtt.topic` contains the original MQTT route.
- `mqtt.protocol`, `mqtt.qos`, `mqtt.dup`, and `mqtt.retain` are present.
- `mqtt.packet_id` is present because the workload uses QoS 1.
- Unique event IDs are present in Iggy.

QoS 1 is at-least-once. During recovery tests, duplicate records are possible;
compare unique event IDs rather than counting raw records only.

## Vehicle mapping

| Connector | MQTT filters | Iggy destination |
| --- | --- | --- |
| C1 | `vehicle/+/engine`, `vehicle/+/battery` | `vehicle-telemetry/engine-battery` |
| C2 | `vehicle/+/tire`, `vehicle/+/fuel` | `vehicle-telemetry/tire-fuel` |
| C3 | `vehicle/+/gps`, `vehicle/+/location` | `vehicle-location/gps-location` |
| C4 | `vehicle/+/speed`, `vehicle/+/heading` | `vehicle-location/speed-heading` |
| C5 | `vehicle/+/diagnostics`, `vehicle/+/faults` | `vehicle-diagnostics/diagnostics-faults` |
| C6 | `vehicle/+/alerts`, `vehicle/+/events` | `vehicle-diagnostics/alerts-events` |

Every destination topic has two partitions. The original MQTT route is stored
in the `mqtt.topic` Iggy header.

## Workload controls

The default workload sends 10,000 messages per route, or 120,000 total:

~~~bash
MESSAGE_LIMIT=10000 INTERVAL_MS=30 ./scripts/publish-vehicle-data.sh
~~~

For a small smoke test:

~~~bash
MESSAGE_LIMIT=10 INTERVAL_MS=100 ./scripts/publish-vehicle-data.sh
~~~

The publisher runs in the background and writes one log per MQTT route under
`logs/`. Inspect them with:

~~~bash
ls -lh logs/
tail -f logs/vehicle-c1-engine.log
~~~

Use a different vehicle identifier by editing the publisher script or its
templates when you need to distinguish separate test runs.

## Troubleshooting

### The connector cannot find its plugin

Run the connector from the Iggy repository root or set `IGGY_REPO_DIR`:

~~~bash
IGGY_REPO_DIR=/absolute/path/to/iggy \
  ./scripts/start-connectors.sh
~~~

The connector configuration uses the release plugin path under
`target/release/`.

### The MQTT source is not receiving messages

Check the EMQX user, then publish a smoke message manually:

~~~bash
mosquitto_pub -h 127.0.0.1 -p 1883 -V mqttv5 -q 1 \
  -u mqtt-test -P mqtt-password \
  -t vehicle/vehicle-001/engine \
  -m '{"event_type":"engine","vehicle_id":"vehicle-001"}'
~~~

Then inspect the C1 source status:

~~~bash
curl -s http://127.0.0.1:8081/sources/mqtt_vehicle_c1 | jq
~~~

### A destination has the wrong partition count

Inspect it with:

~~~bash
target/release/iggy --username iggy --password iggy \
  topic get vehicle-telemetry engine-battery
~~~

Do not start the source against a missing topic. The runtime can create a
missing source destination with its default one-partition configuration.

## Stop the lab

Stop the local Iggy and connector processes with Ctrl-C, then stop EMQX:

~~~bash
./scripts/stop-emqx.sh
~~~

Docker volumes preserve EMQX state. Iggy data is stored under `data/`.

To reset the lab completely, stop the services and remove only this lab's
state:

~~~bash
docker compose down -v
rm -rf data logs
~~~

Only use the reset commands when the stored test data is no longer needed.
