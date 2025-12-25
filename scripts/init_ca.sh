#!/usr/bin/env bash
set -euo pipefail umask 077

# init_ca.sh – инициализация PKI и создание Root CA

PKI_BASE="/etc/pki"
PKI_DIR="$PKI_BASE/pki"
VARS_FILE="$PKI_BASE/vars"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Этот скрипт нужно запускать от root или через sudo."
  exit 1
fi

if [[ ! -x /usr/local/bin/easy-rsa ]]; then
  echo "[!] Команда easy-rsa не найдена. Сначала запусти install_ca.sh."
  exit 1
fi

mkdir -p "$PKI_BASE"
cd "$PKI_BASE"

# Если CA уже есть – выходим
if [[ -d "$PKI_DIR" && -f "$PKI_DIR/ca.crt" ]]; then
  echo "[*] PKI уже инициализирована, CA-сертификат найден: $PKI_DIR/ca.crt"
  exit 0
fi

echo "[*] Инициализирую PKI в $PKI_DIR ..."
easy-rsa init-pki

# vars – политика PKI
if [[ ! -f "$VARS_FILE" ]]; then
  echo "[*] Создаю файл vars..."
  cat > "$VARS_FILE" << 'EOF'
set_var EASYRSA_REQ_COUNTRY    "RU"
set_var EASYRSA_REQ_PROVINCE   "Moscow"
set_var EASYRSA_REQ_CITY       "Moscow"
set_var EASYRSA_REQ_ORG        "DevOps-Final-Project"
set_var EASYRSA_REQ_EMAIL      "admin@devops.local"
set_var EASYRSA_REQ_OU         "Infrastructure"

set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"

set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    825
EOF
else
  echo "[*] Файл vars уже существует, не перезаписываю."
fi

echo "[*] Создаю Root CA (build-ca)..."
echo "    Введи пароль для ключа CA (минимум 4 символа) и CN: DevOps-Final-Root-CA"

easy-rsa build-ca

echo "[+] Root CA создан."
echo "    Сертификат: $PKI_DIR/ca.crt"
echo "    Ключ:       $PKI_DIR/private/ca.key"
