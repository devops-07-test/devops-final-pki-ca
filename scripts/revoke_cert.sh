#!/usr/bin/env bash
set -euo pipefail

PKI_BASE="/etc/pki"
PKI_DIR="$PKI_BASE/pki"

usage() {
  echo "Использование: $0 <common-name>"
  exit 1
}

[[ $# -eq 1 ]] || usage
NAME="$1"

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root или через sudo."; exit 1; }
[[ -x /usr/local/bin/easy-rsa ]] || { echo "[!] easy-rsa не найдена. Сначала install_ca.sh."; exit 1; }

[[ -d "$PKI_DIR" && -f "$PKI_DIR/ca.crt" && -f "$PKI_DIR/private/ca.key" ]] || {
  echo "[!] PKI/CA не найдены. Сначала запусти init_ca.sh."
  exit 1
}

ISSUED_CRT="$PKI_DIR/issued/${NAME}.crt"
[[ -f "$ISSUED_CRT" ]] || { echo "[!] Сертификат не найден: $ISSUED_CRT"; exit 1; }

cd "$PKI_BASE"

echo "[*] Отзываю сертификат '$NAME' (будет запрошен пароль ключа CA)..."
echo "yes" | easy-rsa revoke "$NAME"

echo "[*] Генерирую новый CRL..."
easy-rsa gen-crl

CRL_FILE="$PKI_DIR/crl.pem"
[[ -f "$CRL_FILE" ]] || { echo "[!] CRL не найден: $CRL_FILE"; exit 1; }
chmod 644 "$CRL_FILE"

echo "[+] Отзыв выполнен, CRL обновлён: $CRL_FILE"
