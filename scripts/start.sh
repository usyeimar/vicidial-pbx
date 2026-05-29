#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

# Requiere sudo para reglas de red
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

source .env 2>/dev/null || { echo "❌ Copia .env.example a .env y configúralo"; exit 1; }

SILENT=false
for arg in "$@"; do
  case "$arg" in
    -s|--silent) SILENT=true ;;
  esac
done

echo "🚀 Construyendo y levantando VICIdial..."
docker compose up -d --build

echo "⏳ Esperando que la DB esté lista..."
sleep 15

# Obtener IP del contenedor VICIdial
VICI_IP=$(docker inspect vicidial-pbx-vicidial-1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

# Reglas nftables para port forwarding (Docker no las crea correctamente con nftables)
if [ -n "$VICI_IP" ]; then
  nft add rule ip nat PREROUTING iifname "eth1" tcp dport 8082 counter dnat to ${VICI_IP}:80 2>/dev/null || true
  nft add rule ip nat PREROUTING iifname "eth1" tcp dport 8443 counter dnat to ${VICI_IP}:443 2>/dev/null || true
  nft add rule ip nat PREROUTING iifname "eth1" tcp dport 5062 counter dnat to ${VICI_IP}:5060 2>/dev/null || true
  nft add rule ip nat PREROUTING iifname "eth1" udp dport 5062 counter dnat to ${VICI_IP}:5060 2>/dev/null || true
  nft add rule ip filter FORWARD ip daddr ${VICI_IP} counter accept 2>/dev/null || true
  echo "🔧 Reglas nftables aplicadas (${VICI_IP})"
fi

echo "✅ VICIdial listo en http://${SERVER_IP}:8082/vicidial/welcome.php"
echo "   Login: 6666 / 1234"

if [ "$SILENT" = false ]; then
  echo "📋 Mostrando logs (Ctrl+C para salir)..."
  docker compose logs -f vicidial
fi
