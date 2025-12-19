#!/usr/bin/env bash
set -euo pipefail

# install_ca.sh – подготовка сервера под удостоверяющий центр (CA)

# 1. Проверка root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Этот скрипт нужно запускать от root или через sudo."
  exit 1
fi

echo "[*] Обновление пакетов..."
apt update -y

echo "[*] Установка зависимостей: easy-rsa, openssl, ufw..."
DEBIAN_FRONTEND=noninteractive apt install -y easy-rsa openssl ufw

# 2. Каталог /etc/pki
PKI_BASE="/etc/pki"

if [[ ! -d "$PKI_BASE" ]]; then
  echo "[*] Создаю каталог $PKI_BASE..."
  mkdir -p "$PKI_BASE"
  chown root:root "$PKI_BASE"
  chmod 700 "$PKI_BASE"
else
  echo "[*] Каталог $PKI_BASE уже существует, пропускаю создание."
fi

# 3. Symlink на easy-rsa
if [[ ! -x /usr/local/bin/easy-rsa ]]; then
  if [[ -x /usr/share/easy-rsa/easyrsa ]]; then
    echo "[*] Создаю symlink /usr/local/bin/easy-rsa -> /usr/share/easy-rsa/easyrsa..."
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin/easy-rsa
  else
    echo "[!] Не найден /usr/share/easy-rsa/easyrsa. Проверь установку пакета easy-rsa."
    exit 1
  fi
else
  echo "[*] Symlink /usr/local/bin/easy-rsa уже существует, пропускаю."
fi

# 4. Базовый firewall
echo "[*] Настраиваю UFW..."
ufw default deny incoming
ufw default allow outgoing

# Разрешаем только SSH (22/tcp)
ufw allow ssh

# Включаем UFW, если ещё не включен
if ufw status | grep -q "Status: inactive"; then
  echo "y" | ufw enable
else
  echo "[*] UFW уже активен, правила обновлены."
fi

echo "[+] Базовая подготовка CA-сервера завершена."
echo "    Каталог PKI: $PKI_BASE"
echo "    Команда easy-rsa доступна как: easy-rsa"
