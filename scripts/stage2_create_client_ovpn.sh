#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Использование: $0 <client-name>"
  exit 1
fi

NAME="$1"
OUT_DIR="/etc/openvpn/clients/$NAME"
PKI_DIR="/etc/openvpn/pki"

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0"; exit 1; }

CA_CRT="$PKI_DIR/ca.crt"
CLIENT_CRT="$PKI_DIR/${NAME}.crt"
CLIENT_KEY="$PKI_DIR/${NAME}.key"

[[ -f "$CA_CRT"     ]] || { echo "[!] Нет $CA_CRT"; exit 1; }
[[ -f "$CLIENT_CRT" ]] || { echo "[!] Нет $CLIENT_CRT"; exit 1; }
[[ -f "$CLIENT_KEY" ]] || { echo "[!] Нет $CLIENT_KEY"; exit 1; }

mkdir -p "$OUT_DIR"

OVPN_FILE="$OUT_DIR/${NAME}.ovpn"
if [[ -f "$OVPN_FILE" ]]; then
  echo "[*] Профиль $OVPN_FILE уже существует."
  read -r -p "Перезаписать? [y/N]: " ans
  case "${ans:-N}" in
    y|Y|yes|YES) echo "[*] Перезаписываю $OVPN_FILE..." ;;
    *) echo "[*] Оставляю существующий файл."; exit 0 ;;
  esac
fi

read -r -p "Публичный адрес/домен OpenVPN-сервера: " VPN_REMOTE

cat > "$OVPN_FILE" <<EOF
client
dev tun
proto udp
remote $VPN_REMOTE 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
$(cat "$CA_CRT")
</ca>

<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "$CLIENT_CRT")
</cert>

<key>
$(cat "$CLIENT_KEY")
</key>
EOF

chmod 600 "$OVPN_FILE"
echo "[+] Клиентский профиль создан: $OVPN_FILE"