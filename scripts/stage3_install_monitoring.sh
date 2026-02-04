#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

echo "[*] Установка Prometheus, Alertmanager и Node Exporter..."
apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y prometheus alertmanager prometheus-node-exporter

if command -v ufw >/dev/null 2>&1; then
  echo "[*] Проверяю правила UFW для мониторинга..."
  if ! ufw status | grep -q "9090/tcp"; then
    ufw allow 9090/tcp
  fi
  if ! ufw status | grep -q "9093/tcp"; then
    ufw allow 9093/tcp
  fi
  if ! ufw status | grep -q "9100/tcp"; then
    ufw allow 9100/tcp
  fi
fi

echo "[+] stage3_install_monitoring.sh: установка завершена."
