#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

PROM_CONFIG="/etc/prometheus/prometheus.yml"
TARGETS_FILE="/etc/prometheus/targets.yml"
RULES_DIR="/etc/prometheus/rules"
RULES_FILE="$RULES_DIR/alerts.yml"
ALERTMANAGER_CONFIG="/etc/alertmanager/alertmanager.yml"

if ! command -v prometheus >/dev/null 2>&1; then
  echo "[!] Prometheus не установлен. Сначала запусти stage3_install_monitoring.sh."
  exit 1
fi

mkdir -p "$RULES_DIR"

if [[ ! -f "$TARGETS_FILE" ]]; then
  cat > "$TARGETS_FILE" <<'TARGETS'
- targets:
  - "127.0.0.1:9100"
  labels:
    role: "monitor"
- targets:
  - "10.10.10.10:9100"
  labels:
    role: "vm-ca"
- targets:
  - "10.10.10.11:9100"
  labels:
    role: "vm-vpn"
- targets:
  - "10.10.10.12:9100"
  labels:
    role: "vm-backup"
TARGETS
  echo "[*] Создан $TARGETS_FILE с примером целей. Обнови IP-адреса под свою инфраструктуру."
else
  echo "[*] $TARGETS_FILE уже существует, не перезаписываю."
fi

if [[ ! -f "$RULES_FILE" ]]; then
  cat > "$RULES_FILE" <<'RULES'
groups:
  - name: base-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Инстанс недоступен"
          description: "{{ $labels.instance }} не отвечает более 2 минут."
RULES
else
  echo "[*] $RULES_FILE уже существует, не перезаписываю."
fi

if [[ ! -f "$ALERTMANAGER_CONFIG" ]]; then
  cat > "$ALERTMANAGER_CONFIG" <<'ALERTS'
route:
  receiver: "null"

receivers:
  - name: "null"
ALERTS
  echo "[*] Создан минимальный конфиг Alertmanager (получатель null)."
else
  echo "[*] $ALERTMANAGER_CONFIG уже существует, не перезаписываю."
fi

if [[ ! -f "$PROM_CONFIG" ]]; then
  cat > "$PROM_CONFIG" <<'PROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["127.0.0.1:9093"]

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:9090"]

  - job_name: "node-exporter"
    file_sd_configs:
      - files: ["/etc/prometheus/targets.yml"]
        refresh_interval: 1m
PROM
  echo "[*] Создан $PROM_CONFIG."
else
  echo "[*] $PROM_CONFIG уже существует, не перезаписываю."
fi

echo "[*] Перезапускаю службы monitoring..."
systemctl enable --now prometheus alertmanager prometheus-node-exporter
systemctl restart prometheus alertmanager prometheus-node-exporter

systemctl --no-pager --full status prometheus alertmanager prometheus-node-exporter | sed -n '1,5p' || true

echo "[+] stage3_configure_prometheus.sh: конфигурация применена."