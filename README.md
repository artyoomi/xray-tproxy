[![Xray Core](https://img.shields.io/badge/Xray-Core-00BFFF?style=for-the-badge)](https://github.com/XTLS/Xray-core)


# VLESS-to-HTTP/SOCKS5 proxy

A lightweight Dockerized **HTTP/HTTPS + SOCKS5 proxy** that forwards traffic through a **VLESS + Reality** server.
Designed for simplicity: paste your VLESS link into `vless.conf`, run Docker, and you're done.

---

## ✨ Features
- VLESS + Reality client (Xray-core)
- HTTP proxy inbound (works for HTTP and HTTPS via CONNECT)
- SOCKS5 proxy inbound
- Auto-generated and printed `config.json` (easy debugging)
- Minimal footprint, no host dependencies besides Docker
- Default host ports: **9000** (HTTP/HTTPS) and **1080** (SOCKS5), configurable in `docker-compose.yml`

---
## Related Projects

- [simple-xray-core](https://github.com/thejohnd0e/simple-xray-core) — a lightweight and user-friendly script for installing and managing **Xray**.  
  You can use it to easily set up your VLESS + Reality server, which works perfectly with **VLESS-to-HTTP**.
---

## 📁 Project Layout
```
VLESS-to-HTTP/
├── docker-compose.yml     # docker compose service
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
Edit `vless.conf` and paste your full VLESS URL in one line:

```
vless://UUID@HOST:PORT?security=reality&encryption=none&pbk=PUBLIC_KEY&fp=fingerprint&sni=servername&sid=shortid&spx=/&flow=xtls-rprx-vision
```

Example:
```
vless://49b4b82b-73f0-4772-86ca-ca5059375c63@45.127.127.127:443?security=reality&encryption=none&pbk=6ECfTRNxRBiv7GLIIwOhwlkDs9NyYoZ7lHZrWeU1Q&fp=firefox&sni=github.com&sid=c8aa6a68a476c885&spx=/&flow=xtls-rprx-vision
```

> Tip: keep it on a single line; comments after `#` are ignored.

---

## 🚀 Run
```bash
docker compose up -d --build
```

Logs (shows the generated config and Xray output):
```bash
docker logs -f vless-to-http
```

By default:
- HTTP/HTTPS proxy: **http://127.0.0.1:9000**
- SOCKS5 proxy: **socks5://127.0.0.1:1080**

---

## 🧪 Test
HTTP proxy (HTTPS target via CONNECT):
```bash
curl -x http://127.0.0.1:9000 https://api.ipify.org -m 10 -v
```
Expected: your VLESS server's egress IP.

Test plain HTTP (no TLS):
```bash
curl -x http://127.0.0.1:9000 http://neverssl.com -m 10 -v
```

Test SOCKS5:
```bash
curl --socks5-hostname 127.0.0.1:1080 https://api.ipify.org -m 10 -v
```

---

## 🔄 Update / Change server
1) Edit `vless.conf` with your new VLESS URL  
2) Restart:
```bash
docker compose down
docker compose up -d --build
```

---

## 🛠 Troubleshooting

- **Container restarts with code 23**
  - `vless.conf` missing or has empty/invalid mandatory parameters.
- **HTTP returns 503**
  - Usually your VLESS parameters are incorrect (pbk/sid/sni/flow).
- **TLS errors during CONNECT**
  - Verify `flow`, `fp` (fingerprint), `sni`, `pbk`, `sid` match your server.
- View the generated config section in logs between:
  - `===== GENERATED CONFIG =====` … `============================`

---

## 📜 License
MIT
