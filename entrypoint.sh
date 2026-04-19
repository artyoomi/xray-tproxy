#!/bin/sh
set -eu

CFG=/app/config.json

# ---- read vless.conf, strip CR/LF and remove trailing comment after # ----
if [ ! -s /app/vless.conf ]; then
  echo "vless.conf not found or empty" >&2
  exit 23
fi
VLESS_URL="$(tr -d '\r\n' < /app/vless.conf)"
VLESS_URL="${VLESS_URL%%#*}"

# ---- extract fields from URL ----
USER_ID="$(printf '%s' "$VLESS_URL" | sed -n 's#^vless://\([^@/]*\).*#\1#p')"
SERVER="$(  printf '%s' "$VLESS_URL" | sed -n 's#.*@\([^:/?]*\).*#\1#p')"
PORT_RAW="$(printf '%s' "$VLESS_URL" | sed -n 's#.*:\([0-9][0-9]*\).*#\1#p')"
PORT="$(printf '%s' "$PORT_RAW" | tr -cd '0-9')"

PUBKEY="$( printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]pbk=\([^&]*\).*#\1#p')"
SNI="$(    printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]sni=\([^&]*\).*#\1#p')"
FP="$(     printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]fp=\([^&]*\).*#\1#p')"
SID="$(    printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]sid=\([^&]*\).*#\1#p')"
SPX="$(    printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]spx=\([^&]*\).*#\1#p' | sed 's/%2F/\//g')"
FLOW="$(   printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]flow=\([^&]*\).*#\1#p')"
TYPE="$(   printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]type=\([^&]*\).*#\1#p')"
PATH_RAW="$(printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]path=\([^&]*\).*#\1#p')"
HOST_RAW="$(printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]host=\([^&]*\).*#\1#p')"
MODE="$(   printf '%s' "$VLESS_URL" | sed -n 's#.*[?&]mode=\([^&]*\).*#\1#p')"

[ -z "${FP:-}" ]  && FP="firefox"
[ -z "${SPX:-}" ] && SPX="/"
[ -z "${TYPE:-}" ] && TYPE="tcp"
XHTTP_PATH="$(printf '%s' "${PATH_RAW:-}" | sed 's/%2[Ff]/\//g')"
HOST="$(printf '%s' "${HOST_RAW:-}" | sed 's/%2[Cc]/,/g')"

# ---- minimal validation ----
[ -n "${USER_ID:-}" ] || { echo "ERR: empty USER_ID"; exit 23; }
[ -n "${SERVER:-}" ]  || { echo "ERR: empty SERVER";  exit 23; }
[ -n "${PORT:-}" ]    || { echo "ERR: empty PORT";    exit 23; }
[ -n "${PUBKEY:-}" ]  || { echo "ERR: empty PUBKEY";  exit 23; }
[ -n "${SNI:-}" ]     || { echo "ERR: empty SNI";     exit 23; }
[ -n "${SID:-}" ]     || { echo "ERR: empty SID";     exit 23; }

case "$TYPE" in
  tcp|xhttp) ;;
  *)
    echo "ERR: unsupported transport type '$TYPE' (supported: tcp, xhttp)" >&2
    exit 23
    ;;
esac

if [ "$TYPE" = "xhttp" ] && [ -z "${XHTTP_PATH:-}" ]; then
  echo "ERR: empty PATH for xhttp transport" >&2
  exit 23
fi

# Upstream used by dns-in dokodemo (must match nft OUTPUT bypass rules).
DNS_UPSTREAM="${DNS_UPSTREAM:-1.1.1.1}"
# SO_MARK on Xray outbounds so nft OUTPUT redirect skips them (avoids redirect loops).
XRAY_SO_MARK="${XRAY_SO_MARK:-255}"

# ---- build user block safely (with/without flow) ----
if [ -n "${FLOW:-}" ]; then
  USER_BLOCK=$(cat <<JSON
{
  "id": "${USER_ID}",
  "encryption": "none",
  "level": 0,
  "flow": "${FLOW}"
}
JSON
)
else
  USER_BLOCK=$(cat <<JSON
{
  "id": "${USER_ID}",
  "encryption": "none",
  "level": 0
}
JSON
)
fi

