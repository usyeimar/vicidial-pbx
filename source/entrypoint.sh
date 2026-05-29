#!/usr/bin/env bash
set -e

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' B='\033[1;34m'
W='\033[1;37m' N='\033[0m' DIM='\033[2m'

banner() {
echo ""
echo -e "  ${B}██╗   ██╗██╗ ██████╗██╗██████╗ ██╗ █████╗ ██╗     ${N}"
echo -e "  ${B}██║   ██║██║██╔════╝██║██╔══██╗██║██╔══██╗██║     ${N}"
echo -e "  ${B}██║   ██║██║██║     ██║██║  ██║██║███████║██║     ${N}"
echo -e "  ${B}╚██╗ ██╔╝██║██║     ██║██║  ██║██║██╔══██║██║     ${N}"
echo -e "  ${B} ╚████╔╝ ██║╚██████╗██║██████╔╝██║██║  ██║███████╗${N}"
echo -e "  ${B}  ╚═══╝  ╚═╝ ╚═════╝╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝${N}"
echo -e "                    ${W}Docker Edition${N}"
echo ""
}

log()  { echo -e "  ${C}[$(date +%H:%M:%S)]${N} $1"; }
ok()   { echo -e "  ${G}[$(date +%H:%M:%S)] ✔${N} $1"; }
warn() { echo -e "  ${Y}[$(date +%H:%M:%S)] ⚠${N} $1"; }
info() { echo -e "  ${DIM}  ├─${N} $1"; }
last() { echo -e "  ${DIM}  └─${N} $1"; }
sep()  { echo -e "  ${DIM}─────────────────────────────────────────────────────────${N}"; }

banner
sep
echo -e "  ${W}SISTEMA${N}"
info "OS:          $(cat /etc/os-release 2>/dev/null | grep PRETTY | cut -d= -f2 | tr -d '\"')"
info "Hostname:    $(hostname)"
info "IP:          $(hostname -I 2>/dev/null | awk '{print $1}')"
last "Timezone:    ${TZ:-UTC}"
echo ""

# Wait for DB
sep
log "Esperando conexión a MariaDB (${VICIDIAL_DB_HOST:-db})..."
for i in $(seq 1 60); do
  if mysql -h "${VICIDIAL_DB_HOST:-db}" -u "${MYSQL_USER:-cron}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" &>/dev/null; then
    ok "MariaDB disponible"
    break
  fi
  [ "$i" -eq 60 ] && { echo -e "  ${R}✗ No se pudo conectar a MariaDB${N}"; exit 1; }
  sleep 2
done
echo ""

# Install VICIdial schema if first run
sep
echo -e "  ${W}VICIDIAL SETUP${N}"
SCHEMA_FILE="/usr/src/astguiclient/trunk/extras/MySQL_AST_CREATE_tables.sql"
if ! mysql -h "${VICIDIAL_DB_HOST:-db}" -u "${MYSQL_USER:-cron}" -p"${MYSQL_PASSWORD}" asterisk -e "SELECT count(*) FROM servers" &>/dev/null; then
  log "Primera ejecución: importando esquema VICIdial..."
  mysql -h "${VICIDIAL_DB_HOST:-db}" -u root -p"${MYSQL_ROOT_PASSWORD}" asterisk < "$SCHEMA_FILE"
  mysql -h "${VICIDIAL_DB_HOST:-db}" -u root -p"${MYSQL_ROOT_PASSWORD}" asterisk < /usr/src/astguiclient/trunk/extras/first_server_install.sql
  ok "Esquema importado"
else
  ok "Esquema ya existe"
fi

# Run VICIdial install.pl non-interactively
if [ ! -f /etc/astguiclient.conf ]; then
  log "Configurando astguiclient..."
  cat > /etc/astguiclient.conf <<EOF
PATHhome => /usr/share/astguiclient
PATHlogs => /var/log/astguiclient
PATHagi => /var/lib/asterisk/agi-bin
PATHweb => /var/www/html
PATHsounds => /var/lib/asterisk/sounds
PATHmonitor => /var/spool/asterisk/monitor
PATHDONEmonitor => /var/spool/asterisk/monitorDONE
VARserver_ip => ${SERVER_IP}
VARDB_server => ${VICIDIAL_DB_HOST:-db}
VARDB_database => asterisk
VARDB_user => ${MYSQL_USER:-cron}
VARDB_pass => ${MYSQL_PASSWORD}
VARDB_custom_user => ${MYSQL_CUSTOM_USER:-custom}
VARDB_custom_pass => ${MYSQL_CUSTOM_PASSWORD}
VARDB_port => 3306
EOF
  ok "astguiclient.conf creado"

  # Copy web files
  log "Copiando archivos web VICIdial..."
  cp -r /usr/src/astguiclient/trunk/www/agc /var/www/html/
  cp -r /usr/src/astguiclient/trunk/www/vicidial /var/www/html/
  cp /usr/src/astguiclient/trunk/www/index.html /var/www/html/ 2>/dev/null || true

  # Copy AGI scripts
  cp /usr/src/astguiclient/trunk/agi/*.agi /var/lib/asterisk/agi-bin/ 2>/dev/null || true
  cp /usr/src/astguiclient/trunk/agi/*.pl /var/lib/asterisk/agi-bin/ 2>/dev/null || true
  chmod 755 /var/lib/asterisk/agi-bin/*.agi 2>/dev/null || true
  chmod 755 /var/lib/asterisk/agi-bin/*.pl 2>/dev/null || true

  # Copy bin scripts
  mkdir -p /usr/share/astguiclient
  cp /usr/src/astguiclient/trunk/bin/* /usr/share/astguiclient/
  chmod 755 /usr/share/astguiclient/*

  ok "Archivos VICIdial instalados"
fi

# Permisos para Apache
chown -R apache:apache /var/www/html/vicidial /var/www/html/agc

# Update server IP
log "Actualizando IP del servidor..."
/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15 --server_ip="${SERVER_IP}" --DB_server="${VICIDIAL_DB_HOST:-db}" 2>/dev/null || true
ok "IP actualizada: ${SERVER_IP}"
echo ""

# Set timezone in PHP
sed -i "s|^;*date.timezone.*|date.timezone = ${TZ:-UTC}|" /etc/php.ini

# Start services
sep
echo -e "  ${W}SERVICIOS${N}"

log "Iniciando Asterisk..."
# Configure AMI users for VICIdial
cat > /etc/asterisk/manager.conf << 'AMIEOF'
[general]
enabled = yes
port = 5038
bindaddr = 0.0.0.0

[cron]
secret = 1234
read = system,call,log,verbose,agent,user,config,dtmf,reporting,cdr,dialplan
write = system,call,agent,user,config,command,reporting,originate

[listencron]
secret = 1234
read = system,call,log,verbose,agent,user,config,dtmf,reporting,cdr,dialplan
write = system,call,agent,user,config,command,reporting,originate

[sendcron]
secret = 1234
read = system,call,log,verbose,agent,user,config,dtmf,reporting,cdr,dialplan
write = system,call,agent,user,config,command,reporting,originate
AMIEOF

# Fix AMI version pattern for Asterisk 20 (AMI 9.x)
grep -rl "waitfor('/\[0123\]" /usr/share/astguiclient/ 2>/dev/null | while read f; do
  sed -i "s|waitfor('/\[0123\]|waitfor('/[0-9]|g" "$f"
done

/usr/sbin/asterisk -f &
sleep 3
if asterisk -rx "core show version" &>/dev/null; then
  ok "Asterisk activo (PID: $(pidof asterisk 2>/dev/null | awk '{print $1}'))"
else
  warn "Asterisk no respondió"
fi

# Start VICIdial keepalive processes
log "Iniciando procesos VICIdial..."
# Update asterisk version in DB
mysql -h "${VICIDIAL_DB_HOST:-db}" -u root -p"${MYSQL_ROOT_PASSWORD}" asterisk -e "UPDATE servers SET asterisk_version='20.19', rebuild_conf_files='Y' WHERE server_ip='${SERVER_IP}';" 2>/dev/null || true
mkdir -p /var/log/astguiclient

# Generate Asterisk conf from DB (SIP peers, extensions, etc)
/usr/share/astguiclient/AST_conf_update.pl 2>/dev/null
# Ensure VICIdial generated configs are included
grep -q 'sip-vicidial.conf' /etc/asterisk/sip.conf || echo '#include sip-vicidial.conf' >> /etc/asterisk/sip.conf
grep -q 'extensions-vicidial.conf' /etc/asterisk/extensions.conf 2>/dev/null || echo '#include extensions-vicidial.conf' >> /etc/asterisk/extensions.conf 2>/dev/null
asterisk -rx "sip reload" 2>/dev/null
asterisk -rx "dialplan reload" 2>/dev/null

# Cron for VICIdial keepalive (auto-generates conf when changes are made in admin panel)
cat > /var/spool/cron/root << 'CRONEOF'
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --cu3way
* * * * * /usr/share/astguiclient/AST_update.pl
CRONEOF
crond

/usr/share/astguiclient/AST_manager_listen.pl &
sleep 3
/usr/share/astguiclient/AST_manager_send.pl &
/usr/share/astguiclient/AST_VDadapt.pl &
/usr/share/astguiclient/AST_VDauto_dial.pl &
/usr/share/astguiclient/AST_VDremote_agents.pl &
/usr/share/astguiclient/AST_update.pl &
ok "Procesos VICIdial iniciados"
echo ""

# Summary
IP_ADDR="${SERVER_IP}"
sep
echo ""
echo -e "  ${G}┌─────────────────────────────────────────────────────────┐${N}"
echo -e "  ${G}│  ${W}✔ VICIdial — Listo${G}                                     │${N}"
echo -e "  ${G}│                                                         │${N}"
echo -e "  ${G}│  ${N}Admin Panel  ${C}http://${IP_ADDR}/vicidial/welcome.php${N}"
echo -e "  ${G}│  ${N}Agent Panel  ${C}http://${IP_ADDR}/agc/vicidial.php${N}"
echo -e "  ${G}│  ${N}Login        ${C}6666 / 1234${N}"
echo -e "  ${G}│  ${N}SIP          ${C}${IP_ADDR}:5060 (UDP)${N}"
echo -e "  ${G}│  ${N}RTP          ${C}10000-20000 (UDP)${N}"
echo -e "  ${G}│  ${N}MariaDB      ${C}${VICIDIAL_DB_HOST:-db}:3306${N}"
echo -e "  ${G}│                                                         │${N}"
echo -e "  ${G}└─────────────────────────────────────────────────────────┘${N}"
echo ""
echo -e "  ${DIM}Comandos útiles:${N}"
echo -e "  ${DIM}  asterisk -rvvv              CLI de Asterisk${N}"
echo -e "  ${DIM}  /usr/share/astguiclient/    Scripts VICIdial${N}"
echo ""

# Apache foreground
log "Iniciando PHP-FPM..."
mkdir -p /run/php-fpm
/usr/sbin/php-fpm --daemonize
ok "PHP-FPM activo"

# Remove default test page, add redirect to VICIdial
rm -f /etc/httpd/conf.d/welcome.conf
echo '<meta http-equiv="refresh" content="0;url=/vicidial/welcome.php">' > /var/www/html/index.html

log "Iniciando Apache (foreground)..."
exec /usr/sbin/httpd -D FOREGROUND
