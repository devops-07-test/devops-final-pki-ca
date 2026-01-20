#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Использование: $0 stage1|all"
  exit 1
}

# Требуем root
[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0 ..."; exit 1; }

# Ровно один аргумент
[[ $# -eq 1 ]] || usage

MODE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_scripts_to_path() {
  install -m 0755 "$SCRIPT_DIR/install_ca.sh" /usr/local/sbin/install_ca.sh
  install -m 0755 "$SCRIPT_DIR/init_ca.sh"   /usr/local/sbin/init_ca.sh
  install -m 0755 "$SCRIPT_DIR/sign_csr.sh"  /usr/local/sbin/sign_csr.sh
  install -m 0755 "$SCRIPT_DIR/revoke_cert.sh" /usr/local/sbin/revoke_cert.sh
}

run_init_ca_with_retry() {
  local attempts=0
  local max_attempts=3

  while true; do
    attempts=$((attempts + 1))

    echo "[*] Stage1: CA init (попытка $attempts/$max_attempts)"
    echo "[i] Сейчас Easy-RSA запросит пароль ключа CA. Пароль обязателен."

    set +e
    /usr/local/sbin/init_ca.sh
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    echo
    echo "[!] Ошибка при создании Root CA (код: $rc)."
    echo "[!] Пароль для ключа CA обязателен — без него продолжить нельзя."
    echo "[i] Если ошибся при вводе пароля/подтверждении или CN — просто повтори."
    echo

    if [[ $attempts -ge $max_attempts ]]; then
      echo "[!] Достигнут лимит попыток ($max_attempts). Завершаю."
      return 1
    fi

    read -r -p "Повторить ввод пароля и продолжить? [y/N]: " ans
    case "${ans:-N}" in
      y|Y|yes|YES) ;;
      *) echo "[!] Остановлено пользователем."; return 1 ;;
    esac
  done
}

verify_stage1() {
  local PKI_BASE="/etc/pki"
  local PKI_DIR="$PKI_BASE/pki"

  echo "[*] Stage1: verify"

  # 1. Структура PKI
  [[ -d "$PKI_DIR" ]] || { echo "[!] FAIL: нет каталога $PKI_DIR"; return 1; }
  [[ -f "$PKI_DIR/ca.crt" ]] || { echo "[!] FAIL: нет $PKI_DIR/ca.crt"; return 1; }
  [[ -f "$PKI_DIR/private/ca.key" ]] || { echo "[!] FAIL: нет $PKI_DIR/private/ca.key"; return 1; }

  # 2. Права на ключ
  local perms
  perms="$(stat -c '%a' "$PKI_DIR/private/ca.key")"
  if [[ "$perms" != "600" && "$perms" != "400" ]]; then
    echo "[!] FAIL: права на ca.key должны быть 600 (или строже), сейчас: $perms"
    return 1
  fi

  # 3. Проверка сертификата
  if ! openssl x509 -in "$PKI_DIR/ca.crt" -noout -subject -issuer -dates >/dev/null 2>&1; then
    echo "[!] FAIL: ca.crt не читается openssl"
    return 1
  fi

  # 4. UFW должен быть активен
  if ! ufw status | grep -q "Status: active"; then
    echo "[!] FAIL: UFW не активен (ожидалось active)"
    return 1
  fi

  echo "[+] Stage1 verify: OK"
}

run_stage1() {
  echo "[*] Stage1: CA install"
  /usr/local/sbin/install_ca.sh

  echo "[*] Stage1: CA init"
  run_init_ca_with_retry

  verify_stage1
  echo "[+] Stage1 completed"
}

echo "[*] Installing scripts to /usr/local/sbin ..."
install_scripts_to_path

case "$MODE" in
  stage1) run_stage1 ;;
  all)
    run_stage1
    echo "[!] Этапы 2–6 пока не реализованы: будут добавлены последовательно по брифу."
    ;;
  *) usage ;;
esac