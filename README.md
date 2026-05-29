<h1 align="center">VICIdial — Dockerized</h1>

<p align="center">
  <strong>Open-source call center & predictive dialer, in containers.</strong><br/>
  VICIdial (SVN trunk) + Asterisk 20 + MariaDB, ready with a single command.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Rocky_Linux-9-10B981?style=flat-square&logo=rockylinux" alt="Rocky Linux 9"/>
  <img src="https://img.shields.io/badge/Asterisk-20-1E40AF?style=flat-square&logo=asterisk" alt="Asterisk 20"/>
  <img src="https://img.shields.io/badge/VICIdial-SVN_trunk-DC382D?style=flat-square" alt="VICIdial"/>
  <img src="https://img.shields.io/badge/MariaDB-10.11-003545?style=flat-square&logo=mariadb" alt="MariaDB 10.11"/>
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker" alt="Docker Compose"/>
</p>

---

## What is this?

**VICIdial** is the world's most widely deployed **open-source call center** suite: it runs on top of Asterisk and adds everything a professional contact center needs — a **predictive dialer** for outbound campaigns, inbound/outbound/blended campaign management, browser-based agent and admin panels, call recording, real-time reports, contact lists, and dialing rules. It's the engine behind countless telemarketing, collections, and support operations.

Its reputation also includes how painful it is to install on bare metal: compiling Asterisk, patching Perl, importing the SQL schema, and lining up dozens of RockyLinux/CentOS-side dependencies.

**This repository Dockerizes it end to end:**

- 🐳 **An image built from `source/Dockerfile`** — Asterisk 20 compiled from official source on Rocky Linux 9, plus the VICIdial checkout via SVN trunk.
- 🗄️ **MariaDB** with the schema imported automatically on first boot (`init.sql`).
- 🔧 **`privileged` mode** for the DAHDI timing Asterisk requires.
- 📜 **Scripts and `.env`** that automate build, startup, logs, and cleanup, and isolate `SERVER_IP` and passwords.
- 🤝 **Designed to coexist with FreePBX on the same host** — it uses its own subnet and shifted ports (8082/8443, 5062, 12000-12100) to avoid clashes.

In short: you go from zero to a working call center platform with `./scripts/start.sh`, instead of following a multi-hour install guide.

---

## Requirements

- Docker + Docker Compose
- Linux (DAHDI needs kernel access → `privileged: true`)
- Minimum: 4 cores, 8 GB RAM, SSD

## Quickstart

```bash
cp .env.example .env
# Edit .env → set SERVER_IP and passwords

chmod +x scripts/*.sh
./scripts/start.sh
```

## Access

| Service      | URL                                            |
|--------------|------------------------------------------------|
| Admin Panel  | `http://SERVER_IP:8082/vicidial/welcome.php`   |
| Agent Panel  | `http://SERVER_IP:8082/agc/vicidial.php`       |
| Login        | `6666` / `1234`                                |

## Scripts

| Script              | Description                       |
|---------------------|-----------------------------------|
| `scripts/start.sh`  | Build + start services            |
| `scripts/stop.sh`   | Stop services                     |
| `scripts/logs.sh`   | View logs (arg: service name)     |
| `scripts/clean.sh`  | Remove everything (incl. volumes) |

## Ports

Host ports are shifted so VICIdial can coexist with FreePBX on the same machine (see `compose.yml`). Use the **Host** column when connecting from outside the container.

| Host        | Container    | Protocol | Service        |
|:------------|:-------------|:---------|:---------------|
| 8082        | 80           | TCP      | Web (HTTP)     |
| 8443        | 443          | TCP      | Web (HTTPS)    |
| 5062        | 5060         | UDP/TCP  | SIP signaling  |
| 12000-12100 | 10000-10100  | UDP      | RTP (audio)    |

## Notes

- The container runs in `privileged` mode for DAHDI timing
- The first run imports the SQL schema automatically
- Change the admin password immediately after the first login
- For production with 25+ agents, consider a multi-server cluster

## Structure

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
