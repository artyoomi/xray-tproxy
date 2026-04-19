[![Xray Core](https://img.shields.io/badge/Xray-Core-00BFFF?style=for-the-badge)](https://github.com/XTLS/Xray-core)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-2ea44f?style=for-the-badge)](./LICENSE)



# VLESS transparent proxy

A lightweight Dockerized **transparent proxy** that forwards all in network traffic
in associated network through a **VLESS + Reality** server. Designed for simplicity:
paste your VLESS link into `vless.conf`, run Docker, and you're done. It is used in
a cluster with other containers that need to proxy all their traffic.

---

## ✨ Features
- VLESS + Reality client (Xray-core)
- Supports `tcp` and `xhttp` transports
- Auto-generated and printed `config.json` (easy debugging)
- Minimal footprint, no host dependencies besides Docker

---

## 📁 Project Layout
```
VLESS-to-HTTP/
├── compose.yaml           # docker compose service
├── Dockerfile             # image build (Xray installation)
├── entrypoint.sh          # parses vless.conf → generates config.json
└── vless.conf             # your VLESS Reality URL (single line)
```

---

## ✅ Requirements
- Docker & Docker Compose
  ```bash
  docker --version
  docker compose version
  ```

---

## ⚙️ Configure
Add `vless.conf` and paste your full VLESS URL in one line:

TCP example:
```bash
vless://UUID@HOST:PORT?security=reality&encryption=none&pbk=PUBLIC_KEY&fp=fingerprint&sni=servername&sid=shortid&spx=/&flow=xtls-rprx-vision
```

XHTTP example:
```bash
vless://UUID@HOST:PORT?security=reality&encryption=none&type=xhttp&path=%2Fmy-path&host=example.com&sni=example.com&pbk=PUBLIC_KEY&sid=SHORT_ID&fp=chrome&mode=auto
```

Supported transport query parameters:
- `type=tcp` or `type=xhttp` (`tcp` is the default if omitted)
- For `xhttp`, `path` is required
- For `xhttp`, `host` and `mode` are optional

Example:
```
vless://49b4b82b-73f0-4772-86ca-ca5059375c63@45.127.127.127:443?security=reality&encryption=none&pbk=6ECfTRNxRBiv7GLIIwOhwlkDs9NyYoZ7lHZrWeU1Q&fp=firefox&sni=github.com&sid=c8aa6a68a476c885&spx=/&flow=xtls-rprx-vision
```

> Tip: keep it on a single line; comments after `#` are ignored.

---

## 🚀 Run
```bash
docker compose up --build
```

Logs (shows the generated config and Xray output):
```bash
docker logs -f xray-proxy
```

---

## 🧪 Test

To test you need to start your app container with this proxy container together.

For example, you can add compose.override-proxy.yaml to your project with such
layout:
```
include:
  - path: xray-tproxy/compose.yaml
    project_directory: xray-tproxy

services:
  builder:
    network_mode: "container:xray-tproxy"
    depends_on:
      - xray-tproxy
```
After that your builder service will become member of xray-tproxy container net
and as a result, all its traffic will go through a proxy.

You can find example of such layout [here](https://github.com/artyoomi/bananapi-f3-image/tree/scarthgap).

---

## 🔄 Update / Change server
1) Edit `vless.conf` with your new VLESS URL  
2) Restart:
```bash
docker compose down
docker compose up --build
```

---

## 🛠 Troubleshooting

- **Container restarts with code 23**
  - `vless.conf` missing or has empty/invalid mandatory parameters.
- **Container exits with `ERR: empty PATH for xhttp transport`**
  - Add `path=...` to the VLESS URL when `type=xhttp`.
- **TLS errors during CONNECT**
  - Verify `flow`, `fp` (fingerprint), `sni`, `pbk`, `sid` match your server.
- View the generated config section in logs between:
  - `===== GENERATED CONFIG =====` … `============================`

---

## 📜 License
MIT