if [ "$TYPE" = "xhttp" ]; then
  XHTTP_HOST_LINE=""
  XHTTP_MODE_LINE=""
  if [ -n "${HOST:-}" ]; then
    XHTTP_HOST_LINE=$(cat <<JSON
,
          "host": "${HOST}"
JSON
)
  fi
  if [ -n "${MODE:-}" ]; then
    XHTTP_MODE_LINE=$(cat <<JSON
,
          "mode": "${MODE}"
JSON
)
  fi
  STREAM_SETTINGS_BLOCK=$(cat <<JSON
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "publicKey": "${PUBKEY}",
          "shortId": "${SID}",
          "spiderX": "${SPX}",
          "fingerprint": "${FP}",
          "serverName": "${SNI}"
        },
        "xhttpSettings": {
          "path": "${XHTTP_PATH}"${XHTTP_HOST_LINE}${XHTTP_MODE_LINE}
        },
        "sockopt": { "mark": ${XRAY_SO_MARK} }
      },
JSON
)
else
  STREAM_SETTINGS_BLOCK=$(cat <<JSON
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "publicKey": "${PUBKEY}",
          "shortId": "${SID}",
          "spiderX": "${SPX}",
          "fingerprint": "${FP}",
          "serverName": "${SNI}"
        },
        "sockopt": { "mark": ${XRAY_SO_MARK} }
      },
JSON
)
fi

# ---- generate config.json ----
cat > "$CFG" <<EOF
{
  "log": { "loglevel": "debug" },
  "inbounds": [
    {
      "tag": "tproxy-in",
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "streamSettings": {
        "sockopt": { "tproxy": "redirect" }
      }
    },
    {
      "tag": "dns-in",
      "port": 53,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "${DNS_UPSTREAM}",
        "port": 53,
        "network": "udp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${SERVER}",
            "port": ${PORT},
            "users": [
              ${USER_BLOCK}
            ]
          }
        ]
      },
${STREAM_SETTINGS_BLOCK}
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct",
      "streamSettings": { "sockopt": { "mark": ${XRAY_SO_MARK} } }
    }
  ]
}
EOF

# ---- print generated config for debugging ----
echo "===== GENERATED CONFIG ====="
cat "$CFG"
echo "============================"

echo ""
echo "== NFTABLES (transparent REDIRECT, prerouting + output) =="

# Drop policy-routing from older TPROXY-only setups (not used with REDIRECT).
while ip rule del fwmark 1 table 100 2>/dev/null; do :; done
ip route flush table 100 2>/dev/null || true

nft delete table ip xray 2>/dev/null || true

nft add table ip xray

# Destinations that must not be redirected (loopback + VLESS server).
nft add set ip xray no_tproxy '{ type ipv4_addr; flags interval; elements = { 127.0.0.0/8 } }'
for _ip in $(getent ahosts "$SERVER" 2>/dev/null | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print $1 }' | sort -u); do
  nft add element ip xray no_tproxy "{ $_ip }" 2>/dev/null || true
done

# Ingress (published ports, forwarded) — same exclusions as output.
nft add chain ip xray prerouting '{ type nat hook prerouting priority dstnat; policy accept; }'
nft add rule ip xray prerouting fib daddr type local udp dport 53 return
nft add rule ip xray prerouting fib daddr type local tcp dport 53 return
nft add rule ip xray prerouting fib daddr type local tcp dport 12345 return
nft add rule ip xray prerouting fib daddr type local udp dport 12345 return
nft add rule ip xray prerouting ip daddr @no_tproxy return
nft add rule ip xray prerouting meta l4proto tcp redirect to :12345
nft add rule ip xray prerouting meta l4proto udp redirect to :12345

# Locally originated traffic (e.g. other containers with network_mode: container:xray)
# only hits OUTPUT; TPROXY there is often unsupported, so use REDIRECT to :12345.
nft add chain ip xray output '{ type nat hook output priority dstnat; policy accept; }'
nft add rule ip xray output meta mark "${XRAY_SO_MARK}" return
nft add rule ip xray output ip daddr "${DNS_UPSTREAM}" udp dport 53 return
nft add rule ip xray output fib daddr type local udp dport 53 return
nft add rule ip xray output fib daddr type local tcp dport 53 return
nft add rule ip xray output fib daddr type local tcp dport 12345 return
nft add rule ip xray output fib daddr type local udp dport 12345 return
nft add rule ip xray output ip daddr @no_tproxy return
nft add rule ip xray output meta l4proto tcp redirect to :12345
nft add rule ip xray output meta l4proto udp redirect to :12345

nft list ruleset
echo "============================"

# ---- start Xray ----
exec /usr/local/bin/Xray run -config "$CFG"
