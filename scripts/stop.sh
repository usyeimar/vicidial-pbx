#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "⏹️  Deteniendo VICIdial..."
docker compose down
echo "✅ Detenido"
