#!/usr/bin/env bash
cd "$(dirname "$0")/.."
docker compose logs -f "${1:-vicidial}"
