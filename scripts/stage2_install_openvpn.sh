#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

echo "[*] Установка OpenVPN и вспомогательных пакетов..."
apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y openvpn easy-rsa iptables-persistent

# IP forwarding (идемпотентно)
SYSCTL_FILE="/etc/sysctl.d/99-openvpn-forward.conf"
if [[ ! -f "$SYSCTL_FILE" ]]; then
  echo "[*] Включаю IP forwarding через $SYSCTL_FILE..."
  cat > "$SYSCTL_FILE" <<EOF
net.ipv4.ip_forward=1
EOF
else
  echo "[*] $SYSCTL_FILE уже существует, не перезаписываю."
fi

sysctl -q -p "$SYSCTL_FILE" || true

# UFW: открыть только если ещё нет правила
if command -v ufw >/dev/null 2>&1; then
  echo "[*] Проверяю правила UFW для OpenVPN..."
  if ! ufw status | grep -q "1194/udp"; then
    ufw allow 1194/udp
  else
    echo "[*] Правило для 1194/udp в UFW уже есть."
  fi
fi

echo "[+] stage2_install_openvpn.sh: базовая установка завершена."