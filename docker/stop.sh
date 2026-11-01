#!/usr/bin/env bash
# Stops the Touchless relay. Your data (the relay-data volume) is kept.
set -euo pipefail
cd "$(dirname "$0")"
docker compose -f docker-compose.yml down --remove-orphans
