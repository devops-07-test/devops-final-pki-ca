#!/usr/bin/env bash
set -euo pipefail
umask 077

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

BACKUP_DIR="/var/backups/devops-final"
TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/devops-backup-$TS.tar.gz"
CHECKSUM="$ARCHIVE.sha256"
RETENTION=7

SOURCES=(
  "/etc/pki"
  "/etc/openvpn"
  "/etc/prometheus"
  "/etc/alertmanager"
)

mkdir -p "$BACKUP_DIR"

EXISTING_SOURCES=()
for src in "${SOURCES[@]}"; do
  if [[ -e "$src" ]]; then
    EXISTING_SOURCES+=("$src")
  else
    echo "[!] Пропускаю отсутствующий путь: $src"
  fi
done

if [[ ${#EXISTING_SOURCES[@]} -eq 0 ]]; then
  echo "[!] Нет доступных источников для бэкапа."
  exit 1
fi

echo "[*] Создаю архив: $ARCHIVE"
tar -czf "$ARCHIVE" "${EXISTING_SOURCES[@]}"

sha256sum "$ARCHIVE" > "$CHECKSUM"

COUNT=$(ls -1t "$BACKUP_DIR"/devops-backup-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COUNT" -gt "$RETENTION" ]]; then
  echo "[*] Ротация бэкапов: оставляю последние $RETENTION"
  ls -1t "$BACKUP_DIR"/devops-backup-*.tar.gz | tail -n +$((RETENTION + 1)) | while read -r old; do
    rm -f "$old" "$old.sha256"
  done
fi

echo "[+] Бэкап создан: $ARCHIVE"