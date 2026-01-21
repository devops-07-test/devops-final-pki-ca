#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Использование: $0 <basename> (без .crt)"
  exit 1
fi

NAME="$1"
PKI_DIR="/etc/openvpn/pki"

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

SRC_DIR="/root/${NAME}-signed"   # сюда админ кладёт файлы с vm-ca
SERVER_CRT="$SRC_DIR/${NAME}.crt"
CA_CRT="$SRC_DIR/ca.crt"

[[ -f "$SERVER_CRT" ]] || { echo "[!] Не найден $SERVER_CRT"; exit 1; }
[[ -f "$CA_CRT" ]]     || { echo "[!] Не найден $CA_CRT"; exit 1; }

mkdir -p "$PKI_DIR"

cp "$SERVER_CRT" "$PKI_DIR/server.crt"
cp "$CA_CRT"     "$PKI_DIR/ca.crt"

chmod 644 "$PKI_DIR/"*.crt

echo "[+] Серверный сертификат и CA размещены в $PKI_DIR:"
ls -l "$PKI_DIR"