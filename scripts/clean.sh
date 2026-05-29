#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

read -r -p "⚠️  Esto eliminará contenedores, volúmenes y red. ¿Continuar? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { echo "Cancelado."; exit 0; }

echo "🗑️  Limpiando todo..."
docker compose down -v --remove-orphans
echo "✅ Limpieza completa"
