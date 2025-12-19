#!/usr/bin/env bash
set -euo pipefail

# sign_csr.sh – подпись server/client CSR на CA-сервере

PKI_BASE="/etc/pki"
PKI_DIR="$PKI_BASE/pki"
OUT_DIR="$PKI_BASE/out"

usage() {
  echo "Использование: $0 <server|client> <path-to-csr>"
  exit 1
}

# 1. Проверка аргументов
if [[ $# -ne 2 ]]; then
  usage
fi

TYPE="$1"
CSR_PATH="$2"

if [[ "$TYPE" != "server" && "$TYPE" != "client" ]]; then
  echo "[!] Первый аргумент должен быть 'server' или 'client'."
  usage
fi

if [[ ! -f "$CSR_PATH" ]]; then
  echo "[!] CSR-файл не найден: $CSR_PATH"
  exit 1
fi

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

mkdir -p "$OUT_DIR"

# 3. Имя сертификата по имени файла CSR
CSR_BASENAME="$(basename "$CSR_PATH")"
NAME="${CSR_BASENAME%.*}"

ISSUED_CRT="$PKI_DIR/issued/${NAME}.crt"

if [[ -f "$ISSUED_CRT" ]]; then
  echo "[!] Сертификат для имени '$NAME' уже существует: $ISSUED_CRT"
  echo "    Удали или переименуй существующий сертификат, если нужно выдать новый."
  exit 1
fi

echo "[*] Импортирую CSR '$CSR_PATH' как имя '$NAME'..."
cd "$PKI_BASE"

# Копируем CSR в pki/reqs для наглядности
cp "$CSR_PATH" "$PKI_DIR/reqs/${NAME}.req"

# 4. Подпись CSR
echo "[*] Подписываю запрос как тип '$TYPE'..."
echo "    Будет запрошен пароль ключа CA."

easy-rsa import-req "$PKI_DIR/reqs/${NAME}.req" "$NAME"
easy-rsa sign-req "$TYPE" "$NAME"

# 5. Копирование результата в удобное место
if [[ ! -f "$ISSUED_CRT" ]]; then
  echo "[!] Ожидаемый сертификат не найден: $ISSUED_CRT"
  exit 1
fi

TARGET_DIR="$OUT_DIR/$NAME"
mkdir -p "$TARGET_DIR"

cp "$ISSUED_CRT" "$TARGET_DIR/${NAME}.crt"
cp "$PKI_DIR/ca.crt" "$TARGET_DIR/ca.crt"

echo "[+] Сертификат успешно выдан."
echo "    Тип:       $TYPE"
echo "    Имя:       $NAME"
echo "    CA CRT:    $PKI_DIR/ca.crt"
echo "    Issued CRT:$ISSUED_CRT"
echo "    Файлы для передачи лежат в: $TARGET_DIR"
