#!/usr/bin/env bash
# Removes the containers and network. Data is not persisted, so this is a full reset.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
docker compose down -v
