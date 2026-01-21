#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

SERVER_CONF="/etc/openvpn/server.conf"
PKI_DIR="/etc/openvpn/pki"

[[ -f "$PKI_DIR/server.crt" ]] || { echo "[!] Нет $PKI_DIR/server.crt"; exit 1; }
[[ -f "$PKI_DIR/ca.crt"     ]] || { echo "[!] Нет $PKI_DIR/ca.crt"; exit 1; }

# Определяем ключ сервера
if [[ -f "/etc/openvpn/pki-requests/vpn-server.key" ]]; then
  KEY_FILE="/etc/openvpn/pki-requests/vpn-server.key"
else
  KEY_FILE="$PKI_DIR/server.key"
fi

[[ -f "$KEY_FILE" ]] || { echo "[!] Не найден приватный ключ сервера ($KEY_FILE)"; exit 1; }

# server.conf — идемпотентно: если уже есть, спрашиваем
if [[ -f "$SERVER_CONF" ]]; then
  echo "[*] $SERVER_CONF уже существует."
  read -r -p "Перезаписать конфигурацию OpenVPN? [y/N]: " ans
  case "${ans:-N}" in
    y|Y|yes|YES) echo "[*] Перезаписываю $SERVER_CONF..." ;;
    *) echo "[*] Использую существующий $SERVER_CONF, скрипт завершён."; exit 0 ;;
  esac
else
  echo "[*] Создаю $SERVER_CONF..."
fi

cat > "$SERVER_CONF" <<EOF
port 1194
proto udp
dev tun

ca   $PKI_DIR/ca.crt
cert $PKI_DIR/server.crt
key  $KEY_FILE
dh none
tls-version-min 1.2
cipher AES-256-GCM
user nobody
group nogroup

topology subnet
server 10.8.0.0 255.255.255.0

ifconfig-pool-persist ipp.txt

keepalive 10 120
persist-key
persist-tun

status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

chmod 600 "$SERVER_CONF"

# NAT — проверяем, есть ли уже правило
echo "[*] Настраиваю NAT для сети 10.8.0.0/24..."

WAN_IF="$(ip -4 route show default | awk '/default/ {print $5; exit}')"
: "${WAN_IF:?Не удалось определить внешний интерфейс}"

RULE_EXISTS=$(iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$WAN_IF" -j MASQUERADE 2>/dev/null || echo "no")
if [[ "$RULE_EXISTS" == "no" ]]; then
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$WAN_IF" -j MASQUERADE
else
  echo "[*] Правило MASQUERADE уже существует."
fi

netfilter-persistent save || true

echo "[*] Включаю и перезапускаю OpenVPN (openvpn@server)..."
systemctl enable openvpn@server
systemctl restart openvpn@server

echo "[+] stage2_configure_openvpn.sh: OpenVPN запущен."