#!/usr/bin/env bash
set -euo pipefail

CN_DEFAULT="vpn-server"
OUT_DIR="/etc/openvpn/pki-requests"

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

read -r -p "Common Name для серверного сертификата [$CN_DEFAULT]: " CN
CN="${CN:-$CN_DEFAULT}"

mkdir -p "$OUT_DIR"
KEY_FILE="$OUT_DIR/${CN}.key"
CSR_FILE="$OUT_DIR/${CN}.csr"

if [[ -f "$CSR_FILE" || -f "$KEY_FILE" ]]; then
  echo "[!] Файлы $KEY_FILE или $CSR_FILE уже существуют."
  read -r -p "Пересоздать (перезаписать) их? [y/N]: " ans
  case "${ans:-N}" in
    y|Y|yes|YES)
      echo "[*] Пересоздаю ключ и CSR..."
      ;;
    *)
      echo "[*] Отменено пользователем."
      exit 0
      ;;
  esac
fi

openssl req -new -newkey rsa:4096 -nodes \
  -keyout "$KEY_FILE" \
  -out "$CSR_FILE" \
  -subj "/CN=$CN"

chmod 600 "$KEY_FILE"

echo "[+] Готово."
echo "    KEY: $KEY_FILE"
echo "    CSR: $CSR_FILE"
echo
echo "Дальше:"
echo "  1) Скопировать CSR на vm-ca,"
echo "  2) Подписать: sign_csr.sh server $CSR_FILE,"
echo "  3) Вернуть подписанный сертификат на vm-vpn."