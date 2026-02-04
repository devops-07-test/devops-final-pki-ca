#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

SERVICE_FILE="/etc/systemd/system/devops-backup.service"
TIMER_FILE="/etc/systemd/system/devops-backup.timer"

if [[ ! -x /usr/local/sbin/stage4_run_backup.sh ]]; then
  echo "[!] stage4_run_backup.sh не найден в /usr/local/sbin. Запусти bootstrap.sh stage4 для установки."
  exit 1
fi

cat > "$SERVICE_FILE" <<'SERVICE'
[Unit]
Description=DevOps Final Backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/stage4_run_backup.sh
SERVICE

cat > "$TIMER_FILE" <<'TIMER'
[Unit]
Description=Daily DevOps Final Backup

[Timer]
OnCalendar=*-*-* 03:30:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now devops-backup.timer

systemctl --no-pager --full status devops-backup.timer | sed -n '1,5p' || true

echo "[+] stage4_configure_backup.sh: таймер бэкапов настроен."