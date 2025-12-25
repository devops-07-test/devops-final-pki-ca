#!/usr/bin/env bash
set -euo pipefail

PKI_BASE="/etc/pki"
PKI_DIR="$PKI_BASE/pki"
OUT_DIR="$PKI_BASE/out"

usage() {
  echo "Использование: $0 <server|client> <path_to_csr>"
  exit 1
}

[[ $# -eq 2 ]] || usage

TYPE="$1"
CSR_PATH="$2"

[[ "$TYPE" == "server" || "$TYPE" == "client" ]] || usage
[[ -f "$CSR_PATH" ]] || { echo "[!] CSR-файл не найден: $CSR_PATH"; exit 1; }
[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root или через sudo."; exit 1; }

[[ -d "$PKI_DIR" && -f "$PKI_DIR/ca.crt" && -f "$PKI_DIR/private/ca.key" ]] || {
  echo "[!] PKI/CA не найдены. Сначала запусти init_ca.sh."
  exit 1
}

[[ -x /usr/local/bin/easy-rsa ]] || { echo "[!] easy-rsa не найдена. Сначала install_ca.sh."; exit 1; }

mkdir -p "$OUT_DIR"

CSR_BASENAME="$(basename "$CSR_PATH")"
NAME="${CSR_BASENAME%.*}"
ISSUED_CRT="$PKI_DIR/issued/${NAME}.crt"
REQ_FILE="$PKI_DIR/reqs/${NAME}.req"

if [[ -f "$ISSUED_CRT" ]]; then
  echo "[!] Сертификат '$NAME' уже существует: $ISSUED_CRT"
  exit 1
fi

cd "$PKI_BASE"

echo "[*] Импортирую CSR как '$NAME'..."
cp -f "$CSR_PATH" "$REQ_FILE"
easy-rsa import-req "$REQ_FILE" "$NAME"

echo "[*] Подписываю запрос как '$TYPE' (будет запрошен пароль ключа CA)..."
easy-rsa sign-req "$TYPE" "$NAME"

[[ -f "$ISSUED_CRT" ]] || { echo "[!] Не найден результат: $ISSUED_CRT"; exit 1; }

TARGET_DIR="$OUT_DIR/$NAME"
mkdir -p "$TARGET_DIR"
cp "$ISSUED_CRT" "$TARGET_DIR/${NAME}.crt"
cp "$PKI_DIR/ca.crt" "$TARGET_DIR/ca.crt"

echo "[+] Готово: $TARGET_DIR"
