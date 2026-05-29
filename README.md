<h1 align="center">VICIdial — Dockerized</h1>

<p align="center">
  <strong>Plataforma de call center y marcador predictivo de código abierto, en contenedores.</strong><br/>
  VICIdial (SVN trunk) + Asterisk 20 + MariaDB, listos con un solo comando.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Rocky_Linux-9-10B981?style=flat-square&logo=rockylinux" alt="Rocky Linux 9"/>
  <img src="https://img.shields.io/badge/Asterisk-20-1E40AF?style=flat-square&logo=asterisk" alt="Asterisk 20"/>
  <img src="https://img.shields.io/badge/VICIdial-SVN_trunk-DC382D?style=flat-square" alt="VICIdial"/>
  <img src="https://img.shields.io/badge/MariaDB-10.11-003545?style=flat-square&logo=mariadb" alt="MariaDB 10.11"/>
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker" alt="Docker Compose"/>
</p>

---

## ¿Qué es esto?

**VICIdial** es la suite de **call center de código abierto** más extendida del mundo: corre sobre Asterisk y añade todo lo que necesita un centro de contacto profesional — **marcador predictivo** para campañas salientes, gestión de campañas entrantes/salientes/mixtas, paneles de agente y de administración por navegador, grabación de llamadas, reportes en tiempo real, listas de contactos y reglas de discado. Es el motor detrás de incontables operaciones de telemarketing, cobranza y soporte.

Su fama también incluye lo difícil que es instalarlo sobre metal: compilar Asterisk, parchear Perl, importar el esquema SQL y alinear decenas de dependencias del lado de RockyLinux/CentOS.

**Este repositorio lo Dockeriza de punta a punta:**

- 🐳 **Imagen construida desde `source/Dockerfile`** — Asterisk 20 compilado desde el código oficial sobre Rocky Linux 9, más el checkout de VICIdial vía SVN trunk.
- 🗄️ **MariaDB** con el esquema importado automáticamente en el primer arranque (`init.sql`).
- 🔧 **Modo `privileged`** para el timing de DAHDI que requiere Asterisk.
- 📜 **Scripts y `.env`** que automatizan build, arranque, logs y limpieza, y aíslan la `SERVER_IP` y los passwords.
- 🤝 **Pensado para convivir con FreePBX en el mismo host** — usa una subred y puertos desplazados (8082/8443, 5062, 12000-12100) para no chocar.

En resumen: pasas de cero a una plataforma de call center funcional con `./scripts/start.sh`, en lugar de seguir un manual de instalación de varias horas.

---

## Requisitos

- Docker + Docker Compose
- Linux (DAHDI requiere acceso al kernel → `privileged: true`)
- Mínimo: 4 cores, 8 GB RAM, SSD

## Inicio rápido

```bash
cp .env.example .env
# Editar .env → cambiar SERVER_IP y passwords

chmod +x scripts/*.sh
./scripts/start.sh
```

## Acceso

| Servicio     | URL                                         |
|--------------|---------------------------------------------|
| Admin Panel  | `http://SERVER_IP/vicidial/welcome.php`     |
| Agent Panel  | `http://SERVER_IP/agc/vicidial.php`         |
| Login        | `6666` / `1234`                             |

## Scripts

| Script              | Descripción                    |
|---------------------|--------------------------------|
| `scripts/start.sh`  | Build + levantar servicios     |
| `scripts/stop.sh`   | Detener servicios              |
| `scripts/logs.sh`   | Ver logs (arg: nombre servicio)|
| `scripts/clean.sh`  | Eliminar todo (volúmenes incl.)|

## Puertos

- `80` — Web (HTTP)
- `443` — Web (HTTPS)
- `5060` — SIP (UDP/TCP)
- `10000-10100` — RTP (UDP)

## Notas

- El contenedor corre en modo `privileged` para DAHDI timing
- Primera ejecución importa el esquema SQL automáticamente
- Cambiar password admin inmediatamente después del primer login
- Para producción con +25 agentes, considerar cluster multi-servidor

## Estructura

```
vicidial/
├── compose.yml
├── .env / .env.example
├── config/
│   └── mariadb/
│       ├── init.sql
│       └── my.cnf
├── scripts/
│   ├── start.sh
│   ├── stop.sh
│   ├── logs.sh
│   └── clean.sh
└── source/
    ├── Dockerfile
    └── entrypoint.sh
```
