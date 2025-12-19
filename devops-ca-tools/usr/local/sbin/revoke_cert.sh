#!/usr/bin/env bash
set -euo pipefail

# revoke_cert.sh – отзыв сертификата и обновление CRL на CA-сервере

PKI_BASE="/etc/pki"
PKI_DIR="$PKI_BASE/pki"

usage() {
  echo "Использование: $0 <common-name>"
  exit 1
}

# 1. Аргументы
if [[ $# -ne 1 ]]; then
  usage
fi

NAME="$1"

# 2. Проверка окружения
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Этот скрипт нужно запускать от root или через sudo."
  exit 1
fi

if [[ ! -d "$PKI_DIR" || ! -f "$PKI_DIR/ca.crt" || ! -f "$PKI_DIR/private/ca.key" ]]; then
  echo "[!] PKI не инициализирована или отсутствует CA. Сначала запусти init_ca.sh."
  exit 1
fi

if [[ ! -x /usr/local/bin/easy-rsa ]]; then
  echo "[!] Команда easy-rsa не найдена. Сначала запусти install_ca.sh."
  exit 1
fi

ISSUED_CRT="$PKI_DIR/issued/${NAME}.crt"

if [[ ! -f "$ISSUED_CRT" ]]; then
  echo "[!] Сертификат для имени '$NAME' не найден: $ISSUED_CRT"
  echo "    Проверь имя (Common Name) или список сертификатов в $PKI_DIR/issued."
  exit 1
fi

echo "[*] Отзываю сертификат с именем '$NAME'..."
cd "$PKI_BASE"

# 3. Отзыв сертификата
echo "yes" | easy-rsa revoke "$NAME"

# 4. Генерация CRL
echo "[*] Генерирую новый CRL..."
easy-rsa gen-crl

CRL_FILE="$PKI_DIR/crl.pem"

if [[ ! -f "$CRL_FILE" ]]; then
  echo "[!] Файл CRL не найден: $CRL_FILE"
  exit 1
fi

chmod 644 "$CRL_FILE"

echo "[+] Сертификат '$NAME' отозван."
echo "    Обновлённый CRL: $CRL_FILE"
